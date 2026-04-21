import 'package:example/data/api_client.dart';
import 'package:example/domain/models.dart';
import 'package:example/domain/repositories.dart';

void main() async {
  final client = PokemonClient();
  final teamClient = TeamClient();
  final pokemonRepo = PokemonRepository(client);
  final teamRepo = TeamRepository(teamClient);

  print('Fetching Pokemons for the sample team...');
  final teamNames = [
    'charizard',
    'blastoise',
    'venusaur',
    'pikachu',
    'snorlax',
    'mewtwo',
  ];

  final List<Pokemon> pokemons = [];

  for (final name in teamNames) {
    print('Catching $name...');
    final p = await pokemonRepo.getPokemon(name);
    pokemons.add(p);
  }

  print('\nSaving team to the cloud...');
  try {
    final teamId = await teamRepo.createTeam(pokemons);

    print('\n==================================================');
    print('Sample Team created successfully!');
    print('Team ID: $teamId');
    print('Members: ${teamNames.join(', ')}');
    print('==================================================');
  } catch (e) {
    print('Error: $e');
  }
}
