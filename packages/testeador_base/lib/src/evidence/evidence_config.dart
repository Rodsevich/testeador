/// {@template evidence_config}
/// Configuration for evidence capture, as a plain record.
///
/// - `baseDir` — root directory for evidence artifacts. Relative paths are
///   resolved against `Directory.current` (the package root when running
///   `flutter test`). Baselines live under `<baseDir>/baseline/` (versioned
///   in git) and run artifacts under `<baseDir>/runs/current/` (gitignored).
/// - `capturePixelRatio` — rasterization factor passed to
///   `RenderRepaintBoundary.toImage`. Independent from the viewport's
///   `devicePixelRatio`.
/// - `noiseFloor` — diff ratio below which a capture is considered identical
///   to its baseline (absorbs anti-aliasing noise). Expressed as a fraction
///   (`0.0001` == 0.01% of pixels).
/// - `maxMarks` — upper bound for the `!` drift markers appended to run
///   artifact file names.
/// - `channelTolerance` — per-channel delta (0–255) under which two pixels
///   are considered equal.
/// {@endtemplate}
typedef EvidenceConfig = ({
  String baseDir,
  double capturePixelRatio,
  double noiseFloor,
  int maxMarks,
  int channelTolerance,
});

/// Default [EvidenceConfig] used when none is provided.
///
/// `baseDir: 'test_evidence'`, `capturePixelRatio: 2.5`,
/// `noiseFloor: 0.0001` (0.01%), `maxMarks: 5`, `channelTolerance: 8`.
const EvidenceConfig defaultEvidenceConfig = (
  baseDir: 'test_evidence',
  capturePixelRatio: 2.5,
  noiseFloor: 0.0001,
  maxMarks: 5,
  channelTolerance: 8,
);
