import 'package:testeador/expect.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';
import '../fixtures/session_fixture.dart';

/// Shared state: Watersh's player ID after registration.
///
/// Used by the battle flow.
String? watershPlayerId;

/// Flow: Watersh (Opponent role) registers as a player with her water pool.
///
/// Smoke-tagged: validates the same registration contract from a second
/// actor's perspective, which is what makes the subsequent battle flow's
/// cross-role read meaningful.
TestFlowLasting buildWaterTeamFlow() {
  final actor = watersh();
  AuthUser? authUser;
  BattleRepository battleRepo() =>
      BattleRepository(actor.dio, token: authUser!.token);

  final waterPokemonNames = [
    'blastoise',
    'vaporeon',
    'gyarados',
    'starmie',
    'lapras',
    'cloyster',
  ];

  return TestFlowLasting(
    name: 'Watersh — registers water team',
    tags: {'water', 'registration', 'smoke'},
    fixture: AuthFixture(onLoad: (u) => authUser = u),
    steps: [
      TestStep(
        name: 'Watersh registers with her 6 water Pokémon',
        action: () async {
          final player = await battleRepo().registerPlayer(
            actorName: actor.name,
            pokemonNames: waterPokemonNames,
          );

          watershPlayerId = player.id;

          expect(player.name, equals('Watersh'));
          expect(player.pokemonNames, hasLength(6));
          for (final name in waterPokemonNames) {
            expect(player.pokemonNames, contains(name));
          }
          expect(player.id, isNotEmpty);
        },
      ),
    ],
  );
}
