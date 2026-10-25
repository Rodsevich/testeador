import 'package:dio/dio.dart';

/// A Pokémon as the team builder shows it.
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.heightDm,
    required this.weightHg,
    required this.abilities,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) => Pokemon(
    id: json['id'] as int,
    name: json['name'] as String,
    types: _names(json['types'], 'type'),
    heightDm: json['height'] as int,
    weightHg: json['weight'] as int,
    abilities: _names(json['abilities'], 'ability'),
  );

  /// PokéAPI nests names as `[{<key>: {name: ...}}, ...]`.
  static List<String> _names(Object? list, String key) => [
    for (final entry in list! as List<dynamic>)
      ((entry as Map<String, dynamic>)[key]! as Map<String, dynamic>)['name']!
          as String,
  ];

  final int id;
  final String name;
  final List<String> types;
  final int heightDm;
  final int weightHg;
  final List<String> abilities;
}

/// Thin client over the public, keyless PokéAPI (https://pokeapi.co).
class PokeApi {
  PokeApi(this._dio, {required this.baseUrl});

  final Dio _dio;
  final String baseUrl;

  /// Returns the Pokémon called [name], or `null` when PokéAPI has none.
  Future<Pokemon?> find(String name) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/pokemon/${name.trim().toLowerCase()}',
      options: Options(validateStatus: (s) => s == 200 || s == 404),
    );
    if (response.statusCode == 404) return null;
    return Pokemon.fromJson(response.data!);
  }
}
