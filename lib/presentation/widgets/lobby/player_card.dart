import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../data/models/player_model.dart';

class PlayerCard extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: player.isHost
              ? Colors.amber.shade100
              : colorScheme.primaryContainer,
          child: Icon(
            player.isHost ? Icons.star : Icons.person,
            color: player.isHost
                ? Colors.amber.shade700
                : colorScheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Text(
              player.nickname,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (isMe) ...[
              const Gap(6),
              Text(
                '(나)',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        subtitle: player.isHost
            ? const Text('방장')
            : null,
        trailing: player.isHost
            ? null
            : Icon(
                player.isReady
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: player.isReady ? Colors.green : colorScheme.outline,
              ),
      ),
    );
  }
}
