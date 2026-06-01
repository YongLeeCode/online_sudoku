import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// '나' 탭 — 설정 / 통계 / 어워드 진입점.
///
/// 통계·어워드·랭크 점수는 영구 사용자 식별(Phase 5)이 전제라서,
/// 지금은 진입 골격(메뉴 + "준비 중" 안내)만 만들어 둔다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature 기능은 준비 중이에요. 곧 만나요!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const _ProfileHeader(),
                const Gap(24),
                _MenuTile(
                  icon: Icons.bar_chart,
                  title: '통계',
                  subtitle: '전적 · 승률 · 평균 완료 시간',
                  comingSoon: true,
                  onTap: () => _showComingSoon(context, '통계'),
                ),
                const Gap(12),
                _MenuTile(
                  icon: Icons.emoji_events_outlined,
                  title: '어워드',
                  subtitle: '업적 · 챌린지 트로피',
                  comingSoon: true,
                  onTap: () => _showComingSoon(context, '어워드'),
                ),
                const Gap(12),
                _MenuTile(
                  icon: Icons.settings_outlined,
                  title: '설정',
                  subtitle: '알림 · 테마 · 게임 환경',
                  comingSoon: true,
                  onTap: () => _showComingSoon(context, '설정'),
                ),
                const Gap(12),
                _MenuTile(
                  icon: Icons.help_outline,
                  title: '도움말',
                  subtitle: '게임 규칙과 자주 묻는 질문',
                  comingSoon: true,
                  onTap: () => _showComingSoon(context, '도움말'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 프로필 헤더 (Phase 5 이후 닉네임/랭크 등 실제 데이터로 교체 예정).
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 34,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '게스트',
                  style:
                      textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Gap(4),
                Text(
                  '로그인과 전적 기록은 준비 중이에요.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 메뉴 진입 타일.
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool comingSoon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
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
                        if (comingSoon) ...[
                          const Gap(8),
                          _SoonBadge(),
                        ],
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
