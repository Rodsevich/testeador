import '../generated/protocol.dart';

/// In-memory store for the `--mini` Serverpod example.
///
/// A single instance is shared across endpoints via [instance]. It replaces a
/// proper database — fine for the demo, since the whole point of the example
/// is to show streams driving auto-update, not persistence.
class InMemoryStore {
  InMemoryStore._();

  static final instance = InMemoryStore._();

  final Map<String, AuthUser> _usersByEmail = {};
  final Map<String, String> _passwordsByEmail = {};
  final Map<String, Player> _playersById = {};
  final Map<String, Battle> _battlesById = {};

  /// Persists a freshly registered user.
  void putUser(AuthUser user, String password) {
    _usersByEmail[user.email] = user;
    _passwordsByEmail[user.email] = password;
  }

  /// Returns the user for [email] or `null`.
  AuthUser? userByEmail(String email) => _usersByEmail[email];

  /// Returns the stored password (plain text — demo only) for [email].
  String? passwordByEmail(String email) => _passwordsByEmail[email];

  /// Persists a player.
  void putPlayer(Player player) {
    _playersById[player.id] = player;
  }

  /// Returns the player with [id] or `null`.
  Player? playerById(String id) => _playersById[id];

  /// Snapshot of all currently registered players (insertion order).
  List<Player> listPlayers() => List.unmodifiable(_playersById.values);

  /// Persists a battle.
  void putBattle(Battle battle) {
    _battlesById[battle.id] = battle;
  }

  /// Returns the battle with [id] or `null`.
  Battle? battleById(String id) => _battlesById[id];

  /// Snapshot of all currently active battles (insertion order).
  List<Battle> listBattles() => List.unmodifiable(_battlesById.values);
}
