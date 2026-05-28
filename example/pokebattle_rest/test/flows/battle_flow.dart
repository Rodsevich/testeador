import 'package:testeador/expect.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';
import '../fixtures/session_fixture.dart';

/// Flow: Firesh (Challenger) challenges Watersh (Opponent) to a battle.
///
/// This is the canonical multi-actor smoke test: it exercises a write from
/// one role and a read from another role on the same backend resource,
/// which is the most common shape a contract regression takes (e.g. the
/// challenger POSTs `challengerTeam` but the opponent's GET returns
/// `challenger_team`). Tagged `smoke` because it covers the read+write
/// contract end-to-end with the minimum number of HTTP calls.
///
/// Firesh selects 3 of her 6 fire Pokémon and creates a battle challenge.
/// Watersh fetches the battle by ID to confirm she can see who she's
/// fighting and with what Pokémon.
TestFlowLasting buildBattleFlow() {
  final fireshActor = firesh();
  final watershActor = watersh();
  AuthUser? authUser;
  BattleRepository fireshRepo() =>
      BattleRepository(fireshActor.dio, token: authUser!.token);
  BattleRepository watershRepo() =>
      BattleRepository(watershActor.dio, token: authUser!.token);

  final fireshBattleTeam = ['charizard', 'arcanine', 'flareon'];
  String? battleId;

  return TestFlowLasting(
    name: 'Firesh challenges Watersh to a battle',
    tags: {'battle', 'smoke'},
    fixture: AuthFixture(onLoad: (u) => authUser = u),
    steps: [
      TestStep(
        name: 'Firesh selects 3 fire Pokémon and issues a battle challenge',
        action: () async {
          final battle = await fireshRepo().createBattle(
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
          final battle = await watershRepo().getBattle(battleId!);

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
