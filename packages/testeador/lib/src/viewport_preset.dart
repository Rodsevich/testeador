import 'dart:ui';

/// {@template viewport_preset}
/// Fixed viewport dimensions applied to the test view before pumping.
///
/// The logical size times [devicePixelRatio] gives the physical size set on
/// `tester.view.physicalSize`. This is independent from the capture
/// rasterization factor (`EvidenceConfig.capturePixelRatio`).
/// {@endtemplate}
enum ViewportPreset {
  /// Vertical phone: logical 410×890 at DPR 2 (physical 820×1780).
  phone(logicalSize: Size(410, 890), devicePixelRatio: 2),

  /// Vertical tablet: logical 800×1280 at DPR 2 (physical 1600×2560).
  tablet(logicalSize: Size(800, 1280), devicePixelRatio: 2);

  /// {@macro viewport_preset}
  const ViewportPreset({
    required this.logicalSize,
    required this.devicePixelRatio,
  });

  /// Logical (density-independent) viewport size.
  final Size logicalSize;

  /// Device pixel ratio applied to the test view.
  final double devicePixelRatio;

  /// Physical pixel size set on the test view
  /// ([logicalSize] × [devicePixelRatio]).
  Size get physicalSize => logicalSize * devicePixelRatio;
}
