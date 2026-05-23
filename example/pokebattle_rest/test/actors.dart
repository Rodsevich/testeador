// Two trainer personas used in the multi-actor smoke flows.
//
// Both are the same *role* in the app (a trainer), but during a battle they
// take on opposing positions: one is the Challenger, the other the
// Opponent. testeador gives each actor an independent Dio + CurlInterceptor
// so failures print per-actor cURL logs — invaluable when a contract bug
// only manifests for one role (e.g. the opponent's GET sees a different
// shape than the challenger's POST returned).

import 'package:dio/dio.dart';
import 'package:testeador/testeador.dart';

/// Firesh — fire-team trainer. Takes the Challenger role in the battle flow.
class FireshActor extends Actor {
  /// Creates the Firesh actor with a plain [Dio] instance.
  FireshActor()
      : super(
          name: 'Firesh',
          dio: Dio(),
        );
}

/// Watersh — water-team trainer. Takes the Opponent role in the battle flow.
class WatershActor extends Actor {
  /// Creates the Watersh actor with a plain [Dio] instance.
  WatershActor()
      : super(
          name: 'Watersh',
          dio: Dio(),
        );
}

/// Creates the Firesh actor (Challenger).
FireshActor firesh() => FireshActor();

/// Creates the Watersh actor (Opponent).
WatershActor watersh() => WatershActor();
