import 'package:flutter/material.dart';
import 'package:testeador_example/domain/models.dart';

/// Screen showing the details of a battle.
class BattleScreen extends StatelessWidget {
  /// Creates the [BattleScreen].
  const BattleScreen({
    required this.battle,
    required this.currentPlayer,
    super.key,
  });

  /// The battle to display.
  final Battle battle;

  /// The currently logged-in player.
  final Player currentPlayer;

  @override
  Widget build(BuildContext context) {
    final isChallenger = battle.challengerName == currentPlayer.name;
    final isOpponent = battle.opponentName == currentPlayer.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${battle.challengerName} vs ${battle.opponentName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (isChallenger)
                      const Chip(label: Text('You are the challenger'))
                    else if (isOpponent)
                      const Chip(label: Text('You are the opponent')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "${battle.challengerName}'s battle team:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: battle.challengerTeam
                  .map(
                    (name) => Chip(
                      avatar: const Icon(Icons.catching_pokemon, size: 16),
                      label: Text(name),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            if (isOpponent) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'You have been challenged! '
                '${battle.challengerName} is coming with '
                '${battle.challengerTeam.join(', ')}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
