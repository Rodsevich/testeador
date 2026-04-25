import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';
import 'package:testeador_example/ui/battle_screen.dart';
import 'package:testeador_example/ui/create_battle_screen.dart';

/// Lobby showing all players and available battles.
class LobbyScreen extends StatefulWidget {
  /// Creates the [LobbyScreen] for [currentPlayer].
  const LobbyScreen({required this.currentPlayer, super.key});

  /// The player who just registered.
  final Player currentPlayer;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _dio = Dio();
  late final BattleRepository _battleRepo;

  List<Player> _players = [];
  List<Battle> _battles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _battleRepo = BattleRepository(_dio);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final players = await _battleRepo.listPlayers();
      final battles = await _battleRepo.listBattles();
      setState(() {
        _players = players;
        _battles = battles;
        _loading = false;
      });
    } catch (e) {
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
          currentPlayer: widget.currentPlayer,
          opponent: opponent,
          battleRepo: _battleRepo,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _viewBattle(Battle battle) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleScreen(
          battle: battle,
          currentPlayer: widget.currentPlayer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby — ${widget.currentPlayer.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
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
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
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
                          leading: const Icon(Icons.person),
                          title: Text(p.name),
                          subtitle: Text(p.pokemonNames.join(', ')),
                          trailing: p.name != widget.currentPlayer.name
                              ? FilledButton.tonal(
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
