/// Pure naming helpers for evidence artifacts.
///
/// The run manifest is the single structural source of truth — these file
/// names exist for humans browsing the artifact tree, and are never parsed
/// back by the library.
library;

/// Marker suffix for a capture that has no baseline yet (first run).
const String newMarker = '~new';

/// Marker suffix for a capture taken at the moment a step threw.
const String crashMarker = '~crash';

/// Marker suffix for a capture produced on a real device (patrol e2e), which
/// is never pixel-compared against a baseline.
const String deviceMarker = '~device';

final RegExp _invalidRun = RegExp('[^a-z0-9_]+');

/// Converts [input] into a file-system-safe slug.
///
/// Lowercases, then replaces every run of characters outside `[a-z0-9_]`
/// with a single `_`, trimming leading/trailing `_`. The protocol characters
/// `!` and `~` can therefore never appear in a slug — they are reserved for
/// drift markers.
///
/// Throws an [ArgumentError] if the result is empty (e.g. an input composed
/// only of invalid characters).
String slugify(String input) {
  final slug = input
      .toLowerCase()
      .replaceAll(_invalidRun, '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.isEmpty) {
    throw ArgumentError.value(
      input,
      'input',
      'slugifies to an empty string — use at least one alphanumeric '
          'character',
    );
  }
  return slug;
}

/// Returns the `!` drift marker suffix for [marks] (empty when zero).
String marksSuffix(int marks) => '!' * marks;

/// File name of the versioned baseline for a step.
///
/// Baselines are keyed by `<actor>-<slug>` only — no step-order number and
/// no drift markers — so inserting a step does not invalidate the baselines
/// of the steps that follow it.
String baselineFileName({required String actor, required String slug}) =>
    '$actor-$slug.png';

/// File name of a run capture artifact.
///
/// Carries the 1-based [order] (zero-padded, human reading order) and the
/// drift [marker] (`!`-marks, [newMarker], [crashMarker] or [deviceMarker]).
String captureFileName({
  required String actor,
  required int order,
  required String slug,
  required String marker,
}) => '$actor-${order.toString().padLeft(2, '0')}_$slug$marker.png';

/// File name of the composite `baseline | actual | diff` triptych image
/// generated alongside [captureFileName] when a capture drifts.
String diffFileName({
  required String actor,
  required int order,
  required String slug,
  required String marker,
}) => '$actor-${order.toString().padLeft(2, '0')}_$slug$marker.diff.png';

/// Validates that no two of [descriptions] slugify to the same value.
///
/// Called at flow registration time so a collision is a loud, immediate
/// [ArgumentError] instead of a silently overwritten capture.
void ensureUniqueSlugs(Iterable<String> descriptions) {
  final seen = <String, String>{};
  for (final description in descriptions) {
    final slug = slugify(description);
    final previous = seen[slug];
    if (previous != null) {
      throw ArgumentError(
        'Step descriptions "$previous" and "$description" both slugify to '
        '"$slug". Rename one of them so every step has a unique slug.',
      );
    }
    seen[slug] = description;
  }
}
