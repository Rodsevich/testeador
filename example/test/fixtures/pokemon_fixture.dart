import 'package:dio/dio.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/models.dart';

/// Context produced by [PokemonFixture].
class PokemonContext {
  /// Creates a [PokemonContext] with pre-loaded Pokémon lists.
  const PokemonContext({
    required this.firePokemon,
    required this.waterPokemon,
  });

  /// Pre-loaded fire-type Pokémon (Charizard, Arcanine, Flareon).
  final List<Pokemon> firePokemon;

  /// Pre-loaded water-type Pokémon (Blastoise, Vaporeon, Gyarados).
  final List<Pokemon> waterPokemon;
}

/// Loads Pokémon data from PokéAPI before the flow runs.
class PokemonFixture extends Fixture<PokemonContext> {
  @override
  Future<PokemonContext> load() async {
    final dio = Dio();
    final client = PokeApiClient(dio);

    final firePokemon = await Future.wait([
      client.fetchPokemon('charizard'),
      client.fetchPokemon('arcanine'),
      client.fetchPokemon('flareon'),
    ]);

    final waterPokemon = await Future.wait([
      client.fetchPokemon('blastoise'),
      client.fetchPokemon('vaporeon'),
      client.fetchPokemon('gyarados'),
    ]);

    return PokemonContext(
      firePokemon: firePokemon,
      waterPokemon: waterPokemon,
    );
  }
}
