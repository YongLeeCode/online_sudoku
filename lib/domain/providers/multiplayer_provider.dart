import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/game_repository.dart';
import 'room_provider.dart';

// Game repository
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.read(supabaseProvider));
});

// Event repository
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.read(supabaseProvider));
});

// 현재 선택된 아이템 슬롯 인덱스 (타겟 선택 모드용)
final selectedItemSlotProvider = StateProvider<int?>((_) => null);

// 현재 게임 ID
final currentGameIdProvider = StateProvider<String?>((_) => null);

// 현재 게임 seed
final currentGameSeedProvider = StateProvider<int?>((_) => null);

// 1등 확정 여부
final firstClearProvider = StateProvider<bool>((_) => false);

// 오버타임 남은 시간 (초)
final overtimeRemainingProvider = StateProvider<int>((_) => AppConstants.overtimeSeconds);

// 다른 플레이어들의 진행률 실시간 조회
final opponentStatesProvider =
    StreamProvider.autoDispose<List<OpponentState>>((ref) {
  final gameId = ref.watch(currentGameIdProvider);
  final myPlayerId = ref.watch(currentPlayerProvider)?.id;
  if (gameId == null) return const Stream.empty();

  final repo = ref.read(gameRepositoryProvider);
  final controller = StreamController<List<OpponentState>>();
  bool disposed = false;

  Future<void> fetch() async {
    if (disposed) return;
    try {
      final states = await repo.getPlayerGameStates(gameId);
      if (disposed || controller.isClosed) return;
      final opponents = states.map((s) {
        final players = s['players'] as Map<String, dynamic>?;
        return OpponentState(
          playerId: s['player_id'] as String,
          nickname: players?['nickname'] as String? ?? '???',
          progress: s['progress'] as int,
          totalBlanks: s['total_blanks'] as int,
          rank: s['rank'] as int?,
          finishedAt: s['finished_at'] != null
              ? DateTime.parse(s['finished_at'] as String)
              : null,
          isMe: s['player_id'] == myPlayerId,
          isConnected: players?['is_connected'] as bool? ?? false,
        );
      }).toList();
      if (!disposed && !controller.isClosed) controller.add(opponents);
    } catch (_) {}
  }

  fetch();
  final timer = Timer.periodic(const Duration(seconds: 2), (_) => fetch());

  // Realtime도 시도
  final client = ref.read(supabaseProvider);
  final channel = client.channel('game-states-$gameId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'player_game_states',
        callback: (_) { if (!disposed) fetch(); },
      )
      .subscribe();

  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

class OpponentState {
  final String playerId;
  final String nickname;
  final int progress;
  final int totalBlanks;
  final int? rank;
  final DateTime? finishedAt;
  final bool isMe;
  final bool isConnected;

  const OpponentState({
    required this.playerId,
    required this.nickname,
    required this.progress,
    required this.totalBlanks,
    this.rank,
    this.finishedAt,
    required this.isMe,
    this.isConnected = true,
  });

  double get progressPercent =>
      totalBlanks == 0 ? 0 : progress / totalBlanks;
}
