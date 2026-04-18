enum ItemType {
  hint,    // 💡 나에게: 빈 칸 하나 정답 채우기
  blind,   // 🌫️ 상대에게: 5초간 화면 흐리기
  freeze,  // ⏸️ 상대에게: N초 입력 잠금
  hintCut, // ✂️ 상대에게: 상대 아이템 1개 제거
}

extension ItemTypeX on ItemType {
  String get emoji {
    switch (this) {
      case ItemType.hint:    return '💡';
      case ItemType.blind:   return '🌫️';
      case ItemType.freeze:  return '⏸️';
      case ItemType.hintCut: return '✂️';
    }
  }

  String get name {
    switch (this) {
      case ItemType.hint:    return '힌트';
      case ItemType.blind:   return '블라인드';
      case ItemType.freeze:  return '프리즈';
      case ItemType.hintCut: return '힌트 커트';
    }
  }

  /// 상대방을 타겟으로 하는 아이템인지
  bool get targetsOpponent => this != ItemType.hint;

  String get dbKey {
    switch (this) {
      case ItemType.hint:    return 'hint';
      case ItemType.blind:   return 'blind';
      case ItemType.freeze:  return 'freeze';
      case ItemType.hintCut: return 'hint_cut';
    }
  }

  static ItemType? fromDbKey(String key) {
    switch (key) {
      case 'hint':     return ItemType.hint;
      case 'blind':    return ItemType.blind;
      case 'freeze':   return ItemType.freeze;
      case 'hint_cut': return ItemType.hintCut;
      default:         return null;
    }
  }
}
