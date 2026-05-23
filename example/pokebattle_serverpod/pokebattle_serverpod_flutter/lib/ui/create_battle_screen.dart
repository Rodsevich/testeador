import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';

/// Screen for creating a battle challenge against [opponent].
class CreateBattleScreen extends StatefulWidget {
  /// Creates the [CreateBattleScreen].
  const CreateBattleScreen({
    required this.client,
    required this.currentPlayer,
    required this.opponent,
    super.key,
  });

  /// The Serverpod client.
  final Client client;

  /// The player issuing the challenge.
  final Player currentPlayer;

  /// The player being challenged.
  final Player opponent;

  @override
  State<CreateBattleScreen> createState() => _CreateBattleScreenState();
}

class _CreateBattleScreenState extends State<CreateBattleScreen> {
  final Set<String> _selected = {};
  bool _creating = false;
  String? _error;

  Future<void> _create() async {
    if (_selected.length != 3) return;
    setState(() => _creating = true);
    try {
      await widget.client.battles.createBattle(
        widget.currentPlayer.name,
        widget.opponent.name,
        _selected.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to create battle: $e';
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Challenge ${widget.opponent.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select 3 Pokémon for battle (${_selected.length}/3)',
              key: const Key('TextBattleCounter'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: widget.currentPlayer.pokemonNames.map((name) {
                  final isSelected = _selected.contains(name);
                  return CheckboxListTile(
                    key: Key('CheckPokemon:$name'),
                    title: Text(name),
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if ((checked ?? false) && _selected.length < 3) {
                          _selected.add(name);
                        } else {
                          _selected.remove(name);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('ButtonSendChallenge'),
              onPressed: _selected.length == 3 && !_creating ? _create : null,
              child: _creating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Challenge'),
            ),
          ],
        ),
      ),
    );
  }
}
