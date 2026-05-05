// Single CLI entry point that aggregates *all* contract-test flows for the
// example app, both smoke and regression.
//
// Two layers of flows are registered:
//
//   1. Multi-actor smoke flows  — tagged `smoke`. The minimum subset that
//      proves the backend contract is alive end-to-end. Two trainers
//      (Firesh = Challenger, Watersh = Opponent) register and exchange a
//      battle. Read-after-write across roles is what catches most contract
//      regressions.
//
//   2. Per-method regression flows — tagged `regression`. Exhaustively
//      exercise every method of every datasource (PokeApiClient,
//      BattleApiClient) and repository (PokemonRepository, BattleRepository)
//      to pinpoint *which* method broke.
//
// Backend CI (smoke gate):
//     dart compile exe example/bin/run_tests.dart -o smoke
//     ./smoke --include-tags smoke
//
// Nightly / release CI (full regression):
//     ./smoke --include-tags regression
//
// Local dev (everything):
//     dart run example/bin/run_tests.dart

import 'package:testeador/testeador.dart';

import '../test/actors.dart';
import '../test/flows/battle_flow.dart';
import '../test/flows/client_integration_flows.dart';
import '../test/flows/fire_team_flow.dart';
import '../test/flows/water_team_flow.dart';

Future<void> main(List<String> args) async {
  final fireshActor = firesh();
  final watershActor = watersh();

  await Testeador(
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
  ).run(args);
}
