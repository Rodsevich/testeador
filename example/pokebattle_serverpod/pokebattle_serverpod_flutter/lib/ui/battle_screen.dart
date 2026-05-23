import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';

/// Screen showing the details of a battle. Subscribes to `battleUpdates`
/// so any change broadcast from the server (acceptance, mutation) updates
/// the displayed state without manual refresh.
class BattleScreen extends StatefulWidget {
  /// Creates the [BattleScreen].
  const BattleScreen({
    required this.client,
    required this.battle,
    required this.currentPlayer,
    super.key,
  });

  /// The Serverpod client.
  final Client client;

  /// The battle to display.
  final Battle battle;

  /// The currently logged-in player.
  final Player currentPlayer;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late Battle _battle;
  StreamSubscription<Battle>? _sub;

  @override
  void initState() {
    super.initState();
    _battle = widget.battle;
    _sub = widget.client.battles.battleUpdates(_battle.id).listen((b) {
      if (!mounted) return;
      setState(() => _battle = b);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChallenger = _battle.challengerName == widget.currentPlayer.name;
    final isOpponent = _battle.opponentName == widget.currentPlayer.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle · Live'),
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
                      '${_battle.challengerName} vs ${_battle.opponentName}',
                      key: const Key('TextBattleTitle'),
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
              "${_battle.challengerName}'s battle team:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _battle.challengerTeam
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
                '${_battle.challengerName} is coming with '
                '${_battle.challengerTeam.join(', ')}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
