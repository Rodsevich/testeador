import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:testeador_base/src/mirador/report.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('report_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
    'resolveVmUri lanza StateError si no hay archivos vm-service-info',
    () async {
      expect(
        () => resolveVmUri(tempDir.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ningún *vm-service-info*.json'),
          ),
        ),
      );
    },
  );

  test(
    'resolveVmUri selecciona el archivo más reciente y convierte HTTP a WS URI',
    () async {
      final file1 = File('${tempDir.path}/vm-service-info-old.json')
        ..writeAsStringSync(
          jsonEncode({'uri': 'http://127.0.0.1:8080/old_token/'}),
        );

      // Simular diferencia de tiempo
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final file2 = File('${tempDir.path}/vm-service-info-new.json')
        ..writeAsStringSync(
          jsonEncode({'uri': 'http://127.0.0.1:9090/new_token/'}),
        );

      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);

      final resolved = await resolveVmUri(tempDir.path);
      expect(resolved, equals('ws://127.0.0.1:9090/new_token/ws'));
    },
  );
}
