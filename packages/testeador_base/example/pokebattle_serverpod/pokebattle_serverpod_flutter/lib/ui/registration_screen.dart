import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/data/pokemon_sprite_cache.dart';
import 'package:pokebattle_serverpod_flutter/ui/lobby_screen.dart';

/// Screen where the authenticated user picks their 6-Pokémon team.
class RegistrationScreen extends StatefulWidget {
  /// Creates the [RegistrationScreen].
  const RegistrationScreen({
    required this.client,
    required this.spriteCache,
    required this.authUser,
    super.key,
  });

  /// The Serverpod client.
  final Client client;

  /// Shared cache for Pokémon sprites.
  final PokemonSpriteCache spriteCache;

  /// The authenticated user.
  final AuthUser authUser;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  static const _availableNames = [
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

  /// When set via `--dart-define=AUTO_TEAM=name1,name2,...,name6`, the screen
  /// auto-selects the six listed Pokémon and submits, jumping directly to
  /// [LobbyScreen]. Used together with auto-login so the multi-device E2E
  /// run boots straight into the stream-driven lobby UI.
  static const _autoTeam = String.fromEnvironment('AUTO_TEAM');

  List<Pokemon> _available = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _registering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _maybeAutoRegister() async {
    if (_autoTeam.isEmpty) return;
    final wanted = _autoTeam.split(',').map((s) => s.trim()).toList();
    if (wanted.length != 6) return;
    _selected
      ..clear()
      ..addAll(wanted);
    await _register();
  }

  Future<void> _loadPokemon() async {
    try {
      final results = await Future.wait(
        _availableNames.map(widget.spriteCache.get),
      );
      setState(() {
        _available = results;
        _loading = false;
      });
      await _maybeAutoRegister();
    } catch (e) {
      setState(() {
        _error = 'Failed to load Pokémon: $e';
        _loading = false;
      });
    }
  }

  Future<void> _register() async {
    if (_selected.length != 6) return;
    setState(() => _registering = true);
    try {
      final player = await widget.client.players.registerPlayer(
        widget.authUser.name,
        _selected.toList(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbyScreen(
            client: widget.client,
            spriteCache: widget.spriteCache,
            currentPlayer: player,
            authUser: widget.authUser,
          ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick team — ${widget.authUser.name}'),
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
                      Text(
                        'Select your 6 Pokémon (${_selected.length}/6)',
                        key: const Key('TextSelectionCounter'),
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
                            final isSelected =
                                _selected.contains(pokemon.name);
                            return GestureDetector(
                              key: Key('PokemonCard:${pokemon.name}'),
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
                        key: const Key('ButtonEnterLobby'),
                        onPressed: _selected.length == 6 && !_registering
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
                            : const Text('Enter Lobby'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
