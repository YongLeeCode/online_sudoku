import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/utils/puzzle_generator.dart';

class GameRepository {
  final SupabaseClient _client;

  GameRepository(this._client);

  /// 게임 생성 (방장이 호출)
  Future<GameRecord> createGame({
    required String roomId,
    required int difficulty,
    required List<String> playerIds,
    required Map<String, int> hintCounts,
    required int defaultHints,
  }) async {
    final seed = Random().nextInt(0x7FFFFFFF);
    final puzzleData = PuzzleGenerator.generate(seed: seed, difficulty: difficulty);

    // games 테이블에 저장
    final gameData = await _client
        .from(SupabaseConstants.gamesTable)
        .insert({
          'room_id': roomId,
          'puzzle_seed': seed,
          'answer_grid': puzzleData.solution,
          'status': 'playing',
        })
        .select()
        .single();

    final gameId = gameData['id'] as String;

    // 각 플레이어의 게임 상태 생성
    final playerStates = playerIds.map((pid) => {
          'game_id': gameId,
          'player_id': pid,
          'progress': 0,
          'total_blanks': puzzleData.totalBlanks,
          'hint_remaining': hintCounts[pid] ?? defaultHints,
          'is_penalized': false,
          'item_slots': <dynamic>[],
        }).toList();

    await _client
        .from(SupabaseConstants.playerGameStatesTable)
        .insert(playerStates);

    return GameRecord(
      gameId: gameId,
      seed: seed,
      difficulty: difficulty,
      puzzleData: puzzleData,
    );
  }

  /// 게임 정보 조회
  Future<Map<String, dynamic>> getGame(String gameId) async {
    return await _client
        .from(SupabaseConstants.gamesTable)
        .select()
        .eq('id', gameId)
        .single();
  }

  /// roomId로 현재 게임 조회
  Future<Map<String, dynamic>?> getActiveGame(String roomId) async {
    return await _client
        .from(SupabaseConstants.gamesTable)
        .select()
        .eq('room_id', roomId)
        .eq('status', 'playing')
        .maybeSingle();
  }

  /// 진행률 업데이트
  Future<void> updateProgress({
    required String gameId,
    required String playerId,
    required int progress,
  }) async {
    await _client
        .from(SupabaseConstants.playerGameStatesTable)
        .update({'progress': progress})
        .eq('game_id', gameId)
        .eq('player_id', playerId);
  }

  /// 클리어 처리
  Future<void> playerCleared({
    required String gameId,
    required String playerId,
    required int rank,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // player_game_states 업데이트
    await _client
        .from(SupabaseConstants.playerGameStatesTable)
        .update({
          'rank': rank,
          'finished_at': now,
        })
        .eq('game_id', gameId)
        .eq('player_id', playerId);

    // 1등이면 games 테이블에 first_clear_at 기록
    if (rank == 1) {
      await _client
          .from(SupabaseConstants.gamesTable)
          .update({'first_clear_at': now})
          .eq('id', gameId);
    }
  }

  /// 게임 종료 처리
  Future<void> finishGame(String gameId) async {
    await _client
        .from(SupabaseConstants.gamesTable)
        .update({
          'status': 'finished',
          'finished_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', gameId);
  }

  /// 게임/방 관련 모든 데이터 삭제 (FK 의존 순서 준수)
  Future<void> cleanupGame({
    required String gameId,
    required String roomId,
  }) async {
    // 1. game_events (game_id FK)
    await _client
        .from(SupabaseConstants.gameEventsTable)
        .delete()
        .eq('game_id', gameId);

    // 2. player_game_states (game_id FK)
    await _client
        .from(SupabaseConstants.playerGameStatesTable)
        .delete()
        .eq('game_id', gameId);

    // 3. games (room_id FK)
    await _client
        .from(SupabaseConstants.gamesTable)
        .delete()
        .eq('id', gameId);

    // 4. players (room_id FK)
    await _client
        .from(SupabaseConstants.playersTable)
        .delete()
        .eq('room_id', roomId);

    // 5. room_settings (room_id FK)
    await _client
        .from(SupabaseConstants.roomSettingsTable)
        .delete()
        .eq('room_id', roomId);

    // 6. rooms
    await _client
        .from(SupabaseConstants.roomsTable)
        .delete()
        .eq('id', roomId);
  }

  /// 모든 플레이어 게임 상태 조회
  Future<List<Map<String, dynamic>>> getPlayerGameStates(String gameId) async {
    final data = await _client
        .from(SupabaseConstants.playerGameStatesTable)
        .select('*, players(nickname, is_host, is_connected)')
        .eq('game_id', gameId)
        .order('progress', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}

class GameRecord {
  final String gameId;
  final int seed;
  final int difficulty;
  final PuzzleData puzzleData;

  const GameRecord({
    required this.gameId,
    required this.seed,
    required this.difficulty,
    required this.puzzleData,
  });
}
