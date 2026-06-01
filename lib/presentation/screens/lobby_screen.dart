import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/difficulty.dart';
import '../../domain/providers/game_provider.dart';
import '../../domain/providers/multiplayer_provider.dart';
import '../../domain/providers/room_provider.dart';
import '../widgets/lobby/player_card.dart';
import '../widgets/lobby/settings_panel.dart';
import 'multiplayer_game_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _navigatingToGame = false;
  bool _hostLeft = false;

  void _navigateToGame() async {
    if (_navigatingToGame) return;
    _navigatingToGame = true;

    if (!mounted) return;
    final room = ref.read(currentRoomProvider);
    final player = ref.read(currentPlayerProvider);
    if (room == null || player == null) return;

    // 게임 데이터 조회
    final gameRepo = ref.read(gameRepositoryProvider);
    final roomRepo = ref.read(roomRepositoryProvider);
    final gameData = await gameRepo.getActiveGame(room.id);
    if (gameData == null) return;

    final gameId = gameData['id'] as String;
    final seed = gameData['puzzle_seed'] as int;

    // 항상 DB에서 최신 설정을 직접 fetch (로컬 캐시 무시)
    final settings = await roomRepo.getRoomSettings(room.id);

    if (!mounted) return;

    // 로컬 설정 상태도 최신으로 갱신
    ref.read(roomSettingsProvider.notifier).state = settings;

    // 프로바이더 설정
    ref.read(currentGameIdProvider.notifier).state = gameId;
    ref.read(currentGameSeedProvider.notifier).state = seed;
    ref.read(firstClearProvider.notifier).state = false;
    ref.read(overtimeRemainingProvider.notifier).state = AppConstants.overtimeSeconds;
    ref.read(selectedCellProvider.notifier).state = null;

    // 동일 seed, 최신 설정으로 게임 시작
    ref.read(gameProvider.notifier).startGameWithSeed(
          seed,
          settings?.difficulty ?? Difficulty.normal,
          penaltySeconds: settings?.penaltySeconds,
          maxItemCount: settings?.maxItemCount,
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MultiplayerGameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(heartbeatProvider);
    final room = ref.watch(currentRoomProvider);
    final player = ref.watch(currentPlayerProvider);
    final playersAsync = ref.watch(playersStreamProvider);
    final settings = ref.watch(roomSettingsProvider);
    final allReady = ref.watch(allReadyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (room == null || player == null) {
      return const Scaffold(body: Center(child: Text('오류 발생')));
    }

    final isHost = player.isHost;

    // 방 상태 변경 감지
    ref.listen(roomStreamProvider, (prev, next) {
      next.whenData((roomData) {
        if (roomData.status == 'playing') {
          _navigateToGame();
        } else if (roomData.status == 'closed') {
          _onHostLeft();
        }
      });
    });

    // 설정 변경 실시간 동기화 (참여자: DB → 로컬 반영)
    ref.listen(roomSettingsStreamProvider, (prev, next) {
      next.whenData((freshSettings) {
        ref.read(roomSettingsProvider.notifier).state = freshSettings;
      });
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onLeave(context, ref, player.id);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('대기실'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onLeave(context, ref, player.id),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 방 코드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: colorScheme.primaryContainer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '방 코드: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      room.code,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Gap(8),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: room.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('방 코드가 복사되었습니다'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '참여자',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Gap(8),
                      playersAsync.when(
                        data: (players) => Column(
                          children: players
                              .map((p) => PlayerCard(
                                    player: p,
                                    isMe: p.id == player.id,
                                  ))
                              .toList(),
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Text('오류: $e'),
                      ),
                      const Gap(24),

                      if (settings != null) ...[
                        Text(
                          '게임 설정',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Gap(8),
                        SettingsPanel(
                          settings: settings,
                          isHost: isHost,
                          onSettingsChanged: isHost
                              ? (newSettings) async {
                                  ref.read(roomSettingsProvider.notifier).state =
                                      newSettings;
                                  await ref
                                      .read(lobbyActionsProvider)
                                      .updateSettings(newSettings);
                                }
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 하단 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: isHost
                      ? FilledButton.icon(
                          onPressed: allReady
                              ? () => _startGame(context, ref, room.id)
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            allReady ? '게임 시작!' : '모두 준비 대기 중...',
                            style: const TextStyle(fontSize: 18),
                          ),
                        )
                      : _ReadyButton(player: player),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onLeave(BuildContext context, WidgetRef ref, String playerId) async {
    final player = ref.read(currentPlayerProvider);
    final room = ref.read(currentRoomProvider);

    await ref.read(lobbyActionsProvider).leaveRoom(playerId);

    if (player?.isHost == true && room != null) {
      await ref.read(roomRepositoryProvider).closeRoom(room.id);
    }

    ref.read(currentRoomProvider.notifier).state = null;
    ref.read(currentPlayerProvider.notifier).state = null;
    ref.read(roomSettingsProvider.notifier).state = null;
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onHostLeft() async {
    if (_hostLeft || !mounted) return;
    _hostLeft = true;

    final player = ref.read(currentPlayerProvider);
    if (player != null) {
      await ref.read(lobbyActionsProvider).leaveRoom(player.id);
    }

    ref.read(currentRoomProvider.notifier).state = null;
    ref.read(currentPlayerProvider.notifier).state = null;
    ref.read(roomSettingsProvider.notifier).state = null;

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('호스트가 방을 나갔습니다.')),
    );
  }

  Future<void> _startGame(BuildContext context, WidgetRef ref, String roomId) async {
    try {
      final settings = ref.read(roomSettingsProvider);
      final playersAsync = ref.read(playersStreamProvider);
      final players = playersAsync.valueOrNull ?? [];

      if (settings == null || players.isEmpty) return;

      // 게임 생성 (DB에 저장)
      final gameRepo = ref.read(gameRepositoryProvider);
      await gameRepo.createGame(
        roomId: roomId,
        difficulty: settings.difficulty,
        playerIds: players.map((p) => p.id).toList(),
        hintCounts: settings.hintCounts.map((k, v) => MapEntry(k, v)),
        defaultHints: 3,
      );

      // 방 상태를 playing으로 변경 → 모든 클라이언트가 감지
      await ref.read(lobbyActionsProvider).startGame(roomId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게임 시작 실패: $e')),
        );
      }
    }
  }
}

class _ReadyButton extends ConsumerStatefulWidget {
  final dynamic player;
  const _ReadyButton({required this.player});

  @override
  ConsumerState<_ReadyButton> createState() => _ReadyButtonState();
}

class _ReadyButtonState extends ConsumerState<_ReadyButton> {
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () async {
        setState(() => _isReady = !_isReady);
        await ref
            .read(lobbyActionsProvider)
            .toggleReady(widget.player.id, _isReady);
      },
      style: FilledButton.styleFrom(
        backgroundColor: _isReady
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.primary,
      ),
      icon: Icon(_isReady ? Icons.check_circle : Icons.radio_button_unchecked),
      label: Text(
        _isReady ? '준비 완료!' : '준비',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
