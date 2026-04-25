import 'package:test/test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';

/// Shared state: Firesh's player ID after registration.
///
/// Used by the battle flow.
String? fireshPlayerId;

/// Flow: Firesh registers as a player with her fire Pokémon pool.
TestFlowLasting buildFireTeamFlow() {
  final actor = firesh();
  final battleRepo = BattleRepository(actor.dio);

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
    steps: [
      TestStep(
        name: 'Firesh registers with her 6 fire Pokémon',
        action: () async {
          final player = await battleRepo.registerPlayer(
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
