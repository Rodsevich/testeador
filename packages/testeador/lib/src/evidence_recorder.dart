import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:testeador_base/evidence.dart';
import 'package:testeador/src/viewport_preset.dart';

/// {@template evidence_capture_exception}
/// A failure of the evidence *harness* itself (capture, encoding or disk
/// I/O) — deliberately distinct from a failure of the app under test, so a
/// full disk never masquerades as a UI regression.
/// {@endtemplate}
final class EvidenceCaptureException implements Exception {
  /// {@macro evidence_capture_exception}
  EvidenceCaptureException(this.message, [this.cause]);

  /// Human-readable description of what the harness failed to do.
  final String message;

  /// The underlying error, when one exists.
  final Object? cause;

  @override
  String toString() =>
      'EvidenceCaptureException: $message${cause == null ? '' : ' ($cause)'}';
}

/// {@template evidence_recorder}
/// Low-level evidence capture primitive: mounts a widget under a
/// [RepaintBoundary] with a fixed viewport ([pump]) and rasterizes it to a
/// PNG artifact scored against a versioned baseline ([photo]).
///
/// This is what `UiTestFlow` uses internally; it is exported for use outside
/// the declarative model (ad-hoc widget tests, custom harnesses).
///
/// ## Capture lifecycle
///
/// 1. `photo()` pumps two fixed-duration frames (never `pumpAndSettle` — it
///    hangs on indeterminate animations).
/// 2. The [RepaintBoundary] subtree is rasterized inside `tester.runAsync`
///    (`toImage` is *real* async; without `runAsync` it deadlocks).
/// 3. The capture is scored against
///    `<baseDir>/baseline/<scenario>/<actor>-<slug>.png`; the artifact is
///    written to `<baseDir>/runs/current/<scenario>/` with `!` drift marks
///    (log scale), `~new` when no baseline exists, plus a
///    `baseline | actual | diff` triptych when drift is detected.
/// 4. The run manifest is rewritten atomically after every step.
///
/// Running with `flutter test --update-goldens` writes the capture as the
/// new baseline before scoring (the run then reports zero drift).
///
/// **The run never fails because of visual drift.** Only an app exception or
/// an [EvidenceCaptureException] (harness I/O failure) can fail the test.
/// {@endtemplate}
final class EvidenceRecorder {
  /// {@macro evidence_recorder}
  /// The [actor] is slugified on entry (`[a-z0-9_]` only): the `-` separator
  /// and the `!`/`~` markers can never appear inside it, which is what makes
  /// per-actor artifact scoping (cleanup, orphan reconciliation) collision-
  /// free between actors like `comprador` and `comprador vip`.
  EvidenceRecorder({
    required this.scenario,
    required String actor,
    this.config = defaultEvidenceConfig,
    this.viewport = ViewportPreset.phone,
    EvidenceFileSystem fileSystem = const EvidenceFileSystem(),
  }) : actor = slugify(actor),
       _fs = fileSystem,
       _baseDir = p.isAbsolute(config.baseDir)
           ? config.baseDir
           : p.join(Directory.current.path, config.baseDir) {
    _runDir = scenarioRunDir(baseDir: _baseDir, scenario: scenario);
    _baselineDir = scenarioBaselineDir(baseDir: _baseDir, scenario: scenario);
    manifest = RunManifest(
      scenario: scenario,
      actor: actor,
      scenarioDir: _runDir,
      viewportPreset: viewport.name,
      logicalSize: [viewport.logicalSize.width, viewport.logicalSize.height],
      devicePixelRatio: viewport.devicePixelRatio,
      capturePixelRatio: config.capturePixelRatio,
      fileSystem: fileSystem,
    );
  }

  /// Scenario name; also the artifact folder name.
  final String scenario;

  /// Actor slug; prefixes every artifact of this run.
  final String actor;

  /// Capture configuration (baseDir, pixel ratio, noise floor, marks).
  final EvidenceConfig config;

  /// Viewport preset applied by [pump].
  final ViewportPreset viewport;

  /// The manifest of this run — structural source of truth of the artifacts.
  late final RunManifest manifest;

  final EvidenceFileSystem _fs;
  final String _baseDir;
  late final String _runDir;
  late final String _baselineDir;
  final GlobalKey _boundaryKey = GlobalKey();
  final Set<String> _usedSlugs = {};
  final Map<String, Map<String, List<String>>> _pendingAttachments = {};
  final Map<String, List<String>> _pendingMissing = {};
  int _order = 0;

  /// Directory holding this run's artifacts.
  String get runDir => _runDir;

  /// Directory holding this scenario's versioned baselines.
  String get baselineDir => _baselineDir;

  /// Mounts [child] inside a [RepaintBoundary] with the configured viewport
  /// and pumps two fixed-duration frames.
  ///
  /// With [wrapInMaterialApp] (the default) the child is hosted in a
  /// `MaterialApp(home: ...)` — pass `false` when [child] is already a full
  /// app (the boundary still wraps it from the outside, so overlays and
  /// dialogs are captured).
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    bool wrapInMaterialApp = true,
  }) async {
    tester.view
      ..physicalSize = viewport.physicalSize
      ..devicePixelRatio = viewport.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final content = wrapInMaterialApp
        ? MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: child,
          )
        : child;
    await tester.pumpWidget(
      RepaintBoundary(key: _boundaryKey, child: content),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
  }

  /// Captures the mounted subtree as a PNG evidence artifact named [name]
  /// and records it in the manifest with the given [intent].
  ///
  /// Returns the [DiffResult] against the baseline, or `null` when no
  /// baseline exists yet (the artifact is marked `~new` — a new capture is
  /// **never** silently promoted to baseline; that requires an explicit
  /// verdict or `--update-goldens`).
  ///
  /// Throws an [ArgumentError] if [name] collides with a previous capture of
  /// this run, and an [EvidenceCaptureException] on harness I/O failure.
  Future<DiffResult?> photo(
    WidgetTester tester, {
    required String name,
    String? intent,
  }) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final slug = _claimSlug(name);
    final order = ++_order;

    final actual = await _capture(tester);
    final baselinePath = p.join(
      _baselineDir,
      baselineFileName(actor: actor, slug: slug),
    );
    if (autoUpdateGoldenFiles) {
      _guardIo(
        'update baseline for "$slug"',
        () => _fs.writeBytes(baselinePath, img.encodePng(actual)),
      );
    }
    final baselineBytes = _guardIo(
      'read baseline for "$slug"',
      () => _fs.readBytesOrNull(baselinePath),
    );

    DiffResult? diff;
    String marker;
    String? diffImageName;
    if (baselineBytes == null) {
      marker = newMarker;
    } else {
      final baseline = img.decodePng(baselineBytes);
      if (baseline == null) {
        throw EvidenceCaptureException(
          'baseline for "$slug" is not a valid PNG: $baselinePath',
        );
      }
      diff = diffScore(
        actual: actual,
        baseline: baseline,
        noiseFloor: config.noiseFloor,
        maxMarks: config.maxMarks,
        channelTolerance: config.channelTolerance,
      );
      marker = marksSuffix(diff.marks);
      if (diff.marks > 0 && !diff.dimensionMismatch) {
        diffImageName = diffFileName(
          actor: actor,
          order: order,
          slug: slug,
          marker: marker,
        );
        final triptych = composeDiffImage(
          baseline: baseline,
          actual: actual,
          channelTolerance: config.channelTolerance,
        );
        final diffPath = p.join(_runDir, diffImageName);
        _guardIo(
          'write diff triptych for "$slug"',
          () => _fs.writeBytes(diffPath, img.encodePng(triptych)),
        );
      }
    }

    final captureName = captureFileName(
      actor: actor,
      order: order,
      slug: slug,
      marker: marker,
    );
    _guardIo(
      'write capture for "$slug"',
      () => _fs.writeBytes(
        p.join(_runDir, captureName),
        img.encodePng(actual),
      ),
    );

    _guardIo(
      'record step "$slug" in the manifest',
      () => manifest.recordStep(
        order: order,
        slug: slug,
        description: name,
        status: 'ok',
        intent: intent,
        capture: captureName,
        baseline: baselineBytes == null
            ? null
            : manifestRelative(from: _runDir, target: baselinePath),
        diff: diff == null
            ? null
            : (
                ratio: diff.ratio,
                marks: diff.marks,
                dimensionMismatch: diff.dimensionMismatch,
                image: diffImageName,
              ),
        attachments: _pendingAttachments.remove(slug) ?? const {},
        missingAttachments: _pendingMissing.remove(slug) ?? const [],
      ),
    );
    return diff;
  }

  /// Captures the state of the UI at the moment a step threw, marked
  /// `~crash`, and records the step as `failed` with the [exception].
  ///
  /// Best-effort: if the crashed tree cannot be rasterized, the step is
  /// still recorded (without a capture) so the manifest stays complete.
  Future<void> photoCrash(
    WidgetTester tester, {
    required String name,
    required Object exception,
    String? intent,
  }) async {
    final slug = _claimSlug(name);
    final order = ++_order;
    String? captureName;
    try {
      final actual = await _capture(tester);
      captureName = captureFileName(
        actor: actor,
        order: order,
        slug: slug,
        marker: crashMarker,
      );
      _fs.writeBytes(p.join(_runDir, captureName), img.encodePng(actual));
    } on Object {
      captureName = null; // Crash state could not be rasterized.
    }
    manifest.recordStep(
      order: order,
      slug: slug,
      description: name,
      status: 'failed',
      intent: intent,
      capture: captureName,
      // Los accesorios del paso que FALLÓ son los que más importan: son lo que
      // le permite al juez explicar el crash (input #4 del contrato). Sin esto
      // se escribían en disco y quedaban huérfanos del manifest.
      attachments: _pendingAttachments.remove(slug) ?? const {},
      missingAttachments: _pendingMissing.remove(slug) ?? const [],
      exception: exception.toString(),
    );
  }

  /// Records a step that never ran because an earlier step failed.
  void markSkipped({required String name, String? intent}) {
    final slug = _claimSlug(name);
    manifest.recordStep(
      order: ++_order,
      slug: slug,
      description: name,
      status: 'skipped',
      intent: intent,
    );
  }

  /// Registers an accessory [file] (an HTTP capture as curl, a log) for the
  /// step named [step], under an attachment [type] (e.g. `http`, `logs`).
  ///
  /// Call **before** the step is photographed — the attachment is recorded
  /// in the manifest entry of that step, as a path relative to the run
  /// directory. A file that does not exist (yet) is listed under
  /// `attachments.missing` instead of silently dropped, so the AI judge
  /// knows promised evidence never arrived.
  ///
  /// Relative [file] paths are resolved against [runDir] (the conventional
  /// location for accessory producers like the HTTP capture spike is
  /// `<runDir>/http/`).
  void attach({
    required String step,
    required String type,
    required String file,
  }) {
    final slug = slugify(step);
    final absolute = p.isAbsolute(file) ? file : p.join(_runDir, file);
    final relative = manifestRelative(from: _runDir, target: absolute);
    if (_fs.exists(absolute)) {
      _pendingAttachments
          .putIfAbsent(slug, () => {})
          .putIfAbsent(type, () => [])
          .add(relative);
    } else {
      _pendingMissing.putIfAbsent(slug, () => []).add(relative);
    }
  }

  /// Closes the run's bookkeeping: lists this actor's baselines that no
  /// recorded step references (`orphanedBaselines` — typically leftovers of
  /// a renamed or deleted step) and surfaces attachments registered for a
  /// step that was never photographed (`unclaimedAttachments` — typically a
  /// typo in [attach]'s `step`), so promised evidence never disappears
  /// silently.
  void reconcileOrphans() {
    final unclaimed = <String, List<String>>{};
    _pendingAttachments.forEach((slug, byType) {
      unclaimed
          .putIfAbsent(slug, () => [])
          .addAll(byType.values.expand((files) => files));
    });
    _pendingMissing.forEach((slug, files) {
      unclaimed.putIfAbsent(slug, () => []).addAll(files);
    });
    manifest.reconcileOrphans(_baselineDir, unclaimedAttachments: unclaimed);
  }

  Future<img.Image> _capture(WidgetTester tester) async {
    final context = _boundaryKey.currentContext;
    if (context == null) {
      throw EvidenceCaptureException(
        'no RepaintBoundary mounted — call pump() before photo()',
      );
    }
    img.Image? actual;
    Object? failure;
    await tester.runAsync(() async {
      ui.Image? image;
      try {
        final boundary = context.findRenderObject()! as RenderRepaintBoundary;
        image = await boundary.toImage(pixelRatio: config.capturePixelRatio);
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        // A null byteData (engine failure) becomes a TypeError here, which
        // the catch below wraps as a harness EvidenceCaptureException.
        actual = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: byteData!.buffer,
          order: img.ChannelOrder.rgba,
        );
      } on Object catch (error) {
        failure = error;
      } finally {
        image?.dispose();
      }
    });
    if (failure case final EvidenceCaptureException harnessFailure) {
      throw harnessFailure;
    }
    if (failure != null) {
      throw EvidenceCaptureException('failed to rasterize capture', failure);
    }
    return actual!;
  }

  String _claimSlug(String name) {
    final slug = slugify(name);
    if (!_usedSlugs.add(slug)) {
      throw ArgumentError(
        'A capture named "$slug" already exists in this run — every step of '
        'a flow needs a unique name.',
      );
    }
    return slug;
  }

  T _guardIo<T>(String action, T Function() operation) {
    try {
      return operation();
    } on Object catch (error) {
      throw EvidenceCaptureException('failed to $action', error);
    }
  }
}
