/// Runtime surface used by the code emitted by testeador's `build_runner`
/// builders (`lib/test_injector.g.dart` in consumer packages).
///
/// User code typically does NOT import this directly — it consumes
/// `TestInjector` from the generated file. The exports here are public only
/// so the generated file can resolve them without reaching into
/// `package:testeador/src/...`.
library;

export 'src/codegen/captured.dart' show CaptureState, runCapture;
export 'src/codegen/registry.dart' show CapturedTest, Registry;
