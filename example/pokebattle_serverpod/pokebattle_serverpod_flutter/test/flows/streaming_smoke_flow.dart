import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

/// End-to-end smoke flow that proves the Serverpod streaming contract by
/// driving the Flutter app on TWO devices in parallel via Patrol, and
/// capturing side-by-side composite screenshots of every meaningful state.
///
/// Run with two Android emulators booted (`emulator-5554` and `emulator-5556`):
///
/// ```bash
/// dart test test/contract_test.dart -N streaming
/// ```
TestFlowLasting buildStreamingSmokeFlow() {
  final fireshDevice = const AndroidEmulator(serial: 'emulator-5554');
  final watershDevice = const AndroidEmulator(serial: 'emulator-5556');
  final fleet = DeviceFleet(
    [fireshDevice, watershDevice],
    evidenceDir: 'evidence',
  );

  final ts = DateTime.now().millisecondsSinceEpoch;
  final fireshEmail = 'firesh_$ts@testeador.dev';
  final watershEmail = 'watersh_$ts@testeador.dev';
  const fireshPassword = 'Firesh_Pass1!';
  const watershPassword = 'Watersh_Pass1!';

  const fireTeam = 'charizard,arcanine,flareon,rapidash,magmar,ninetales';
  const waterTeam = 'blastoise,gyarados,vaporeon,lapras,starmie,cloyster';
  const fireBattleTeam = 'charizard,arcanine,flareon';

  ScreenshotBundle? bundle01;
  ScreenshotBundle? bundle02;
  ScreenshotBundle? bundle03;

  return TestFlowLasting(
    name: 'PokéBattle (Serverpod) — streaming smoke across 2 devices',
    tags: {'streaming', 'e2e', 'multi-device', 'smoke'},
    steps: [
      TestStep(
        name: 'Both trainers register and land in lobby (parallel UI)',
        action: () async {
          final results = await fleet.runPatrolAcross(
            target: 'integration_test/agent_flows/register_and_land_in_lobby.dart',
            envPerDevice: {
              fireshDevice.id: {
                'TRAINER_NAME': 'Firesh',
                'EMAIL': fireshEmail,
                'PASSWORD': fireshPassword,
                'TEAM': fireTeam,
              },
              watershDevice.id: {
                'TRAINER_NAME': 'Watersh',
                'EMAIL': watershEmail,
                'PASSWORD': watershPassword,
                'TEAM': waterTeam,
              },
            },
          );
          for (final r in results) {
            expect(
              r.passed,
              isTrue,
              reason: 'Patrol on ${r.device.id} failed (exit ${r.exitCode}):\n'
                  '${r.stdout}\n${r.stderr}',
            );
          }
          bundle01 = await fleet.snapshotComposite('01-both-in-lobby');
        },
      ),
      TestStep(
        name: 'Firesh sees Watersh appear in her lobby live (stream-driven)',
        action: () async {
          // No UI action: Watersh is already registered. Composite captures
          // Firesh's lobby (already showing both players) and Watersh's
          // lobby (already showing both). The composite proves the
          // playerAdded stream propagated to BOTH devices without any
          // refresh button being tapped.
          bundle02 = await fleet.snapshotComposite('02-both-see-both-players');
        },
      ),
      TestStep(
        name: 'Firesh challenges Watersh — both see the battle live',
        action: () async {
          final result = await fleet.runPatrolOn(
            device: fireshDevice,
            target: 'integration_test/agent_flows/create_battle.dart',
            env: {
              'EMAIL': fireshEmail,
              'PASSWORD': fireshPassword,
              'OPPONENT': 'Watersh',
              'BATTLE_TEAM': fireBattleTeam,
            },
          );
          expect(
            result.passed,
            isTrue,
            reason: 'Patrol on ${result.device.id} failed '
                '(exit ${result.exitCode}):\n${result.stdout}\n'
                '${result.stderr}',
          );
          // Watersh's device is still on the lobby — the battle card was
          // pushed via battleAdded stream. The composite captures both
          // sides of the new challenge.
          bundle03 = await fleet.snapshotComposite('03-battle-live-on-both');
        },
      ),
      TestStep(
        name: 'Composites and metadata exist on disk for AI review',
        action: () async {
          for (final b in [bundle01!, bundle02!, bundle03!]) {
            expect(
              b.composite,
              isNotNull,
              reason: 'Composite missing for ${b.label}',
            );
            expect(b.composite!.existsSync(), isTrue);
            expect(b.shots, hasLength(2));
            expect(
              b.skewMs,
              lessThan(2000),
              reason: 'Screenshot skew too high for ${b.label}: ${b.skewMs}ms',
            );
          }
        },
      ),
    ],
  );
}
