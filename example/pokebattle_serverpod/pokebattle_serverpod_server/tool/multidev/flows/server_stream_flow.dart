import 'dart:async';

import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:testeador/expect.dart';
import 'package:testeador/testeador.dart';

/// Path to the Flutter app under test, relative to the server package root.
const _flutterApp = '../pokebattle_serverpod_flutter';

/// End-to-end flow that exercises the Serverpod stream contract from the
/// host while two Flutter apps (running in their respective devices in
/// auto-login mode) observe the UI react to server-pushed events.
///
/// Setup (run before `dart test`):
///   1. Boot the Serverpod server:
///      `cd ../pokebattle_serverpod_server && dart bin/main.dart &`
///   2. Boot device A (Android) and device B (iOS).
///   3. `flutter run -d ANDROID --dart-define=SEED_COLOR=red \
///        --dart-define=AUTO_LOGIN_EMAIL=firesh@auto.dev \
///        --dart-define=AUTO_LOGIN_PASSWORD=Auto_Pass1! \
///        --dart-define=AUTO_LOGIN_NAME=Firesh \
///        --dart-define=AUTO_TEAM=charizard,arcanine,flareon,rapidash,magmar,ninetales \
///        --dart-define=SERVER_URL=http://10.0.2.2:8080/`
///   4. Same with `-d <ios>`, `SEED_COLOR=cyan`, `Watersh`, water team,
///      `SERVER_URL=http://localhost:8080/`.
///
/// On launch each app auto-registers, auto-picks its team, and lands on the
/// Lobby (stream-subscribed). The flow then mutates server state from the
/// host and snapshots after each push to capture both lobbies reflecting
/// the same event.
TestFlowLasting buildServerStreamFlow({
  required List<TargetDevice> devices,
}) {
  final fleet = DeviceFleet(
    devices,
    evidenceDir: 'evidence',
    workingDirectory: _flutterApp,
  );

  const fireshName = 'Firesh';
  const watershName = 'Watersh';

  // The Dart client that drives mutations from the host. It only needs auth
  // to satisfy the API; the resulting events go to every subscribed lobby.
  final hostClient = Client('http://localhost:8080/');

  Player? firesh;
  Player? watersh;
  Battle? createdBattle;

  return TestFlowLasting(
    name: 'PokéBattle (Serverpod) — battle journey via streams',
    tags: {'streaming', 'e2e', 'server'},
    steps: [
      TestStep(
        name: 'Both apps auto-logged in and reached their lobbies',
        action: () async {
          // The apps auto-register and auto-team-pick on launch via
          // dart-defines. Wait until the server has heard from both.
          await hostClient.auth.register(
            'Host',
            'host_${DateTime.now().millisecondsSinceEpoch}@testeador.dev',
            'Host_Pass1!',
          );
          await _waitFor(
            () async {
              final players = await hostClient.players.listPlayers();
              firesh = players
                  .where((p) => p.name == fireshName)
                  .firstOrNull;
              watersh = players
                  .where((p) => p.name == watershName)
                  .firstOrNull;
              return firesh != null && watersh != null;
            },
            description: 'both Firesh and Watersh to appear via apps',
            timeout: const Duration(seconds: 20),
          );
          expect(firesh!.pokemonNames, hasLength(6));
          expect(watersh!.pokemonNames, hasLength(6));
          // Give the lobby UIs a beat to render the player list before we
          // capture the baseline.
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          await fleet.snapshotComposite('01-both-apps-in-lobby');
        },
      ),
      TestStep(
        name: 'Host creates a battle Firesh vs Watersh — both lobbies push',
        action: () async {
          createdBattle = await hostClient.battles.createBattle(
            fireshName,
            watershName,
            firesh!.pokemonNames.take(3).toList(),
          );
          expect(createdBattle!.id, isNotEmpty);
          // Wait for the stream to propagate to the apps' Lobby StreamSub.
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          await fleet.snapshotComposite('02-battle-pushed-to-both-lobbies');
        },
      ),
      TestStep(
        name: 'Host registers a third trainer — appears in both lobbies',
        action: () async {
          await hostClient.players.registerPlayer(
            'Sparky',
            ['pikachu', 'raichu', 'jolteon', 'electrode', 'magneton', 'voltorb'],
          );
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          await fleet.snapshotComposite('03-third-player-pushed-live');
        },
      ),
      TestStep(
        name: 'Host creates a Sparky vs Firesh battle — both lobbies push',
        action: () async {
          await hostClient.battles.createBattle(
            'Sparky',
            fireshName,
            ['pikachu', 'raichu', 'jolteon'],
          );
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          await fleet.snapshotComposite('04-second-battle-live');
        },
      ),
      TestStep(
        name: 'Cleanup — close client',
        action: () async {
          hostClient.close();
        },
      ),
    ],
  );
}

Future<void> _waitFor(
  FutureOr<bool> Function() predicate, {
  required String description,
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) return;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException(
    'Timed out after ${timeout.inMilliseconds}ms waiting for: $description',
  );
}
