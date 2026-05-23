import 'package:dio/dio.dart';
import 'package:testeador/src/actor.dart';
import 'package:testeador/src/multidev/target_device.dart';

/// {@template flutter_actor}
/// An [Actor] that is bound to a specific [TargetDevice].
///
/// The host-side [dio] keeps the same role as in the base [Actor] — recording
/// cURL evidence for HTTP assertions in a [TestStep]. The new [device] field
/// lets steps route Patrol invocations and screenshots to the right
/// emulator/simulator without an out-of-band registry.
/// {@endtemplate}
class FlutterActor extends Actor {
  /// {@macro flutter_actor}
  FlutterActor({
    required super.name,
    required this.device,
    Dio? dio,
    super.redactHeaders,
  }) : super(dio: dio ?? Dio());

  /// The device hosting the Flutter app this actor controls.
  final TargetDevice device;
}
