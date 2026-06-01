import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/item_model.dart';
import '../../domain/providers/game_provider.dart';
import '../../domain/providers/multiplayer_provider.dart';
import '../../domain/providers/room_provider.dart';
import '../widgets/hud/item_slot.dart';
import '../widgets/sudoku/sudoku_grid.dart';
import '../widgets/sudoku/number_pad.dart';
import 'result_screen.dart';

class MultiplayerGameScreen extends ConsumerStatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  ConsumerState<MultiplayerGameScreen> createState() =>
      _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState
    extends ConsumerState<MultiplayerGameScreen> {
  Timer? _timer;
  Timer? _penaltyTimer;
  Timer? _blindTimer;
  Timer? _freezeTimer;
  Timer? _overtimeTimer;
  Timer? _itemEventTimer;

  Duration _elapsed = Duration.zero;
  bool _gameEnded = false;

  // 아이템 이벤트 중복 처리 방지
  final Set<String> _processedEventIds = {};
  DateTime _lastEventCheck = DateTime.now().toUtc().subtract(const Duration(seconds: 10));

  // cleanup 경쟁 조건 방어: 스트림이 빈 값을 emit해도 마지막 유효 상태 보존
  List<OpponentState> _lastKnownOpponentStates = [];

  // 아이템 타겟 선택 모드: 선택된 슬롯 인덱스
  int? _selectedItemSlot;

  // 인라인 알림
  String? _notifText;
  Color _notifColor = Colors.black;
  Timer? _notifTimer;

  // 플레이어 게이지 GlobalKey (비행 애니메이션용)
  final Map<String, GlobalKey> _gaugeKeys = {};

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game != null && !game.isCompleted) {
        setState(() {
          _elapsed = DateTime.now().difference(game.startedAt);
        });
      }
    });

    final gameNotifier = ref.read(gameProvider.notifier);
    gameNotifier.onProgressChanged = _onProgressChanged;
    gameNotifier.onItemCollected = (item) {
      if (mounted) _showNotif('${item.emoji} ${item.name} 획득!', Colors.indigo);
    };

    // 2초마다 나를 타겟으로 한 아이템 이벤트 확인
    _itemEventTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _checkIncomingItemEvents();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _penaltyTimer?.cancel();
    _blindTimer?.cancel();
    _freezeTimer?.cancel();
    _overtimeTimer?.cancel();
    _itemEventTimer?.cancel();
    _notifTimer?.cancel();
    ref.read(gameProvider.notifier).onProgressChanged = null;
    ref.read(gameProvider.notifier).onItemCollected = null;
    ref.read(memoModeProvider.notifier).state = false;
    super.dispose();
  }

  // ────────────────────────────────────────────────
  //  아이템 이벤트 수신
  // ────────────────────────────────────────────────

  Future<void> _checkIncomingItemEvents() async {
    if (!mounted) return;
    final gameId = ref.read(currentGameIdProvider);
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (gameId == null || playerId == null) return;

    final eventRepo = ref.read(eventRepositoryProvider);
    try {
      final events = await eventRepo.fetchItemEventsAfter(
            gameId: gameId,
            myPlayerId: playerId,
            after: _lastEventCheck,
          );

      if (!mounted) return;
      _lastEventCheck = DateTime.now().toUtc();

      for (final event in events) {
        final id = event['id'] as String? ?? '';
        if (_processedEventIds.contains(id)) continue;
        _processedEventIds.add(id);
        _applyItemEvent(event);
      }
    } catch (_) {}
  }

  void _applyItemEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final payload = event['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final itemType = ItemTypeX.fromDbKey(payload['item_type'] as String? ?? '');
    if (itemType == null) return;

    final duration = (payload['duration'] as num?)?.toInt() ?? 5;
    final senderId = event['player_id'] as String? ?? '';
    final myId = ref.read(currentPlayerProvider)?.id ?? '';

    if (senderId.isNotEmpty && myId.isNotEmpty) {
      _startFlyAnim(itemType.emoji, senderId, myId);
    }

    switch (itemType) {
      case ItemType.blind:
        final shielded = ref.read(gameProvider)?.isShielded ?? false;
        if (shielded) {
          ref.read(gameProvider.notifier).consumeShield();
          if (mounted) _showNotif('🛡️ 방어막이 블라인드를 막았습니다!', Colors.green);
        } else {
          ref.read(gameProvider.notifier).applyBlind(duration);
          _startBlindCountdown();
          if (mounted) {
            final boxNum = (ref.read(gameProvider)?.blindedBoxIndex ?? 0) + 1;
            _showNotif('🌫️ $boxNum번 박스 블라인드! ($duration초)', Colors.deepPurple);
          }
        }
      case ItemType.freeze:
        final shielded = ref.read(gameProvider)?.isShielded ?? false;
        if (shielded) {
          ref.read(gameProvider.notifier).consumeShield();
          if (mounted) _showNotif('🛡️ 방어막이 프리즈를 막았습니다!', Colors.green);
        } else {
          ref.read(gameProvider.notifier).applyFreeze(duration);
          _startFreezeCountdown();
          if (mounted) _showNotif('⏸️ 프리즈 당했습니다!', Colors.indigo);
        }
      case ItemType.itemCut:
        final shielded = ref.read(gameProvider)?.isShielded ?? false;
        if (shielded) {
          ref.read(gameProvider.notifier).consumeShield();
          if (mounted) _showNotif('🛡️ 방어막이 아이템 커터를 막았습니다!', Colors.green);
        } else {
          final removed = ref.read(gameProvider.notifier).removeFirstItem();
          if (mounted) {
            final msg = removed != null
                ? '✂️ ${removed.emoji} ${removed.name}이(가) 제거됐습니다!'
                : '✂️ 아이템 커터! 제거할 아이템이 없었습니다.';
            _showNotif(msg, Colors.deepOrange);
          }
        }
      case ItemType.reverse:
        final shielded = ref.read(gameProvider)?.isShielded ?? false;
        if (shielded) {
          ref.read(gameProvider.notifier).consumeShield();
          if (mounted) _showNotif('🛡️ 방어막이 리버스를 막았습니다!', Colors.green);
        } else {
          ref.read(gameProvider.notifier).applyReverse();
          if (mounted) _showNotif('💥 리버스! 맞은 칸 하나가 지워졌습니다!', Colors.red);
        }
      case ItemType.hint:
      case ItemType.shield:
      case ItemType.mystery:
        break;
    }
  }

  // ────────────────────────────────────────────────
  //  아이템 사용 (발신)
  // ────────────────────────────────────────────────

  void _showNotif(String text, Color color) {
    _notifTimer?.cancel();
    setState(() { _notifText = text; _notifColor = color; });
    _notifTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notifText = null);
    });
  }

  void _startFlyAnim(String emoji, String fromPlayerId, String toPlayerId) {
    if (!mounted) return;
    final fromKey = _gaugeKeys[fromPlayerId];
    final toKey = _gaugeKeys[toPlayerId];
    if (fromKey == null || toKey == null) return;
    final fromBox = fromKey.currentContext?.findRenderObject() as RenderBox?;
    final toBox = toKey.currentContext?.findRenderObject() as RenderBox?;
    if (fromBox == null || toBox == null) return;
    final from = fromBox.localToGlobal(fromBox.size.center(Offset.zero));
    final to = toBox.localToGlobal(toBox.size.center(Offset.zero));
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyingEmoji(
        emoji: emoji,
        from: from,
        to: to,
        onDone: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void _onItemTap(int slotIndex) {
    final game = ref.read(gameProvider);
    if (game == null) return;
    final item = game.myItems[slotIndex];
    if (item == null) return;

    if (item == ItemType.hint) {
      final selected = ref.read(selectedCellProvider);
      if (selected == null) {
        _showNotif('💡 힌트를 적용할 빈 칸을 먼저 선택해주세요', Colors.amber);
        return;
      }
      final (row, col) = selected;
      final gameNow = ref.read(gameProvider);
      if (gameNow == null ||
          gameNow.isOriginalCell(row, col) ||
          gameNow.current[row][col] != 0) {
        _showNotif('💡 비어있는 칸을 선택해주세요', Colors.amber);
        return;
      }
      ref.read(gameProvider.notifier).useHintItem(slotIndex, row, col);
      setState(() => _selectedItemSlot = null);
      _showNotif('💡 힌트 적용!', Colors.amber);
    } else if (item == ItemType.shield) {
      ref.read(gameProvider.notifier).applyShield();
      ref.read(gameProvider.notifier).removeItemAt(slotIndex);
      setState(() => _selectedItemSlot = null);
      _showNotif('🛡️ 방어막 활성화! 다음 상대 아이템을 막아냅니다', Colors.green);
    } else if (item == ItemType.mystery) {
      _useMysteryItem(slotIndex);
    } else {
      setState(() {
        _selectedItemSlot = _selectedItemSlot == slotIndex ? null : slotIndex;
      });
    }
  }

  Future<void> _useMysteryItem(int slotIndex) async {
    final rng = Random();
    // 미스터리 효과 풀: 자신에게(좋음/나쁨) + 상대에게(좋음/나쁨)
    const outcomes = [
      'hint_self',    // 💡 나에게 랜덤 힌트 (좋음)
      'shield_self',  // 🛡️ 나에게 방어막 (좋음)
      'freeze_self',  // ❄️ 나에게 3초 프리즈 (나쁨)
      'blind_self',   // 🌫️ 나에게 블라인드 (나쁨)
      'freeze_opp',   // ⏸️ 상대에게 프리즈 (상대에게 나쁨)
      'blind_opp',    // 🌫️ 상대에게 블라인드 (상대에게 나쁨)
      'reverse_opp',  // 💥 상대 칸 지우기 (상대에게 나쁨)
      'hint_opp',     // 💡 상대에게 힌트 (상대에게 좋음 = 나에게 나쁨)
    ];
    final outcome = outcomes[rng.nextInt(outcomes.length)];

    ref.read(gameProvider.notifier).removeItemAt(slotIndex);
    setState(() => _selectedItemSlot = null);

    switch (outcome) {
      case 'hint_self':
        ref.read(gameProvider.notifier).applyRandomHint();
        if (mounted) _showNotif('❓ → 💡 럭키! 랜덤 힌트 발동!', Colors.amber);

      case 'shield_self':
        ref.read(gameProvider.notifier).applyShield();
        if (mounted) _showNotif('❓ → 🛡️ 럭키! 방어막 발동!', Colors.green);

      case 'freeze_self':
        ref.read(gameProvider.notifier).applyFreeze(3);
        _startFreezeCountdown();
        if (mounted) _showNotif('❓ → ❄️ 불운! 자신이 3초 프리즈!', Colors.indigo);

      case 'blind_self':
        ref.read(gameProvider.notifier).applyBlind(5);
        _startBlindCountdown();
        if (mounted) _showNotif('❓ → 🌫️ 불운! 자신에게 블라인드!', Colors.deepPurple);

      case 'freeze_opp':
      case 'blind_opp':
      case 'reverse_opp':
      case 'hint_opp':
        final opponents = ref.read(opponentStatesProvider).value
            ?.where((o) => !o.isMe && o.isConnected)
            .toList() ?? [];
        if (opponents.isEmpty) {
          ref.read(gameProvider.notifier).applyRandomHint();
          if (mounted) _showNotif('❓ → 💡 상대가 없어 자신에게 힌트 적용!', Colors.amber);
          return;
        }
        final targetId = opponents[rng.nextInt(opponents.length)].playerId;
        final gameId = ref.read(currentGameIdProvider);
        final myId = ref.read(currentPlayerProvider)?.id;
        if (gameId == null || myId == null) return;

        if (outcome == 'hint_opp') {
          ref.read(gameProvider.notifier).applyReverse();
          if (mounted) _showNotif('❓ → 💥 불운! 자신의 칸이 지워졌어요...', Colors.red);
          return;
        }

        ItemType eventType;
        int eventDuration;
        String msg;
        switch (outcome) {
          case 'freeze_opp':
            eventType = ItemType.freeze; eventDuration = 5;
            msg = '❓ → ⏸️ 상대에게 프리즈 발동!';
          case 'blind_opp':
            eventType = ItemType.blind; eventDuration = 5;
            msg = '❓ → 🌫️ 상대에게 블라인드 발동!';
          default: // reverse_opp
            eventType = ItemType.reverse; eventDuration = 0;
            msg = '❓ → 💥 상대의 칸을 지웠어요!';
        }
        try {
          await ref.read(eventRepositoryProvider).sendItemEvent(
            gameId: gameId,
            fromPlayerId: myId,
            itemType: eventType,
            targetPlayerId: targetId,
            duration: eventDuration,
          );
          if (mounted) {
            _showNotif(msg, Colors.orange);
            _startFlyAnim('❓', myId, targetId);
          }
        } catch (_) {}
    }
  }

  Future<void> _useItemOnTarget(String targetPlayerId) async {
    final slotIndex = _selectedItemSlot;
    if (slotIndex == null) return;

    final game = ref.read(gameProvider);
    if (game == null) return;
    final item = game.myItems[slotIndex];
    if (item == null || !item.targetsOpponent) return;

    final gameId = ref.read(currentGameIdProvider);
    final myPlayerId = ref.read(currentPlayerProvider)?.id;
    if (gameId == null || myPlayerId == null) return;

    try {
      await ref.read(eventRepositoryProvider).sendItemEvent(
            gameId: gameId,
            fromPlayerId: myPlayerId,
            itemType: item,
            targetPlayerId: targetPlayerId,
            duration: item == ItemType.freeze ? 5 : item == ItemType.reverse ? 0 : 30,
          );

      if (!mounted) return;
      ref.read(gameProvider.notifier).removeItemAt(slotIndex);
      setState(() => _selectedItemSlot = null);
      _showNotif('${item.emoji} ${item.name} 사용!', Colors.orange);
      _startFlyAnim(item.emoji, myPlayerId, targetPlayerId);
    } catch (e) {
      if (mounted) _showNotif('아이템 사용 실패: $e', Colors.red);
    }
  }

  // ────────────────────────────────────────────────
  //  타이머
  // ────────────────────────────────────────────────

  void _startPenaltyCountdown() {
    _penaltyTimer?.cancel();
    _penaltyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game == null || !game.isPenalized) {
        _penaltyTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).penaltyTick();
    });
  }

  void _startBlindCountdown() {
    _blindTimer?.cancel();
    _blindTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game == null || !game.isBlinded) {
        _blindTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).blindTick();
    });
  }

  void _startFreezeCountdown() {
    _freezeTimer?.cancel();
    _freezeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game == null || !game.isFrozen) {
        _freezeTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).freezeTick();
    });
  }

  void _startOvertime() {
    ref.read(overtimeRemainingProvider.notifier).state = AppConstants.overtimeSeconds;
    _overtimeTimer?.cancel();
    _overtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = ref.read(overtimeRemainingProvider) - 1;
      ref.read(overtimeRemainingProvider.notifier).state = remaining;
      if (remaining <= 0) {
        _overtimeTimer?.cancel();
        _endGame();
      }
    });
  }

  // ────────────────────────────────────────────────
  //  게임 진행
  // ────────────────────────────────────────────────

  void _onProgressChanged(int progress, bool isCompleted) async {
    if (!mounted) return;
    final gameId = ref.read(currentGameIdProvider);
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (gameId == null || playerId == null) return;

    final repo = ref.read(gameRepositoryProvider);
    await repo.updateProgress(gameId: gameId, playerId: playerId, progress: progress);

    if (isCompleted) {
      if (!mounted) return;
      // 완료한 순간 오버타임 시작 (RPC 결과와 무관하게)
      if (!ref.read(firstClearProvider)) {
        ref.read(firstClearProvider.notifier).state = true;
      }
      try {
        await repo.playerCleared(gameId: gameId, playerId: playerId);
      } catch (_) {
        // rank 저장 실패해도 게임 종료 흐름에는 영향 없음
      }
    }
  }

  Future<void> _leaveGame() async {
    if (!mounted) return;
    final playerId = ref.read(currentPlayerProvider)?.id;
    final lobbyActions = ref.read(lobbyActionsProvider);
    if (playerId != null) {
      try {
        await lobbyActions.leaveRoom(playerId);
      } catch (_) {
        // 이미 삭제된 경우 무시
      }
    }
    if (!mounted) return;
    ref.read(currentRoomProvider.notifier).state = null;
    ref.read(currentPlayerProvider.notifier).state = null;
    ref.read(currentGameIdProvider.notifier).state = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _endGame() async {
    if (_gameEnded) return;
    _gameEnded = true;

    // 타이머 즉시 취소 — cleanup 후 삭제된 레코드에 이벤트 쓰는 것 방지
    _itemEventTimer?.cancel();
    _overtimeTimer?.cancel();

    if (!mounted) return;
    final gameId = ref.read(currentGameIdProvider);
    final roomId = ref.read(currentRoomProvider)?.id;
    final myPlayerId = ref.read(currentPlayerProvider)?.id;
    if (gameId == null) return;

    // cleanup으로 스트림이 빈 값을 emit하기 전에 찍어둔 마지막 유효 스냅샷 사용
    final inMemoryStates = List<OpponentState>.of(_lastKnownOpponentStates);

    final repo = ref.read(gameRepositoryProvider);
    try {
      await repo.finishGame(gameId);
    } catch (_) {}

    // 메모리 스냅샷 우선 사용, 없으면 DB에서 조회
    List<OpponentState> results;
    if (inMemoryStates.isNotEmpty) {
      results = inMemoryStates;
    } else {
      try {
        final states = await repo.getPlayerGameStates(gameId);
        results = states.map((s) {
          final players = s['players'] as Map<String, dynamic>?;
          return OpponentState(
            playerId: s['player_id'] as String,
            nickname: players?['nickname'] as String? ?? '???',
            progress: s['progress'] as int,
            totalBlanks: s['total_blanks'] as int,
            rank: s['rank'] as int?,
            finishedAt: s['finished_at'] != null
                ? DateTime.parse(s['finished_at'] as String)
                : null,
            isMe: s['player_id'] == myPlayerId,
          );
        }).toList();
      } catch (_) {
        results = [];
      }
    }

    // DB 전체 삭제 (먼저 호출한 플레이어만 성공, 나머지는 무시)
    if (roomId != null) {
      try {
        await repo.cleanupGame(gameId: gameId, roomId: roomId);
      } catch (_) {}
    }

    if (!mounted) return;

    // 로컬 상태 초기화
    ref.read(currentGameIdProvider.notifier).state = null;
    ref.read(currentRoomProvider.notifier).state = null;
    ref.read(currentPlayerProvider.notifier).state = null;
    ref.read(firstClearProvider.notifier).state = false;
    ref.read(overtimeRemainingProvider.notifier).state = AppConstants.overtimeSeconds;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(results: results)),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(heartbeatProvider);
    final game = ref.watch(gameProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final opponentsAsync = ref.watch(opponentStatesProvider);
    final firstClear = ref.watch(firstClearProvider);
    final overtimeRemaining = ref.watch(overtimeRemainingProvider);

    if (game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    ref.listen(gameProvider, (prev, next) {
      if (next == null) return;
      if (next.isPenalized && (prev == null || !prev.isPenalized)) {
        _startPenaltyCountdown();
      }
      if (next.isBlinded && (prev == null || !prev.isBlinded)) {
        _startBlindCountdown();
      }
      if (next.isFrozen && (prev == null || !prev.isFrozen)) {
        _startFreezeCountdown();
      }
    });

    ref.listen(firstClearProvider, (prev, next) {
      if (next && !(prev ?? false)) _startOvertime();
    });

    ref.listen(opponentStatesProvider, (prev, next) {
      next.whenData((states) {
        if (states.isNotEmpty) _lastKnownOpponentStates = states;

        final anyCleared = states.any((s) => s.rank != null || s.progressPercent >= 1.0);
        if (anyCleared && !ref.read(firstClearProvider)) {
          ref.read(firstClearProvider.notifier).state = true;
        }
        final allDone = states.every(
          (s) => s.rank != null || s.progressPercent >= 1.0 || !s.isConnected,
        );
        if (allDone && !_gameEnded) _endGame();
      });
    });

    final progressPercent = (game.progress * 100).toInt();

    // 타겟 선택 모드인지
    final isTargeting = _selectedItemSlot != null &&
        game.myItems[_selectedItemSlot!] != null &&
        game.myItems[_selectedItemSlot!]!.targetsOpponent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveGame();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveGame,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 20, color: colorScheme.onSurface),
              const Gap(4),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 오버타임 카운트다운 배너
                  if (firstClear)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.orange.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, size: 18, color: Colors.orange.shade800),
                          const Gap(6),
                          Text(
                            '$overtimeRemaining초 후 게임 종료!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.orange.shade900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 블라인드 배너
                  if (game.isBlinded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.deepPurple.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🌫️', style: TextStyle(fontSize: 14)),
                          const Gap(6),
                          Text(
                            '${game.blindedBoxIndex! + 1}번 박스 블라인드 — ${game.blindRemaining}초',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.deepPurple.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Gap(4),

                  // 아이템 슬롯
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(4, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ItemSlot(
                              item: game.myItems[i],
                              isSelected: _selectedItemSlot == i,
                              onTap: () => _onItemTap(i),
                            ),
                          );
                        }),
                        // 취소 버튼
                        if (isTargeting)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedItemSlot = null),
                              child: Icon(Icons.cancel_outlined,
                                  color: colorScheme.error, size: 28),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Gap(4),

                  // 플레이어 게이지 (타겟 선택 모드에서는 탭 가능)
                  opponentsAsync.when(
                    data: (opponents) {
                      final me = opponents.where((o) => o.isMe);
                      final others = opponents
                          .where((o) => !o.isMe && o.isConnected)
                          .toList()
                        ..sort((a, b) => b.progress.compareTo(a.progress));
                      final all = [...me, ...others];
                      if (all.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: all.map((o) {
                            final effectiveProgress = o.isMe
                                ? game.progress
                                : o.progressPercent;
                            final canTarget = isTargeting && !o.isMe;

                            final key = _gaugeKeys.putIfAbsent(o.playerId, () => GlobalKey());
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: GestureDetector(
                                  onTap: canTarget
                                      ? () => _useItemOnTarget(o.playerId)
                                      : null,
                                  child: Container(
                                    key: key,
                                    child: _PlayerGauge(
                                      nickname: o.nickname,
                                      progress: effectiveProgress,
                                      isMe: o.isMe,
                                      isCleared: o.rank != null ||
                                          (o.isMe && game.isCompleted),
                                      isTargetable: canTarget,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const Gap(4),

                  // 스도쿠 그리드
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildGrid(game),
                  ),

                  const Spacer(),

                  if (_notifText != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _notifColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _notifColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _notifText!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _notifColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (!game.isCompleted) const NumberPad(),

                  if (game.isCompleted)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const Gap(8),
                              Text(
                                firstClear
                                    ? '완료! $overtimeRemaining초 후 결과 화면으로 이동합니다'
                                    : '완료! 다른 플레이어를 기다리는 중...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const Gap(16),
                ],
              ),

              // 패널티 오버레이 (오답)
              if (game.isPenalized)
                _BlockOverlay(
                  icon: Icons.block,
                  iconColor: Colors.red.shade400,
                  title: '오답!',
                  titleColor: Colors.red.shade600,
                  seconds: game.penaltyRemaining,
                  message: '입력이 잠겼습니다',
                  bgColor: Colors.white.withValues(alpha: 0.92),
                ),

              // 프리즈 오버레이
              if (game.isFrozen)
                _BlockOverlay(
                  icon: Icons.ac_unit,
                  iconColor: Colors.blue.shade400,
                  title: '⏸️ 프리즈!',
                  titleColor: Colors.blue.shade700,
                  seconds: game.freezeRemaining,
                  message: '상대방이 입력을 잠갔습니다',
                  bgColor: Colors.blue.shade50.withValues(alpha: 0.92),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(GameState game) => const SudokuGrid();
}

class _BlockOverlay extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final int seconds;
  final String message;
  final Color bgColor;

  const _BlockOverlay({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.seconds,
    required this.message,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: iconColor),
            const Gap(20),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const Gap(12),
            Text(
              '$seconds초',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: iconColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Gap(8),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlyingEmoji extends StatefulWidget {
  final String emoji;
  final Offset from;
  final Offset to;
  final VoidCallback onDone;

  const _FlyingEmoji({
    required this.emoji,
    required this.from,
    required this.to,
    required this.onDone,
  });

  @override
  State<_FlyingEmoji> createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<_FlyingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _pos;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pos = Tween<Offset>(begin: widget.from, end: widget.to)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 30),
    ]).animate(_ctrl);
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pos = _pos.value;
        return Stack(
          children: [
            Positioned(
              left: pos.dx - 18,
              top: pos.dy - 18,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: _scale.value,
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(
                      fontSize: 32,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerGauge extends StatelessWidget {
  final String nickname;
  final double progress;
  final bool isMe;
  final bool isCleared;
  final bool isTargetable;

  const _PlayerGauge({
    required this.nickname,
    required this.progress,
    required this.isMe,
    required this.isCleared,
    this.isTargetable = false,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toInt();
    final barColor = isCleared
        ? Colors.green
        : isMe
            ? Colors.indigo
            : Colors.indigo.shade300;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            Container(color: Colors.grey.shade200),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: progress.clamp(0.0, 1.0),
                child: Container(color: barColor),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMe ? '나' : nickname,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                      color: progress > 0.5 ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    isCleared ? '완료' : '$percent%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: progress > 0.5 ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // 타겟 가능 표시
            if (isTargetable)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange, width: 2.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: Colors.orange,
                    child: const Text(
                      'TAP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
