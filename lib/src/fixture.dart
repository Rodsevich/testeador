/// {@template fixture}
/// A base class for fixtures that pre-load models or data for tests.
/// {@endtemplate}
abstract class Fixture<T> {
  /// {@macro fixture}
  const Fixture();

  /// Pre-loads the model or data.
  Future<T> load();

  /// Disposes of any resources used by the fixture.
  Future<void> dispose(T data) async {}
}
