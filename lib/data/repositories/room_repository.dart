import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/errors/app_exception.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../models/room_settings_model.dart';

class RoomRepository {
  final SupabaseClient _client;

  RoomRepository(this._client);

  /// 6자리 방 코드 생성
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 혼동 문자 제외
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 방 생성 + 설정 + 방장 플레이어 생성
  Future<({RoomModel room, PlayerModel player})> createRoom({
    required String nickname,
  }) async {
    final code = _generateCode();
    final tempHostId = const Uuid().v4();

    // 방 생성 (임시 host_id, 플레이어 생성 후 업데이트)
    final roomData = await _client
        .from(SupabaseConstants.roomsTable)
        .insert({
          'code': code,
          'host_id': tempHostId,
          'status': 'waiting',
          'max_players': 6,
        })
        .select()
        .single();

    final room = RoomModel.fromJson(roomData);

    // 방 설정 생성
    await _client.from(SupabaseConstants.roomSettingsTable).insert({
      'room_id': room.id,
      'difficulty': 5,
      'penalty_seconds': 5,
      'item_interval': 10,
      'allowed_items': ['hint', 'blind', 'hint_cut', 'freeze'],
      'hint_counts': {},
    });

    // 방장 플레이어 생성
    final playerData = await _client
        .from(SupabaseConstants.playersTable)
        .insert({
          'room_id': room.id,
          'nickname': nickname,
          'is_host': true,
          'is_ready': true, // 방장은 항상 준비 완료
          'is_connected': true,
        })
        .select()
        .single();

    final player = PlayerModel.fromJson(playerData);

    // host_id를 player.id로 업데이트
    await _client
        .from(SupabaseConstants.roomsTable)
        .update({'host_id': player.id})
        .eq('id', room.id);

    final updatedRoom = RoomModel(
      id: room.id,
      code: room.code,
      hostId: player.id,
      status: room.status,
      maxPlayers: room.maxPlayers,
      createdAt: room.createdAt,
    );

    return (room: updatedRoom, player: player);
  }

  /// 방 코드로 입장
  Future<({RoomModel room, PlayerModel player})> joinRoom({
    required String code,
    required String nickname,
  }) async {
    // 방 찾기
    final roomData = await _client
        .from(SupabaseConstants.roomsTable)
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();

    if (roomData == null) {
      throw const RoomNotFoundException();
    }

    final room = RoomModel.fromJson(roomData);

    if (room.status != 'waiting') {
      throw const GameAlreadyStartedException();
    }

    // 현재 인원 확인
    final players = await _client
        .from(SupabaseConstants.playersTable)
        .select()
        .eq('room_id', room.id)
        .eq('is_connected', true);

    if ((players as List).length >= room.maxPlayers) {
      throw const RoomFullException();
    }

    // 플레이어 생성
    final playerData = await _client
        .from(SupabaseConstants.playersTable)
        .insert({
          'room_id': room.id,
          'nickname': nickname,
          'is_host': false,
          'is_ready': false,
          'is_connected': true,
        })
        .select()
        .single();

    final player = PlayerModel.fromJson(playerData);

    return (room: room, player: player);
  }

  /// 방 정보 조회
  Future<RoomModel> getRoom(String roomId) async {
    final data = await _client
        .from(SupabaseConstants.roomsTable)
        .select()
        .eq('id', roomId)
        .single();
    return RoomModel.fromJson(data);
  }

  /// 방 설정 조회
  Future<RoomSettingsModel> getRoomSettings(String roomId) async {
    final data = await _client
        .from(SupabaseConstants.roomSettingsTable)
        .select()
        .eq('room_id', roomId)
        .single();
    return RoomSettingsModel.fromJson(data);
  }

  /// 방 설정 업데이트 (방장만)
  Future<void> updateRoomSettings(RoomSettingsModel settings) async {
    await _client
        .from(SupabaseConstants.roomSettingsTable)
        .update(settings.toJson())
        .eq('room_id', settings.roomId);
  }

  /// 방 상태 변경
  Future<void> updateRoomStatus(String roomId, String status) async {
    await _client
        .from(SupabaseConstants.roomsTable)
        .update({'status': status})
        .eq('id', roomId);
  }

  /// 플레이어 목록 조회
  Future<List<PlayerModel>> getPlayers(String roomId) async {
    final data = await _client
        .from(SupabaseConstants.playersTable)
        .select()
        .eq('room_id', roomId)
        .eq('is_connected', true)
        .order('joined_at');
    return (data as List).map((e) => PlayerModel.fromJson(e)).toList();
  }

  /// 준비 상태 토글
  Future<void> toggleReady(String playerId, bool isReady) async {
    await _client
        .from(SupabaseConstants.playersTable)
        .update({'is_ready': isReady})
        .eq('id', playerId);
  }

  /// 플레이어 연결 해제 (퇴장)
  Future<void> disconnectPlayer(String playerId) async {
    await _client
        .from(SupabaseConstants.playersTable)
        .update({'is_connected': false})
        .eq('id', playerId);
  }

  /// 방의 players 실시간 스트림 (채널 기반)
  Stream<List<PlayerModel>> watchPlayers(String roomId) async* {
    // 초기 데이터
    yield await getPlayers(roomId);

    // Realtime 변경 감지 → 변경될 때마다 전체 목록 다시 조회
    final controller = StreamController<List<PlayerModel>>();
    final channel = _client.channel('players:$roomId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.playersTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final players = await getPlayers(roomId);
            if (!controller.isClosed) {
              controller.add(players);
            }
          },
        )
        .subscribe();

    yield* controller.stream;

    // cleanup
    await channel.unsubscribe();
    await controller.close();
  }

  /// 방 상태 실시간 스트림 (채널 기반)
  Stream<RoomModel> watchRoom(String roomId) async* {
    // 초기 데이터
    yield await getRoom(roomId);

    final controller = StreamController<RoomModel>();
    final channel = _client.channel('room:$roomId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.roomsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) async {
            final room = await getRoom(roomId);
            if (!controller.isClosed) {
              controller.add(room);
            }
          },
        )
        .subscribe();

    yield* controller.stream;

    await channel.unsubscribe();
    await controller.close();
  }
}
