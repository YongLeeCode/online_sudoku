import 'package:flutter/material.dart';

import '../../core/constants/difficulty.dart';

/// 난이도별 표시 색상 (presentation 전용 매핑).
extension DifficultyColor on Difficulty {
  Color get color {
    switch (this) {
      case Difficulty.veryEasy:
        return Colors.green;
      case Difficulty.easy:
        return Colors.teal;
      case Difficulty.normal:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.deepOrange;
      case Difficulty.extreme:
        return Colors.purple;
    }
  }
}

/// 5단계 난이도 선택 위젯 (ChoiceChip Wrap).
///
/// 홈 화면(싱글)과 멀티 로비 설정 패널에서 공통으로 사용한다.
/// [onChanged]가 null이면 읽기 전용(비방장)으로 동작한다.
class DifficultySelector extends StatelessWidget {
  final Difficulty value;
  final ValueChanged<Difficulty>? onChanged;

  const DifficultySelector({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: Difficulty.values.map((d) {
        final selected = d == value;
        return ChoiceChip(
          label: Text(d.labelKo),
          selected: selected,
          showCheckmark: false,
          onSelected:
              onChanged == null ? null : (_) => onChanged!(d),
          selectedColor: d.color.withValues(alpha: 0.18),
          side: selected ? BorderSide(color: d.color, width: 1.5) : null,
          labelStyle: TextStyle(
            color: selected ? d.color : null,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }
}
