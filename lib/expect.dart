/// Zone-independent assertions for testeador flows.
///
/// Import this *in addition to* `package:testeador/testeador.dart` when a flow
/// needs to assert:
///
/// ```dart
/// import 'package:testeador/testeador.dart';
/// import 'package:testeador/expect.dart';
/// ```
///
/// It is a separate import (not part of the main barrel) on purpose: it
/// re-exports the entire `package:matcher` matcher namespace, which would
/// collide with `package:test`'s `expect`/matchers in files that also drive
/// the runner directly (`test()`, `group()`). Flows never import
/// `package:test`, so they pick up testeador's `expect` cleanly.
library;

export 'src/expectations.dart';
