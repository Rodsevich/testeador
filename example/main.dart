import 'package:testeador/testeador.dart';

class DatabaseFixture extends Fixture<String> {
  @override
  Future<String> load() async {
    print('Connecting to database...');
    return 'db_connection_string';
  }

  @override
  Future<void> dispose(String data) async {
    print('Disconnecting from database...');
  }
}

void main() async {
  final flows = [
    TestFlow(
      name: 'Auth Flow',
      tags: {'smoke', 'auth'},
      fixtures: [DatabaseFixture()],
      steps: [
        TestStep(
          name: 'Login',
          action: () => print('Performing login...'),
        ),
        TestStep(
          name: 'Verify Profile',
          action: () => print('Verifying profile data...'),
        ),
      ],
    ),
    TestFlow(
      name: 'Settings Flow',
      tags: {'settings'},
      steps: [
        TestStep(
          name: 'Update Password',
          action: () => print('Updating password...'),
        ),
      ],
    ),
  ];

  final runner = TestRunner(flows: flows);

  print('--- Running all tests ---');
  await runner.run();

  print('\n--- Running smoke tests only ---');
  await runner.run(tags: {'smoke'});
}
