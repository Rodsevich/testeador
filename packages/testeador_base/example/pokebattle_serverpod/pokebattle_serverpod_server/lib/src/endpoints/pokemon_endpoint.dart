import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Server-side proxy to PokéAPI.
///
/// Going through the server (rather than letting the Flutter client hit
/// PokéAPI directly) keeps the client transport-uniform — every screen calls
/// `client.X.method(...)` — and lets us cache or rewrite the response later
/// without touching the UI.
class PokemonEndpoint extends Endpoint {
  /// Returns the Pokémon with [name] from PokéAPI.
  Future<Pokemon> getPokemon(Session session, String name) async {
    final response = await http.get(Uri.parse(
      'https://pokeapi.co/api/v2/pokemon/${name.toLowerCase()}',
    ));
    if (response.statusCode != 200) {
      throw Exception('PokéAPI returned ${response.statusCode} for "$name".');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final types = (data['types'] as List<dynamic>)
        .map((t) => (t as Map<String, dynamic>)['type'] as Map<String, dynamic>)
        .map((t) => t['name'] as String)
        .toList();
    final sprites = data['sprites'] as Map<String, dynamic>;
    final spriteUrl = (sprites['front_default'] as String?) ?? '';
    return Pokemon(
      name: data['name'] as String,
      types: types,
      spriteUrl: spriteUrl,
    );
  }
}
