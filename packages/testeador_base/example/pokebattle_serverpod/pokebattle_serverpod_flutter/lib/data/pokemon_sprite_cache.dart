import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';

/// Caches Pokémon fetched from the Serverpod `pokemon.getPokemon` endpoint.
///
/// Memoizes the in-flight Future per (lowercased) name so concurrent
/// requests for the same Pokémon share a single round-trip.
class PokemonSpriteCache {
  /// Builds a cache backed by [client].
  PokemonSpriteCache(this._client);

  final Client _client;
  final Map<String, Future<Pokemon>> _byName = {};

  /// Returns the [Pokemon] for [name], fetching from the server on first use.
  Future<Pokemon> get(String name) {
    final key = name.toLowerCase();
    return _byName.putIfAbsent(key, () => _client.pokemon.getPokemon(key));
  }
}
