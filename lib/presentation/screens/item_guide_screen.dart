import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../data/models/item_model.dart';

/// Phase 3 — 아이템 설명(도감) 화면.
///
/// 7종 아이템을 사용 대상(나에게 / 상대에게 / 즉시 발동)별로 묶어 보여준다.
/// 본문은 [ItemGuideList]로 분리해 튜토리얼·로비 등에서도 재사용할 수 있다.
class ItemGuideScreen extends StatelessWidget {
  const ItemGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('아이템 설명'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // 넓은 화면에서 과도하게 늘어나지 않도록 폭 제한 (홈과 동일 기준)
            constraints: const BoxConstraints(maxWidth: 480),
            child: const ItemGuideList(),
          ),
        ),
      ),
    );
  }
}

/// 아이템 설명 본문 — 인트로 + 그룹별 아이템 카드 목록.
class ItemGuideList extends StatelessWidget {
  const ItemGuideList({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _GuideIntro(),
        for (final target in ItemTarget.values) ...[
          const Gap(20),
          _ItemGroup(target: target),
        ],
      ],
    );
  }
}

/// 상단 안내 카드.
class _GuideIntro extends StatelessWidget {
  const _GuideIntro();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: colorScheme.onPrimaryContainer),
          const Gap(12),
          Expanded(
            child: Text(
              '정답 칸을 채우면 랜덤으로 아이템을 얻어요.\n'
              '아이템으로 내 풀이를 돕거나 상대를 방해할 수 있어요.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 대상별 아이템 그룹 (헤더 + 카드들).
class _ItemGroup extends StatelessWidget {
  final ItemTarget target;
  const _ItemGroup({required this.target});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final items =
        ItemType.values.where((t) => t.target == target).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                target.labelKo,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  target.descriptionKo,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Gap(10),
          _ItemCard(item: items[i]),
        ],
      ],
    );
  }
}

/// 개별 아이템 설명 카드.
class _ItemCard extends StatelessWidget {
  final ItemType item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이모지 아바타
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Gap(8),
                    _DurationBadge(label: item.durationLabel),
                  ],
                ),
                const Gap(4),
                Text(
                  item.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 지속 시간 뱃지.
class _DurationBadge extends StatelessWidget {
  final String label;
  const _DurationBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
