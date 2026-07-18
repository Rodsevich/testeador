// Example: configuring a running app's questline runtime from a TestFlow.
//
// Run the target dev app (with QuestlineDevtools) first, grab its VM-service
// ws:// URI, then:
//
//   dart run example/questline_live_example.dart <ws://127.0.0.1:PORT/ws>
//
// The fixture pins the clock to Sexta and seeds a Sunday-novice state before
// the steps run, and restores the prior state afterwards.
import 'package:testeador/testeador.dart';

Future<void> main(List<String> args) async {
  final wsUri = args.isNotEmpty ? args.first : 'ws://127.0.0.1:8181/ws';
  final actor = QuestlineActor.forApp(wsUri, name: 'novicio');
  final client = actor.client;

  final flow = TestFlowTransient(
    name: 'novicio en Sexta ve el Opus Diei bloqueado',
    fixture: QuestlineScenarioFixture(
      actor: actor,
      scenario: QuestlineScenario.sundayNovice,
    ),
    steps: [
      forceHourStep(client, 'sexta'),
      setSignalStep(client, 'openCount', 3),
      assertSignalStep(client, 'unlockedOpusDiei', false),
      // ...here a flutter_driver / DTD step would assert the UI reflects it.
    ],
  );

  await Testeador(flows: [flow]).run(args.skip(1).toList());
}
