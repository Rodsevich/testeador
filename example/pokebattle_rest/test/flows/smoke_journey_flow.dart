import 'package:test/test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';

import '../actors.dart';

/// End-to-end smoke flow that exercises every important feature of the
/// PokéBattle app in one happy-path journey.
///
/// Two trainers (Firesh = Challenger, Watersh = Opponent) walk through the
/// whole app: register, log back in, browse Pokémon data, register their
/// teams, list players, challenge each other to a battle, and verify the
/// challenge is visible from the opponent's role and in the active list.
///
/// Tagged `smoke` so it gates every PR: if it goes red, something in the
/// auth / pokeapi / players / battles contract is broken.
TestFlowLasting buildSmokeJourneyFlow() {
  final firesh = FireshActor();
  final watersh = WatershActor();

  final ts = DateTime.now().millisecondsSinceEpoch;
  final fireshEmail = 'firesh_$ts@testeador.dev';
  final watershEmail = 'watersh_$ts@testeador.dev';
  const fireshPassword = 'Firesh_Pass1!';
  const watershPassword = 'Watersh_Pass1!';

  final fireshAuth = AuthRepository(firesh.dio);
  final watershAuth = AuthRepository(watersh.dio);
  final pokemonRepo = PokemonRepository(firesh.dio);

  AuthUser? fireshUser;
  AuthUser? watershUser;
  BattleRepository fireshBattles() =>
      BattleRepository(firesh.dio, token: fireshUser!.token);
  BattleRepository watershBattles() =>
      BattleRepository(watersh.dio, token: watershUser!.token);

  const fireTeam = [
    'charizard',
    'arcanine',
    'flareon',
    'rapidash',
    'magmar',
    'ninetales',
  ];
  const waterTeam = [
    'blastoise',
    'gyarados',
    'vaporeon',
    'lapras',
    'starmie',
    'cloyster',
  ];
  const fireshBattleTeam = ['charizard', 'arcanine', 'flareon'];

  String? fireshPlayerId;
  String? watershPlayerId;
  String? battleId;

  return TestFlowLasting(
    name: 'PokéBattle — full smoke journey (auth → pokeapi → players → battle)',
    tags: {'smoke', 'e2e'},
    steps: [
      TestStep(
        name: 'Firesh registers a new trainer account',
        action: () async {
          fireshUser = await fireshAuth.register(
            firesh.name,
            fireshEmail,
            fireshPassword,
          );
          expect(fireshUser!.id, isNotEmpty);
          expect(fireshUser!.name, equals(firesh.name));
          expect(fireshUser!.email, equals(fireshEmail));
          expect(fireshUser!.token, isNotEmpty);
        },
      ),
      TestStep(
        name: 'Firesh logs out and back in, receiving a fresh token',
        action: () async {
          final reAuthed = await fireshAuth.login(fireshEmail, fireshPassword);
          expect(reAuthed.id, equals(fireshUser!.id));
          expect(reAuthed.email, equals(fireshEmail));
          expect(reAuthed.token, isNotEmpty);
          fireshUser = reAuthed;
        },
      ),
      TestStep(
        name: 'Watersh registers her own trainer account',
        action: () async {
          watershUser = await watershAuth.register(
            watersh.name,
            watershEmail,
            watershPassword,
          );
          expect(watershUser!.id, isNotEmpty);
          expect(watershUser!.token, isNotEmpty);
          expect(watershUser!.id, isNot(equals(fireshUser!.id)));
        },
      ),
      TestStep(
        name: 'Firesh looks up charizard on PokéAPI before picking her team',
        action: () async {
          final pokemon = await pokemonRepo.getPokemon('charizard');
          expect(pokemon.name, equals('charizard'));
          expect(pokemon.types, contains('fire'));
          expect(pokemon.spriteUrl, startsWith('https://'));
        },
      ),
      TestStep(
        name: 'Firesh registers as a player with her 6 fire Pokémon',
        action: () async {
          final player = await fireshBattles().registerPlayer(
            actorName: firesh.name,
            pokemonNames: fireTeam,
          );
          fireshPlayerId = player.id;
          expect(player.id, isNotEmpty);
          expect(player.name, equals(firesh.name));
          expect(player.pokemonNames, equals(fireTeam));
        },
      ),
      TestStep(
        name: 'Watersh registers as a player with her 6 water Pokémon',
        action: () async {
          final player = await watershBattles().registerPlayer(
            actorName: watersh.name,
            pokemonNames: waterTeam,
          );
          watershPlayerId = player.id;
          expect(player.id, isNotEmpty);
          expect(player.pokemonNames, equals(waterTeam));
        },
      ),
      TestStep(
        name: 'Firesh opens the lobby and sees both players listed',
        action: () async {
          final players = await fireshBattles().listPlayers();
          final ids = players.map((Player p) => p.id);
          expect(ids, contains(fireshPlayerId));
          expect(ids, contains(watershPlayerId));
        },
      ),
      TestStep(
        name: 'Firesh challenges Watersh to a battle with 3 of her fire team',
        action: () async {
          final battle = await fireshBattles().createBattle(
            challengerName: firesh.name,
            opponentName: watersh.name,
            challengerTeam: fireshBattleTeam,
          );
          battleId = battle.id;
          expect(battle.id, isNotEmpty);
          expect(battle.challengerName, equals(firesh.name));
          expect(battle.opponentName, equals(watersh.name));
          expect(battle.challengerTeam, equals(fireshBattleTeam));
        },
      ),
      TestStep(
        name: 'Watersh opens the battle from her side and sees who & what',
        action: () async {
          final battle = await watershBattles().getBattle(battleId!);
          expect(battle.id, equals(battleId));
          expect(battle.challengerName, equals(firesh.name));
          expect(battle.opponentName, equals(watersh.name));
          expect(battle.challengerTeam, equals(fireshBattleTeam));
        },
      ),
      TestStep(
        name: 'Active battles list includes the new challenge for both actors',
        action: () async {
          final fromFiresh = await fireshBattles().listBattles();
          expect(fromFiresh.map((Battle b) => b.id), contains(battleId));

          final fromWatersh = await watershBattles().listBattles();
          expect(fromWatersh.map((Battle b) => b.id), contains(battleId));
        },
      ),
    ],
  );
}
