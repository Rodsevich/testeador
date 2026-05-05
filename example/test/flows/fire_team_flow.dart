import 'package:test/test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';
import '../fixtures/session_fixture.dart';

/// Shared state: Firesh's player ID after registration.
///
/// Used by the battle flow.
String? fireshPlayerId;

/// Flow: Firesh (Challenger role) registers as a player with her fire pool.
///
/// Smoke-tagged: this is the minimum write path needed to prove the
/// player-registration contract is alive. Pair with `water_team_flow` and
/// `battle_flow` to cover read-after-write across two roles.
TestFlowLasting buildFireTeamFlow() {
  final actor = firesh();
  AuthUser? authUser;
  BattleRepository battleRepo() =>
      BattleRepository(actor.dio, token: authUser!.token);

  final firePokemonNames = [
    'charizard',
    'arcanine',
    'flareon',
    'rapidash',
    'magmar',
    'ninetales',
  ];

  return TestFlowLasting(
    name: 'Firesh — registers fire team',
    tags: {'fire', 'registration', 'smoke'},
    fixture: AuthFixture(onLoad: (u) => authUser = u),
    steps: [
      TestStep(
        name: 'Firesh registers with her 6 fire Pokémon',
        action: () async {
          final player = await battleRepo().registerPlayer(
            actorName: actor.name,
            pokemonNames: firePokemonNames,
          );

          fireshPlayerId = player.id;

          expect(player.name, equals('Firesh'));
          expect(player.pokemonNames, hasLength(6));
          for (final name in firePokemonNames) {
            expect(player.pokemonNames, contains(name));
          }
          expect(player.id, isNotEmpty);
        },
      ),
    ],
  );
}
