import 'dart:async';

import 'package:dev_mate_client/dev_mate_client.dart';
import 'package:test/test.dart';
import 'package:testeador/src/live/live_persona.dart';

void main() {
  FakeVmBackend backend({
    int registerAfter = 0,
    Map<String, dynamic> result = const <String, dynamic>{},
  }) => FakeVmBackend(
    registerAfter: registerAfter,
    extensions: const <String>{
      LivePersonaClient.setPersonaExt,
      LivePersonaClient.listPersonasExt,
      LivePersonaClient.getActivePersonaExt,
    },
    onCall: (_, _) => result,
  );

  LivePersonaClient clientWith(FakeVmBackend b) =>
      LivePersonaClient(wsUri: 'ws://localhost/ws', connect: (_) async => b);

  test(
    'setPersona pasa la persona, devuelve el body y cierra la conexión',
    () async {
      final b = backend(
        result: <String, dynamic>{'persona': 'monje', 'seeded': true},
      );
      final res = await clientWith(b).setPersona('monje');

      expect(res['persona'], 'monje');
      expect(b.calls.single.method, LivePersonaClient.setPersonaExt);
      expect(b.calls.single.args, <String, dynamic>{'persona': 'monje'});
      expect(b.disposed, isTrue);
    },
  );

  test('setPersona(null) omite el arg persona (salir de fixture)', () async {
    final b = backend();
    await clientWith(b).setPersona(null);
    expect(b.calls.single.args, isEmpty);
  });

  test('espera hasta que la extensión se registra (discovery)', () async {
    final b = backend(registerAfter: 2);
    await clientWith(b).setPersona('novicio');
    expect(b.calls, hasLength(1));
    expect(b.calls.single.args, <String, dynamic>{'persona': 'novicio'});
  });

  test('timeout accionable si la extensión nunca aparece', () async {
    final b = FakeVmBackend(registerAfter: 1 << 30);
    await expectLater(
      LivePersonaClient(
        wsUri: 'ws://localhost/ws',
        connect: (_) async => b,
      ).setPersona('monje', timeout: const Duration(milliseconds: 150)),
      throwsA(isA<TimeoutException>()),
    );
    expect(b.disposed, isTrue);
  });

  test('listPersonas y activePersona invocan sus extensiones', () async {
    final b = backend(
      result: <String, dynamic>{'personas': <Object>[], 'persona': 'monje'},
    );
    final client = clientWith(b);

    await client.listPersonas();
    expect(b.calls.last.method, LivePersonaClient.listPersonasExt);

    await client.activePersona();
    expect(b.calls.last.method, LivePersonaClient.getActivePersonaExt);
  });
}
