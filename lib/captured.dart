/// Public re-export of the `package:test` shim used by codegen-transformed
/// `*_test.dart` files. The transformer rewrites
/// `import 'package:test/test.dart'` to
/// `import 'package:testeador/captured.dart'` so the file's `test()` /
/// `group()` / `setUp()` / `tearDown()` calls register into a capture buffer
/// instead of executing.
library;

export 'src/codegen/captured.dart';
