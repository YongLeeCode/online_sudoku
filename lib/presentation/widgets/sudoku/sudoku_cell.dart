import 'package:flutter/material.dart';

class SudokuCell extends StatelessWidget {
  final int value;
  final bool isOriginal;
  final bool isSelected;
  final bool isError;
  final bool isSameNumber;
  final bool isSameRowOrCol;
  final Set<int> notes;
  final VoidCallback onTap;

  final bool isItemCell;
  final bool isBlinded;

  const SudokuCell({
    super.key,
    required this.value,
    required this.isOriginal,
    required this.isSelected,
    required this.isError,
    required this.isSameNumber,
    required this.isSameRowOrCol,
    required this.notes,
    this.isItemCell = false,
    this.isBlinded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    if (isSelected) {
      bgColor = colorScheme.primaryContainer;
    } else if (isError) {
      bgColor = colorScheme.errorContainer.withValues(alpha: 0.5);
    } else if (isSameNumber && value != 0) {
      bgColor = colorScheme.primaryContainer.withValues(alpha: 0.4);
    } else if (isSameRowOrCol) {
      bgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      bgColor = colorScheme.surface;
    }

    Color textColor;
    if (isError) {
      textColor = colorScheme.error;
    } else if (isOriginal) {
      textColor = colorScheme.onSurface;
    } else {
      textColor = colorScheme.primary;
    }

    Widget? cellChild;
    if (isBlinded && value != 0) {
      // 블라인드: 채워진 칸은 배경색으로만 표시 (숫자 숨김)
      bgColor = isSelected
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer.withValues(alpha: 0.7);
    } else if (value != 0) {
      cellChild = Text(
        '$value',
        style: TextStyle(
          fontSize: 20,
          fontWeight: isOriginal ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
        ),
      );
    } else if (!isBlinded && notes.isNotEmpty) {
      // 블라인드 중에는 메모도 숨김
      cellChild = _buildNotes(colorScheme);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: bgColor),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ?cellChild,
            // 아이템 셀 표시: 우하단 작은 별
            if (isItemCell)
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '★',
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.amber.shade600,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes(ColorScheme colorScheme) {
    final noteColor = colorScheme.primary.withValues(alpha: 0.75);
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (col) {
              final num = row * 3 + col + 1;
              return Expanded(
                child: Text(
                  notes.contains(num) ? '$num' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: noteColor,
                    height: 1.1,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
