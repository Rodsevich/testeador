import 'dart:async';

import 'package:test/test.dart';
import 'package:testeador/src/live/live_persona.dart';

/// Backend fake: la extensión "aparece" tras [registerAfter] polls; [result]
/// es lo que devuelve cada `call`.
class _FakeBackend implements PersonaVmBackend {
  _FakeBackend({
    this.registerAfter = 0,
    this.result = const <String, dynamic>{},
  });

  final int registerAfter;
  final Map<String, dynamic> result;

  int _polls = 0;
  bool disposed = false;
  final List<({String method, Map<String, dynamic> args})> calls =
      <({String method, Map<String, dynamic> args})>[];

  @override
  Future<String> mainIsolateId() async => 'iso-1';

  @override
  Future<Set<String>> extensionRPCs(String isolateId) async {
    final n = _polls++;
    if (n < registerAfter) return <String>{};
    return <String>{
      LivePersonaClient.setPersonaExt,
      LivePersonaClient.listPersonasExt,
      LivePersonaClient.getActivePersonaExt,
    };
  }

  @override
  Future<Map<String, dynamic>> call(
    String method,
    String isolateId,
    Map<String, dynamic> args,
  ) async {
    calls.add((method: method, args: args));
    return result;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  LivePersonaClient clientWith(_FakeBackend backend) => LivePersonaClient(
    wsUri: 'ws://localhost/ws',
    connect: (_) async => backend,
  );

  test(
    'setPersona pasa la persona, devuelve el body y cierra la conexión',
    () async {
      final backend = _FakeBackend(
        result: <String, dynamic>{'persona': 'monje', 'seeded': true},
      );
      final res = await clientWith(
        backend,
      ).setPersona('monje');

      expect(res['persona'], 'monje');
      expect(backend.calls.single.method, LivePersonaClient.setPersonaExt);
      expect(backend.calls.single.args, <String, dynamic>{'persona': 'monje'});
      expect(backend.disposed, isTrue);
    },
  );

  test('setPersona(null) omite el arg persona (salir de fixture)', () async {
    final backend = _FakeBackend();
    await clientWith(backend).setPersona(null);
    expect(backend.calls.single.args, isEmpty);
  });

  test('espera hasta que la extensión se registra (discovery)', () async {
    final backend = _FakeBackend(registerAfter: 2);
    await clientWith(backend).setPersona('novicio');
    expect(backend.calls, hasLength(1));
    expect(backend.calls.single.args, <String, dynamic>{'persona': 'novicio'});
  });

  test('timeout accionable si la extensión nunca aparece', () async {
    final backend = _FakeBackend(registerAfter: 1 << 30);
    await expectLater(
      clientWith(backend).setPersona(
        'monje',
        timeout: const Duration(milliseconds: 150),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(backend.disposed, isTrue);
  });

  test('listPersonas y activePersona invocan sus extensiones', () async {
    final backend = _FakeBackend(
      result: <String, dynamic>{'personas': <Object>[], 'persona': 'monje'},
    );
    final client = clientWith(backend);

    await client.listPersonas();
    expect(backend.calls.last.method, LivePersonaClient.listPersonasExt);

    await client.activePersona();
    expect(backend.calls.last.method, LivePersonaClient.getActivePersonaExt);
  });
}
