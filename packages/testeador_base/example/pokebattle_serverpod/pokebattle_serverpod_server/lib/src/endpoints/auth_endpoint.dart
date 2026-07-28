import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../store/in_memory_store.dart';

/// Auth endpoint exposed to clients as `client.auth`.
///
/// Demo-grade: passwords are kept in plaintext in memory and tokens are random
/// strings. The point of the example is the streaming endpoints downstream,
/// not real authentication.
class AuthEndpoint extends Endpoint {
  /// Creates a new account and returns an [AuthUser] with a fresh token.
  Future<AuthUser> register(
    Session session,
    String name,
    String email,
    String password,
  ) async {
    if (InMemoryStore.instance.userByEmail(email) != null) {
      throw Exception('Email already registered: $email');
    }
    final user = AuthUser(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: email,
      token: _newToken(),
    );
    InMemoryStore.instance.putUser(user, password);
    return user;
  }

  /// Authenticates an existing account, issuing a fresh token.
  Future<AuthUser> login(
    Session session,
    String email,
    String password,
  ) async {
    final user = InMemoryStore.instance.userByEmail(email);
    final stored = InMemoryStore.instance.passwordByEmail(email);
    if (user == null || stored != password) {
      throw Exception('Invalid credentials.');
    }
    final refreshed = AuthUser(
      id: user.id,
      name: user.name,
      email: user.email,
      token: _newToken(),
    );
    InMemoryStore.instance.putUser(refreshed, password);
    return refreshed;
  }

  String _newToken() =>
      'tok_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
