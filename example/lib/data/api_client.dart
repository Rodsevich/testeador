import 'package:dio/dio.dart';
import 'package:testeador_example/domain/models.dart';

/// Client for the PokéAPI (https://pokeapi.co/api/v2/).
///
/// Accepts a [Dio] instance so the caller's interceptors (e.g., cURL logging)
/// capture all outgoing requests.
class PokeApiClient {
  /// Creates a [PokeApiClient] with the given [Dio] instance.
  const PokeApiClient(this._dio);

  final Dio _dio;

  static const _baseUrl = 'https://pokeapi.co/api/v2';

  /// Fetches a [Pokemon] by name from PokéAPI, including its sprite URL.
  Future<Pokemon> fetchPokemon(String name) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/pokemon/${name.toLowerCase()}',
    );
    final data = response.data!;
    final types = (data['types'] as List<dynamic>)
        .map((t) => (t as Map<String, dynamic>)['type'])
        .cast<Map<String, dynamic>>()
        .map((t) => t['name'] as String)
        .toList();
    final sprites = data['sprites'] as Map<String, dynamic>;
    final spriteUrl = sprites['front_default'] as String? ?? '';
    return Pokemon(
      name: data['name'] as String,
      types: types,
      spriteUrl: spriteUrl,
    );
  }
}

/// Client for restful-api.dev — used to persist players and battles.
///
/// Accepts a [Dio] instance so the caller's interceptors (e.g., cURL logging)
/// capture all outgoing requests.
class BattleApiClient {
  /// Creates a [BattleApiClient] with the given [Dio] instance.
  const BattleApiClient(this._dio);

  final Dio _dio;

  static const _baseUrl = 'https://api.restful-api.dev';
  static const _objectsPath = '/objects';

  /// Registers a player with their 6 Pokémon pool.
  Future<Player> registerPlayer({
    required String actorName,
    required List<String> pokemonNames,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl$_objectsPath',
      data: {
        'name': actorName,
        'data': {
          'type': 'player',
          'pokemon': pokemonNames,
        },
      },
    );
    final body = response.data!;
    final data = body['data'] as Map<String, dynamic>;
    return Player(
      id: body['id'] as String,
      name: body['name'] as String,
      pokemonNames: (data['pokemon'] as List<dynamic>).cast<String>(),
    );
  }

  /// Lists all registered players.
  Future<List<Player>> listPlayers() async {
    final response = await _dio.get<List<dynamic>>('$_baseUrl$_objectsPath');
    final items = response.data!;
    final players = <Player>[];
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final data = map['data'];
      if (data is Map<String, dynamic> && data['type'] == 'player') {
        players.add(
          Player(
            id: map['id'] as String,
            name: map['name'] as String,
            pokemonNames: (data['pokemon'] as List<dynamic>).cast<String>(),
          ),
        );
      }
    }
    return players;
  }

  /// Creates a battle challenge.
  Future<Battle> createBattle({
    required String challengerName,
    required String opponentName,
    required List<String> challengerTeam,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl$_objectsPath',
      data: {
        'name': 'battle:$challengerName-vs-$opponentName',
        'data': {
          'type': 'battle',
          'challenger': challengerName,
          'opponent': opponentName,
          'challengerTeam': challengerTeam,
        },
      },
    );
    final body = response.data!;
    final data = body['data'] as Map<String, dynamic>;
    return Battle(
      id: body['id'] as String,
      challengerName: data['challenger'] as String,
      opponentName: data['opponent'] as String,
      challengerTeam: (data['challengerTeam'] as List<dynamic>).cast<String>(),
    );
  }

  /// Fetches a battle by ID.
  Future<Battle> getBattle(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl$_objectsPath/$id',
    );
    final body = response.data!;
    final data = body['data'] as Map<String, dynamic>;
    return Battle(
      id: body['id'] as String,
      challengerName: data['challenger'] as String,
      opponentName: data['opponent'] as String,
      challengerTeam: (data['challengerTeam'] as List<dynamic>).cast<String>(),
    );
  }

  /// Lists all battles.
  Future<List<Battle>> listBattles() async {
    final response = await _dio.get<List<dynamic>>('$_baseUrl$_objectsPath');
    final items = response.data!;
    final battles = <Battle>[];
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final data = map['data'];
      if (data is Map<String, dynamic> && data['type'] == 'battle') {
        battles.add(
          Battle(
            id: map['id'] as String,
            challengerName: data['challenger'] as String,
            opponentName: data['opponent'] as String,
            challengerTeam:
                (data['challengerTeam'] as List<dynamic>).cast<String>(),
          ),
        );
      }
    }
    return battles;
  }
}
