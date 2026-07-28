import 'package:pokebattle_serverpod_server/src/generated/protocol.dart';
import 'package:pokebattle_serverpod_server/src/store/in_memory_store.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryStore', () {
    final store = InMemoryStore.instance;

    test('round-trips a registered user', () {
      final user = AuthUser(
        id: 'u-roundtrip',
        name: 'Pikachu Trainer',
        email: 'pikachu@testeador.dev',
        token: 'tok-1',
      );
      store.putUser(user, 'Secret_1!');

      expect(store.userByEmail(user.email)?.id, user.id);
      expect(store.passwordByEmail(user.email), 'Secret_1!');
    });

    test('returns null for an unknown email', () {
      expect(store.userByEmail('ghost@testeador.dev'), isNull);
      expect(store.passwordByEmail('ghost@testeador.dev'), isNull);
    });

    test('lists players in insertion order', () {
      final ash = Player(
        id: 'p-ash',
        name: 'Ash',
        pokemonNames: const ['pikachu', 'bulbasaur'],
      );
      final misty = Player(
        id: 'p-misty',
        name: 'Misty',
        pokemonNames: const ['staryu', 'starmie'],
      );
      store.putPlayer(ash);
      store.putPlayer(misty);

      final all = store.listPlayers();
      expect(all.map((p) => p.id), containsAllInOrder(['p-ash', 'p-misty']));
      expect(store.playerById('p-ash')?.name, 'Ash');
    });

    test('persists and retrieves a battle', () {
      final battle = Battle(
        id: 'b-1',
        challengerName: 'Ash',
        opponentName: 'Misty',
        challengerTeam: const ['pikachu'],
      );
      store.putBattle(battle);

      expect(store.battleById('b-1')?.challengerName, 'Ash');
      expect(store.listBattles().map((b) => b.id), contains('b-1'));
    });
  });
}
