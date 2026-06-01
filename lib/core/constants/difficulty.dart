/// 게임 난이도 5단계.
///
/// 기존에는 1~10 정수 슬라이더였으나, 5단계 라벨로 개편되었다.
/// DB(`room_settings.difficulty`)에는 [dbValue](1~5) 정수로 저장한다.
/// 기존 제약(`between 1 and 10`)이 1~5를 그대로 허용하므로 마이그레이션이 필요 없다.
enum Difficulty {
  veryEasy(dbValue: 1, blanks: 30, label: 'Very Easy', labelKo: '아주 쉬움'),
  easy(dbValue: 2, blanks: 38, label: 'Easy', labelKo: '쉬움'),
  normal(dbValue: 3, blanks: 45, label: 'Normal', labelKo: '보통'),
  hard(dbValue: 4, blanks: 52, label: 'Hard', labelKo: '어려움'),
  extreme(dbValue: 5, blanks: 58, label: 'Extreme', labelKo: '극한');

  const Difficulty({
    required this.dbValue,
    required this.blanks,
    required this.label,
    required this.labelKo,
  });

  /// DB 저장값 (1~5).
  final int dbValue;

  /// 퍼즐에서 비울 칸 수.
  final int blanks;

  /// 영문 라벨.
  final String label;

  /// 한글 라벨 (UI 표시용).
  final String labelKo;

  /// DB/레거시 정수값으로부터 복원.
  ///
  /// 기존 1~10 슬라이더 값과의 하위호환: 1~5는 그대로 매핑되고,
  /// 6~10 등 범위를 벗어난 값은 [extreme]/[veryEasy]로 clamp 된다.
  static Difficulty fromDbValue(int value) {
    final clamped = value.clamp(1, 5);
    return values.firstWhere((d) => d.dbValue == clamped, orElse: () => normal);
  }
}
