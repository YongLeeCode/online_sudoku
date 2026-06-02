import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/constants/difficulty.dart';
import '../../domain/providers/game_provider.dart';
import '../../domain/providers/room_provider.dart';
import '../../domain/providers/tutorial_provider.dart';
import '../widgets/difficulty_selector.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'tutorial_menu_screen.dart';

/// 홈 화면 상단 모드 탭.
enum HomeMode {
  single(icon: Icons.person, labelKo: '싱글'),
  multi(icon: Icons.groups, labelKo: '멀티'),
  rank(icon: Icons.emoji_events, labelKo: '랭크');

  const HomeMode({required this.icon, required this.labelKo});

  final IconData icon;
  final String labelKo;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nicknameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  HomeMode _mode = HomeMode.single;

  @override
  void initState() {
    super.initState();
    // 저장된 닉네임 로드
    Future.microtask(() {
      final nickname = ref.read(nicknameProvider);
      if (nickname.isNotEmpty) {
        _nicknameController.text = nickname;
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateNickname() {
    final name = _nicknameController.text.trim();
    if (name.isEmpty) return '닉네임을 입력해주세요';
    if (name.length > 20) return '닉네임은 20자 이하로 입력해주세요';
    return null;
  }

  Future<void> _createRoom() async {
    final error = _validateNickname();
    if (error != null) {
      _showSnackBar(error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nickname = _nicknameController.text.trim();
      await ref.read(nicknameProvider.notifier).setNickname(nickname);

      final result = await ref.read(lobbyActionsProvider).createRoom(nickname);
      ref.read(currentRoomProvider.notifier).state = result.room;
      ref.read(currentPlayerProvider.notifier).state = result.player;

      // 방 설정 로드
      final settings = await ref.read(roomRepositoryProvider).getRoomSettings(result.room.id);
      ref.read(roomSettingsProvider.notifier).state = settings;

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    } catch (e) {
      _showSnackBar('방 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final error = _validateNickname();
    if (error != null) {
      _showSnackBar(error);
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnackBar('6자리 방 코드를 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nickname = _nicknameController.text.trim();
      await ref.read(nicknameProvider.notifier).setNickname(nickname);

      final result = await ref.read(lobbyActionsProvider).joinRoom(code, nickname);
      ref.read(currentRoomProvider.notifier).state = result.room;
      ref.read(currentPlayerProvider.notifier).state = result.player;

      final settings = await ref.read(roomRepositoryProvider).getRoomSettings(result.room.id);
      ref.read(roomSettingsProvider.notifier).state = settings;

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    } catch (e) {
      _showSnackBar('입장 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startSingleGame(Difficulty difficulty) {
    ref.read(gameProvider.notifier).startGame(difficulty);
    ref.read(selectedCellProvider.notifier).state = null;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _startTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TutorialMenuScreen()),
    );
  }

  void _showComingSoon(String feature) {
    _showSnackBar('$feature 기능은 준비 중이에요. 곧 만나요!');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 닉네임이 로드되면 컨트롤러에 반영
    ref.listen(nicknameProvider, (prev, next) {
      if (prev == '' && next.isNotEmpty && _nicknameController.text.isEmpty) {
        _nicknameController.text = next;
      }
    });

    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 360;
    final isShort = size.height < 640;
    final hPad = isNarrow ? 16.0 : 24.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // 태블릿/웹 등 넓은 화면에서 과도하게 늘어나지 않도록 폭 제한
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Gap(isShort ? 20 : 40),

                  // 타이틀 (좁은 화면에서도 잘리지 않도록 축소)
                  _Header(compact: isShort),
                  Gap(isShort ? 18 : 28),

                  // 상단 모드 선택
                  _ModeSelector(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  Gap(isShort ? 16 : 24),

                  // 모드별 본문 (탭 전환 시 페이드)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: _buildPane(),
                  ),

                  Gap(isShort ? 20 : 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  const Gap(16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPane() {
    switch (_mode) {
      case HomeMode.single:
        return _SinglePane(
          key: const ValueKey(HomeMode.single),
          onStart: _startSingleGame,
          onTutorial: _startTutorial,
          onComingSoon: _showComingSoon,
        );
      case HomeMode.multi:
        return _MultiPane(
          key: const ValueKey(HomeMode.multi),
          nicknameController: _nicknameController,
          codeController: _codeController,
          isLoading: _isLoading,
          onCreate: _createRoom,
          onJoin: _joinRoom,
        );
      case HomeMode.rank:
        return _RankPane(
          key: const ValueKey(HomeMode.rank),
          onComingSoon: () => _showComingSoon('랭크 매치'),
        );
    }
  }
}

/// 앱 타이틀 헤더.
class _Header extends StatelessWidget {
  final bool compact;
  const _Header({required this.compact});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        // FittedBox로 어떤 폭에서도 가로 잘림 방지
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Sudoku Clash',
            style: (compact ? textTheme.headlineMedium : textTheme.headlineLarge)
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
        const Gap(4),
        Text(
          'Multiplayer Sudoku Game',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 상단 모드 선택 세그먼트.
class _ModeSelector extends StatelessWidget {
  final HomeMode mode;
  final ValueChanged<HomeMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 매우 좁은 화면에서는 라벨을 숨겨 오버플로를 방지한다.
        final showLabel = constraints.maxWidth >= 300;
        return SegmentedButton<HomeMode>(
          showSelectedIcon: false,
          segments: HomeMode.values.map((m) {
            return ButtonSegment<HomeMode>(
              value: m,
              icon: Icon(m.icon, size: 18),
              label: showLabel ? Text(m.labelKo) : null,
            );
          }).toList(),
          selected: {mode},
          onSelectionChanged: (sel) => onChanged(sel.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: showLabel ? 12 : 6, vertical: 10),
            ),
          ),
        );
      },
    );
  }
}

/// 싱글 모드 패널.
class _SinglePane extends ConsumerWidget {
  final ValueChanged<Difficulty> onStart;
  final VoidCallback onTutorial;
  final ValueChanged<String> onComingSoon;

  const _SinglePane({
    super.key,
    required this.onStart,
    required this.onTutorial,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difficulty = ref.watch(difficultyProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 난이도 헤더
        Row(
          children: [
            Icon(Icons.trending_up, size: 20, color: difficulty.color),
            const Gap(8),
            Text(
              '난이도',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                difficulty.labelKo,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: difficulty.color,
                ),
              ),
            ),
          ],
        ),
        const Gap(10),
        DifficultySelector(
          value: difficulty,
          onChanged: (d) => ref.read(difficultyProvider.notifier).state = d,
        ),
        const Gap(20),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => onStart(difficulty),
            icon: const Icon(Icons.play_arrow),
            label: const Text('혼자 풀기', style: TextStyle(fontSize: 17)),
          ),
        ),
        const Gap(20),

        // 튜토리얼 (Phase 4) — 완료 여부 배지 표시
        _TutorialTile(onTap: onTutorial),
        const Gap(12),
        _ComingSoonTile(
          icon: Icons.workspace_premium_outlined,
          title: '주간 챌린지',
          subtitle: '매주 새로운 고난도 문제에 도전',
          onTap: () => onComingSoon('주간 챌린지'),
        ),
      ],
    );
  }
}

/// 멀티 모드 패널.
class _MultiPane extends StatelessWidget {
  final TextEditingController nicknameController;
  final TextEditingController codeController;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _MultiPane({
    super.key,
    required this.nicknameController,
    required this.codeController,
    required this.isLoading,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 닉네임 입력
        TextField(
          controller: nicknameController,
          maxLength: 20,
          decoration: InputDecoration(
            labelText: '닉네임',
            hintText: '닉네임을 입력하세요',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            counterText: '',
          ),
        ),
        const Gap(20),

        _SectionTitle(title: '방 만들기'),
        const Gap(10),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onCreate,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('새 방 만들기', style: TextStyle(fontSize: 17)),
          ),
        ),
        const Gap(24),

        _OrDivider(),
        const Gap(24),

        _SectionTitle(title: '코드로 입장'),
        const Gap(10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: codeController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: '방 코드',
                  hintText: '6자리 코드',
                  prefixIcon: const Icon(Icons.key),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
              ),
            ),
            const Gap(8),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: isLoading ? null : onJoin,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('입장', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 랭크 모드 패널 (Phase 6 연결 전 placeholder).
class _RankPane extends StatelessWidget {
  final VoidCallback onComingSoon;

  const _RankPane({super.key, required this.onComingSoon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events_outlined,
                  size: 48, color: colorScheme.primary),
              const Gap(12),
              Text(
                '랭크 모드 준비 중',
                textAlign: TextAlign.center,
                style:
                    textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Gap(6),
              Text(
                '비슷한 실력의 상대와 겨루고\n점수를 쌓는 랭크 매치가 곧 추가됩니다.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const Gap(20),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            // 준비 중: 시각적으로는 보이되 안내 스낵바 노출
            onPressed: onComingSoon,
            icon: const Icon(Icons.lock_outline),
            label: const Text('랭크 매치 시작', style: TextStyle(fontSize: 17)),
          ),
        ),
      ],
    );
  }
}

/// "준비 중" 진입 타일 (튜토리얼/챌린지 등).
class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ComingSoonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Gap(8),
                        _SoonBadge(),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Gap(4),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '준비 중',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 튜토리얼 진입 타일 (완료 여부 배지 포함).
class _TutorialTile extends ConsumerWidget {
  final VoidCallback onTap;
  const _TutorialTile({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(tutorialCompletedProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.school_outlined, color: colorScheme.primary),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '튜토리얼',
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Gap(8),
                        _TutorialBadge(done: done),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      '규칙과 아이템 사용법을 단계별로 배우기',
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Gap(4),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// 튜토리얼 완료/추천 배지.
class _TutorialBadge extends StatelessWidget {
  final bool done;
  const _TutorialBadge({required this.done});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = done
        ? Colors.green.withValues(alpha: 0.15)
        : colorScheme.primaryContainer;
    final fg = done ? Colors.green.shade700 : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(Icons.check, size: 12, color: fg),
            const SizedBox(width: 2),
          ],
          Text(
            done ? '완료' : '추천',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('또는', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
