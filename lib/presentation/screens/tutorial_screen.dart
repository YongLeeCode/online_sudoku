import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/constants/difficulty.dart';
import '../../core/utils/puzzle_generator.dart';
import '../../data/models/item_model.dart';
import '../../domain/providers/game_provider.dart';
import '../../domain/providers/tutorial_provider.dart';
import '../widgets/hud/item_slot.dart';
import '../widgets/sudoku/number_pad.dart';
import '../widgets/sudoku/sudoku_grid.dart';

/// 튜토리얼 메뉴(스테이지 선택)에 표시할 각 단계의 아이콘/제목.
///
/// [TutorialScreen]의 단계 정의(`_buildSteps`)와 **순서가 일치**해야 한다.
/// 메뉴는 정답판/게임 상태 없이도 그려야 하므로 별도 메타데이터로 분리해 둔다.
const List<({IconData icon, String title})> tutorialStageMeta = [
  (icon: Icons.touch_app_outlined, title: '셀 선택과 숫자 입력'),
  (icon: Icons.grid_on_outlined, title: '행 · 열 · 박스 규칙'),
  (icon: Icons.edit_outlined, title: '메모(연필) 사용'),
  (icon: Icons.block, title: '오답 패널티'),
  (icon: Icons.star_outline, title: '아이템 칸과 획득'),
  (icon: Icons.bolt_outlined, title: '아이템 — 💡 힌트'),
  (icon: Icons.bolt_outlined, title: '아이템 — 🌫️ 블라인드'),
  (icon: Icons.bolt_outlined, title: '아이템 — ⏸️ 프리즈'),
  (icon: Icons.bolt_outlined, title: '아이템 — ✂️ 아이템 커터'),
  (icon: Icons.bolt_outlined, title: '아이템 — 🛡️ 방어막'),
  (icon: Icons.bolt_outlined, title: '아이템 — 💥 리버스'),
  (icon: Icons.bolt_outlined, title: '아이템 — ❓ 미스터리'),
];

/// 각 단계의 완료(=다음 버튼 활성화) 조건.
enum _Goal {
  next, // 설명/데모 — 항상 다음 가능
  fillBlank, // 빈 칸을 모두 정답으로 채우면 완료
  addNote, // 메모를 하나 이상 남기면 완료
  triggerPenalty, // 오답 패널티를 한 번 겪으면 완료
  getItem, // 아이템을 하나 이상 획득하면 완료
}

/// 단계별 튜토리얼 화면.
///
/// 실제 게임 엔진([gameProvider])과 위젯([SudokuGrid]/[NumberPad])을 그대로
/// 재사용하되, 각 단계마다 스크립트된 보드를 [GameNotifier.loadScriptedBoard]로
/// 주입한다. 채울 칸 외에는 모두 고정 칸이라 입력이 자연스럽게 제한된다.
///
/// [initialStep]으로 시작 단계를 지정할 수 있다([TutorialMenuScreen]에서 특정
/// 스테이지만 골라 들어올 때 사용). 이후 「다음」으로 다음 단계로 넘어갈 수 있고,
/// 뒤로가기를 누르면 다시 스테이지 목록으로 돌아간다.
class TutorialScreen extends ConsumerStatefulWidget {
  /// 시작 단계 인덱스(0-based). 기본값 0(첫 단계).
  final int initialStep;

  const TutorialScreen({super.key, this.initialStep = 0});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  // 모든 단계가 공유하는 완성 정답판 (고정 시드).
  late final List<List<int>> _solution;
  late final List<_Step> _steps;

  int _index = 0;
  bool _penaltyHappened = false; // 패널티 단계 완료 플래그
  (int, int)? _penaltyCell; // 패널티 단계에서 비워둔 칸

  Timer? _penaltyTimer;
  Timer? _blindTimer;
  Timer? _freezeTimer;

  String? _flashText;
  Timer? _flashTimer;

  // dispose 시점엔 `ref`가 이미 해제돼 사용할 수 없으므로, 정리에 필요한
  // notifier 참조를 initState에서 미리 잡아둔다.
  late final GameNotifier _gameNotifier;
  late final StateController<bool> _memoModeNotifier;
  late final StateController<(int, int)?> _selectedCellNotifier;

  @override
  void initState() {
    super.initState();
    _gameNotifier = ref.read(gameProvider.notifier);
    _memoModeNotifier = ref.read(memoModeProvider.notifier);
    _selectedCellNotifier = ref.read(selectedCellProvider.notifier);
    _solution = PuzzleGenerator.generate(
      seed: 20260602,
      difficulty: Difficulty.normal,
    ).solution;
    _steps = _buildSteps();
    _index = widget.initialStep.clamp(0, _steps.length - 1);
    // 첫 프레임 이후 보드 주입 (provider 수정은 build 밖에서)
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToStep(_index));
  }

  @override
  void dispose() {
    _penaltyTimer?.cancel();
    _blindTimer?.cancel();
    _freezeTimer?.cancel();
    _flashTimer?.cancel();
    // 튜토리얼 종료 시 게임/입력 상태 정리.
    //
    // gameProvider는 이 화면이 직접 watch하므로, dispose 도중 곧바로 상태를
    // 바꾸면 해제 중(defunct)인 자기 자신을 리빌드하려다 오류가 난다. 트리
    // 해제가 끝난 다음 마이크로태스크에서 정리한다(캡처해 둔 notifier 사용).
    final gameNotifier = _gameNotifier;
    final memoModeNotifier = _memoModeNotifier;
    final selectedCellNotifier = _selectedCellNotifier;
    Future.microtask(() {
      memoModeNotifier.state = false;
      selectedCellNotifier.state = null;
      gameNotifier.clear();
    });
    super.dispose();
  }

  int _answerAt((int, int) cell) => _solution[cell.$1][cell.$2];

  // ────────────────────────────────────────────────
  //  단계 정의
  // ────────────────────────────────────────────────

  List<_Step> _buildSteps() {
    const s1 = (4, 4);
    const s2 = (1, 1);
    const s3 = (7, 7);
    const s4 = (0, 8); // 패널티
    const s5 = (2, 2); // 아이템 칸
    final n1 = _answerAt(s1);
    final n2 = _answerAt(s2);
    final n4 = _answerAt(s4);
    final n5 = _answerAt(s5);
    final wrong4 = (n4 % 9) + 1; // 정답이 아닌 숫자

    return [
      // ① 셀 선택 · 숫자 입력
      _Step(
        icon: Icons.touch_app_outlined,
        title: '셀 선택과 숫자 입력',
        body:
            '스도쿠는 빈 칸에 숫자를 채우는 퍼즐이에요.\n'
            '파란색으로 선택된 칸에 들어갈 정답은 $n1이에요.\n'
            '아래 숫자판에서 $n1을(를) 눌러 입력해보세요!',
        goal: _Goal.fillBlank,
        showNumberPad: true,
        setup: () => ref
            .read(gameProvider.notifier)
            .loadScriptedBoard(solution: _solution, blanks: const {s1}),
        selectCell: s1,
      ),

      // ② 행 / 열 / 박스 규칙
      _Step(
        icon: Icons.grid_on_outlined,
        title: '행 · 열 · 박스 규칙',
        body:
            '가로 한 줄(행), 세로 한 줄(열), 굵은 선으로 나뉜 3×3 박스 안에는\n'
            '1~9가 한 번씩만 들어가야 해요.\n'
            '선택된 칸과 같은 행·열·박스가 함께 표시돼요. 빠진 숫자 $n2을(를) 넣어보세요.',
        goal: _Goal.fillBlank,
        showNumberPad: true,
        setup: () => ref
            .read(gameProvider.notifier)
            .loadScriptedBoard(solution: _solution, blanks: const {s2}),
        selectCell: s2,
      ),

      // ③ 메모(연필)
      // 메모 모드를 강제로 켜두고(잠금) 지우기를 막아, 정답을 곧바로 입력해
      // 칸이 채워져버리는(→ 메모를 더 못 남겨 진행 불가) 상황을 원천 차단한다.
      _Step(
        icon: Icons.edit_outlined,
        title: '메모(연필) 사용',
        body:
            '확신이 없을 땐 후보 숫자를 메모로 적어둬요.\n'
            '메모 모드가 켜져 있어요. 선택된 칸에 숫자 2~3개를 눌러 작게 적어보세요.',
        goal: _Goal.addNote,
        showNumberPad: true,
        memoMode: true,
        lockInputMode: true,
        setup: () => ref
            .read(gameProvider.notifier)
            .loadScriptedBoard(solution: _solution, blanks: const {s3}),
        selectCell: s3,
      ),

      // ④ 오답 패널티
      // 빈 칸이 하나뿐이라 정답 외의 숫자는 모두 "완성"되어 비활성된다. 그래서
      // 일부러 오답을 넣으려면 숫자판을 오답 하나로 제한해야 한다(allowedNumbers).
      _Step(
        icon: Icons.block,
        title: '오답 패널티',
        body:
            '틀린 숫자를 넣으면 잠시 입력이 잠겨요(패널티).\n'
            '이 칸의 정답은 $n4이에요. 일부러 정답이 아닌 $wrong4을(를) 눌러 패널티를 겪어보세요.',
        goal: _Goal.triggerPenalty,
        showNumberPad: true,
        lockInputMode: true,
        allowedNumbers: {wrong4},
        setup: () => ref
            .read(gameProvider.notifier)
            .loadScriptedBoard(
              solution: _solution,
              blanks: const {s4},
              penaltySeconds: 3,
            ),
        selectCell: s4,
      ),

      // ⑤ 아이템 칸 · 획득
      _Step(
        icon: Icons.star_outline,
        title: '아이템 칸과 획득',
        body:
            '별(★)이 표시된 칸을 정답으로 채우면 랜덤 아이템을 얻어요!\n'
            '선택된 ★ 칸의 정답 $n5을(를) 넣어 아이템을 획득해보세요.',
        goal: _Goal.getItem,
        showItems: true,
        showNumberPad: true,
        setup: () => ref
            .read(gameProvider.notifier)
            .loadScriptedBoard(
              solution: _solution,
              blanks: const {s5, (6, 3)},
              itemCells: const {s5},
              itemPool: const [ItemType.hint],
            ),
        selectCell: s5,
      ),

      // ⑥ 아이템 7종 — 각 아이템별 스테이지
      _itemDemoStep(
        item: ItemType.hint,
        body:
            '내 풀이를 돕는 아이템이에요. 선택한 빈 칸 하나를 정답으로 바로 채워줍니다.\n'
            '아래 「힌트 사용해보기」를 눌러 효과를 확인하세요.',
        demoLabel: '힌트 사용해보기',
        myItems: const [ItemType.hint, null, null, null],
        blanks: const {(4, 0), (4, 2), (4, 4)},
        demo: _demoHint,
      ),
      _itemDemoStep(
        item: ItemType.blind,
        body:
            '🌫️ 블라인드는 원래 상대에게 쓰는 방해 아이템이에요. 3×3 박스 하나를 잠시 가려요.\n'
            '효과가 어떤지 내 보드에서 직접 보여드릴게요.',
        demoLabel: '효과 보기',
        myItems: const [ItemType.blind, null, null, null],
        blanks: const {(4, 4)},
        demo: _demoBlind,
      ),
      _itemDemoStep(
        item: ItemType.freeze,
        body:
            '⏸️ 프리즈는 상대의 숫자 입력을 잠시 잠그는 아이템이에요.\n'
            '내 화면에서 잠금 효과를 직접 보여드릴게요.',
        demoLabel: '효과 보기',
        myItems: const [ItemType.freeze, null, null, null],
        blanks: const {(4, 4)},
        demo: _demoFreeze,
      ),
      _itemDemoStep(
        item: ItemType.itemCut,
        body:
            '✂️ 아이템 커터는 상대가 가진 아이템 1개를 없애요.\n'
            '지금 슬롯 맨 앞의 아이템(💡)이 사라지는 모습을 보여드릴게요.',
        demoLabel: '효과 보기',
        myItems: const [ItemType.hint, ItemType.itemCut, null, null],
        blanks: const {(4, 4)},
        demo: _demoItemCut,
      ),
      _itemDemoStep(
        item: ItemType.shield,
        body:
            '🛡️ 방어막은 다음에 날아오는 상대 아이템 1개를 막아줘요.\n'
            '「방어막 켜기」를 누르면 활성화되고, 아이템 줄 위에 🛡️ 표시가 떠요.',
        demoLabel: '방어막 켜기',
        myItems: const [ItemType.shield, null, null, null],
        blanks: const {(4, 4)},
        demo: _demoShield,
      ),
      _itemDemoStep(
        item: ItemType.reverse,
        body:
            '💥 리버스는 상대가 맞게 채운 칸 하나를 다시 비워버려요.\n'
            '내 보드에 채워둔 칸 하나가 지워지는 모습을 보여드릴게요.',
        demoLabel: '효과 보기',
        myItems: const [ItemType.reverse, null, null, null],
        blanks: const {(3, 3), (3, 4), (3, 5)},
        prefilled: {(3, 3): _answerAt((3, 3)), (3, 4): _answerAt((3, 4))},
        demo: _demoReverse,
      ),
      _itemDemoStep(
        item: ItemType.mystery,
        body:
            '❓ 미스터리는 쓰는 순간 랜덤 효과! 행운(내게 도움)일 수도, 불운(상대에게 이득)일 수도.\n'
            '여기선 운 좋게 힌트가 나온 셈 치고 빈 칸 하나를 채워볼게요.',
        demoLabel: '사용해보기',
        myItems: const [ItemType.mystery, null, null, null],
        blanks: const {(4, 0), (4, 1)},
        demo: _demoMystery,
      ),
    ];
  }

  _Step _itemDemoStep({
    required ItemType item,
    required String body,
    required String demoLabel,
    required List<ItemType?> myItems,
    required Set<(int, int)> blanks,
    Map<(int, int), int> prefilled = const {},
    required VoidCallback demo,
  }) {
    return _Step(
      icon: Icons.bolt_outlined,
      title: '아이템 사용 — ${item.emoji} ${item.name}',
      body: body,
      goal: _Goal.next,
      showItems: true,
      demoLabel: demoLabel,
      demoAction: demo,
      setup: () => ref
          .read(gameProvider.notifier)
          .loadScriptedBoard(
            solution: _solution,
            blanks: blanks,
            prefilled: prefilled,
            myItems: List<ItemType?>.from(myItems),
          ),
    );
  }

  // ────────────────────────────────────────────────
  //  단계 전환
  // ────────────────────────────────────────────────

  void _goToStep(int index) {
    if (index >= _steps.length) {
      _finish();
      return;
    }
    _penaltyTimer?.cancel();
    _blindTimer?.cancel();
    _freezeTimer?.cancel();
    _penaltyHappened = false;

    final step = _steps[index];
    ref.read(memoModeProvider.notifier).state = step.memoMode;
    step.setup();
    ref.read(selectedCellProvider.notifier).state = step.selectCell;
    _penaltyCell = step.goal == _Goal.triggerPenalty ? step.selectCell : null;

    setState(() {
      _index = index;
      _flashText = null;
    });
  }

  void _next() {
    if (!_canAdvance(ref.read(gameProvider))) return;
    _goToStep(_index + 1);
  }

  Future<void> _finish() async {
    await ref.read(tutorialCompletedProvider.notifier).markCompleted();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('튜토리얼 완료! 🎉'),
        content: const Text('이제 규칙과 아이템을 모두 익혔어요.\n싱글 모드나 멀티 모드에서 직접 플레이해보세요!'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  bool _canAdvance(GameState? game) {
    if (game == null) return false;
    switch (_steps[_index].goal) {
      case _Goal.next:
        return true;
      case _Goal.fillBlank:
        return game.totalBlanks > 0 && game.filledCount >= game.totalBlanks;
      case _Goal.addNote:
        return game.notes.any((row) => row.any((n) => n.isNotEmpty));
      case _Goal.triggerPenalty:
        return _penaltyHappened;
      case _Goal.getItem:
        return game.myItems.any((e) => e != null);
    }
  }

  // ────────────────────────────────────────────────
  //  아이템 데모 동작
  // ────────────────────────────────────────────────

  void _demoHint() {
    final s = ref.read(gameProvider);
    if (s == null) return;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (!s.isOriginalCell(r, c) && s.current[r][c] == 0) {
          ref.read(selectedCellProvider.notifier).state = (r, c);
          ref.read(gameProvider.notifier).useHintItem(0, r, c);
          _flash('💡 힌트로 빈 칸 하나가 채워졌어요!');
          return;
        }
      }
    }
    _flash('채울 빈 칸이 없어요');
  }

  void _demoBlind() {
    ref.read(gameProvider.notifier).applyBlind(5);
    _startBlindCountdown();
    _flash('🌫️ 박스 하나가 잠시 가려졌어요!');
  }

  void _demoFreeze() {
    ref.read(gameProvider.notifier).applyFreeze(3);
    _startFreezeCountdown();
    _flash('⏸️ 잠시 입력이 잠겼어요!');
  }

  void _demoItemCut() {
    final removed = ref.read(gameProvider.notifier).removeFirstItem();
    _flash(
      removed != null
          ? '✂️ ${removed.emoji} ${removed.name}이(가) 제거됐어요!'
          : '✂️ 제거할 아이템이 없어요',
    );
  }

  void _demoShield() {
    ref.read(gameProvider.notifier).applyShield();
    _flash('🛡️ 방어막이 활성화됐어요!');
  }

  void _demoReverse() {
    ref.read(gameProvider.notifier).applyReverse();
    _flash('💥 채워둔 칸 하나가 지워졌어요!');
  }

  void _demoMystery() {
    ref.read(gameProvider.notifier).applyRandomHint();
    _flash('❓ → 💡 행운! 빈 칸 하나가 채워졌어요!');
  }

  void _flash(String text) {
    _flashTimer?.cancel();
    setState(() => _flashText = text);
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _flashText = null);
    });
  }

  // ────────────────────────────────────────────────
  //  타이머
  // ────────────────────────────────────────────────

  void _startPenaltyCountdown() {
    _penaltyTimer?.cancel();
    _penaltyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game == null || !game.isPenalized) {
        _penaltyTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).penaltyTick();
    });
  }

  void _startBlindCountdown() {
    _blindTimer?.cancel();
    _blindTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game == null || !game.isBlinded) {
        _blindTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).blindTick();
    });
  }

  void _startFreezeCountdown() {
    _freezeTimer?.cancel();
    _freezeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = ref.read(gameProvider);
      if (game == null || !game.isFrozen) {
        _freezeTimer?.cancel();
        return;
      }
      ref.read(gameProvider.notifier).freezeTick();
    });
  }

  // ────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final step = _steps[_index];

    ref.listen(gameProvider, (prev, next) {
      if (next == null) return;
      // 패널티 발생 감지 → 카운트다운 시작 + 완료 처리
      if (next.isPenalized && (prev == null || !prev.isPenalized)) {
        _penaltyHappened = true;
        _startPenaltyCountdown();
      }
      // 패널티 단계에서 정답을 맞혀버린 경우 → 다시 비워 재시도 유도
      if (step.goal == _Goal.triggerPenalty &&
          !_penaltyHappened &&
          _penaltyCell != null &&
          next.current[_penaltyCell!.$1][_penaltyCell!.$2] != 0) {
        final cell = _penaltyCell!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(gameProvider.notifier).eraseCell(cell.$1, cell.$2);
            _flash('정답을 맞히셨네요! 이번엔 일부러 틀린 숫자를 넣어볼까요?');
          }
        });
      }
    });

    final canAdvance = _canAdvance(game);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text('튜토리얼 · ${_index + 1}/${_steps.length}'),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('목록'),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_index + 1) / _steps.length,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      if (step.showItems) ...[
                        const Gap(8),
                        _ItemRow(game: game),
                      ],
                      const Gap(8),

                      // 스도쿠 그리드 — 남은 공간에 맞춰 정사각형으로 축소
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: game == null
                                ? const SizedBox.shrink()
                                : const SudokuGrid(),
                          ),
                        ),
                      ),

                      // 안내 카드 (텍스트 + 데모/다음 버튼)
                      _InstructionCard(
                        step: step,
                        index: _index,
                        total: _steps.length,
                        canAdvance: canAdvance,
                        flashText: _flashText,
                        onDemo: step.demoAction,
                        onNext: canAdvance ? _next : null,
                        isLast: _index == _steps.length - 1,
                      ),

                      if (step.showNumberPad)
                        NumberPad(
                          allowedNumbers: step.allowedNumbers,
                          lockInputMode: step.lockInputMode,
                        ),
                      const Gap(12),
                    ],
                  ),
                ),
              ),

              // 패널티 오버레이
              if (game != null && game.isPenalized)
                _BlockOverlay(
                  icon: Icons.block,
                  iconColor: Colors.red.shade400,
                  title: '오답!',
                  titleColor: Colors.red.shade600,
                  seconds: game.penaltyRemaining,
                  message: '입력이 잠겼습니다',
                  bgColor: Colors.white.withValues(alpha: 0.92),
                ),

              // 프리즈 오버레이
              if (game != null && game.isFrozen)
                _BlockOverlay(
                  icon: Icons.ac_unit,
                  iconColor: Colors.blue.shade400,
                  title: '⏸️ 프리즈!',
                  titleColor: Colors.blue.shade700,
                  seconds: game.freezeRemaining,
                  message: '잠시 입력이 잠겼습니다',
                  bgColor: Colors.blue.shade50.withValues(alpha: 0.92),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아이템 슬롯 줄 (+ 방어막 표시).
class _ItemRow extends StatelessWidget {
  final GameState? game;
  const _ItemRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final myItems = game?.myItems ?? List<ItemType?>.filled(4, null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(4, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ItemSlot(item: myItems[i]),
            );
          }),
          if (game?.isShielded ?? false)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text('🛡️', style: TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 하단 안내 카드.
class _InstructionCard extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;
  final bool canAdvance;
  final String? flashText;
  final VoidCallback? onDemo;
  final VoidCallback? onNext;
  final bool isLast;

  const _InstructionCard({
    required this.step,
    required this.index,
    required this.total,
    required this.canAdvance,
    required this.flashText,
    required this.onDemo,
    required this.onNext,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(step.icon, size: 20, color: colorScheme.primary),
              const Gap(8),
              Expanded(
                child: Text(
                  step.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(step.body, style: textTheme.bodyMedium?.copyWith(height: 1.4)),
          if (flashText != null) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                flashText!,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          const Gap(12),
          Row(
            children: [
              if (onDemo != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDemo,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(step.demoLabel ?? '사용해보기'),
                  ),
                ),
              if (onDemo != null) const Gap(8),
              Expanded(
                child: FilledButton(
                  onPressed: onNext,
                  child: Text(isLast ? '완료' : '다음'),
                ),
              ),
            ],
          ),
          if (!canAdvance && step.goal != _Goal.next)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '👆 위 안내대로 해보면 「다음」이 활성화돼요',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 입력 잠금 오버레이 (패널티 / 프리즈).
class _BlockOverlay extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final int seconds;
  final String message;
  final Color bgColor;

  const _BlockOverlay({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.seconds,
    required this.message,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: iconColor),
            const Gap(20),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const Gap(12),
            Text(
              '$seconds초',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: iconColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Gap(8),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 단계 정의 모델.
class _Step {
  final IconData icon;
  final String title;
  final String body;
  final _Goal goal;
  final bool showItems;
  final bool showNumberPad;
  final void Function() setup;
  final (int, int)? selectCell;
  final String? demoLabel;
  final VoidCallback? demoAction;

  /// 이 단계 진입 시 메모 모드 초기값.
  final bool memoMode;

  /// true이면 메모 토글/지우기 버튼을 잠근다(메모 단계 보호용).
  final bool lockInputMode;

  /// 입력 가능한 숫자 제한(null = 제한 없음). 패널티 단계에서 오답 하나만
  /// 누를 수 있게 할 때 사용한다.
  final Set<int>? allowedNumbers;

  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    required this.goal,
    this.showItems = false,
    this.showNumberPad = false,
    required this.setup,
    this.selectCell,
    this.demoLabel,
    this.demoAction,
    this.memoMode = false,
    this.lockInputMode = false,
    this.allowedNumbers,
  });
}
