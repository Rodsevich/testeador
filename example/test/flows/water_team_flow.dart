import 'package:test/test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';

/// Shared state: Watersh's player ID after registration.
///
/// Used by the battle flow.
String? watershPlayerId;

/// Flow: Watersh registers as a player with her water Pokémon pool.
TestFlowLasting buildWaterTeamFlow() {
  final actor = watersh();
  final battleRepo = BattleRepository(actor.dio);

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
    steps: [
      TestStep(
        name: 'Watersh registers with her 6 water Pokémon',
        action: () async {
          final player = await battleRepo.registerPlayer(
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
