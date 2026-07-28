/// {@template fixture}
/// Manages resources needed before a `TestFlow` runs.
///
/// A fixture prepares the **world** — database records, configuration,
/// feature flags — and produces the typed context [T] the flow's steps
/// receive. It says nothing about *who* acts on that world: that is the
/// `Actor`'s job, so one fixture combines with M actors and N flows.
///
/// [load] is called once before the flow's steps execute.
/// [dispose] is called once after all steps complete, even on failure.
/// {@endtemplate}
abstract class Fixture<T> {
  /// {@macro fixture}
  const Fixture();

  /// One-time preparation before [load]: migrations, starting services,
  /// reading corpora off the bundle. Default implementation is a no-op.
  Future<void> setUp() async {}

  /// Loads the fixture in backend. [T] needed by the flow's steps.
  Future<T> load();

  /// Releases any resources acquired during [load].
  ///
  /// Called even if steps fail. Default implementation is a no-op.
  Future<void> dispose(T data) async {}

  /// One-time teardown after [dispose]. Default implementation is a no-op.
  Future<void> tearDown() async {}

  /// Wraps each transient flow in a transaction so the world is restored
  /// afterwards. `null` (the default) means the world is not transactional
  /// and lasting flows keep whatever they wrote.
  Future<void> Function(Future<void> Function() body)? get transactionScope =>
      null;
}
