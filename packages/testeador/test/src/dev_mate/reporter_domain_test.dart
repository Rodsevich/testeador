import 'package:dev_mate/dev_mate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testeador/testeador.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    unregisterReporterDomain();
  });

  test('registerReporterDomain registra el dominio reporter en DevMate', () {
    registerReporterDomain(currentRoute: () => '/home');

    final domains = DevMate.instance.domains;
    expect(domains.containsKey('reporter'), isTrue);

    final reporter = domains['reporter']!;
    expect(reporter.description, contains('Captura ruta activa'));
    expect(reporter.actions.map((a) => a.name), contains('capture'));
  });

  test('action capture del dominio reporter responde con la ruta y estado', () async {
    registerReporterDomain(currentRoute: () => '/profile');

    final reporter = DevMate.instance.domains['reporter']!;
    final captureAction = reporter.actions.firstWhere((a) => a.name == 'capture');

    final result = await captureAction.handler({'message': 'probando captura'});

    expect(result['route'], equals('/profile'));
    expect(result['message'], equals('probando captura'));
    expect(result.containsKey('lastError'), isTrue);
    expect(result.containsKey('blocStates'), isTrue);
  });

  test('unregisterReporterDomain remueve el dominio reporter', () {
    registerReporterDomain(currentRoute: () => '/settings');
    expect(DevMate.instance.domains.containsKey('reporter'), isTrue);

    unregisterReporterDomain();
    expect(DevMate.instance.domains.containsKey('reporter'), isFalse);
  });
}
