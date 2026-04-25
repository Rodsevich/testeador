/// A Pokémon with its name, types, and sprite URL.
class Pokemon {
  /// Creates a [Pokemon] with the given [name], [types], and [spriteUrl].
  const Pokemon({
    required this.name,
    required this.types,
    required this.spriteUrl,
  });

  /// The Pokémon's name as returned by PokéAPI (e.g. `'charizard'`).
  final String name;

  /// The list of type names for this Pokémon (e.g. `['fire', 'flying']`).
  final List<String> types;

  /// URL of the official front sprite from PokéAPI.
  final String spriteUrl;

  @override
  String toString() => 'Pokemon(name: $name, types: $types)';
}

/// A player registered in the battle system.
class Player {
  /// Creates a [Player] with the given fields.
  const Player({
    required this.id,
    required this.name,
    required this.pokemonNames,
  });

  /// The ID assigned by restful-api.dev.
  final String id;

  /// The actor's name.
  final String name;

  /// The 6 Pokémon names in this player's pool.
  final List<String> pokemonNames;

  @override
  String toString() => 'Player(id: $id, name: $name, pokemon: $pokemonNames)';
}

/// A battle challenge between two players.
class Battle {
  /// Creates a [Battle] with the given fields.
  const Battle({
    required this.id,
    required this.challengerName,
    required this.opponentName,
    required this.challengerTeam,
  });

  /// The ID assigned by restful-api.dev.
  final String id;

  /// Name of the actor who issued the challenge.
  final String challengerName;

  /// Name of the actor being challenged.
  final String opponentName;

  /// The 3 Pokémon names the challenger selected for battle.
  final List<String> challengerTeam;

  @override
  String toString() => 'Battle(id: $id, $challengerName vs $opponentName, '
      'team: $challengerTeam)';
}
