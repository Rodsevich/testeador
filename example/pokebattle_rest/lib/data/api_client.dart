import 'package:dio/dio.dart';
import 'package:testeador_example/domain/models.dart';

/// Client for the PokéAPI (https://pokeapi.co/api/v2/).
class PokeApiClient {
  /// Creates a [PokeApiClient] using the given [Dio] instance.
  const PokeApiClient(this._dio);

  final Dio _dio;

  static const _baseUrl = 'https://pokeapi.co/api/v2';

  /// Fetches a [Pokemon] by [name] from PokéAPI.
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

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

/// Client for the restful-api.dev authentication endpoints.
class AuthApiClient {
  /// Creates an [AuthApiClient] using the given [Dio] instance.
  const AuthApiClient(this._dio);

  final Dio _dio;

  static const _apiKey = 'd16e1ce2-5fa2-4a25-bcc7-d0a071bd448b';
  static const _baseUrl = 'https://api.restful-api.dev';

  Options get _opts => Options(headers: {'x-api-key': _apiKey});

  /// Creates a new user account and returns an [AuthUser] with a JWT token.
  Future<AuthUser> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/register',
      data: {'name': name, 'email': email, 'password': password},
      options: _opts,
    );
    return _userFromBody(response.data!);
  }

  /// Authenticates an existing user and returns an [AuthUser] with a JWT token.
  Future<AuthUser> login(String email, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/login',
      data: {'email': email, 'password': password},
      options: _opts,
    );
    return _userFromBody(response.data!);
  }

  AuthUser _userFromBody(Map<String, dynamic> body) {
    final user = body['user'] as Map<String, dynamic>;
    return AuthUser(
      id: user['id'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
      token: body['token'] as String,
    );
  }
}

// ---------------------------------------------------------------------------
// Battle API (private collections)
// ---------------------------------------------------------------------------

/// Client for restful-api.dev private collections.
///
/// All requests are authenticated with the app API key and the user's JWT.
class BattleApiClient {
  /// Creates a [BattleApiClient] using the given [Dio] instance and JWT
  /// [token].
  const BattleApiClient(this._dio, {required this.token});

  final Dio _dio;

  /// The JWT token of the currently authenticated user.
  final String token;

  static const _apiKey = 'd16e1ce2-5fa2-4a25-bcc7-d0a071bd448b';
  static const _baseUrl = 'https://api.restful-api.dev';
  static const _players = '/collections/players/objects';
  static const _battles = '/collections/battles/objects';

  Options get _opts => Options(
        headers: {
          'x-api-key': _apiKey,
          'Authorization': 'Bearer $token',
        },
      );

  // -------------------------------------------------------------------------
  // Players
  // -------------------------------------------------------------------------

  /// Registers a new player with the given [actorName] and [pokemonNames].
  Future<Player> registerPlayer({
    required String actorName,
    required List<String> pokemonNames,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl$_players',
      data: {
        'name': actorName,
        'data': {'pokemon': pokemonNames},
      },
      options: _opts,
    );
    return _playerFromBody(response.data!);
  }

  /// Lists all registered players.
  Future<List<Player>> listPlayers() async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl$_players',
      options: _opts,
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(_playerFromBody)
        .toList();
  }

  Player _playerFromBody(Map<String, dynamic> body) => Player(
        id: body['id'] as String,
        name: body['name'] as String,
        pokemonNames:
            ((body['data'] as Map<String, dynamic>)['pokemon'] as List<dynamic>)
                .cast<String>(),
      );

  // -------------------------------------------------------------------------
  // Battles
  // -------------------------------------------------------------------------

  /// Creates a battle challenge from [challengerName] against [opponentName].
  Future<Battle> createBattle({
    required String challengerName,
    required String opponentName,
    required List<String> challengerTeam,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl$_battles',
      data: {
        'name': 'battle:$challengerName-vs-$opponentName',
        'data': {
          'challenger': challengerName,
          'opponent': opponentName,
          'challengerTeam': challengerTeam,
        },
      },
      options: _opts,
    );
    return _battleFromBody(response.data!);
  }

  /// Fetches a battle by its [id].
  Future<Battle> getBattle(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl$_battles/$id',
      options: _opts,
    );
    return _battleFromBody(response.data!);
  }

  /// Lists all active battles.
  Future<List<Battle>> listBattles() async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl$_battles',
      options: _opts,
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(_battleFromBody)
        .toList();
  }

  Battle _battleFromBody(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    return Battle(
      id: body['id'] as String,
      challengerName: data['challenger'] as String,
      opponentName: data['opponent'] as String,
      challengerTeam:
          (data['challengerTeam'] as List<dynamic>).cast<String>(),
    );
  }
}
