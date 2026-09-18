/// Testeador — e2e testing for Flutter with **UI flows as the unit of work**.
///
/// You declare a `Fixture` (the world), one or more [UiActor]s (who lives in
/// it) and [UiTestFlow]s (what they do, each step carrying a required
/// `intent`). Every step is photographed, scored against a versioned baseline
/// and recorded in a manifest an AI judge can read.
///
/// Re-exports `testeador_base`, so a Flutter test only ever imports this.
library;

// `PatrolTester` aparece en la firma de `UiTestStep.body`: quien escribe un
// paso necesita el tipo, así que viaja con el barrel.
export 'package:patrol_finders/patrol_finders.dart';
export 'package:testeador_base/evidence.dart';
export 'package:testeador_base/testeador_base.dart';

export 'src/dev_mate/reporter_domain.dart';
export 'src/evidence_recorder.dart';
export 'src/evidence_setup.dart';
export 'src/fixture_entry.dart';
export 'src/registrable_flow.dart';
export 'src/test_suite.dart';
export 'src/ui_actor.dart';
export 'src/ui_test_flow.dart';
export 'src/ui_test_step.dart';
export 'src/viewport_preset.dart';
