// dart test entry point — runs all contract flows (smoke + regression) as
// `group()`/`test()` blocks via testeador's package:test integration.
//
// Use this for local development:
//     dart test example/test/contract_test.dart
//
// In CI you typically compile bin/run_tests.dart to a standalone binary
// instead, since it has no Dart SDK requirement and supports tag filtering
// via --include-tags / --exclude-tags.

import 'package:testeador/testeador.dart';

import 'actors.dart';
import 'flows/battle_flow.dart';
import 'flows/client_integration_flows.dart';
import 'flows/fire_team_flow.dart';
import 'flows/water_team_flow.dart';

void main() {
  final fireshActor = firesh();
  final watershActor = watersh();

  Testeador(
    actors: [fireshActor, watershActor],
    flows: [
      // Smoke: multi-actor business flows.
      buildFireTeamFlow(),
      buildWaterTeamFlow(),
      buildBattleFlow(),
      // Regression: per-method datasource / repository coverage.
      buildPokeApiClientFlow(),
      buildBattleApiClientFlow(),
      buildRepositoryFlow(),
    ],
  ).registerWithDartTest();
}
