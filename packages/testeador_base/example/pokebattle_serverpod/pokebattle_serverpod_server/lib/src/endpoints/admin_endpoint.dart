import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../store/in_memory_store.dart';
import 'battles_endpoint.dart';
import 'players_endpoint.dart';

/// Admin endpoint exposed to clients as `client.admin`.
///
/// Powers the "force data" controls of the web admin panel: it can wipe the
/// in-memory store and seed demo players/battles. Every seed broadcasts on the
/// same MessageCentral channels the player/battle streams listen on, so the
/// live monitor reflects seeded entities in real time — exactly like organic
/// traffic from the player app.
class AdminEndpoint extends Endpoint {
  /// Fixed pool of Pokémon used to build seeded teams (deterministic so e2e
  /// assertions stay stable).
  static const _pool = <String>[
    'pikachu',
    'charizard',
    'blastoise',
    'venusaur',
    'gengar',
    'snorlax',
    'gyarados',
    'lapras',
  ];

  /// Wipes players and battles. Returns the number of entities removed so the
  /// panel can show a confirmation.
  Future<int> reset(Session session) async {
    return InMemoryStore.instance.clear();
  }

  /// Registers [count] demo players and broadcasts a `playerAdded` event for
  /// each. Returns the created players.
  Future<List<Player>> seedPlayers(Session session, int count) async {
    final created = <Player>[];
    for (var i = 0; i < count; i++) {
      final team = [
        for (var j = 0; j < 3; j++) _pool[(i + j) % _pool.length],
      ];
      final player = Player(
        id: 'pl_seed_${DateTime.now().microsecondsSinceEpoch}_$i',
        name: 'Seed Trainer ${i + 1}',
        pokemonNames: team,
      );
      InMemoryStore.instance.putPlayer(player);
      unawaited(
        session.messages.postMessage(PlayersEndpoint.channel, player),
      );
      created.add(player);
    }
    return created;
  }

  /// Seeds a single demo battle between the two most recently seeded players
  /// (or placeholder names when the store is empty) and broadcasts it.
  Future<Battle> seedBattle(Session session) async {
    final players = InMemoryStore.instance.listPlayers();
    final challenger = players.isNotEmpty ? players.last.name : 'Seed Red';
    final opponent =
        players.length > 1 ? players[players.length - 2].name : 'Seed Blue';
    final battle = Battle(
      id: 'btl_seed_${DateTime.now().microsecondsSinceEpoch}',
      challengerName: challenger,
      opponentName: opponent,
      challengerTeam: _pool.take(3).toList(),
    );
    InMemoryStore.instance.putBattle(battle);
    unawaited(
      session.messages.postMessage(BattlesEndpoint.channelAll, battle),
    );
    unawaited(
      session.messages.postMessage(
        '${BattlesEndpoint.channelByIdPrefix}${battle.id}',
        battle,
      ),
    );
    return battle;
  }
}
