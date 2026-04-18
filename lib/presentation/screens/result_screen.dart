import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../domain/providers/multiplayer_provider.dart';

class ResultScreen extends ConsumerWidget {
  final List<OpponentState> results;

  const ResultScreen({super.key, required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // 등수 순 정렬 (rank 있는 사람 우선, 없으면 progress 높은 순)
    final sorted = List<OpponentState>.from(results)
      ..sort((a, b) {
        if (a.rank != null && b.rank != null) return a.rank!.compareTo(b.rank!);
        if (a.rank != null) return -1;
        if (b.rank != null) return 1;
        return b.progress.compareTo(a.progress);
      });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('게임 결과'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Gap(16),

              // 1등 표시
              if (sorted.isNotEmpty) ...[
                _WinnerCard(player: sorted.first),
                const Gap(24),
              ],

              // 전체 순위
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final player = sorted[index];
                    final rank = player.rank ?? (index + 1);
                    return _RankCard(
                      rank: rank,
                      player: player,
                      colorScheme: colorScheme,
                    );
                  },
                ),
              ),

              // 홈으로 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('홈으로', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final OpponentState player;

  const _WinnerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
        const Gap(8),
        Text(
          player.nickname,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Gap(4),
        Text(
          '1등!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.amber.shade700,
          ),
        ),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final OpponentState player;
  final ColorScheme colorScheme;

  const _RankCard({
    required this.rank,
    required this.player,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = (player.progressPercent * 100).toInt();
    final isCleared = player.rank != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: player.isMe ? colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _rankColor(rank),
          child: Text(
            '$rank',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              player.nickname,
              style: TextStyle(
                fontWeight: player.isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (player.isMe) ...[
              const Gap(6),
              Text(
                '(나)',
                style: TextStyle(fontSize: 12, color: colorScheme.primary),
              ),
            ],
          ],
        ),
        trailing: Text(
          isCleared ? '완료!' : '$progressPercent%',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isCleared ? Colors.green : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600;
      case 2:
        return Colors.grey.shade500;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.blueGrey;
    }
  }
}
