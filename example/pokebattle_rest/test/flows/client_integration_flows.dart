// Per-method regression flows for the data and domain layers.
//
// These flows exhaustively exercise every public method of PokeApiClient,
// BattleApiClient, PokemonRepository and BattleRepository. They are tagged
// `regression` (not `smoke`) because they are intentionally redundant with
// the multi-actor flows in flows/{fire_team,water_team,battle}_flow.dart:
// the multi-actor flows prove the contract is alive end-to-end; these
// flows pinpoint *which* method broke when the smoke run fails.
//
// Run them in CI for releases / nightly builds:
//     dart run example/bin/run_tests.dart --include-tags regression

import 'package:dio/dio.dart';
import 'package:testeador/expect.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../fixtures/session_fixture.dart';

/// A minimal [Actor] used internally by the client integration flows.
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
    tags: {'client', 'pokeapi', 'regression'},
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
/// against the real restful-api.dev backend.
///
/// Uses an [AuthFixture] to register a unique test user before the steps run,
/// giving each flow run its own isolated private collection.
TestFlowLasting buildBattleApiClientFlow() {
  final dio = Dio();
  AuthUser? authUser;
  BattleApiClient client() => BattleApiClient(dio, token: authUser!.token);

  String? registeredPlayerId;
  String? battleId;
  final ts = DateTime.now().millisecondsSinceEpoch;
  final testPlayerName = 'TestPlayer_$ts';
  final testOpponentName = 'TestOpponent_$ts';
  final testTeam = ['pikachu', 'mewtwo', 'gengar'];

  return TestFlowLasting(
    name: 'BattleApiClient — full CRUD',
    tags: {'client', 'battle-api', 'regression'},
    fixture: AuthFixture(onLoad: (u) => authUser = u),
    steps: [
      TestStep(
        name: 'registerPlayer creates a player and returns it with an id',
        action: () async {
          final player = await client().registerPlayer(
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
        name: 'listPlayers includes the registered player',
        action: () async {
          final players = await client().listPlayers();
          expect(
            players.map((Player p) => p.id),
            contains(registeredPlayerId),
          );
          final found =
              players.firstWhere((Player p) => p.id == registeredPlayerId);
          expect(found.name, equals(testPlayerName));
        },
      ),
      TestStep(
        name: 'createBattle creates a battle and returns it with an id',
        action: () async {
          final battle = await client().createBattle(
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
          final battle = await client().getBattle(battleId!);
          expect(battle.id, equals(battleId));
          expect(battle.challengerName, equals(testPlayerName));
          expect(battle.opponentName, equals(testOpponentName));
          expect(battle.challengerTeam, equals(testTeam));
        },
      ),
      TestStep(
        name: 'listBattles includes the created battle',
        action: () async {
          final battles = await client().listBattles();
          expect(battles.map((Battle b) => b.id), contains(battleId));
          final found = battles.firstWhere((Battle b) => b.id == battleId);
          expect(found.challengerName, equals(testPlayerName));
        },
      ),
    ],
  );
}

/// Builds a [TestFlowLasting] that tests [PokemonRepository] and
/// [BattleRepository] — the higher-level wrappers over the API clients.
///
/// Uses an [AuthFixture] to register a unique test user before steps run.
TestFlowLasting buildRepositoryFlow() {
  final dio = Dio();
  AuthUser? authUser;
  final pokemonRepo = PokemonRepository(dio);
  BattleRepository battleRepo() =>
      BattleRepository(dio, token: authUser!.token);

  final ts = DateTime.now().millisecondsSinceEpoch;
  final repoPlayerName = 'RepoPlayer_$ts';
  String? repoPlayerId;
  String? repoBattleId;

  return TestFlowLasting(
    name: 'Repositories — PokemonRepository and BattleRepository',
    tags: {'repository', 'regression'},
    fixture: AuthFixture(onLoad: (u) => authUser = u),
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
          final player = await battleRepo().registerPlayer(
            actorName: repoPlayerName,
            pokemonNames: ['snorlax', 'alakazam', 'machamp'],
          );
          repoPlayerId = player.id;
          expect(player.id, isNotEmpty);
          expect(player.name, equals(repoPlayerName));
          expect(player.pokemonNames, hasLength(3));
        },
      ),
      TestStep(
        name: 'BattleRepository.listPlayers includes the registered player',
        action: () async {
          final players = await battleRepo().listPlayers();
          expect(players.map((Player p) => p.id), contains(repoPlayerId));
        },
      ),
      TestStep(
        name: 'BattleRepository.createBattle and getBattle round-trip',
        action: () async {
          final battle = await battleRepo().createBattle(
            challengerName: repoPlayerName,
            opponentName: 'SomeOpponent',
            challengerTeam: ['snorlax', 'alakazam', 'machamp'],
          );
          repoBattleId = battle.id;
          expect(battle.id, isNotEmpty);
          expect(battle.challengerTeam, hasLength(3));

          final fetched = await battleRepo().getBattle(repoBattleId!);
          expect(fetched.id, equals(repoBattleId));
          expect(fetched.challengerName, equals(repoPlayerName));
        },
      ),
      TestStep(
        name: 'BattleRepository.listBattles includes the created battle',
        action: () async {
          final battles = await battleRepo().listBattles();
          expect(battles.map((Battle b) => b.id), contains(repoBattleId));
        },
      ),
    ],
  );
}
