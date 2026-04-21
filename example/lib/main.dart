import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/api_client.dart';
import 'domain/models.dart';
import 'domain/repositories.dart';

void main() {
  runApp(const PokemonApp());
}

class PokemonApp extends StatelessWidget {
  const PokemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokemon App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const PokemonHomePage(),
    );
  }
}

class PokemonHomePage extends StatefulWidget {
  const PokemonHomePage({super.key});

  @override
  State<PokemonHomePage> createState() => _PokemonHomePageState();
}

class _PokemonHomePageState extends State<PokemonHomePage> {
  final PokemonClient _client = PokemonClient();
  final TeamClient _teamClient = TeamClient();
  late final PokemonRepository _pokemonRepo;
  late final AbilityRepository _abilityRepo;
  late final TeamRepository _teamRepo;
  final TextEditingController _searchController = TextEditingController(
    text: 'pikachu',
  );

  Pokemon? _pokemon;
  Ability? _ability;
  bool _loading = false;
  String _error = '';

  List<Pokemon> _team = [];
  String? _teamId;
  bool _syncingTeam = false;

  @override
  void initState() {
    super.initState();
    _pokemonRepo = PokemonRepository(_client);
    _abilityRepo = AbilityRepository(_client);
    _teamRepo = TeamRepository(_teamClient);
    _initTeam();
    _loadPokemon('pikachu');
  }

  Future<void> _initTeam() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTeamId = prefs.getString('team_id');
    if (savedTeamId != null) {
      setState(() => _syncingTeam = true);
      try {
        final loadedTeam = await _teamRepo.getTeam(savedTeamId);
        setState(() {
          _teamId = savedTeamId;
          _team = loadedTeam;
        });
      } catch (e) {
        // If the ID expired or is invalid
        await prefs.remove('team_id');
      } finally {
        setState(() => _syncingTeam = false);
      }
    }
  }

  Future<void> _addToTeam() async {
    if (_pokemon == null) return;
    if (_team.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team is full! Max 6 Pokemons.')),
      );
      return;
    }
    if (_team.any((p) => p.id == _pokemon!.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pokemon already in team.')));
      return;
    }

    setState(() => _syncingTeam = true);
    try {
      final newTeam = List<Pokemon>.from(_team)..add(_pokemon!);
      if (_teamId == null) {
        _teamId = await _teamRepo.createTeam(newTeam);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('team_id', _teamId!);
      } else {
        await _teamRepo.updateTeam(_teamId!, newTeam);
      }
      setState(() {
        _team = newTeam;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving team: $e')));
    } finally {
      setState(() => _syncingTeam = false);
    }
  }

  Future<void> _removeFromTeam(Pokemon p) async {
    setState(() => _syncingTeam = true);
    try {
      final newTeam = _team.where((member) => member.id != p.id).toList();
      if (_teamId != null) {
        await _teamRepo.updateTeam(_teamId!, newTeam);
      }
      setState(() {
        _team = newTeam;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving team: $e')));
    } finally {
      setState(() => _syncingTeam = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPokemon(String name) async {
    if (name.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = '';
      _pokemon = null;
      _ability = null;
    });

    try {
      final pika = await _pokemonRepo.getPokemon(name.trim().toLowerCase());
      Ability? ability;
      if (pika.firstAbilityName.isNotEmpty) {
        ability = await _abilityRepo.getAbility(pika.firstAbilityName);
      }
      setState(() {
        _pokemon = pika;
        _ability = ability;
      });
    } catch (e) {
      setState(() {
        _error = 'Pokemon not found or error occurred.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokemon Explorer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Pokemon Name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. charizard',
                    ),
                    onSubmitted: _loadPokemon,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _loadPokemon(_searchController.text),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Search Result
                Expanded(
                  flex: 2,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : _error.isNotEmpty
                        ? Text(
                            _error,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          )
                        : _pokemon == null
                        ? const Text('Search for a pokemon!')
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_pokemon!.imageUrl.isNotEmpty)
                                  Image.network(_pokemon!.imageUrl, scale: 0.5),
                                Text(
                                  '#${_pokemon!.id} ${_pokemon!.name.toUpperCase()}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 20),
                                if (_ability != null) ...[
                                  Text(
                                    'Ability: ${_ability!.name}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      _ability!.effect,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _syncingTeam ? null : _addToTeam,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add to Team'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right Panel: Team list
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey.shade100,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            'My Team (${_team.length}/6)',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_syncingTeam) const LinearProgressIndicator(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _team.length,
                            itemBuilder: (context, index) {
                              final p = _team[index];
                              return ListTile(
                                leading: Image.network(
                                  p.imageUrl,
                                  width: 40,
                                  height: 40,
                                ),
                                title: Text(p.name.toUpperCase()),
                                subtitle: Text(
                                  'Ability: ${p.firstAbilityName}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: _syncingTeam
                                      ? null
                                      : () => _removeFromTeam(p),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
