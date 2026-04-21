import 'dart:convert';
import 'package:http/http.dart' as http;

class PokemonClient {
  PokemonClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> fetchPokemon(String name) async {
    final response = await _client.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon/$name'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load pokemon: $name');
    }
  }

  Future<Map<String, dynamic>> fetchAbility(String name) async {
    final response = await _client.get(
      Uri.parse('https://pokeapi.co/api/v2/ability/$name'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load ability: $name');
    }
  }
}

class TeamClient {
  TeamClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String baseUrl = 'https://api.restful-api.dev/objects';

  Future<String> createTeam(List<Map<String, dynamic>> pokemons) async {
    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': 'Pokemon Team',
        'data': {'team': pokemons},
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return json['id'] as String;
    } else {
      throw Exception(
        'Failed to create team: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<dynamic>> fetchTeam(String id) async {
    final response = await _client.get(Uri.parse('$baseUrl/$id'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['data'] != null && json['data']['team'] != null) {
        return json['data']['team'] as List<dynamic>;
      }
      return [];
    } else {
      throw Exception('Failed to fetch team');
    }
  }

  Future<void> updateTeam(
    String id,
    List<Map<String, dynamic>> pokemons,
  ) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': 'Pokemon Team',
        'data': {'team': pokemons},
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update team');
    }
  }
}
