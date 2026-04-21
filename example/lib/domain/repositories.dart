import '../data/api_client.dart';
import 'models.dart';

class PokemonRepository {
  const PokemonRepository(this.client);
  final PokemonClient client;

  Future<Pokemon> getPokemon(String name) async {
    final data = await client.fetchPokemon(name);
    return Pokemon.fromJson(data);
  }
}

class AbilityRepository {
  const AbilityRepository(this.client);
  final PokemonClient client;

  Future<Ability> getAbility(String name) async {
    final data = await client.fetchAbility(name);
    return Ability.fromJson(data);
  }
}

class TeamRepository {
  const TeamRepository(this.client);
  final TeamClient client;

  Future<String> createTeam(List<Pokemon> pokemons) async {
    final data = pokemons.map((p) => p.toJson()).toList();
    return await client.createTeam(data);
  }

  Future<List<Pokemon>> getTeam(String id) async {
    final data = await client.fetchTeam(id);
    return data
        .map((json) => Pokemon.fromTeamJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateTeam(String id, List<Pokemon> pokemons) async {
    final data = pokemons.map((p) => p.toJson()).toList();
    await client.updateTeam(id, data);
  }
}
