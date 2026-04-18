import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/game_provider.dart';

class NumberPad extends ConsumerWidget {
  const NumberPad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final game = ref.watch(gameProvider);
    final numberCounts = game?.numberCounts ?? {};
    final isMemoMode = ref.watch(memoModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // 메모 모드 토글 버튼
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildMemoToggleButton(context, ref, isMemoMode, colorScheme),
              ],
            ),
          ),
          // 1열: 1~5
          Row(
            children: List.generate(5, (i) {
              final number = i + 1;
              final isCompleted =
                  !isMemoMode && (numberCounts[number] ?? 0) >= 9;
              return _buildNumberButton(
                context, ref, number, isCompleted, isMemoMode, colorScheme,
              );
            }),
          ),
          const SizedBox(height: 6),
          // 2열: 6~9 + 지우기
          Row(
            children: [
              ...List.generate(4, (i) {
                final number = i + 6;
                final isCompleted =
                    !isMemoMode && (numberCounts[number] ?? 0) >= 9;
                return _buildNumberButton(
                  context, ref, number, isCompleted, isMemoMode, colorScheme,
                );
              }),
              // 지우기 버튼
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    height: 56,
                    child: MaterialButton(
                      onPressed: () => _onErase(ref),
                      color: colorScheme.errorContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                      child: Icon(
                        Icons.backspace_outlined,
                        color: colorScheme.onErrorContainer,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoToggleButton(
    BuildContext context,
    WidgetRef ref,
    bool isMemoMode,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(memoModeProvider.notifier).state = !isMemoMode;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isMemoMode
              ? colorScheme.secondary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: isMemoMode
                  ? colorScheme.onSecondary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '메모',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMemoMode
                    ? colorScheme.onSecondary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(
    BuildContext context,
    WidgetRef ref,
    int number,
    bool isCompleted,
    bool isMemoMode,
    ColorScheme colorScheme,
  ) {
    Color buttonColor;
    Color textColor;
    if (isCompleted) {
      buttonColor = colorScheme.surfaceContainerHighest;
      textColor = colorScheme.outlineVariant;
    } else if (isMemoMode) {
      buttonColor = colorScheme.secondary;
      textColor = colorScheme.onSecondary;
    } else {
      buttonColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SizedBox(
          height: 56,
          child: MaterialButton(
            onPressed: isCompleted ? null : () => _onNumberTap(ref, number),
            color: buttonColor,
            disabledColor: colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
            child: isMemoMode && !isCompleted
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.edit,
                          size: 10,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  )
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? colorScheme.outlineVariant : textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _onNumberTap(WidgetRef ref, int number) {
    final selected = ref.read(selectedCellProvider);
    if (selected == null) return;
    final isMemoMode = ref.read(memoModeProvider);
    ref.read(gameProvider.notifier).inputNumber(
          selected.$1,
          selected.$2,
          number,
          isMemoMode: isMemoMode,
        );
  }

  void _onErase(WidgetRef ref) {
    final selected = ref.read(selectedCellProvider);
    if (selected == null) return;
    ref.read(gameProvider.notifier).eraseCell(selected.$1, selected.$2);
  }
}
