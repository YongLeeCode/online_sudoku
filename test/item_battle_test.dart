import 'package:flutter_test/flutter_test.dart';

import 'package:online_sudoku/core/constants/difficulty.dart';
import 'package:online_sudoku/data/models/item_model.dart';
import 'package:online_sudoku/domain/providers/game_provider.dart';

void main() {
  group('방어막(실드) 3초 지속', () {
    test('applyShield() 이후 isShielded=true, shieldRemaining=3', () {
      final notifier = GameNotifier()..startGame(Difficulty.veryEasy);
      notifier.applyShield();
      expect(notifier.state!.isShielded, isTrue);
      expect(notifier.state!.shieldRemaining, 3);
    });

    test('shieldTick() 3회면 자동 해제된다', () {
      final notifier = GameNotifier()..startGame(Difficulty.veryEasy);
      notifier.applyShield();

      notifier.shieldTick(); // 3 -> 2
      expect(notifier.state!.shieldRemaining, 2);
      expect(notifier.state!.isShielded, isTrue);

      notifier.shieldTick(); // 2 -> 1
      notifier.shieldTick(); // 1 -> 0 => 해제
      expect(notifier.state!.shieldRemaining, 0);
      expect(notifier.state!.isShielded, isFalse);
    });

    test('consumeShield()는 즉시 해제하고 남은 시간을 0으로 만든다', () {
      final notifier = GameNotifier()..startGame(Difficulty.veryEasy);
      notifier.applyShield();
      notifier.consumeShield();
      expect(notifier.state!.isShielded, isFalse);
      expect(notifier.state!.shieldRemaining, 0);
    });

    test('shieldTick()은 실드가 없으면 아무 일도 하지 않는다', () {
      final notifier = GameNotifier()..startGame(Difficulty.veryEasy);
      expect(notifier.state!.isShielded, isFalse);
      notifier.shieldTick();
      expect(notifier.state!.shieldRemaining, 0);
    });
  });

  group('로비 허용 아이템 → 아이템 풀 매핑', () {
    test('allowed_items dbKey 리스트가 ItemType 풀로 매핑된다', () {
      final pool = ['hint', 'shield', 'item_cut']
          .map(ItemTypeX.fromDbKey)
          .whereType<ItemType>()
          .toList();
      expect(pool, [ItemType.hint, ItemType.shield, ItemType.itemCut]);
    });

    test('알 수 없는 키는 무시된다', () {
      final pool = ['hint', 'bogus', 'hint_cut']
          .map(ItemTypeX.fromDbKey)
          .whereType<ItemType>()
          .toList();
      expect(pool, [ItemType.hint]);
    });

    test('startGameWithSeed에 넘긴 풀이 그대로 반영된다 (빈 풀 포함)', () {
      final notifier = GameNotifier();
      notifier.startGameWithSeed(
        12345,
        Difficulty.veryEasy,
        itemPool: const [ItemType.hint, ItemType.shield],
      );
      expect(notifier.state!.itemPool, [ItemType.hint, ItemType.shield]);

      notifier.startGameWithSeed(12345, Difficulty.veryEasy, itemPool: const []);
      expect(notifier.state!.itemPool, isEmpty);
    });
  });
}
