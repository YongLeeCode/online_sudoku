import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'tutorial_screen.dart';

/// 튜토리얼 스테이지 선택 화면.
///
/// 12개 단계를 처음부터 끝까지 순서대로만 진행하던 방식 대신, 원하는 단계를
/// 직접 골라 들어갈 수 있게 한다. 각 항목을 누르면 해당 단계부터 [TutorialScreen]이
/// 열리고, 거기서 「다음」으로 이어가거나 「목록」/뒤로가기로 다시 이 화면으로 돌아온다.
class TutorialMenuScreen extends ConsumerWidget {
  const TutorialMenuScreen({super.key});

  // 1~5: 기본 규칙 / 6~12: 아이템 사용. (tutorialStageMeta 순서와 일치)
  static const int _basicCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('튜토리얼'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  '배우고 싶은 단계를 골라보세요.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(16),

                _SectionLabel(label: '기본 규칙'),
                const Gap(8),
                for (int i = 0; i < _basicCount; i++)
                  _StageTile(index: i),

                const Gap(20),
                _SectionLabel(label: '아이템 사용'),
                const Gap(8),
                for (int i = _basicCount; i < tutorialStageMeta.length; i++)
                  _StageTile(index: i),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      label,
      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// 단계 한 줄. 누르면 해당 단계부터 튜토리얼을 시작한다.
class _StageTile extends StatelessWidget {
  final int index;
  const _StageTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final meta = tutorialStageMeta[index];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TutorialScreen(initialStep: index),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // 단계 번호 배지
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Gap(12),
                Icon(meta.icon, color: colorScheme.primary, size: 22),
                const Gap(12),
                Expanded(
                  child: Text(
                    meta.title,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
