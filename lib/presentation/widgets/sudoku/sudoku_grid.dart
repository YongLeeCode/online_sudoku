import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/game_provider.dart';
import 'sudoku_cell.dart';

class SudokuGrid extends ConsumerWidget {
  const SudokuGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final selected = ref.watch(selectedCellProvider);

    if (game == null) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: CustomPaint(
            foregroundPainter: _GridLinePainter(
              color: Theme.of(context).colorScheme.outline,
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
              ),
              itemCount: 81,
              itemBuilder: (context, index) {
                final row = index ~/ 9;
                final col = index % 9;
                final value = game.current[row][col];
                final isOriginal = game.isOriginalCell(row, col);
                final isSelected = selected == (row, col);
                final isError = game.errorCells.contains((row, col));

                // 같은 숫자 하이라이트
                bool isSameNumber = false;
                if (selected != null && !isSelected) {
                  final selectedVal = game.current[selected.$1][selected.$2];
                  if (selectedVal != 0 && value == selectedVal) {
                    isSameNumber = true;
                  }
                }

                // 같은 행/열/박스 하이라이트
                bool isSameRowOrCol = false;
                if (selected != null && !isSelected) {
                  final sr = selected.$1;
                  final sc = selected.$2;
                  if (row == sr || col == sc ||
                      (row ~/ 3 == sr ~/ 3 && col ~/ 3 == sc ~/ 3)) {
                    isSameRowOrCol = true;
                  }
                }

                return SudokuCell(
                  value: value,
                  isOriginal: isOriginal,
                  isSelected: isSelected,
                  isError: isError,
                  isSameNumber: isSameNumber,
                  isSameRowOrCol: isSameRowOrCol,
                  notes: game.notes[row][col],
                  isItemCell: game.isItemCell(row, col),
                  onTap: () {
                    ref.read(selectedCellProvider.notifier).state = (row, col);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GridLinePainter extends CustomPainter {
  final Color color;

  _GridLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final thinPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    final thickPaint = Paint()
      ..color = color
      ..strokeWidth = 2;

    final cellW = size.width / 9;
    final cellH = size.height / 9;

    for (int i = 1; i < 9; i++) {
      final paint = (i % 3 == 0) ? thickPaint : thinPaint;

      // 세로선
      canvas.drawLine(
        Offset(cellW * i, 0),
        Offset(cellW * i, size.height),
        paint,
      );

      // 가로선
      canvas.drawLine(
        Offset(0, cellH * i),
        Offset(size.width, cellH * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinePainter old) => color != old.color;
}
