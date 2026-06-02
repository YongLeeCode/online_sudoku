import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/game_provider.dart';

class NumberPad extends ConsumerWidget {
  /// 입력 가능한 숫자 제한(튜토리얼 전용).
  ///
  /// null이면 기존 동작(완성된 숫자만 비활성). 값이 주어지면 이 집합에 포함된
  /// 숫자 버튼만 활성화되고, "완성된 숫자" 비활성 규칙은 무시한다.
  final Set<int>? allowedNumbers;

  /// 입력 모드 잠금(튜토리얼 전용).
  ///
  /// true이면 메모 토글 버튼과 지우기 버튼을 비활성화한다(현재 메모 상태 고정).
  final bool lockInputMode;

  const NumberPad({
    super.key,
    this.allowedNumbers,
    this.lockInputMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final game = ref.watch(gameProvider);
    final numberCounts = game?.numberCounts ?? {};
    final isMemoMode = ref.watch(memoModeProvider);

    bool isEnabled(int number) {
      if (allowedNumbers != null) return allowedNumbers!.contains(number);
      if (isMemoMode) return true;
      return (numberCounts[number] ?? 0) < 9;
    }

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
                _buildMemoToggleButton(
                  context, ref, isMemoMode, !lockInputMode, colorScheme,
                ),
              ],
            ),
          ),
          // 1열: 1~5
          Row(
            children: List.generate(5, (i) {
              final number = i + 1;
              return _buildNumberButton(
                context, ref, number, isEnabled(number), isMemoMode, colorScheme,
              );
            }),
          ),
          const SizedBox(height: 6),
          // 2열: 6~9 + 지우기
          Row(
            children: [
              ...List.generate(4, (i) {
                final number = i + 6;
                return _buildNumberButton(
                  context, ref, number, isEnabled(number), isMemoMode, colorScheme,
                );
              }),
              // 지우기 버튼
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    height: 56,
                    child: MaterialButton(
                      onPressed: lockInputMode ? null : () => _onErase(ref),
                      color: colorScheme.errorContainer,
                      disabledColor: colorScheme.surfaceContainerHighest,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                      child: Icon(
                        Icons.backspace_outlined,
                        color: lockInputMode
                            ? colorScheme.outlineVariant
                            : colorScheme.onErrorContainer,
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
    bool enabled,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: enabled
          ? () => ref.read(memoModeProvider.notifier).state = !isMemoMode
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isMemoMode
              ? colorScheme.secondary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
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
      ),
    );
  }

  Widget _buildNumberButton(
    BuildContext context,
    WidgetRef ref,
    int number,
    bool enabled,
    bool isMemoMode,
    ColorScheme colorScheme,
  ) {
    Color buttonColor;
    Color textColor;
    if (!enabled) {
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
            onPressed: enabled ? () => _onNumberTap(ref, number) : null,
            color: buttonColor,
            disabledColor: colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
            child: isMemoMode && enabled
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
                      color: textColor,
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
