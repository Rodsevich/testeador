import 'package:dio/dio.dart';
import 'package:testeador/testeador.dart';

/// Firesh — manages fire-type Pokémon teams.
class FireshActor extends Actor {
  /// Creates the Firesh actor with a plain [Dio] instance.
  FireshActor()
      : super(
          name: 'Firesh',
          dio: Dio(),
        );
}

/// Watersh — manages water-type Pokémon teams.
class WatershActor extends Actor {
  /// Creates the Watersh actor with a plain [Dio] instance.
  WatershActor()
      : super(
          name: 'Watersh',
          dio: Dio(),
        );
}

/// Creates the Firesh actor.
FireshActor firesh() => FireshActor();

/// Creates the Watersh actor.
WatershActor watersh() => WatershActor();
