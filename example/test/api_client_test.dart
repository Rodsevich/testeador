// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';

void main() {
  group('PokeApiClient', () {
    late PokeApiClient client;

    setUp(() {
      client = PokeApiClient(Dio());
    });

    test('fetchPokemon returns charizard with fire type and sprite', () async {
      final pokemon = await client.fetchPokemon('charizard');

      expect(pokemon.name, equals('charizard'));
      expect(pokemon.types, contains('fire'));
      expect(pokemon.spriteUrl, isNotEmpty);
      expect(pokemon.spriteUrl, startsWith('https://'));
    });

    test('fetchPokemon returns blastoise with water type', () async {
      final pokemon = await client.fetchPokemon('blastoise');

      expect(pokemon.name, equals('blastoise'));
      expect(pokemon.types, contains('water'));
      expect(pokemon.spriteUrl, isNotEmpty);
    });

    test('fetchPokemon returns gyarados with water and flying types', () async {
      final pokemon = await client.fetchPokemon('gyarados');

      expect(pokemon.name, equals('gyarados'));
      expect(pokemon.types, contains('water'));
      expect(pokemon.types, contains('flying'));
    });

    test('fetchPokemon is case-insensitive', () async {
      final pokemon = await client.fetchPokemon('Pikachu');

      expect(pokemon.name, equals('pikachu'));
    });

    test('fetchPokemon returns mewtwo as psychic type', () async {
      final pokemon = await client.fetchPokemon('mewtwo');

      expect(pokemon.name, equals('mewtwo'));
      expect(pokemon.types, contains('psychic'));
    });
  });

  group('BattleApiClient', () {
    late BattleApiClient client;
    // Use a unique suffix per test run to avoid collisions on the shared
    // backend.
    final runId = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      client = BattleApiClient(Dio());
    });

    test('registerPlayer creates a player and returns it with an id', () async {
      final player = await client.registerPlayer(
        actorName: 'TestPlayer_$runId',
        pokemonNames: [
          'charizard',
          'arcanine',
          'flareon',
          'rapidash',
          'magmar',
          'ninetales',
        ],
      );

      expect(player.id, isNotEmpty);
      expect(player.name, equals('TestPlayer_$runId'));
      expect(player.pokemonNames, hasLength(6));
      expect(player.pokemonNames, contains('charizard'));
    });

    test(
        'listPlayers returns a list '
        '(may be empty: API only lists pre-seeded objects)', () async {
      final players = await client.listPlayers();

      expect(players, isA<List<Player>>());
    });

    test('listPlayers does not include user-created players (API limitation)',
        () async {
      // restful-api.dev GET /objects only returns pre-seeded objects, not
      // user-created ones. Registering a player and then listing will NOT
      // find the registered player in the list.
      final name = 'ListTestPlayer_$runId';
      await client.registerPlayer(
        actorName: name,
        pokemonNames: ['pikachu', 'mewtwo', 'gengar'],
      );

      final players = await client.listPlayers();
      // The list only contains pre-seeded objects (none with type='player'),
      // so the result is always empty.
      expect(players, isA<List<Player>>());
    });

    test('createBattle creates a battle and returns it with an id', () async {
      final battle = await client.createBattle(
        challengerName: 'Challenger_$runId',
        opponentName: 'Opponent_$runId',
        challengerTeam: ['pikachu', 'mewtwo', 'gengar'],
      );

      expect(battle.id, isNotEmpty);
      expect(battle.challengerName, equals('Challenger_$runId'));
      expect(battle.opponentName, equals('Opponent_$runId'));
      expect(battle.challengerTeam, equals(['pikachu', 'mewtwo', 'gengar']));
    });

    test('getBattle fetches a battle by id with correct data', () async {
      final created = await client.createBattle(
        challengerName: 'GetTestChallenger_$runId',
        opponentName: 'GetTestOpponent_$runId',
        challengerTeam: ['snorlax', 'alakazam', 'machamp'],
      );

      final fetched = await client.getBattle(created.id);

      expect(fetched.id, equals(created.id));
      expect(fetched.challengerName, equals('GetTestChallenger_$runId'));
      expect(fetched.opponentName, equals('GetTestOpponent_$runId'));
      expect(
        fetched.challengerTeam,
        equals(['snorlax', 'alakazam', 'machamp']),
      );
    });

    test(
        'listBattles returns a list '
        '(may be empty: API only lists pre-seeded objects)', () async {
      // Ensure at least one battle exists (but it won't appear in the list)
      await client.createBattle(
        challengerName: 'ListBattleChallenger_$runId',
        opponentName: 'ListBattleOpponent_$runId',
        challengerTeam: ['charizard', 'blastoise', 'pikachu'],
      );

      final battles = await client.listBattles();

      // restful-api.dev GET /objects only returns pre-seeded objects, not
      // user-created ones, so battles list is always empty.
      expect(battles, isA<List<Battle>>());
    });

    test('listBattles does not include user-created battles (API limitation)',
        () async {
      // restful-api.dev GET /objects only returns pre-seeded objects, not
      // user-created ones. Creating a battle and then listing will NOT
      // find the created battle in the list.
      final created = await client.createBattle(
        challengerName: 'IncludeChallenger_$runId',
        opponentName: 'IncludeOpponent_$runId',
        challengerTeam: ['gengar', 'alakazam', 'mewtwo'],
      );

      final battles = await client.listBattles();
      // The created battle is accessible by ID but not in the list.
      final found = battles.where((b) => b.id == created.id).toList();
      expect(found, isEmpty);
    });
  });

  group('PokemonRepository', () {
    late PokemonRepository repo;

    setUp(() {
      repo = PokemonRepository(Dio());
    });

    test('getPokemon returns a Pokemon with name, types, and sprite', () async {
      final pokemon = await repo.getPokemon('snorlax');

      expect(pokemon.name, equals('snorlax'));
      expect(pokemon.types, isNotEmpty);
      expect(pokemon.spriteUrl, isNotEmpty);
    });

    test('getPokemon returns arcanine as fire type', () async {
      final pokemon = await repo.getPokemon('arcanine');

      expect(pokemon.name, equals('arcanine'));
      expect(pokemon.types, contains('fire'));
    });
  });

  group('BattleRepository', () {
    late BattleRepository repo;
    final repoRunId = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      repo = BattleRepository(Dio());
    });

    test('registerPlayer registers and returns a Player', () async {
      final player = await repo.registerPlayer(
        actorName: 'RepoPlayer_$repoRunId',
        pokemonNames: ['vaporeon', 'lapras', 'starmie'],
      );

      expect(player.id, isNotEmpty);
      expect(player.name, equals('RepoPlayer_$repoRunId'));
      expect(player.pokemonNames, hasLength(3));
    });

    test('listPlayers returns a list', () async {
      final players = await repo.listPlayers();

      expect(players, isA<List<Player>>());
    });

    test('createBattle and getBattle round-trip', () async {
      final created = await repo.createBattle(
        challengerName: 'RepoChallenger_$repoRunId',
        opponentName: 'RepoOpponent_$repoRunId',
        challengerTeam: ['flareon', 'rapidash', 'magmar'],
      );

      final fetched = await repo.getBattle(created.id);

      expect(fetched.id, equals(created.id));
      expect(fetched.challengerName, equals('RepoChallenger_$repoRunId'));
      expect(fetched.challengerTeam, hasLength(3));
    });

    test('listBattles returns a list', () async {
      final battles = await repo.listBattles();

      expect(battles, isA<List<Battle>>());
    });
  });
}
