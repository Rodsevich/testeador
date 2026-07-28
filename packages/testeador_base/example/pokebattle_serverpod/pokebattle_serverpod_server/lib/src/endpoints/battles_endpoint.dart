import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../store/in_memory_store.dart';

/// Battles endpoint exposed to clients as `client.battles`.
///
/// Two streams: [battleAdded] (every new challenge) and
/// [battleUpdates] (updates to a specific battle). Both are fed by
/// [createBattle] via MessageCentral.
class BattlesEndpoint extends Endpoint {
  /// Channel name for "any battle created" events.
  static const channelAll = 'battles';

  /// Prefix for per-battle channels: `battle:<id>`.
  static const channelByIdPrefix = 'battle:';

  /// Persists a battle challenge and broadcasts on both channels.
  Future<Battle> createBattle(
    Session session,
    String challengerName,
    String opponentName,
    List<String> challengerTeam,
  ) async {
    final battle = Battle(
      id: 'btl_${DateTime.now().microsecondsSinceEpoch}',
      challengerName: challengerName,
      opponentName: opponentName,
      challengerTeam: challengerTeam,
    );
    InMemoryStore.instance.putBattle(battle);
    unawaited(session.messages.postMessage(channelAll, battle));
    unawaited(
      session.messages.postMessage('$channelByIdPrefix${battle.id}', battle),
    );
    return battle;
  }

  /// Returns the battle with [id] or throws if unknown.
  Future<Battle> getBattle(Session session, String id) async {
    final battle = InMemoryStore.instance.battleById(id);
    if (battle == null) {
      throw Exception('Battle not found: $id');
    }
    return battle;
  }

  /// Snapshot of currently active battles.
  Future<List<Battle>> listBattles(Session session) async {
    return InMemoryStore.instance.listBattles();
  }

  /// Emits each new battle as it is created.
  Stream<Battle> battleAdded(Session session) async* {
    final updates = session.messages.createStream<Battle>(channelAll);
    await for (final b in updates) {
      yield b;
    }
  }

  /// Emits updates to a specific battle [id].
  Stream<Battle> battleUpdates(Session session, String id) async* {
    final updates = session.messages
        .createStream<Battle>('$channelByIdPrefix$id');
    await for (final b in updates) {
      yield b;
    }
  }
}
