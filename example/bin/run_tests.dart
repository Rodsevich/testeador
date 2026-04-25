import 'package:testeador/testeador.dart';

import '../test/actors.dart';
import '../test/flows/battle_flow.dart';
import '../test/flows/fire_team_flow.dart';
import '../test/flows/water_team_flow.dart';

void main() {
  final fireshActor = firesh();
  final watershActor = watersh();

  Testeador(
    flows: [
      buildFireTeamFlow(),
      buildWaterTeamFlow(),
      buildBattleFlow(),
    ],
    actors: [fireshActor, watershActor],
  ).registerWithDartTest();
}
