/// Zone-independent assertions for testeador flows.
///
/// Import this *in addition to* `package:testeador_base/testeador_base.dart` when a flow
/// needs to assert:
///
/// ```dart
/// import 'package:testeador_base/testeador_base.dart';
/// import 'package:testeador_base/expect.dart';
/// ```
///
/// It is a separate import (not part of the main barrel) on purpose: it
/// re-exports the entire `package:matcher` matcher namespace, which would
/// collide with `package:test`'s `expect`/matchers in files that also drive
/// the runner directly (`test()`, `group()`). Flows never import
/// `package:test`, so they pick up testeador's `expect` cleanly.
library;

export 'src/expectations.dart';
