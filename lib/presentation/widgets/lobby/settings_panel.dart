import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../data/models/item_model.dart';
import '../../../data/models/room_settings_model.dart';
import '../difficulty_selector.dart';

class SettingsPanel extends StatelessWidget {
  final RoomSettingsModel settings;
  final bool isHost;
  final ValueChanged<RoomSettingsModel>? onSettingsChanged;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.isHost,
    this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 난이도
            _SettingRow(
              icon: Icons.trending_up,
              label: '난이도',
              value: settings.difficulty.labelKo,
              color: settings.difficulty.color,
              child: isHost
                  ? SizedBox(
                      width: double.infinity,
                      child: DifficultySelector(
                        value: settings.difficulty,
                        onChanged: (d) {
                          onSettingsChanged
                              ?.call(settings.copyWith(difficulty: d));
                        },
                      ),
                    )
                  : null,
            ),
            const Divider(height: 24),

            // 오답 패널티
            _SettingRow(
              icon: Icons.timer,
              label: '오답 패널티',
              value: '${settings.penaltySeconds}초',
              color: colorScheme.error,
              child: isHost
                  ? SizedBox(
                      width: 180,
                      child: Slider(
                        value: settings.penaltySeconds.toDouble(),
                        min: 1,
                        max: 15,
                        divisions: 14,
                        onChanged: (v) {
                          onSettingsChanged?.call(
                              settings.copyWith(penaltySeconds: v.round()));
                        },
                      ),
                    )
                  : null,
            ),
            const Divider(height: 24),

            // 아이템 개수
            _SettingRow(
              icon: Icons.card_giftcard,
              label: '아이템 개수',
              value: settings.maxItemCount == 0 ? '없음' : '${settings.maxItemCount}개',
              color: colorScheme.tertiary,
              child: isHost
                  ? SizedBox(
                      width: 180,
                      child: Slider(
                        value: settings.maxItemCount.toDouble(),
                        min: 0,
                        max: 15,
                        divisions: 15,
                        onChanged: (v) {
                          onSettingsChanged?.call(
                              settings.copyWith(maxItemCount: v.round()));
                        },
                      ),
                    )
                  : null,
            ),
            const Divider(height: 24),

            // 사용 아이템 (방장이 종류 선택)
            _ItemSelector(
              settings: settings,
              isHost: isHost,
              onSettingsChanged: onSettingsChanged,
            ),
          ],
        ),
      ),
    );
  }

}

/// 방장이 게임에 등장할 아이템 종류를 체크박스(FilterChip)로 고르는 섹션.
/// 참여자는 읽기 전용으로 허용 여부만 본다.
class _ItemSelector extends StatelessWidget {
  final RoomSettingsModel settings;
  final bool isHost;
  final ValueChanged<RoomSettingsModel>? onSettingsChanged;

  const _ItemSelector({
    required this.settings,
    required this.isHost,
    this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allowed = settings.allowedItems.toSet();

    void toggle(String dbKey, bool selected) {
      final next = settings.allowedItems.toList();
      if (selected) {
        if (!next.contains(dbKey)) next.add(dbKey);
      } else {
        next.remove(dbKey);
      }
      onSettingsChanged?.call(settings.copyWith(allowedItems: next));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.style, size: 20, color: colorScheme.primary),
            const Gap(8),
            const Text('사용 아이템', style: TextStyle(fontSize: 15)),
            const Spacer(),
            Text(
              '${allowed.length}/${ItemType.values.length}종',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const Gap(8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ItemType.values.map((item) {
            final isOn = allowed.contains(item.dbKey);
            return FilterChip(
              label: Text('${item.emoji} ${item.name}'),
              selected: isOn,
              onSelected:
                  isHost ? (sel) => toggle(item.dbKey, sel) : null,
              showCheckmark: true,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        if (allowed.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '아이템을 모두 끄면 아이템 없이 진행돼요.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Widget? child;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const Gap(8),
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        if (child != null) ...[
          const Gap(4),
          Align(alignment: Alignment.centerRight, child: child!),
        ],
      ],
    );
  }
}
