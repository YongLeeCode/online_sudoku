import 'dart:math';

import '../constants/difficulty.dart';

class PuzzleGenerator {
  /// seed 기반으로 동일한 퍼즐을 생성
  static PuzzleData generate({
    required int seed,
    required Difficulty difficulty,
  }) {
    final random = Random(seed);
    final solution = List.generate(9, (_) => List.filled(9, 0));

    // 1) 대각선 3x3 박스를 먼저 채움 (서로 독립)
    for (int box = 0; box < 9; box += 3) {
      _fillBox(solution, box, box, random);
    }

    // 2) 나머지 칸을 백트래킹으로 채움
    _solveSudoku(solution);

    // 3) 난이도에 따라 칸을 제거
    final blanks = difficulty.blanks;
    final puzzle = solution.map((row) => List<int>.from(row)).toList();
    _removeCells(puzzle, blanks, random);

    return PuzzleData(
      puzzle: puzzle,
      solution: solution,
      totalBlanks: blanks,
    );
  }

  static void _fillBox(List<List<int>> grid, int rowStart, int colStart, Random random) {
    final nums = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(random);
    int idx = 0;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        grid[rowStart + r][colStart + c] = nums[idx++];
      }
    }
  }

  static bool _solveSudoku(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          for (int num = 1; num <= 9; num++) {
            if (_isValid(grid, row, col, num)) {
              grid[row][col] = num;
              if (_solveSudoku(grid)) return true;
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  static bool _isValid(List<List<int>> grid, int row, int col, int num) {
    // 행 검사
    for (int c = 0; c < 9; c++) {
      if (grid[row][c] == num) return false;
    }
    // 열 검사
    for (int r = 0; r < 9; r++) {
      if (grid[r][col] == num) return false;
    }
    // 3x3 박스 검사
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (grid[boxRow + r][boxCol + c] == num) return false;
      }
    }
    return true;
  }

  static void _removeCells(List<List<int>> puzzle, int count, Random random) {
    final positions = <int>[];
    for (int i = 0; i < 81; i++) {
      positions.add(i);
    }
    positions.shuffle(random);

    int removed = 0;
    for (final pos in positions) {
      if (removed >= count) break;
      final row = pos ~/ 9;
      final col = pos % 9;
      puzzle[row][col] = 0;
      removed++;
    }
  }
}

class PuzzleData {
  final List<List<int>> puzzle;
  final List<List<int>> solution;
  final int totalBlanks;

  const PuzzleData({
    required this.puzzle,
    required this.solution,
    required this.totalBlanks,
  });
}
