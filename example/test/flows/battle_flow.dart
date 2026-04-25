import 'package:test/test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';

/// Flow: Firesh challenges Watersh to a battle.
///
/// Firesh selects 3 of her 6 fire Pokémon, creates a battle challenge.
/// Watersh fetches the battle by ID to confirm she can see who she's
/// fighting and with what Pokémon.
///
/// Note: restful-api.dev GET /objects only returns pre-seeded objects, not
/// user-created ones. Player listing is therefore skipped; instead we verify
/// the battle round-trip directly via createBattle + getBattle.
TestFlowLasting buildBattleFlow() {
  final fireshActor = firesh();
  final watershActor = watersh();

  final fireshBattleRepo = BattleRepository(fireshActor.dio);
  final watershBattleRepo = BattleRepository(watershActor.dio);

  // Firesh selects 3 of her 6 fire Pokémon for battle.
  final fireshBattleTeam = ['charizard', 'arcanine', 'flareon'];

  String? battleId;

  return TestFlowLasting(
    name: 'Firesh challenges Watersh to a battle',
    tags: {'battle', 'smoke'},
    steps: [
      TestStep(
        name: 'Firesh selects 3 fire Pokémon and issues a battle challenge',
        action: () async {
          final battle = await fireshBattleRepo.createBattle(
            challengerName: fireshActor.name,
            opponentName: watershActor.name,
            challengerTeam: fireshBattleTeam,
          );

          battleId = battle.id;

          expect(battle.challengerName, equals('Firesh'));
          expect(battle.opponentName, equals('Watersh'));
          expect(battle.challengerTeam, hasLength(3));
          for (final name in fireshBattleTeam) {
            expect(battle.challengerTeam, contains(name));
          }
          expect(battle.id, isNotEmpty);
        },
      ),
      TestStep(
        name: 'Watersh views the battle challenge and sees '
            'who she fights and with what',
        action: () async {
          final battle = await watershBattleRepo.getBattle(battleId!);

          expect(battle.challengerName, equals('Firesh'));
          expect(battle.opponentName, equals('Watersh'));
          expect(battle.challengerTeam, hasLength(3));
          for (final name in ['charizard', 'arcanine', 'flareon']) {
            expect(battle.challengerTeam, contains(name));
          }
        },
      ),
    ],
  );
}
