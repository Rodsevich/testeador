import 'package:dio/dio.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/models.dart';

/// Handles user registration and login.
class AuthRepository {
  /// Creates an [AuthRepository] using the given [Dio] instance.
  AuthRepository(Dio dio) : _client = AuthApiClient(dio);

  final AuthApiClient _client;

  /// Registers a new user and returns an [AuthUser] with a JWT token.
  Future<AuthUser> register(String name, String email, String password) =>
      _client.register(name, email, password);

  /// Authenticates an existing user and returns an [AuthUser] with a JWT token.
  Future<AuthUser> login(String email, String password) =>
      _client.login(email, password);
}

/// Fetches Pokémon data from PokéAPI.
class PokemonRepository {
  /// Creates a [PokemonRepository] using the given [Dio] instance.
  PokemonRepository(Dio dio) : _client = PokeApiClient(dio);

  final PokeApiClient _client;

  /// Fetches a single [Pokemon] by [name] from PokéAPI.
  Future<Pokemon> getPokemon(String name) => _client.fetchPokemon(name);
}

/// Manages player registrations and battles via restful-api.dev private
/// collections.
class BattleRepository {
  /// Creates a [BattleRepository] using the given [Dio] instance and JWT
  /// [token].
  BattleRepository(Dio dio, {required String token})
      : _client = BattleApiClient(dio, token: token);

  final BattleApiClient _client;

  /// Registers this actor as a player with their Pokémon pool.
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
