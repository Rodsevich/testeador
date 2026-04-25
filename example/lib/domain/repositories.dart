import 'package:dio/dio.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/models.dart';

/// Fetches Pokémon data from PokéAPI.
class PokemonRepository {
  /// Creates a [PokemonRepository] using the given [Dio] instance.
  PokemonRepository(Dio dio) : _client = PokeApiClient(dio);

  final PokeApiClient _client;

  /// Fetches a single [Pokemon] by [name] from PokéAPI.
  Future<Pokemon> getPokemon(String name) => _client.fetchPokemon(name);
}

/// Manages player registrations and battles via restful-api.dev.
class BattleRepository {
  /// Creates a [BattleRepository] using the given [Dio] instance.
  BattleRepository(Dio dio) : _client = BattleApiClient(dio);

  final BattleApiClient _client;

  /// Registers this actor as a player with their 6 Pokémon pool.
  Future<Player> registerPlayer({
    required String actorName,
    required List<String> pokemonNames,
  }) =>
      _client.registerPlayer(
        actorName: actorName,
        pokemonNames: pokemonNames,
      );

  /// Lists all registered players.
  Future<List<Player>> listPlayers() => _client.listPlayers();

  /// Creates a battle challenge from [challengerName] against [opponentName].
  Future<Battle> createBattle({
    required String challengerName,
    required String opponentName,
    required List<String> challengerTeam,
  }) =>
      _client.createBattle(
        challengerName: challengerName,
        opponentName: opponentName,
        challengerTeam: challengerTeam,
      );

  /// Fetches a battle by its [id].
  Future<Battle> getBattle(String id) => _client.getBattle(id);

  /// Lists all active battles.
  Future<List<Battle>> listBattles() => _client.listBattles();
}
