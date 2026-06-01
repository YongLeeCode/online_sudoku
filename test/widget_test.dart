import 'package:flutter_test/flutter_test.dart';
import 'package:online_sudoku/core/constants/difficulty.dart';
import 'package:online_sudoku/core/utils/puzzle_generator.dart';

void main() {
  test('PuzzleGenerator produces valid puzzle', () {
    final data =
        PuzzleGenerator.generate(seed: 42, difficulty: Difficulty.normal);

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        expect(data.solution[r][c], inInclusiveRange(1, 9));
      }
    }

    int blanks = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (data.puzzle[r][c] == 0) blanks++;
      }
    }
    expect(blanks, data.totalBlanks);
  });

  test('Same seed produces same puzzle', () {
    final a = PuzzleGenerator.generate(seed: 123, difficulty: Difficulty.easy);
    final b = PuzzleGenerator.generate(seed: 123, difficulty: Difficulty.easy);

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        expect(a.puzzle[r][c], b.puzzle[r][c]);
        expect(a.solution[r][c], b.solution[r][c]);
      }
    }
  });
}
