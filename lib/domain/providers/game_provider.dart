import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/puzzle_generator.dart';
import '../../data/models/item_model.dart';

// 선택된 셀 좌표
final selectedCellProvider = StateProvider<(int, int)?>((_) => null);

// 난이도
final difficultyProvider = StateProvider<int>((_) => 5);

// 메모 모드 (연필 버튼)
final memoModeProvider = StateProvider<bool>((_) => false);

// 게임 상태 Provider
final gameProvider = StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier();
});

class GameState {
  final List<List<int>> puzzle;         // 초기 퍼즐 (0 = 빈칸)
  final List<List<int>> current;        // 현재 유저 입력 상태
  final List<List<int>> solution;       // 정답
  final List<List<Set<int>>> notes;     // 메모 후보 숫자 (9x9)
  final int totalBlanks;
  final int filledCount;                // 유저가 채운 칸 수
  final Set<(int, int)> errorCells;    // 오답 셀
  final bool isCompleted;
  final DateTime startedAt;
  final Duration? completedDuration;
  final bool isPenalized;              // 오답 패널티 중
  final int penaltySeconds;            // 패널티 시간
  final int penaltyRemaining;          // 남은 패널티 시간

  // 아이템 시스템
  final Set<(int, int)> itemCells;     // 아이템 지급 칸 (게임 시작 시 고정)
  final List<ItemType> itemPool;        // 이 게임에서 나올 수 있는 아이템 풀
  final List<ItemType?> myItems;        // 내 아이템 슬롯 4칸 (null = 비어있음)
  final bool isBlinded;                // 블라인드 효과 중
  final int blindRemaining;            // 블라인드 남은 초
  final bool isFrozen;                 // 프리즈 효과 중
  final int freezeRemaining;           // 프리즈 남은 초

  const GameState({
    required this.puzzle,
    required this.current,
    required this.solution,
    required this.notes,
    required this.totalBlanks,
    required this.filledCount,
    required this.errorCells,
    required this.isCompleted,
    required this.startedAt,
    this.completedDuration,
    this.isPenalized = false,
    this.penaltySeconds = 5,
    this.penaltyRemaining = 0,
    required this.itemCells,
    required this.itemPool,
    required this.myItems,
    this.isBlinded = false,
    this.blindRemaining = 0,
    this.isFrozen = false,
    this.freezeRemaining = 0,
  });

  double get progress => totalBlanks == 0 ? 0 : filledCount / totalBlanks;

  bool isOriginalCell(int row, int col) => puzzle[row][col] != 0;

  bool isItemCell(int row, int col) =>
      itemCells.contains((row, col)) && current[row][col] == 0;

  bool get isInputBlocked => isPenalized || isFrozen;

  /// 각 숫자(1~9)가 보드에 몇 개 있는지 카운트
  Map<int, int> get numberCounts {
    final counts = <int, int>{};
    for (int n = 1; n <= 9; n++) { counts[n] = 0; }
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = current[r][c];
        if (v != 0 && v == solution[r][c]) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  bool isNumberCompleted(int number) => (numberCounts[number] ?? 0) >= 9;

  GameState copyWith({
    List<List<int>>? current,
    List<List<Set<int>>>? notes,
    int? filledCount,
    Set<(int, int)>? errorCells,
    bool? isCompleted,
    Duration? completedDuration,
    bool? isPenalized,
    int? penaltyRemaining,
    List<ItemType?>? myItems,
    bool? isBlinded,
    int? blindRemaining,
    bool? isFrozen,
    int? freezeRemaining,
  }) {
    return GameState(
      puzzle: puzzle,
      current: current ?? this.current,
      solution: solution,
      notes: notes ?? this.notes,
      totalBlanks: totalBlanks,
      filledCount: filledCount ?? this.filledCount,
      errorCells: errorCells ?? this.errorCells,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt,
      completedDuration: completedDuration ?? this.completedDuration,
      isPenalized: isPenalized ?? this.isPenalized,
      penaltySeconds: penaltySeconds,
      penaltyRemaining: penaltyRemaining ?? this.penaltyRemaining,
      itemCells: itemCells,
      itemPool: itemPool,
      myItems: myItems ?? this.myItems,
      isBlinded: isBlinded ?? this.isBlinded,
      blindRemaining: blindRemaining ?? this.blindRemaining,
      isFrozen: isFrozen ?? this.isFrozen,
      freezeRemaining: freezeRemaining ?? this.freezeRemaining,
    );
  }
}

List<List<Set<int>>> _emptyNotes() =>
    List.generate(9, (_) => List.generate(9, (_) => <int>{}));

List<List<Set<int>>> _deepCopyNotes(List<List<Set<int>>> notes) =>
    notes.map((row) => row.map((cell) => Set<int>.from(cell)).toList()).toList();

// 멀티플레이어 진행률 동기화 콜백
typedef OnProgressChanged = void Function(int progress, bool isCompleted);
// 아이템 획득 알림 콜백
typedef OnItemCollected = void Function(ItemType item);

class GameNotifier extends StateNotifier<GameState?> {
  OnProgressChanged? onProgressChanged;
  OnItemCollected? onItemCollected;

  GameNotifier() : super(null);

  /// 싱글플레이어: 힌트 아이템만 지급
  void startGame(int difficulty, {int? penaltySeconds}) {
    final seed = Random().nextInt(0x7FFFFFFF);
    startGameWithSeed(seed, difficulty,
        penaltySeconds: penaltySeconds,
        itemPool: [ItemType.hint]);
  }

  /// 시드 기반 시작 (멀티플레이어에서도 사용)
  void startGameWithSeed(
    int seed,
    int difficulty, {
    int? penaltySeconds,
    List<ItemType>? itemPool,
  }) {
    final data = PuzzleGenerator.generate(seed: seed, difficulty: difficulty);

    // 아이템 셀 결정 (seed 기반 → 같은 게임의 모든 플레이어가 동일한 셀)
    final itemRng = Random(seed ^ 0xCAFEBABE);
    final blanks = <(int, int)>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (data.puzzle[r][c] == 0) blanks.add((r, c));
      }
    }
    blanks.shuffle(itemRng);
    final itemCount = (blanks.length / 10).ceil().clamp(3, 6);
    final itemCells = blanks.take(itemCount).toSet();

    final pool = itemPool ?? ItemType.values.toList();

    state = GameState(
      puzzle: data.puzzle,
      current: data.puzzle.map((row) => List<int>.from(row)).toList(),
      solution: data.solution,
      notes: _emptyNotes(),
      totalBlanks: data.totalBlanks,
      filledCount: 0,
      errorCells: {},
      isCompleted: false,
      startedAt: DateTime.now(),
      penaltySeconds: penaltySeconds ?? 5,
      itemCells: itemCells,
      itemPool: pool,
      myItems: List.filled(4, null),
    );
  }

  // ────────────────────────────────────────────────
  //  입력
  // ────────────────────────────────────────────────

  void inputNumber(int row, int col, int number, {bool isMemoMode = false}) {
    final s = state;
    if (s == null || s.isCompleted || s.isInputBlocked) return;
    if (s.isOriginalCell(row, col)) return;

    // 메모 모드
    if (isMemoMode) {
      if (s.current[row][col] != 0) return;
      final newNotes = _deepCopyNotes(s.notes);
      if (newNotes[row][col].contains(number)) {
        newNotes[row][col].remove(number);
      } else {
        newNotes[row][col].add(number);
      }
      state = s.copyWith(notes: newNotes);
      return;
    }

    // 정답 검증
    if (number != s.solution[row][col]) {
      state = s.copyWith(isPenalized: true, penaltyRemaining: s.penaltySeconds);
      return;
    }

    // 정답 입력
    final newCurrent = s.current.map((r) => List<int>.from(r)).toList();
    newCurrent[row][col] = number;

    // 메모 자동 제거 (같은 행/열/박스)
    final newNotes = _deepCopyNotes(s.notes);
    newNotes[row][col].clear();
    for (int i = 0; i < 9; i++) {
      newNotes[row][i].remove(number);
      newNotes[i][col].remove(number);
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        newNotes[r][c].remove(number);
      }
    }

    final newErrors = Set<(int, int)>.from(s.errorCells)..remove((row, col));

    int filled = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (s.puzzle[r][c] == 0 && newCurrent[r][c] != 0) filled++;
      }
    }

    final completed = (newErrors.isEmpty && filled == s.totalBlanks);
    final duration = completed ? DateTime.now().difference(s.startedAt) : null;

    // 아이템 셀 확인
    final newItems = List<ItemType?>.from(s.myItems);
    if (s.itemCells.contains((row, col)) && s.itemPool.isNotEmpty) {
      final newItem = s.itemPool[Random().nextInt(s.itemPool.length)];
      final emptySlot = newItems.indexOf(null);
      if (emptySlot != -1) {
        newItems[emptySlot] = newItem;
        onItemCollected?.call(newItem);
      }
      // 슬롯이 가득 차면 자동 소멸
    }

    state = s.copyWith(
      current: newCurrent,
      notes: newNotes,
      myItems: newItems,
      filledCount: filled,
      errorCells: newErrors,
      isCompleted: completed,
      completedDuration: duration,
    );

    onProgressChanged?.call(filled, completed);
  }

  void eraseCell(int row, int col) {
    final s = state;
    if (s == null || s.isCompleted || s.isInputBlocked) return;
    if (s.isOriginalCell(row, col)) return;
    if (s.current[row][col] == 0 && s.notes[row][col].isEmpty) return;

    final newCurrent = s.current.map((r) => List<int>.from(r)).toList();
    newCurrent[row][col] = 0;

    final newNotes = _deepCopyNotes(s.notes);
    newNotes[row][col].clear();

    final newErrors = Set<(int, int)>.from(s.errorCells)..remove((row, col));

    int filled = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (s.puzzle[r][c] == 0 && newCurrent[r][c] != 0) filled++;
      }
    }

    state = s.copyWith(
      current: newCurrent,
      notes: newNotes,
      filledCount: filled,
      errorCells: newErrors,
    );
  }

  // ────────────────────────────────────────────────
  //  아이템 사용
  // ────────────────────────────────────────────────

  /// 💡 힌트: 선택된 빈 칸에 정답 채우기
  void useHintItem(int slotIndex, int row, int col) {
    final s = state;
    if (s == null || s.isCompleted) return;
    if (s.myItems[slotIndex] != ItemType.hint) return;
    if (s.isOriginalCell(row, col)) return;
    if (s.current[row][col] != 0) return; // 이미 채워진 칸

    final answer = s.solution[row][col];

    final newCurrent = s.current.map((r) => List<int>.from(r)).toList();
    newCurrent[row][col] = answer;

    final newNotes = _deepCopyNotes(s.notes);
    newNotes[row][col].clear();
    for (int i = 0; i < 9; i++) {
      newNotes[row][i].remove(answer);
      newNotes[i][col].remove(answer);
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        newNotes[r][c].remove(answer);
      }
    }

    int filled = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (s.puzzle[r][c] == 0 && newCurrent[r][c] != 0) filled++;
      }
    }

    final completed = filled == s.totalBlanks;
    final newItems = List<ItemType?>.from(s.myItems)..[slotIndex] = null;

    state = s.copyWith(
      current: newCurrent,
      notes: newNotes,
      myItems: newItems,
      filledCount: filled,
      isCompleted: completed,
      completedDuration: completed ? DateTime.now().difference(s.startedAt) : null,
    );

    onProgressChanged?.call(filled, completed);
  }

  /// 슬롯에서 아이템 제거 (힌트 커트 당했을 때)
  void removeItemAt(int slotIndex) {
    final s = state;
    if (s == null) return;
    final newItems = List<ItemType?>.from(s.myItems)..[slotIndex] = null;
    state = s.copyWith(myItems: newItems);
  }

  /// 첫 번째 채워진 슬롯의 아이템 제거 (상대가 힌트 커트 사용 시)
  void removeFirstItem() {
    final s = state;
    if (s == null) return;
    final idx = s.myItems.indexWhere((item) => item != null);
    if (idx == -1) return;
    final newItems = List<ItemType?>.from(s.myItems)..[idx] = null;
    state = s.copyWith(myItems: newItems);
  }

  // ────────────────────────────────────────────────
  //  아이템 효과 수신 (상대가 나에게 사용)
  // ────────────────────────────────────────────────

  /// 🌫️ 블라인드: 그리드 흐리기
  void applyBlind(int seconds) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(isBlinded: true, blindRemaining: seconds);
  }

  /// ⏸️ 프리즈: 입력 잠금
  void applyFreeze(int seconds) {
    final s = state;
    if (s == null || s.isInputBlocked) return;
    state = s.copyWith(isFrozen: true, freezeRemaining: seconds);
  }

  // ────────────────────────────────────────────────
  //  타이머 틱
  // ────────────────────────────────────────────────

  void penaltyTick() {
    final s = state;
    if (s == null || !s.isPenalized) return;
    final remaining = s.penaltyRemaining - 1;
    state = remaining <= 0
        ? s.copyWith(isPenalized: false, penaltyRemaining: 0)
        : s.copyWith(penaltyRemaining: remaining);
  }

  void blindTick() {
    final s = state;
    if (s == null || !s.isBlinded) return;
    final remaining = s.blindRemaining - 1;
    state = remaining <= 0
        ? s.copyWith(isBlinded: false, blindRemaining: 0)
        : s.copyWith(blindRemaining: remaining);
  }

  void freezeTick() {
    final s = state;
    if (s == null || !s.isFrozen) return;
    final remaining = s.freezeRemaining - 1;
    state = remaining <= 0
        ? s.copyWith(isFrozen: false, freezeRemaining: 0)
        : s.copyWith(freezeRemaining: remaining);
  }
}
