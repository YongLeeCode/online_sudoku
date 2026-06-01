import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../domain/providers/game_provider.dart';
import '../../domain/providers/room_provider.dart';
import '../widgets/difficulty_selector.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nicknameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final difficulty = ref.watch(difficultyProvider);

    // 닉네임이 로드되면 컨트롤러에 반영
    ref.listen(nicknameProvider, (prev, next) {
      if (prev == '' && next.isNotEmpty && _nicknameController.text.isEmpty) {
        _nicknameController.text = next;
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Gap(48),

              // 타이틀
              Text(
                'Sudoku Clash',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
              ),
              const Gap(4),
              Text(
                'Multiplayer Sudoku Game',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const Gap(36),

              // 닉네임 입력
              TextField(
                controller: _nicknameController,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: '닉네임',
                  hintText: '닉네임을 입력하세요',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
              const Gap(28),

              // 멀티플레이어 섹션
              _SectionTitle(title: '멀티플레이어'),
              const Gap(12),

              // 방 만들기
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _createRoom,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('방 만들기', style: TextStyle(fontSize: 17)),
                ),
              ),
              const Gap(12),

              // 코드 입장
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: '방 코드',
                        hintText: '6자리 코드',
                        prefixIcon: const Icon(Icons.key),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  const Gap(8),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _joinRoom,
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
              const Gap(28),

              // 구분선
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '또는',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const Gap(28),

              // 혼자 풀기 섹션
              _SectionTitle(title: '혼자 풀기'),
              const Gap(12),

              // 난이도 선택
              Row(
                children: [
                  Icon(Icons.trending_up, size: 20, color: difficulty.color),
                  const Gap(8),
                  Text(
                    '난이도',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    difficulty.labelKo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: difficulty.color,
                    ),
                  ),
                ],
              ),
              const Gap(10),
              DifficultySelector(
                value: difficulty,
                onChanged: (d) {
                  ref.read(difficultyProvider.notifier).state = d;
                },
              ),
              const Gap(16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(gameProvider.notifier).startGame(difficulty);
                    ref.read(selectedCellProvider.notifier).state = null;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('혼자 풀기', style: TextStyle(fontSize: 17)),
                ),
              ),
              const Gap(32),

              if (_isLoading) const CircularProgressIndicator(),
              const Gap(16),
            ],
          ),
        ),
      ),
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
