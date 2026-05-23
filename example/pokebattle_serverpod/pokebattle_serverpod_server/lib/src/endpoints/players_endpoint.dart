import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../store/in_memory_store.dart';

/// Players endpoint exposed to clients as `client.players`.
///
/// The streaming method [playerAdded] is the centerpiece: any client
/// subscribed to it receives every new player as soon as another client
/// calls [registerPlayer]. Fan-out is in-memory via MessageCentral
/// (`session.messages.postMessage` + `createStream`), no DB triggers needed.
class PlayersEndpoint extends Endpoint {
  /// Channel name fanned-out by [registerPlayer] and consumed by
  /// [playerAdded].
  static const channel = 'players';

  /// Persists a player and broadcasts a `playerAdded` event.
  Future<Player> registerPlayer(
    Session session,
    String name,
    List<String> pokemonNames,
  ) async {
    final player = Player(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      pokemonNames: pokemonNames,
    );
    InMemoryStore.instance.putPlayer(player);
    unawaited(session.messages.postMessage(channel, player));
    return player;
  }

  /// Snapshot of currently registered players. Pair with [playerAdded] to
  /// initialise the lobby on subscribe.
  Future<List<Player>> listPlayers(Session session) async {
    return InMemoryStore.instance.listPlayers();
  }

  /// Emits each new player as it is registered, until the client disconnects.
  Stream<Player> playerAdded(Session session) async* {
    final updates = session.messages.createStream<Player>(channel);
    await for (final p in updates) {
      yield p;
    }
  }
}
