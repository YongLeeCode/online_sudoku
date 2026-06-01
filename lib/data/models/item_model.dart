enum ItemType {
  hint,    // 💡 나에게: 빈 칸 하나 정답 채우기
  blind,   // 🌫️ 상대에게: N초간 화면 흐리기
  freeze,  // ⏸️ 상대에게: N초 입력 잠금
  itemCut, // ✂️ 상대에게: 상대 아이템 1개 제거
  shield,  // 🛡️ 나에게: 다음 상대 아이템 1개 방어
  reverse, // 💥 상대에게: 상대의 정답 칸 하나를 지움
  mystery, // ❓ 즉시: 랜덤 효과 발동 (자신/상대, 좋음/나쁨)
}

extension ItemTypeX on ItemType {
  String get emoji {
    switch (this) {
      case ItemType.hint:    return '💡';
      case ItemType.blind:   return '🌫️';
      case ItemType.freeze:  return '⏸️';
      case ItemType.itemCut: return '✂️';
      case ItemType.shield:  return '🛡️';
      case ItemType.reverse: return '💥';
      case ItemType.mystery: return '❓';
    }
  }

  String get name {
    switch (this) {
      case ItemType.hint:    return '힌트';
      case ItemType.blind:   return '블라인드';
      case ItemType.freeze:  return '프리즈';
      case ItemType.itemCut: return '아이템 커터';
      case ItemType.shield:  return '방어막';
      case ItemType.reverse: return '리버스';
      case ItemType.mystery: return '미스터리';
    }
  }

  /// 상대방을 타겟으로 하는 아이템인지 (true → 상대 게이지 탭 필요)
  bool get targetsOpponent {
    switch (this) {
      case ItemType.blind:
      case ItemType.freeze:
      case ItemType.itemCut:
      case ItemType.reverse:
        return true;
      case ItemType.hint:
      case ItemType.shield:
      case ItemType.mystery:
        return false;
    }
  }

  String get dbKey {
    switch (this) {
      case ItemType.hint:    return 'hint';
      case ItemType.blind:   return 'blind';
      case ItemType.freeze:  return 'freeze';
      case ItemType.itemCut: return 'item_cut';
      case ItemType.shield:  return 'shield';
      case ItemType.reverse: return 'reverse';
      case ItemType.mystery: return 'mystery';
    }
  }

  static ItemType? fromDbKey(String key) {
    switch (key) {
      case 'hint':     return ItemType.hint;
      case 'blind':    return ItemType.blind;
      case 'freeze':   return ItemType.freeze;
      case 'item_cut': return ItemType.itemCut;
      case 'shield':   return ItemType.shield;
      case 'reverse':  return ItemType.reverse;
      case 'mystery':  return ItemType.mystery;
      default:         return null;
    }
  }
}
