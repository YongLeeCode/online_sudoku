enum ItemType {
  hint,    // 💡 나에게: 빈 칸 하나 정답 채우기
  blind,   // 🌫️ 상대에게: N초간 화면 흐리기
  freeze,  // ⏸️ 상대에게: N초 입력 잠금
  itemCut, // ✂️ 상대에게: 상대 아이템 1개 제거
  shield,  // 🛡️ 나에게: 다음 상대 아이템 1개 방어
  reverse, // 💥 상대에게: 상대의 정답 칸 하나를 지움
  mystery, // ❓ 즉시: 랜덤 효과 발동 (자신/상대, 좋음/나쁨)
}

/// 아이템 사용 대상 분류 (아이템 설명 페이지의 그룹 구분에 사용).
enum ItemTarget {
  self('나에게', '내 풀이를 돕는 아이템'),
  opponent('상대에게', '상대를 방해하는 아이템'),
  instant('즉시 발동', '쓰는 순간 효과가 결정되는 아이템');

  const ItemTarget(this.labelKo, this.descriptionKo);

  final String labelKo;
  final String descriptionKo;
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

  /// 아이템 설명 페이지에서의 그룹(나에게 / 상대에게 / 즉시 발동) 분류.
  ItemTarget get target {
    switch (this) {
      case ItemType.hint:
      case ItemType.shield:
        return ItemTarget.self;
      case ItemType.blind:
      case ItemType.freeze:
      case ItemType.itemCut:
      case ItemType.reverse:
        return ItemTarget.opponent;
      case ItemType.mystery:
        return ItemTarget.instant;
    }
  }

  /// 효과 설명 텍스트 (아이템 설명/도감 페이지에서 사용).
  String get description {
    switch (this) {
      case ItemType.hint:    return '선택한 빈 칸 하나를 정답으로 채워줍니다.';
      case ItemType.blind:   return '상대 보드의 3×3 박스 하나를 일정 시간 가립니다. (3초 경고 후 발동 · 실드로 방어 가능)';
      case ItemType.freeze:  return '상대의 숫자 입력을 일정 시간 잠급니다. (3초 경고 후 발동 · 실드로 방어 가능)';
      case ItemType.itemCut: return '상대가 가진 아이템 1개를 제거합니다. (3초 경고 후 발동 · 실드로 방어 가능)';
      case ItemType.shield:  return '3초간 유지되며 그 사이 날아온 상대 아이템 1개를 막아냅니다.';
      case ItemType.reverse: return '상대가 맞게 채운 칸 하나를 다시 비웁니다. (3초 경고 후 발동 · 실드로 방어 가능)';
      case ItemType.mystery: return '랜덤 효과가 즉시 발동됩니다. 행운일 수도, 불운일 수도!';
    }
  }

  /// 효과 지속 시간 라벨 (아이템 설명 페이지에서 사용).
  String get durationLabel {
    switch (this) {
      case ItemType.blind:   return '30초 지속';
      case ItemType.freeze:  return '5초 지속';
      case ItemType.shield:  return '3초 · 1회';
      case ItemType.hint:
      case ItemType.itemCut:
      case ItemType.reverse:
      case ItemType.mystery:
        return '즉시 발동';
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
