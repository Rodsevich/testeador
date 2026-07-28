import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';

/// The single-screen web admin panel.
///
/// Covers the four admin capabilities, each wired with stable `Key`s so a
/// Patrol-web e2e flow can drive and assert on it:
///
///  - **View players** — `listPlayers()` + live `playerAdded`.
///  - **View/manage battles** — `listBattles()` + tap a tile to `getBattle`.
///  - **Force data** — `admin.seedPlayers` / `admin.seedBattle` / `admin.reset`.
///  - **Live monitor** — a feed fed by the `playerAdded` / `battleAdded`
///    streams so seeded (or organic) entities appear in real time.
class AdminDashboardScreen extends StatefulWidget {
  /// Creates the [AdminDashboardScreen].
  const AdminDashboardScreen({required this.client, super.key});

  /// The Serverpod client.
  final Client client;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final List<Player> _players = [];
  final List<Battle> _battles = [];
  final List<_LiveEvent> _events = [];
  StreamSubscription<Player>? _playerSub;
  StreamSubscription<Battle>? _battleSub;
  bool _loading = true;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
      _subscribe();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load admin data: $e';
        _loading = false;
      });
    }
  }

  void _subscribe() {
    _playerSub = widget.client.players.playerAdded().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          if (_players.every((e) => e.id != p.id)) _players.add(p);
          _pushEvent(
            _LiveEvent(
              id: 'player:${p.id}',
              label: 'Player joined · ${p.name}',
              icon: Icons.person_add,
            ),
          );
        });
      },
      onError: (Object e) => _onStreamError(e),
    );

    _battleSub = widget.client.battles.battleAdded().listen(
      (b) {
        if (!mounted) return;
        setState(() {
          if (_battles.every((e) => e.id != b.id)) _battles.add(b);
          _pushEvent(
            _LiveEvent(
              id: 'battle:${b.id}',
              label: 'Battle created · ${b.challengerName} vs ${b.opponentName}',
              icon: Icons.sports_kabaddi,
            ),
          );
        });
      },
      onError: (Object e) => _onStreamError(e),
    );
  }

  void _onStreamError(Object e) {
    if (!mounted) return;
    setState(() => _error = 'Stream error: $e');
  }

  /// Newest-first, deduped by [_LiveEvent.id].
  void _pushEvent(_LiveEvent event) {
    _events
      ..removeWhere((e) => e.id == event.id)
      ..insert(0, event);
  }

  Future<void> _seedPlayers() async {
    await _guard(() async {
      final created = await widget.client.admin.seedPlayers(3);
      _snack('Seeded ${created.length} players');
    });
  }

  Future<void> _seedBattle() async {
    await _guard(() async {
      final b = await widget.client.admin.seedBattle();
      _snack('Seeded battle ${b.challengerName} vs ${b.opponentName}');
    });
  }

  Future<void> _reset() async {
    await _guard(() async {
      final removed = await widget.client.admin.reset();
      if (!mounted) return;
      setState(() {
        _players.clear();
        _battles.clear();
        _pushEvent(
          _LiveEvent(
            id: 'reset:${_seq++}',
            label: 'Store reset · $removed removed',
            icon: Icons.delete_sweep,
          ),
        );
      });
      _snack('Reset: $removed entities removed');
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _snack('Action failed: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _viewBattle(Battle battle) async {
    Battle detail;
    try {
      detail = await widget.client.battles.getBattle(battle.id);
    } catch (e) {
      _snack('getBattle failed: $e');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('AdminBattleDetail'),
        title: Text('Battle ${detail.id}'),
        content: Text(
          '${detail.challengerName} vs ${detail.opponentName}\n'
          'Team: ${detail.challengerTeam.join(', ')}',
        ),
        actions: [
          TextButton(
            key: const Key('AdminBattleDetailClose'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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
        title: const Text('PokéBattle Admin'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              key: Key('AdminChipLive'),
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
                    key: const Key('AdminError'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ForceDataBar(
          onSeedPlayers: _seedPlayers,
          onSeedBattle: _seedBattle,
          onReset: _reset,
        ),
        const SizedBox(height: 16),
        _LiveMonitor(events: _events),
        const SizedBox(height: 24),
        _SectionHeader(
          icon: Icons.people,
          title: 'Players',
          countKey: const Key('AdminPlayersCount'),
          count: _players.length,
        ),
        if (_players.isEmpty)
          const _EmptyHint(key: Key('AdminPlayersEmpty'), text: 'No players.'),
        ..._players.map(
          (p) => ListTile(
            key: Key('AdminPlayerTile:${p.id}'),
            leading: const Icon(Icons.person),
            title: Text(p.name),
            subtitle: Text(p.pokemonNames.join(', ')),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          icon: Icons.sports_kabaddi,
          title: 'Battles',
          countKey: const Key('AdminBattlesCount'),
          count: _battles.length,
        ),
        if (_battles.isEmpty)
          const _EmptyHint(key: Key('AdminBattlesEmpty'), text: 'No battles.'),
        ..._battles.map(
          (b) => Card(
            key: Key('AdminBattleTile:${b.id}'),
            child: ListTile(
              leading: const Icon(Icons.sports_kabaddi),
              title: Text('${b.challengerName} vs ${b.opponentName}'),
              subtitle: Text(b.challengerTeam.join(', ')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _viewBattle(b),
            ),
          ),
        ),
      ],
    );
  }
}

class _ForceDataBar extends StatelessWidget {
  const _ForceDataBar({
    required this.onSeedPlayers,
    required this.onSeedBattle,
    required this.onReset,
  });

  final VoidCallback onSeedPlayers;
  final VoidCallback onSeedBattle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.bolt, title: 'Force data'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('AdminButtonSeedPlayers'),
                  onPressed: onSeedPlayers,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Seed players'),
                ),
                FilledButton.icon(
                  key: const Key('AdminButtonSeedBattle'),
                  onPressed: onSeedBattle,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Seed battle'),
                ),
                OutlinedButton.icon(
                  key: const Key('AdminButtonReset'),
                  onPressed: onReset,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMonitor extends StatelessWidget {
  const _LiveMonitor({required this.events});

  final List<_LiveEvent> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('AdminLiveMonitor'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.podcasts,
              title: 'Live monitor',
              countKey: const Key('AdminLiveCount'),
              count: events.length,
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const _EmptyHint(
                key: Key('AdminLiveEmpty'),
                text: 'Waiting for stream events…',
              )
            else
              ...events.map(
                (e) => ListTile(
                  key: Key('AdminLiveEvent:${e.id}'),
                  dense: true,
                  leading: Icon(e.icon, size: 18),
                  title: Text(e.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.count,
    this.countKey,
  });

  final IconData icon;
  final String title;
  final int? count;
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '($count)',
            key: countKey,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _LiveEvent {
  const _LiveEvent({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}
