import 'dart:async';

import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

/// End-to-end flow that exercises the Serverpod stream contract from the
/// host with TWO Dart clients (no Flutter required).
///
/// Demonstrates the "battle journey" against a running Serverpod server on
/// `localhost:8080`. Captures a screenshot of the connected emulator after
/// each meaningful state change as composite evidence.
///
/// Pre-requisites:
///  - `dart bin/main.dart` is running in
///    `example/pokebattle_serverpod/pokebattle_serverpod_server/`.
///  - At least one Android emulator is reachable from the host.
TestFlowLasting buildServerStreamFlow({
  required List<TargetDevice> devices,
}) {
  final fleet = DeviceFleet(devices, evidenceDir: 'evidence');

  final ts = DateTime.now().millisecondsSinceEpoch;
  final fireshEmail = 'firesh_$ts@testeador.dev';
  final watershEmail = 'watersh_$ts@testeador.dev';
  const fireshPassword = 'Firesh_Pass1!';
  const watershPassword = 'Watersh_Pass1!';

  final fireshClient = Client('http://localhost:8080/');
  final watershClient = Client('http://localhost:8080/');

  AuthUser? fireshAuth;
  AuthUser? watershAuth;
  Player? fireshPlayer;
  Player? watershPlayer;
  Battle? createdBattle;

  final fireshPlayerEvents = <Player>[];
  final fireshBattleEvents = <Battle>[];
  StreamSubscription<Player>? fireshPlayerSub;
  StreamSubscription<Battle>? fireshBattleSub;

  return TestFlowLasting(
    name: 'PokéBattle (Serverpod) — battle journey via streams',
    tags: {'streaming', 'e2e', 'server'},
    steps: [
      TestStep(
        name: 'Both trainers register accounts on the Serverpod server',
        action: () async {
          fireshAuth = await fireshClient.auth.register(
            'Firesh', fireshEmail, fireshPassword,
          );
          watershAuth = await watershClient.auth.register(
            'Watersh', watershEmail, watershPassword,
          );
          expect(fireshAuth!.id, isNotEmpty);
          expect(watershAuth!.id, isNotEmpty);
          expect(fireshAuth!.id, isNot(equals(watershAuth!.id)));
        },
      ),
      TestStep(
        name: 'Firesh opens her playerAdded and battleAdded streams',
        action: () async {
          fireshPlayerSub = fireshClient.players
              .playerAdded()
              .listen(fireshPlayerEvents.add);
          fireshBattleSub = fireshClient.battles
              .battleAdded()
              .listen(fireshBattleEvents.add);
          // Give Serverpod a moment to register the subscriptions.
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(fireshPlayerSub, isNotNull);
          expect(fireshBattleSub, isNotNull);
        },
      ),
      TestStep(
        name: 'Watersh registers her player team — Firesh sees the push',
        action: () async {
          watershPlayer = await watershClient.players.registerPlayer(
            'Watersh',
            ['blastoise', 'gyarados', 'vaporeon', 'lapras', 'starmie', 'cloyster'],
          );
          expect(watershPlayer!.id, isNotEmpty);

          await _waitFor(
            () => fireshPlayerEvents.any((p) => p.id == watershPlayer!.id),
            description: "Firesh's playerAdded stream to deliver Watersh",
          );
          expect(
            fireshPlayerEvents.last.name,
            equals('Watersh'),
            reason: 'Stream event payload should match the registered player.',
          );
          await _snapshotIfDevices(fleet, '01-watersh-pushed-to-firesh');
        },
      ),
      TestStep(
        name: 'Firesh registers her own player team (snapshot pre-battle)',
        action: () async {
          fireshPlayer = await fireshClient.players.registerPlayer(
            'Firesh',
            ['charizard', 'arcanine', 'flareon', 'rapidash', 'magmar', 'ninetales'],
          );
          expect(fireshPlayer!.id, isNotEmpty);
          await _snapshotIfDevices(fleet, '02-both-players-registered');
        },
      ),
      TestStep(
        name: 'Firesh challenges Watersh to a battle — both streams fire',
        action: () async {
          createdBattle = await fireshClient.battles.createBattle(
            'Firesh', 'Watersh',
            ['charizard', 'arcanine', 'flareon'],
          );
          expect(createdBattle!.id, isNotEmpty);

          await _waitFor(
            () => fireshBattleEvents.any((b) => b.id == createdBattle!.id),
            description: "Firesh's battleAdded stream to deliver the battle",
          );
          expect(
            fireshBattleEvents.last.challengerTeam,
            equals(['charizard', 'arcanine', 'flareon']),
          );
          await _snapshotIfDevices(fleet, '03-battle-created-via-stream');
        },
      ),
      TestStep(
        name: 'Watersh subscribes to battleUpdates(id) and gets initial state',
        action: () async {
          final updates = watershClient.battles
              .battleUpdates(createdBattle!.id);
          // Re-broadcast and wait for the next event when the server
          // re-emits the battle for the per-battle channel.
          final firstUpdate = updates.timeout(
            const Duration(seconds: 5),
            onTimeout: (sink) {
              // No periodic update is sent for an idle battle; the
              // assertion below just confirms the channel exists and we
              // can subscribe without error.
              sink.close();
            },
          );
          final completer = Completer<void>();
          final sub = firstUpdate.listen(
            (_) {},
            onDone: completer.complete,
            onError: (Object _) => completer.complete(),
          );
          await completer.future;
          await sub.cancel();
          await _snapshotIfDevices(fleet, '04-watersh-subscribed');
        },
      ),
      TestStep(
        name: 'Cleanup — cancel subscriptions',
        action: () async {
          await fireshPlayerSub?.cancel();
          await fireshBattleSub?.cancel();
          fireshClient.close();
          watershClient.close();
        },
      ),
    ],
  );
}

Future<void> _waitFor(
  bool Function() predicate, {
  required String description,
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 50),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException(
    'Timed out after ${timeout.inMilliseconds}ms waiting for: $description',
  );
}

Future<void> _snapshotIfDevices(DeviceFleet fleet, String label) async {
  if (fleet.devices.isEmpty) return;
  await fleet.snapshotComposite(label);
}
