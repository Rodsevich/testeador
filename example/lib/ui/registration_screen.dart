import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';
import 'package:testeador_example/ui/lobby_screen.dart';

/// Screen where the user enters their name and picks 6 Pokémon.
class RegistrationScreen extends StatefulWidget {
  /// Creates the [RegistrationScreen].
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _dio = Dio();
  late final PokemonRepository _pokemonRepo;
  late final BattleRepository _battleRepo;

  final _availableNames = const [
    'charizard',
    'arcanine',
    'flareon',
    'rapidash',
    'magmar',
    'ninetales',
    'blastoise',
    'vaporeon',
    'gyarados',
    'starmie',
    'lapras',
    'cloyster',
    'pikachu',
    'mewtwo',
    'gengar',
    'alakazam',
    'machamp',
    'snorlax',
  ];

  List<Pokemon> _available = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _registering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pokemonRepo = PokemonRepository(_dio);
    _battleRepo = BattleRepository(_dio);
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    try {
      final results = await Future.wait(
        _availableNames.map(_pokemonRepo.getPokemon),
      );
      setState(() {
        _available = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load Pokémon: $e';
        _loading = false;
      });
    }
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.length != 6) return;
    setState(() => _registering = true);
    try {
      final player = await _battleRepo.registerPlayer(
        actorName: name,
        pokemonNames: _selected.toList(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbyScreen(currentPlayer: player),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Registration failed: $e';
        _registering = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PokéBattle — Register'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _available.isEmpty
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your trainer name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select your 6 Pokémon (${_selected.length}/6)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _available.length,
                          itemBuilder: (context, i) {
                            final pokemon = _available[i];
                            final isSelected = _selected.contains(pokemon.name);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selected.remove(pokemon.name);
                                  } else if (_selected.length < 6) {
                                    _selected.add(pokemon.name);
                                  }
                                });
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isSelected
                                      ? BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 3,
                                        )
                                      : BorderSide.none,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (pokemon.spriteUrl.isNotEmpty)
                                      Image.network(
                                        pokemon.spriteUrl,
                                        height: 72,
                                        width: 72,
                                        fit: BoxFit.contain,
                                      )
                                    else
                                      const Icon(
                                        Icons.catching_pokemon,
                                        size: 72,
                                      ),
                                    Text(
                                      pokemon.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      pokemon.types.join(' / '),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      FilledButton(
                        onPressed: _nameController.text.trim().isNotEmpty &&
                                _selected.length == 6 &&
                                !_registering
                            ? _register
                            : null,
                        child: _registering
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Register & Enter Lobby'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
