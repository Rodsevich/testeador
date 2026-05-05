import 'package:testeador/testeador.dart';

import 'flows/client_integration_flows.dart';

/// Entry point for the client integration test suite.
///
/// Runs all three client integration flows sequentially against the real APIs:
/// - [buildPokeApiClientFlow] — tests `PokeApiClient.fetchPokemon`
/// - [buildBattleApiClientFlow] — tests all `BattleApiClient` methods
/// - [buildRepositoryFlow] — tests `PokemonRepository` and `BattleRepository`
void main() {
  Testeador(
    flows: [
      buildPokeApiClientFlow(),
      buildBattleApiClientFlow(),
      buildRepositoryFlow(),
    ],
  ).registerWithDartTest();
}
