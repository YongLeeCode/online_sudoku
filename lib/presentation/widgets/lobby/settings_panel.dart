import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
                          onSettingsChanged?.call(RoomSettingsModel(
                            roomId: settings.roomId,
                            difficulty: d,
                            penaltySeconds: settings.penaltySeconds,
                            maxItemCount: settings.maxItemCount,
                            allowedItems: settings.allowedItems,
                            hintCounts: settings.hintCounts,
                          ));
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
                          onSettingsChanged?.call(RoomSettingsModel(
                            roomId: settings.roomId,
                            difficulty: settings.difficulty,
                            penaltySeconds: v.round(),
                            maxItemCount: settings.maxItemCount,
                            allowedItems: settings.allowedItems,
                            hintCounts: settings.hintCounts,
                          ));
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
                          onSettingsChanged?.call(RoomSettingsModel(
                            roomId: settings.roomId,
                            difficulty: settings.difficulty,
                            penaltySeconds: settings.penaltySeconds,
                            maxItemCount: v.round(),
                            allowedItems: settings.allowedItems,
                            hintCounts: settings.hintCounts,
                          ));
                        },
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
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
