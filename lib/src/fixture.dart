/// {@template fixture}
/// Manages resources needed before a `TestFlow` runs.
///
/// [load] is called once before the flow's steps execute.
/// [dispose] is called once after all steps complete, even on failure.
/// {@endtemplate}
abstract class Fixture<T> {
  /// {@macro fixture}
  const Fixture();

  /// Loads the fixture in backend. [T] needed by the flow's steps.
  Future<T> load();

  /// Releases any resources acquired during [load].
  ///
  /// Called even if steps fail. Default implementation is a no-op.
  Future<void> dispose(T data) async {}
}
