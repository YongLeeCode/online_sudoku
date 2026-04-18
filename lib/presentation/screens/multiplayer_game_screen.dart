import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

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

  // 아이템 타겟 선택 모드: 선택된 슬롯 인덱스
  int? _selectedItemSlot;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.emoji} ${item.name} 획득!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };

    // 2초마다 나를 타겟으로 한 아이템 이벤트 확인
    _itemEventTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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
    ref.read(gameProvider.notifier).onProgressChanged = null;
    ref.read(gameProvider.notifier).onItemCollected = null;
    ref.read(memoModeProvider.notifier).state = false;
    super.dispose();
  }

  // ────────────────────────────────────────────────
  //  아이템 이벤트 수신
  // ────────────────────────────────────────────────

  Future<void> _checkIncomingItemEvents() async {
    final gameId = ref.read(currentGameIdProvider);
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (gameId == null || playerId == null) return;

    try {
      final events = await ref.read(eventRepositoryProvider).fetchItemEventsAfter(
            gameId: gameId,
            myPlayerId: playerId,
            after: _lastEventCheck,
          );

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
    final payload = event['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final itemType = ItemTypeX.fromDbKey(payload['item_type'] as String? ?? '');
    if (itemType == null) return;

    final duration = (payload['duration'] as num?)?.toInt() ?? 5;

    switch (itemType) {
      case ItemType.blind:
        ref.read(gameProvider.notifier).applyBlind(duration);
        _startBlindCountdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🌫️ 블라인드 당했습니다!'),
              backgroundColor: Colors.deepPurple,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      case ItemType.freeze:
        ref.read(gameProvider.notifier).applyFreeze(duration);
        _startFreezeCountdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏸️ 프리즈 당했습니다!'),
              backgroundColor: Colors.indigo,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      case ItemType.hintCut:
        ref.read(gameProvider.notifier).removeFirstItem();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✂️ 아이템 하나가 제거됐습니다!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      case ItemType.hint:
        break; // 힌트는 자기 자신에게만 사용
    }
  }

  // ────────────────────────────────────────────────
  //  아이템 사용 (발신)
  // ────────────────────────────────────────────────

  void _onItemTap(int slotIndex) {
    final game = ref.read(gameProvider);
    if (game == null) return;
    final item = game.myItems[slotIndex];
    if (item == null) return;

    if (item == ItemType.hint) {
      final selected = ref.read(selectedCellProvider);
      if (selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 힌트를 적용할 빈 칸을 먼저 선택해주세요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final (row, col) = selected;
      final gameNow = ref.read(gameProvider);
      if (gameNow == null ||
          gameNow.isOriginalCell(row, col) ||
          gameNow.current[row][col] != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 비어있는 칸을 선택해주세요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ref.read(gameProvider.notifier).useHintItem(slotIndex, row, col);
      setState(() => _selectedItemSlot = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 힌트 적용!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // 타겟 선택 모드 토글
      setState(() {
        _selectedItemSlot = _selectedItemSlot == slotIndex ? null : slotIndex;
      });
      if (_selectedItemSlot != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.emoji} ${item.name} - 상대방 게이지를 탭하세요'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

    final penaltySeconds = ref.read(roomSettingsProvider)?.penaltySeconds ?? 5;

    try {
      await ref.read(eventRepositoryProvider).sendItemEvent(
            gameId: gameId,
            fromPlayerId: myPlayerId,
            itemType: item,
            targetPlayerId: targetPlayerId,
            duration: item == ItemType.freeze ? penaltySeconds : 5,
          );

      // 슬롯에서 아이템 제거
      ref.read(gameProvider.notifier).removeItemAt(slotIndex);
      setState(() => _selectedItemSlot = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.emoji} ${item.name} 사용!'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('아이템 사용 실패: $e')),
        );
      }
    }
  }

  // ────────────────────────────────────────────────
  //  타이머
  // ────────────────────────────────────────────────

  void _startPenaltyCountdown() {
    _penaltyTimer?.cancel();
    _penaltyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
      final game = ref.read(gameProvider);
      if (game == null || !game.isFrozen) {
        _freezeTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).freezeTick();
    });
  }

  void _startOvertime() {
    ref.read(overtimeRemainingProvider.notifier).state = 60;
    _overtimeTimer?.cancel();
    _overtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final gameId = ref.read(currentGameIdProvider);
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (gameId == null || playerId == null) return;

    final repo = ref.read(gameRepositoryProvider);
    await repo.updateProgress(gameId: gameId, playerId: playerId, progress: progress);

    if (isCompleted) {
      final states = await repo.getPlayerGameStates(gameId);
      final clearedCount = states.where((s) => s['rank'] != null).length;
      final rank = clearedCount + 1;
      await repo.playerCleared(gameId: gameId, playerId: playerId, rank: rank);
      if (rank == 1) {
        ref.read(firstClearProvider.notifier).state = true;
      }
    }
  }

  Future<void> _leaveGame() async {
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (playerId != null) {
      await ref.read(lobbyActionsProvider).leaveRoom(playerId);
    }
    ref.read(currentRoomProvider.notifier).state = null;
    ref.read(currentPlayerProvider.notifier).state = null;
    ref.read(currentGameIdProvider.notifier).state = null;
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _endGame() async {
    if (_gameEnded) return;
    _gameEnded = true;

    final gameId = ref.read(currentGameIdProvider);
    if (gameId == null) return;

    final repo = ref.read(gameRepositoryProvider);
    await repo.finishGame(gameId);

    final states = await repo.getPlayerGameStates(gameId);
    final myPlayerId = ref.read(currentPlayerProvider)?.id;

    final results = states.map((s) {
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

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(results: results)),
      );
    }
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
        final anyCleared = states.any((s) => s.rank != null);
        if (anyCleared && !ref.read(firstClearProvider)) {
          ref.read(firstClearProvider.notifier).state = true;
        }
        final connectedPlayers = states.where((s) => s.isConnected).toList();
        if (connectedPlayers.length <= 1 && !_gameEnded) {
          _endGame();
          return;
        }
        final allDone = states.every((s) => s.rank != null || !s.isConnected);
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
                  // 오버타임 경고
                  if (firstClear && !game.isCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.red.shade50,
                      child: Text(
                        '1등 확정! 남은 시간: $overtimeRemaining초',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade700,
                          fontSize: 15,
                        ),
                      ),
                    ),

                  const Gap(4),

                  // 아이템 슬롯
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 타겟 선택 모드 안내
                        if (isTargeting)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '▶ 상대 선택',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ),
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

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: GestureDetector(
                                  onTap: canTarget
                                      ? () => _useItemOnTarget(o.playerId)
                                      : null,
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
                                '완료! 다른 플레이어를 기다리는 중...',
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

  Widget _buildGrid(GameState game) {
    if (!game.isBlinded) return const SudokuGrid();

    return Stack(
      children: [
        const SudokuGrid(),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.purple.withValues(alpha: 0.2),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌫️', style: TextStyle(fontSize: 36)),
                    const Gap(8),
                    Text(
                      '블라인드 ${game.blindRemaining}초',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
