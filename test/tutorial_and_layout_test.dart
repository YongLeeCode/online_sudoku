import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_sudoku/core/constants/difficulty.dart';
import 'package:online_sudoku/core/utils/puzzle_generator.dart';
import 'package:online_sudoku/domain/providers/game_provider.dart';
import 'package:online_sudoku/presentation/screens/game_screen.dart';
import 'package:online_sudoku/presentation/screens/root_screen.dart';
import 'package:online_sudoku/presentation/screens/tutorial_menu_screen.dart';
import 'package:online_sudoku/presentation/screens/tutorial_screen.dart';
import 'package:online_sudoku/presentation/widgets/sudoku/sudoku_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // nickname / tutorialCompleted Notifier가 생성자에서 SharedPreferences를 읽음
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GameScreen은 넓고 낮은 화면에서도 오버플로가 없다 (반응형)', (tester) async {
    // 태블릿/가로모드 같은 "넓고 낮은" 화면 — 기존엔 그리드가 세로 공간을 넘쳤다.
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(gameProvider.notifier).startGame(Difficulty.veryEasy);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SudokuGrid), findsOneWidget);

    // 타이머 정리
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('게임 화면을 열면 하단 네비게이션 바가 화면에서 사라진다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(navigatorKey: navKey, home: const RootScreen()),
      ),
    );
    await tester.pump();

    // 탭 화면(루트)에서는 하단바가 보인다.
    expect(find.byType(NavigationBar), findsOneWidget);

    // 게임 화면을 전체화면 라우트로 push (홈에서의 진입과 동일한 방식).
    container.read(gameProvider.notifier).startGame(Difficulty.veryEasy);
    navKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
    // push 전환 애니메이션을 끝까지 진행시킨다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 불투명한 게임 라우트가 위에 덮이면 하단바(루트 화면)는 트리에서 빠진다.
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TutorialScreen이 첫 단계를 정상적으로 띄운다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TutorialScreen()),
      ),
    );
    // initState의 postFrameCallback이 첫 단계 보드를 주입하도록 한 프레임 더.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('셀 선택과 숫자 입력'), findsOneWidget);
    expect(find.byType(SudokuGrid), findsOneWidget);
    // 진행 표시
    expect(find.textContaining('1/12'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('튜토리얼 메뉴에서 스테이지를 골라 해당 단계로 진입한다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TutorialMenuScreen()),
      ),
    );
    await tester.pump();

    // 메뉴에 단계 목록이 보인다.
    expect(find.text('셀 선택과 숫자 입력'), findsOneWidget);
    expect(find.text('메모(연필) 사용'), findsOneWidget);
    expect(find.text('기본 규칙'), findsOneWidget);
    expect(find.text('아이템 사용'), findsOneWidget);

    // 3번(메모) 단계를 골라 진입 → 해당 단계로 바로 시작된다.
    await tester.tap(find.text('메모(연필) 사용'));
    await tester.pumpAndSettle();

    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.textContaining('3/12'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('스테이지 3(메모)은 메모 모드가 강제되고 지우기가 잠겨, 정답을 바로 채울 수 없다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TutorialScreen(initialStep: 2)),
      ),
    );
    await tester.pump(); // postFrameCallback으로 보드/모드 주입

    expect(find.text('메모(연필) 사용'), findsOneWidget);
    expect(container.read(memoModeProvider), isTrue);

    // 지우기 버튼은 잠겨 있다.
    final eraseBtn = tester.widget<MaterialButton>(
      find.ancestor(
        of: find.byIcon(Icons.backspace_outlined),
        matching: find.byType(MaterialButton),
      ),
    );
    expect(eraseBtn.onPressed, isNull);

    // 숫자를 눌러도 정답이 칸을 채우지 않고 메모로만 들어간다.
    await tester.tap(find.widgetWithText(MaterialButton, '1'));
    await tester.pump();

    final game = container.read(gameProvider)!;
    expect(game.notes[7][7].contains(1), isTrue); // 메모로 기록됨
    expect(game.current[7][7], 0); // 칸은 여전히 비어 있음

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('스테이지 4(패널티)는 오답 숫자만 활성화되고, 누르면 패널티가 발생한다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TutorialScreen(initialStep: 3)),
      ),
    );
    await tester.pump();

    expect(find.text('오답 패널티'), findsOneWidget);

    // 튜토리얼과 동일 시드로 정답/유도 오답을 계산한다.
    final solution = PuzzleGenerator.generate(
      seed: 20260602,
      difficulty: Difficulty.normal,
    ).solution;
    final n4 = solution[0][8];
    final wrong4 = (n4 % 9) + 1;

    // 정답 숫자 버튼은 비활성(완성된 숫자라 누를 수 없다).
    final correctBtn = tester.widget<MaterialButton>(
      find.widgetWithText(MaterialButton, '$n4'),
    );
    expect(correctBtn.onPressed, isNull);

    // 오답 숫자 버튼만 누를 수 있고, 누르면 패널티가 걸린다.
    await tester.tap(find.widgetWithText(MaterialButton, '$wrong4'));
    await tester.pump();

    expect(container.read(gameProvider)!.isPenalized, isTrue);
    expect(find.text('오답!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
