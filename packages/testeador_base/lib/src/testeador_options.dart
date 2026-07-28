/// Configuration options for a `Testeador` run.
class TesteadorOptions {
  /// Creates a [TesteadorOptions] with the given settings.
  const TesteadorOptions({
    this.includeTags = const {},
    this.excludeTags = const {},
    this.includeFlows = const {},
    this.excludeFlows = const {},
    this.failFast = true,
    this.verbose = false,
    this.exitOnFailure = true,
    this.showCurls = true,
    this.showStackTraces = false,
  });

  /// Only run flows whose tags intersect with this set. Empty = no filter.
  final Set<String> includeTags;

  /// Skip flows whose tags intersect with this set.
  final Set<String> excludeTags;

  /// Only run flows whose name is in this set. Empty = no filter.
  final Set<String> includeFlows;

  /// Skip flows whose name is in this set.
  final Set<String> excludeFlows;

  /// Stop execution after the first flow failure.
  final bool failFast;

  /// Print each step name as it executes.
  final bool verbose;

  /// Call [exit(1)] when any flow fails (for CI/CD pipelines).
  final bool exitOnFailure;

  /// Print the cURL log for the actors involved in a failed flow.
  final bool showCurls;

  /// Print the Dart stack trace when a step throws.
  final bool showStackTraces;
}
