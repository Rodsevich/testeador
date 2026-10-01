# testeador — UI test flows for Flutter

`testeador` is the Flutter layer of the [testeador monorepo](../../README.md). It
lets you write user-journey tests where every step is photographed and its
intent is declared, so a reviewer — human or AI — can see what the app was
supposed to do and whether it did it.

```
feature request
      ↓
UiTestFlow (steps + intents)
      ↓
flutter test  ──▶  test_evidence/runs/current/<scenario>/
      ↓
mirador review  ──▶  http://localhost:<port>  (paint verdicts)
      ↓
verdict: fix_code | replace_baseline | explain
```

## Quick start (5 minutes)

Add the dev dependency:

```yaml
dev_dependencies:
  testeador: ^0.5.0
```

Write a flow in `test/my_flow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:testeador/testeador.dart';

void main() => TestSuite.entry(
  fixture: MyFixture(),
  actors: [MyActor('alice')],
  flows: [myFlow()],
);

UiTestFlow<MyWorld> myFlow() => UiTestFlow(
  name: 'my feature',
  steps: [
    (
      description: 'Alice opens the screen',
      intent: 'The screen header reads "My Feature" and the list is empty.',
      body: (world, $) async {
        await $.pumpWidget(MyApp(world: world));
        await $.pump();
      },
    ),
  ],
);
```

Run the flow and review the photos:

```bash
flutter test                                     # photos → test_evidence/runs/current/
dart run testeador_base:mirador review --port 4799   # open http://127.0.0.1:4799
```

Accept the baseline once the photos look right:

```bash
dart run testeador_base:mirador promote \
  --scenario my_feature \
  --actor alice \
  --slugs alice_opens_the_screen
```

## Concepts

| Term | What it is |
|---|---|
| `UiTestFlow` | A named sequence of `UiTestStep`s run once per actor |
| `UiTestStep` | `{ description, intent, body }` — body never calls the camera |
| `intent` | What the photo must prove; falsifiable by a reviewer |
| `knownDefects` | Documented `FlutterError`s the flow tolerates |
| baseline | The committed reference photos under `test_evidence/baseline/` |
| drift | A `!` mark when a photo differs from the baseline |

## Go deeper

- [Reference example](example/README.md) — full two-actor flow against a real API
- [Authoring guide](../../.claude/skills/testeador/references/authoring.md) — eloquent flows
- [Mirador guide](../../.claude/skills/testeador/references/mirador.md) — supervision loop
- [Architecture](../testeador_base/docs/architecture.md) — full technical spec
- [testeador_base](../testeador_base/README.md) — pure-Dart contract flows and the CLI
