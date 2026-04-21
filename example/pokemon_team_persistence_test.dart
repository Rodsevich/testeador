import 'package:testeador/testeador.dart';
import 'package:example/data/api_client.dart';
import 'package:example/domain/repositories.dart';

/// Integration test: add Jinx, Articuno and Mew to the team, restart the app,
/// and verify those 3 Pokémon are still in the team.
///
/// Run with:
///   dart run pokemon_team_persistence_test.dart
void main() async {
  final client = PokemonClient();
  final teamClient = TeamClient();
  final pokemonRepo = PokemonRepository(client);
  final teamRepo = TeamRepository(teamClient);

  // We store state across steps using simple closures.
  String? teamId;
  final targetNames = ['jynx', 'articuno', 'mew'];

  final flows = [
    TestFlowTransient(
      name: 'Pokémon Team Persistence – Jinx, Articuno & Mew',
      description:
          'Adds Jinx, Articuno and Mew to the team, simulates an app '
          'restart by fetching the team fresh from the API (as the app would '
          'do via shared_preferences), and verifies all three are present.',
      tags: {'persistence', 'team', 'smoke'},
      rollbackStrategy: RollbackStrategyCustom(
        revertAction: () async {
          if (teamId != null) {
            print(
              'ℹ️  Rollback: team $teamId was created during this test. '
              'In a real environment you would delete it here.',
            );
          }
        },
      ),
      steps: [
        // ── Step 1: fetch the three Pokémon from PokéAPI ─────────────────
        TestStep(
          name: 'Fetch Jynx, Articuno and Mew from PokéAPI',
          action: () async {
            print('🔍 Fetching Pokémon from PokéAPI…');
            for (final name in targetNames) {
              final p = await pokemonRepo.getPokemon(name);
              if (p.name != name) {
                throw Exception('Expected "$name" but got "${p.name}"');
              }
              print('  ✅ ${p.name.toUpperCase()} (#${p.id}) fetched OK');
            }
          },
        ),

        // ── Step 2: create the team (simulates pressing "Add to Team" x3) ─
        TestStep(
          name: 'Create team with Jynx, Articuno and Mew',
          action: () async {
            print('📝 Creating team…');
            final pokemons = [
              await pokemonRepo.getPokemon('jynx'),
              await pokemonRepo.getPokemon('articuno'),
              await pokemonRepo.getPokemon('mew'),
            ];
            teamId = await teamRepo.createTeam(pokemons);
            if (teamId == null || teamId!.isEmpty) {
              throw Exception('Team ID returned empty after creation');
            }
            print('  ✅ Team created with ID: $teamId');
            print('  Members: ${pokemons.map((p) => p.name).join(', ')}');
          },
        ),

        // ── Step 3: simulate app restart (re-load team from API by ID) ───
        TestStep(
          name: 'Simulate app restart – reload team by saved ID',
          action: () async {
            print('🔄 Simulating app restart (fetching team by ID)…');
            if (teamId == null) throw Exception('No team ID to reload');

            final loadedTeam = await teamRepo.getTeam(teamId!);
            print('  Loaded ${loadedTeam.length} Pokémon from the API');
            if (loadedTeam.length != targetNames.length) {
              throw Exception(
                'Expected ${targetNames.length} Pokémon after restart, '
                'got ${loadedTeam.length}',
              );
            }
          },
        ),

        // ── Step 4: verify Jynx is in the team ───────────────────────────
        TestStep(
          name: 'Verify Jynx is in the reloaded team',
          action: () async {
            final loadedTeam = await teamRepo.getTeam(teamId!);
            final found = loadedTeam.any((p) => p.name == 'jynx');
            if (!found) {
              throw Exception('Jynx was NOT found in the reloaded team!');
            }
            print('  ✅ Jynx found in team after restart');
          },
        ),

        // ── Step 5: verify Articuno is in the team ────────────────────────
        TestStep(
          name: 'Verify Articuno is in the reloaded team',
          action: () async {
            final loadedTeam = await teamRepo.getTeam(teamId!);
            final found = loadedTeam.any((p) => p.name == 'articuno');
            if (!found) {
              throw Exception('Articuno was NOT found in the reloaded team!');
            }
            print('  ✅ Articuno found in team after restart');
          },
        ),

        // ── Step 6: verify Mew is in the team ────────────────────────────
        TestStep(
          name: 'Verify Mew is in the reloaded team',
          action: () async {
            final loadedTeam = await teamRepo.getTeam(teamId!);
            final found = loadedTeam.any((p) => p.name == 'mew');
            if (!found) {
              throw Exception('Mew was NOT found in the reloaded team!');
            }
            print('  ✅ Mew found in team after restart');
          },
        ),
      ],
    ),
  ];

  final runner = TestRunner(flows: flows);

  print('');
  print('══════════════════════════════════════════════════════');
  print(' Pokémon Team Persistence Test');
  print('══════════════════════════════════════════════════════');
  await runner.run();
}
