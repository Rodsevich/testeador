import 'package:testeador/testeador.dart';
import 'package:example/data/api_client.dart';
import 'package:example/domain/repositories.dart';

void main() async {
  // Let's create the client and repositories to test
  final client = PokemonClient();
  final teamClient = TeamClient();
  final pokemonRepo = PokemonRepository(client);
  final abilityRepo = AbilityRepository(client);
  final teamRepo = TeamRepository(teamClient);

  final flows = [
    TestFlowTransient(
      name: 'Team Repository CRUD Flow',
      description:
          'Creates, fetches, updates and relies on cleanup (Nuke / Custom)',
      tags: {'domain', 'api', 'team'},
      rollbackStrategy: RollbackStrategyCustom(
        revertAction: () async {
          print(
            'In a real scenario, this would clean up the test team ID from the DB',
          );
        },
      ),
      steps: [
        TestStep(
          name: 'Create a new team with Pikachu',
          action: () async {
            print('Creating new team...');
            final pikachu = await pokemonRepo.getPokemon('pikachu');
            final teamId = await teamRepo.createTeam([pikachu]);
            if (teamId.isEmpty) throw Exception('Team ID is empty');
            print('Created team with ID: $teamId');

            print('Fetching the created team...');
            final loadedTeam = await teamRepo.getTeam(teamId);
            if (loadedTeam.length != 1) throw Exception('Expected team size 1');
            if (loadedTeam[0].name != 'pikachu')
              throw Exception('Expected pikachu');

            print('Updating the team to add Bulbasaur...');
            final bulbasaur = await pokemonRepo.getPokemon('bulbasaur');
            await teamRepo.updateTeam(teamId, [pikachu, bulbasaur]);

            print('Fetching the updated team...');
            final updatedTeam = await teamRepo.getTeam(teamId);
            if (updatedTeam.length != 2)
              throw Exception('Expected team size 2');
            print('Team CRUD flow completed successfully!');
          },
        ),
      ],
    ),
    TestFlowLasting(
      name: 'Pokemon Repository Integration Tests',
      tags: {'domain', 'api', 'pokemon'},
      steps: [
        TestStep(
          name: 'Fetch Pikachu',
          action: () async {
            print('Calling pokemon endpoint for pikachu...');
            final pokemon = await pokemonRepo.getPokemon('pikachu');
            if (pokemon.name != 'pikachu') {
              throw Exception(
                'Expected name to be pikachu, got ${pokemon.name}',
              );
            }
            if (pokemon.id != 25) {
              throw Exception('Expected id to be 25, got ${pokemon.id}');
            }
            print('Successfully fetched Pikachu!');
          },
        ),
      ],
    ),
    TestFlowLasting(
      name: 'Ability Repository Integration Tests',
      tags: {'domain', 'api', 'ability'},
      steps: [
        TestStep(
          name: 'Fetch Static ability',
          action: () async {
            print('Calling ability endpoint for static...');
            final ability = await abilityRepo.getAbility('static');
            if (ability.name != 'static') {
              throw Exception(
                'Expected name to be static, got ${ability.name}',
              );
            }
            if (ability.effect.isEmpty) {
              throw Exception('Expected ability to have an effect description');
            }
            print(
              'Successfully fetched Static ability! Effect: ${ability.effect.substring(0, 20)}...',
            );
          },
        ),
      ],
    ),
    TestFlowTransient(
      name: 'Transient Test Example with PokeAPI',
      description:
          'Simulates a flow that needs rollback (though PokeAPI is read-only, we demonstrate the strategy)',
      tags: {'transient'},
      rollbackStrategy: RollbackStrategyCustomHeader(
        headerName: 'X-Testing-Ephemeral',
        headerValue: 'true',
      ),
      steps: [
        TestStep(
          name: 'Fetch Ditto',
          action: () async {
            print('Calling pokemon endpoint for ditto...');
            final pokemon = await pokemonRepo.getPokemon('ditto');
            if (pokemon.name != 'ditto') {
              throw Exception('Expected name to be ditto, got ${pokemon.name}');
            }
            print(
              'Successfully fetched Ditto! (This flow represents an ephemeral test)',
            );
          },
        ),
      ],
    ),
  ];

  final runner = TestRunner(flows: flows);

  print('--- Running Integration Pipeline ---');
  await runner.run();
}
