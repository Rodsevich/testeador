import 'package:flutter/material.dart';
import 'package:testeador_example/pokemon.dart';

/// Root of the team builder. Owns the team; both screens read it from here.
class TeamApp extends StatefulWidget {
  const TeamApp({
    required this.api,
    this.themeMode = ThemeMode.light,
    super.key,
  });

  final PokeApi api;
  final ThemeMode themeMode;

  @override
  State<TeamApp> createState() => _TeamAppState();
}

class _TeamAppState extends State<TeamApp> {
  final _team = <Pokemon>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: widget.themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.red),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('My team')),
          body: _team.isEmpty
              ? const Center(child: Text('No Pokémon yet. Add your first one!'))
              : ListView(
                  children: [
                    for (final p in _team)
                      ListTile(
                        title: Text('${p.name} #${p.id}'),
                        subtitle: Text(p.types.join(' / ')),
                      ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final added = await Navigator.of(context).push(
                MaterialPageRoute<Pokemon>(
                  builder: (_) => AddPokemonScreen(api: widget.api),
                ),
              );
              if (added != null) setState(() => _team.add(added));
            },
            label: const Text('Add Pokémon'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

/// Searches PokéAPI by name and lets the trainer add the result to the team.
class AddPokemonScreen extends StatefulWidget {
  const AddPokemonScreen({required this.api, super.key});

  final PokeApi api;

  @override
  State<AddPokemonScreen> createState() => _AddPokemonScreenState();
}

class _AddPokemonScreenState extends State<AddPokemonScreen> {
  final _query = TextEditingController();
  Pokemon? _found;
  String? _error;

  Future<void> _search() async {
    final name = _query.text.trim();
    final found = await widget.api.find(name);
    setState(() {
      _found = found;
      _error = found == null ? 'No Pokémon called $name' : null;
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Pokémon')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('nameField'),
              controller: _query,
              decoration: const InputDecoration(labelText: 'Pokémon name'),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _search, child: const Text('Search')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (found != null) _ResultCard(pokemon: found),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.pokemon});

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${pokemon.name} #${pokemon.id}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(pokemon.types.join(' / ')),
            const SizedBox(height: 8),
            // Known defect: this row never wraps, so long ability names
            // overflow it on a phone-width screen.
            Row(
              children: [
                Text('Height ${pokemon.heightDm} dm'),
                const SizedBox(width: 16),
                Text('Weight ${pokemon.weightHg} hg'),
                const SizedBox(width: 16),
                Text('Abilities: ${pokemon.abilities.join(', ')}'),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(pokemon),
              child: const Text('Add to team'),
            ),
          ],
        ),
      ),
    );
  }
}
