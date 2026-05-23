import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/ui/battle_screen.dart';
import 'package:pokebattle_serverpod_flutter/ui/create_battle_screen.dart';

/// Lobby with live updates: subscribes to `playerAdded` and `battleAdded`
/// streams so new players and challenges appear with no manual refresh.
class LobbyScreen extends StatefulWidget {
  /// Creates the [LobbyScreen].
  const LobbyScreen({
    required this.client,
    required this.currentPlayer,
    required this.authUser,
    super.key,
  });

  /// The Serverpod client.
  final Client client;

  /// The player who just registered.
  final Player currentPlayer;

  /// The authenticated user.
  final AuthUser authUser;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final List<Player> _players = [];
  final List<Battle> _battles = [];
  StreamSubscription<Player>? _playerSub;
  StreamSubscription<Battle>? _battleSub;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLobby();
  }

  Future<void> _initLobby() async {
    try {
      final players = await widget.client.players.listPlayers();
      final battles = await widget.client.battles.listBattles();
      if (!mounted) return;
      setState(() {
        _players
          ..clear()
          ..addAll(players);
        _battles
          ..clear()
          ..addAll(battles);
        _loading = false;
      });

      _playerSub = widget.client.players.playerAdded().listen(
        (p) {
          if (!mounted) return;
          setState(() {
            if (_players.every((existing) => existing.id != p.id)) {
              _players.add(p);
            }
          });
        },
        onError: (Object e) => setState(() => _error = 'Stream error: $e'),
      );

      _battleSub = widget.client.battles.battleAdded().listen(
        (b) {
          if (!mounted) return;
          setState(() {
            if (_battles.every((existing) => existing.id != b.id)) {
              _battles.add(b);
            }
          });
        },
        onError: (Object e) => setState(() => _error = 'Stream error: $e'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load lobby: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createBattle(Player opponent) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateBattleScreen(
          client: widget.client,
          currentPlayer: widget.currentPlayer,
          opponent: opponent,
        ),
      ),
    );
  }

  Future<void> _viewBattle(Battle battle) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleScreen(
          client: widget.client,
          battle: battle,
          currentPlayer: widget.currentPlayer,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _battleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby — ${widget.currentPlayer.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              key: Key('ChipLive'),
              avatar: Icon(Icons.circle, size: 12, color: Colors.greenAccent),
              label: Text('Live'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _SectionHeader(
                      title: 'Your Team',
                      icon: Icons.catching_pokemon,
                    ),
                    Wrap(
                      spacing: 8,
                      children: widget.currentPlayer.pokemonNames
                          .map((name) => Chip(label: Text(name)))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Players (${_players.length})',
                      icon: Icons.people,
                    ),
                    ..._players.map(
                      (p) => ListTile(
                        key: Key('PlayerTile:${p.id}'),
                        leading: const Icon(Icons.person),
                        title: Text(p.name),
                        subtitle: Text(p.pokemonNames.join(', ')),
                        trailing: p.name != widget.currentPlayer.name
                            ? FilledButton.tonal(
                                key: Key('ButtonChallenge:${p.id}'),
                                onPressed: () => _createBattle(p),
                                child: const Text('Challenge'),
                              )
                            : const Chip(label: Text('You')),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Battles (${_battles.length})',
                      icon: Icons.sports_kabaddi,
                    ),
                    if (_battles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No battles yet. Challenge someone!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ..._battles.map(
                      (b) => Card(
                        key: Key('BattleCard:${b.id}'),
                        child: ListTile(
                          leading: const Icon(Icons.sports_kabaddi),
                          title: Text(
                            '${b.challengerName} vs ${b.opponentName}',
                          ),
                          subtitle: Text(
                            'Challenger team: ${b.challengerTeam.join(', ')}',
                          ),
                          trailing:
                              b.opponentName == widget.currentPlayer.name
                                  ? FilledButton(
                                      onPressed: () => _viewBattle(b),
                                      child: const Text('Join'),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                          onTap: () => _viewBattle(b),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
