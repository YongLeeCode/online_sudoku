import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';
import '../../core/constants/supabase_constants.dart';

class EventRepository {
  final SupabaseClient _client;

  EventRepository(this._client);

  /// 아이템 사용 이벤트를 DB에 기록
  Future<void> sendItemEvent({
    required String gameId,
    required String fromPlayerId,
    required ItemType itemType,
    required String targetPlayerId,
    int duration = 5,
  }) async {
    await _client.from(SupabaseConstants.gameEventsTable).insert({
      'game_id': gameId,
      'player_id': fromPlayerId,
      'event_type': 'item_used',
      'payload': {
        'item_type': itemType.dbKey,
        'target_player_id': targetPlayerId,
        'duration': duration,
      },
    });
  }

  /// 특정 시각 이후 나를 타겟으로 한 아이템 이벤트 조회
  Future<List<Map<String, dynamic>>> fetchItemEventsAfter({
    required String gameId,
    required String myPlayerId,
    required DateTime after,
  }) async {
    final rows = await _client
        .from(SupabaseConstants.gameEventsTable)
        .select()
        .eq('game_id', gameId)
        .eq('event_type', 'item_used')
        .gt('created_at', after.toUtc().toIso8601String())
        .order('created_at');

    return (rows as List).cast<Map<String, dynamic>>().where((row) {
      final payload = row['payload'] as Map<String, dynamic>?;
      return payload?['target_player_id'] == myPlayerId;
    }).toList();
  }
}
