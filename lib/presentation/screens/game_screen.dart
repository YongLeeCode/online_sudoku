import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../data/models/item_model.dart';
import '../../domain/providers/game_provider.dart';
import '../widgets/hud/item_slot.dart';
import '../widgets/sudoku/sudoku_grid.dart';
import '../widgets/sudoku/number_pad.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _timer;
  Timer? _penaltyTimer;
  Timer? _blindTimer;
  Duration _elapsed = Duration.zero;

  // dispose 시점엔 `ref`가 이미 해제돼 사용할 수 없으므로, 정리에 필요한
  // notifier 참조를 initState에서 미리 잡아둔다.
  late final GameNotifier _gameNotifier;
  late final StateController<bool> _memoModeNotifier;

  @override
  void initState() {
    super.initState();
    _gameNotifier = ref.read(gameProvider.notifier);
    _memoModeNotifier = ref.read(memoModeProvider.notifier);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game != null && !game.isCompleted) {
        setState(() {
          _elapsed = DateTime.now().difference(game.startedAt);
        });
      }
    });

    // 아이템 획득 콜백
    ref.read(gameProvider.notifier).onItemCollected = (item) {
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _penaltyTimer?.cancel();
    _blindTimer?.cancel();
    _memoModeNotifier.state = false;
    _gameNotifier.onItemCollected = null;
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 힌트 적용!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // 싱글플레이어에서는 상대 타겟 아이템 사용 불가
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.emoji} ${item.name}은 멀티플레이어에서만 사용 가능합니다'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    ref.listen(gameProvider, (prev, next) {
      if (next == null) return;
      if (next.isCompleted && (prev == null || !prev.isCompleted)) {
        _showCompletionDialog(context, next);
      }
      if (next.isPenalized && (prev == null || !prev.isPenalized)) {
        _startPenaltyCountdown();
      }
      if (next.isBlinded && (prev == null || !prev.isBlinded)) {
        _startBlindCountdown();
      }
    });

    final progressPercent = (game.progress * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 20, color: colorScheme.onSurface),
            const Gap(4),
            Text(
              _formatDuration(game.isCompleted
                  ? game.completedDuration ?? _elapsed
                  : _elapsed),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        centerTitle: true,
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
            // 넓은 화면(태블릿/웹)에서 과도하게 늘어나지 않도록 폭 제한
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    // 진행률 바
                    LinearProgressIndicator(
                      value: game.progress,
                      minHeight: 4,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                    const Gap(8),

                    // 아이템 슬롯
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ItemSlot(
                              item: game.myItems[i],
                              onTap: () => _onItemTap(i),
                            ),
                          );
                        }),
                      ),
                    ),

                    const Gap(8),

                    // 스도쿠 그리드 — 남은 세로 공간에 맞춰 정사각형으로
                    // 축소되도록 Expanded+Center로 감싸 오버플로를 방지한다.
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildGrid(game),
                        ),
                      ),
                    ),

                    // 숫자 키패드
                    const NumberPad(),

                    const Gap(16),
                  ],
                ),
              ),
            ),

            // 패널티 오버레이
            if (game.isPenalized)
              _BlockOverlay(
                icon: Icons.block,
                iconColor: Colors.red.shade400,
                title: '오답!',
                titleColor: Colors.red.shade600,
                seconds: game.penaltyRemaining,
                message: '입력이 잠겼습니다',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(GameState game) => const SudokuGrid();

  void _showCompletionDialog(BuildContext context, GameState game) {
    final duration = game.completedDuration ?? Duration.zero;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('축하합니다!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const Gap(16),
            Text(
              '완료 시간: ${_formatDuration(duration)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('홈으로'),
          ),
        ],
      ),
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

  const _BlockOverlay({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.seconds,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.92),
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
