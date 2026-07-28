import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the deterministic Roboto fonts bundled with `testeador` so captures
/// render with real typography instead of the boxy test-default font —
/// **without any network access** (hermetic, CI-safe).
///
/// Call once from `setUpAll`:
///
/// ```dart
/// setUpAll(setUpEvidence);
/// ```
///
/// Initializes the test binding if needed. Consumers using `google_fonts`
/// should additionally set `GoogleFonts.config.allowRuntimeFetching = false`
/// in their own setup (documented in the README) — `testeador` deliberately
/// does not depend on `google_fonts`.
Future<void> setUpEvidence() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Roboto');
  var loadedAny = false;
  for (final asset in const [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final data = await _loadFirst([
      // Key when testeador is the package under test.
      'assets/fonts/$asset',
      // Key when testeador is a dependency of the app under test.
      'packages/testeador/assets/fonts/$asset',
    ]);
    if (data != null) {
      loader.addFont(Future.value(data));
      loadedAny = true;
    }
  }
  if (loadedAny) await loader.load();
}

Future<ByteData?> _loadFirst(List<String> keys) async {
  for (final key in keys) {
    try {
      return await rootBundle.load(key);
    } on Object {
      // The key that doesn't match the current bundle layout is expected to
      // fail — try the next one.
    }
  }
  return null;
}
