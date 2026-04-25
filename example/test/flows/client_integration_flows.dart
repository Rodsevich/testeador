import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/repositories.dart';

/// A minimal [Actor] used internally by the client integration flows.
///
/// Not part of the public test API — each flow creates its own instance.
class _IntegrationActor extends Actor {
  _IntegrationActor(String name) : super(name: name, dio: Dio());
}

/// Builds a [TestFlowLasting] that tests every method of [PokeApiClient]
/// against the real PokéAPI (`https://pokeapi.co/api/v2`).
TestFlowLasting buildPokeApiClientFlow() {
  final actor = _IntegrationActor('PokeApiTester');
  final client = PokeApiClient(actor.dio);

  return TestFlowLasting(
    name: 'PokeApiClient — fetchPokemon',
    tags: {'client', 'pokeapi', 'smoke'},
    steps: [
      TestStep(
        name: 'fetches charizard with correct name and fire type',
        action: () async {
          final pokemon = await client.fetchPokemon('charizard');
          expect(pokemon.name, equals('charizard'));
          expect(pokemon.types, contains('fire'));
          expect(pokemon.spriteUrl, isNotEmpty);
          expect(pokemon.spriteUrl, startsWith('https://'));
        },
      ),
      TestStep(
        name: 'fetches blastoise with correct name and water type',
        action: () async {
          final pokemon = await client.fetchPokemon('blastoise');
          expect(pokemon.name, equals('blastoise'));
          expect(pokemon.types, contains('water'));
          expect(pokemon.spriteUrl, isNotEmpty);
        },
      ),
      TestStep(
        name: 'fetches gyarados which is water/flying type',
        action: () async {
          final pokemon = await client.fetchPokemon('gyarados');
          expect(pokemon.name, equals('gyarados'));
          expect(pokemon.types, contains('water'));
          expect(pokemon.types, contains('flying'));
        },
      ),
      TestStep(
        name: 'name lookup is case-insensitive',
        action: () async {
          final pokemon = await client.fetchPokemon('Pikachu');
          expect(pokemon.name, equals('pikachu'));
        },
      ),
    ],
  );
}

/// Builds a [TestFlowLasting] that tests every method of [BattleApiClient]
/// against the real restful-api.dev backend (`https://api.restful-api.dev`).
///
/// Uses a unique timestamp suffix on player names to avoid collisions between
/// concurrent test runs on the shared backend.
///
/// Note: `GET /objects` on restful-api.dev only returns pre-seeded objects,
/// not user-created ones. The `listPlayers` and `listBattles` steps therefore
/// only verify that the response is a [List] — they do not search for
/// user-created records.
TestFlowLasting buildBattleApiClientFlow() {
  final actor = _IntegrationActor('BattleApiTester');
  final client = BattleApiClient(actor.dio);

  String? registeredPlayerId;
  String? battleId;
  final testPlayerName = 'TestPlayer_${DateTime.now().millisecondsSinceEpoch}';
  final testOpponentName =
      'TestOpponent_${DateTime.now().millisecondsSinceEpoch}';
  final testTeam = ['pikachu', 'mewtwo', 'gengar'];

  return TestFlowLasting(
    name: 'BattleApiClient — full CRUD',
    tags: {'client', 'battle-api', 'smoke'},
    steps: [
      TestStep(
        name: 'registerPlayer creates a player and returns it with an id',
        action: () async {
          final player = await client.registerPlayer(
            actorName: testPlayerName,
            pokemonNames: [
              'charizard',
              'arcanine',
              'flareon',
              'rapidash',
              'magmar',
              'ninetales',
            ],
          );
          registeredPlayerId = player.id;
          expect(player.id, isNotEmpty);
          expect(player.name, equals(testPlayerName));
          expect(player.pokemonNames, hasLength(6));
          expect(player.pokemonNames, contains('charizard'));
        },
      ),
      TestStep(
        name: 'listPlayers returns a list',
        description:
            'restful-api.dev GET /objects only returns pre-seeded objects, '
            'not user-created ones. We verify the response is a List.',
        action: () async {
          final players = await client.listPlayers();
          expect(players, isA<List<Object?>>());
          // Suppress unused variable warning.
          expect(registeredPlayerId, isNotNull);
        },
      ),
      TestStep(
        name: 'createBattle creates a battle and returns it with an id',
        action: () async {
          final battle = await client.createBattle(
            challengerName: testPlayerName,
            opponentName: testOpponentName,
            challengerTeam: testTeam,
          );
          battleId = battle.id;
          expect(battle.id, isNotEmpty);
          expect(battle.challengerName, equals(testPlayerName));
          expect(battle.opponentName, equals(testOpponentName));
          expect(battle.challengerTeam, equals(testTeam));
        },
      ),
      TestStep(
        name: 'getBattle fetches the battle by id with correct data',
        action: () async {
          final battle = await client.getBattle(battleId!);
          expect(battle.id, equals(battleId));
          expect(battle.challengerName, equals(testPlayerName));
          expect(battle.opponentName, equals(testOpponentName));
          expect(battle.challengerTeam, equals(testTeam));
        },
      ),
      TestStep(
        name: 'listBattles returns a list',
        description:
            'restful-api.dev GET /objects only returns pre-seeded objects, '
            'not user-created ones. We verify the response is a List.',
        action: () async {
          final battles = await client.listBattles();
          expect(battles, isA<List<Object?>>());
        },
      ),
    ],
  );
}

/// Builds a [TestFlowLasting] that tests [PokemonRepository] and
/// [BattleRepository] — the higher-level wrappers over the API clients.
///
/// Uses a unique timestamp suffix on player names to avoid collisions between
/// concurrent test runs on the shared backend.
///
/// Note: `GET /objects` on restful-api.dev only returns pre-seeded objects,
/// not user-created ones. The `listPlayers` and `listBattles` steps therefore
/// only verify that the response is a [List].
TestFlowLasting buildRepositoryFlow() {
  final actor = _IntegrationActor('RepoTester');
  final pokemonRepo = PokemonRepository(actor.dio);
  final battleRepo = BattleRepository(actor.dio);

  final repoPlayerName = 'RepoPlayer_${DateTime.now().millisecondsSinceEpoch}';
  String? repoBattleId;

  return TestFlowLasting(
    name: 'Repositories — PokemonRepository and BattleRepository',
    tags: {'client', 'repositories', 'smoke'},
    steps: [
      TestStep(
        name: 'PokemonRepository.getPokemon returns a Pokemon',
        action: () async {
          final pokemon = await pokemonRepo.getPokemon('snorlax');
          expect(pokemon.name, equals('snorlax'));
          expect(pokemon.types, isNotEmpty);
          expect(pokemon.spriteUrl, isNotEmpty);
        },
      ),
      TestStep(
        name: 'BattleRepository.registerPlayer registers and returns a Player',
        action: () async {
          final player = await battleRepo.registerPlayer(
            actorName: repoPlayerName,
            pokemonNames: ['snorlax', 'alakazam', 'machamp'],
          );
          expect(player.id, isNotEmpty);
          expect(player.name, equals(repoPlayerName));
          expect(player.pokemonNames, hasLength(3));
        },
      ),
      TestStep(
        name: 'BattleRepository.listPlayers returns a list',
        description:
            'restful-api.dev GET /objects only returns pre-seeded objects, '
            'not user-created ones. We verify the response is a List.',
        action: () async {
          final players = await battleRepo.listPlayers();
          expect(players, isA<List<Object?>>());
        },
      ),
      TestStep(
        name: 'BattleRepository.createBattle and getBattle round-trip',
        action: () async {
          final battle = await battleRepo.createBattle(
            challengerName: repoPlayerName,
            opponentName: 'SomeOpponent',
            challengerTeam: ['snorlax', 'alakazam', 'machamp'],
          );
          repoBattleId = battle.id;
          expect(battle.id, isNotEmpty);
          expect(battle.challengerTeam, hasLength(3));

          final fetched = await battleRepo.getBattle(repoBattleId!);
          expect(fetched.id, equals(repoBattleId));
          expect(fetched.challengerName, equals(repoPlayerName));
        },
      ),
      TestStep(
        name: 'BattleRepository.listBattles returns a list',
        description:
            'restful-api.dev GET /objects only returns pre-seeded objects, '
            'not user-created ones. We verify the response is a List.',
        action: () async {
          final battles = await battleRepo.listBattles();
          expect(battles, isA<List<Object?>>());
        },
      ),
    ],
  );
}
