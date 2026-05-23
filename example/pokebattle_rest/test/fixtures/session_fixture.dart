import 'package:dio/dio.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/data/api_client.dart';
import 'package:testeador_example/domain/models.dart';

/// Registers a unique test user before the flow runs so each test run gets its
/// own isolated private collection on restful-api.dev.
///
/// [onLoad] is called with the new [AuthUser] as soon as it's available,
/// so the enclosing flow can capture it for its steps via a closure variable.
class AuthFixture extends Fixture<AuthUser> {
  AuthFixture({required this.onLoad});

  final void Function(AuthUser user) onLoad;
  final _dio = Dio();

  @override
  Future<AuthUser> load() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final client = AuthApiClient(_dio);
    final user = await client.register(
      'TestUser_$ts',
      'test_$ts@testeador.dev',
      'Password_$ts!',
    );
    onLoad(user);
    return user;
  }

  // restful-api.dev does not support user deletion.
  @override
  Future<void> dispose(AuthUser user) async {}
}
