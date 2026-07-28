import 'package:patrol_finders/patrol_finders.dart';

/// A named, async UI test step with a declared visual intent.
///
/// Mirrors `TestStep` but for `UiTestFlow`:
///
/// - `description` names the step; its slug keys the capture and baseline
///   file names (`<actor>-<slug>.png`).
/// - `intent` declares **what should be visible** when the step completes.
///   It is required: it is the primary input of the post-run AI judge, and
///   the precise target of a "fix the test" verdict.
/// - `body` performs the interactions, receiving the fixture context and a
///   [PatrolTester] (`$`) for finding/tapping/scrolling — use
///   `$(...).scrollTo()` for lazily-built list items, never `ensureVisible`.
///
/// A photo of the UI is captured automatically **after** the body completes;
/// steps never call the camera themselves.
///
/// ## Example
///
/// ```dart
/// (
///   description: 'cupon_aplicado',
///   intent: 'tras aplicar SUPER10 se ve el descuento y el total recalculado',
///   body: (ctx, $) async {
///     await $(#campoCupon).scrollTo().enterText('SUPER10');
///     await $('Aplicar').tap();
///   },
/// )
/// ```
typedef UiTestStep<T> = ({
  /// Step name; its slug keys capture and baseline file names.
  String description,

  /// What should be visible when this step completes — consumed by the AI
  /// judge and targeted by "fix the test" verdicts.
  String intent,

  /// Interactions of this step. The photo is taken after it completes.
  Future<void> Function(T context, PatrolTester $) body,
});
