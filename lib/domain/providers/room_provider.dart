import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/player_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/room_settings_model.dart';
import '../../data/repositories/room_repository.dart';

// Supabase client
final supabaseProvider = Provider<SupabaseClient>((_) {
  return Supabase.instance.client;
});

// Room repository
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(ref.read(supabaseProvider));
});

// 닉네임 관리
final nicknameProvider = StateNotifierProvider<NicknameNotifier, String>((ref) {
  return NicknameNotifier();
});

class NicknameNotifier extends StateNotifier<String> {
  static const _key = 'nickname';

  NicknameNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? '';
  }

  Future<void> setNickname(String name) async {
    state = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }
}

// 현재 방 상태
final currentRoomProvider = StateProvider<RoomModel?>((_) => null);

// 현재 내 플레이어 정보
final currentPlayerProvider = StateProvider<PlayerModel?>((_) => null);

// 방 설정
final roomSettingsProvider = StateProvider<RoomSettingsModel?>((_) => null);

// 방의 플레이어 목록 (폴링 + Realtime 병행)
final playersStreamProvider = StreamProvider.autoDispose<List<PlayerModel>>((ref) {
  final room = ref.watch(currentRoomProvider);
  if (room == null) return const Stream.empty();
  final repo = ref.read(roomRepositoryProvider);

  final controller = StreamController<List<PlayerModel>>();

  // 초기 로드
  Future<void> fetchPlayers() async {
    try {
      final players = await repo.getPlayers(room.id);
      if (!controller.isClosed) controller.add(players);
    } catch (_) {}
  }

  fetchPlayers();

  // 2초마다 폴링 (Realtime 백업)
  final timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchPlayers());

  // Realtime 채널도 시도
  final client = ref.read(supabaseProvider);
  final channel = client.channel('lobby-players-${room.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: room.id,
        ),
        callback: (_) => fetchPlayers(),
      )
      .subscribe();

  ref.onDispose(() {
    timer.cancel();
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

// 방 상태 (폴링 + Realtime 병행)
final roomStreamProvider = StreamProvider.autoDispose<RoomModel>((ref) {
  final room = ref.watch(currentRoomProvider);
  if (room == null) return const Stream.empty();
  final repo = ref.read(roomRepositoryProvider);

  final controller = StreamController<RoomModel>();

  Future<void> fetchRoom() async {
    try {
      final r = await repo.getRoom(room.id);
      if (!controller.isClosed) controller.add(r);
    } catch (_) {}
  }

  fetchRoom();

  final timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchRoom());

  final client = ref.read(supabaseProvider);
  final channel = client.channel('lobby-room-${room.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: room.id,
        ),
        callback: (_) => fetchRoom(),
      )
      .subscribe();

  ref.onDispose(() {
    timer.cancel();
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

// 모든 참여자 준비 완료 여부 (방장 제외)
final allReadyProvider = Provider<bool>((ref) {
  final playersAsync = ref.watch(playersStreamProvider);
  return playersAsync.when(
    data: (players) {
      final nonHostPlayers = players.where((p) => !p.isHost);
      if (nonHostPlayers.isEmpty) return false;
      return nonHostPlayers.every((p) => p.isReady);
    },
    loading: () => false,
    error: (_, _) => false,
  );
});

// 로비 액션들
class LobbyActions {
  final RoomRepository _repo;

  LobbyActions(this._repo);

  Future<({RoomModel room, PlayerModel player})> createRoom(String nickname) {
    return _repo.createRoom(nickname: nickname);
  }

  Future<({RoomModel room, PlayerModel player})> joinRoom(String code, String nickname) {
    return _repo.joinRoom(code: code, nickname: nickname);
  }

  Future<void> toggleReady(String playerId, bool isReady) {
    return _repo.toggleReady(playerId, isReady);
  }

  Future<void> updateSettings(RoomSettingsModel settings) {
    return _repo.updateRoomSettings(settings);
  }

  Future<void> startGame(String roomId) {
    return _repo.updateRoomStatus(roomId, 'playing');
  }

  Future<void> leaveRoom(String playerId) {
    return _repo.disconnectPlayer(playerId);
  }
}

final lobbyActionsProvider = Provider<LobbyActions>((ref) {
  return LobbyActions(ref.read(roomRepositoryProvider));
});
