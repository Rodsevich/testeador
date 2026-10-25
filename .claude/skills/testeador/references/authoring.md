# Authoring reference — UiTestFlow

## UiTestStep anatomy

Each step is a Dart record `({description, intent, body})`.

### `description`

A slug that names the baseline file: `<actor>-<description>.png`.

- Good: `checkout_submitted`, `empty_team_screen`, `pikachu_result_card`
- Bad: `step3`, `test`, `screen1`

The slug doubles as the human-readable label in mirador, so make it a readable action or state.

### `intent`

The falsifiable visual contract. Write it before the implementation. It is the primary input to the AI judge.

- Good: `"The confirmation screen shows order #1234, total $49.99, and a 'Track order' button. No error banner is visible."`
- Bad: `"The screen looks correct."`, `"Checkout is done."`

Be specific: name widgets, copy, counts, absence of elements. If the intent can't be falsified from a screenshot, rewrite it.

### `body`

Interactions only. The camera fires automatically after body completes — **do not call the camera manually**. Light assertions are allowed when you need to coordinate state between steps (e.g. capture a found name for the next step).

```dart
body: (world, $) async {
  await $(#nameField).enterText('pikachu');
  await $('Search').tap();
  await waitFor($, find.text('pikachu #25'));
  world.foundName = 'pikachu'; // state for later steps, not an assertion
},
```

## PatrolTester patterns

```dart
$(#semanticLabel)      // by semantic key (preferred for stable tests)
$('Button text')       // by text
$(MyWidget)            // by type
await $.scrollTo(finder) // lazy list items — NOT ensureVisible
await $(...).tap()
await $(...).enterText('value')
```

### Waiting for real HTTP

Use `waitFor` from the testeador package for async results:

```dart
Future<void> waitFor(PatrolTester $, Finder finder, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('waitFor timed out');
    await $.pump(const Duration(milliseconds: 100));
  }
}
```

## Fixture + UiActor

**Fixture** — loads world state, no mocks:

```dart
final class PokeFixture extends Fixture<PokeWorld> {
  @override
  Future<PokeWorld> load() async {
    const baseUrl = 'https://pokeapi.co/api/v2';
    await Dio().get<void>('$baseUrl/pokemon/pikachu'); // health check — fails fast on infra problems
    return const PokeWorld(baseUrl);
  }
}
```

The health check in `load()` catches infrastructure problems before any test runs, not mid-flow.

**UiActor** — one Dio per actor, `idleTimeout = Duration.zero` to avoid pending-timer failures:

```dart
final class Trainer extends UiActor<PokeWorld> {
  Trainer(String name, {required this.themeMode})
    : super(
        name: name,
        dio: Dio()..httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => HttpClient()..idleTimeout = Duration.zero,
        ),
      );
  final ThemeMode themeMode;

  @override
  Future<Widget Function()> session(PokeWorld world) async =>
      () => TeamApp(api: PokeApi(dio, baseUrl: world.baseUrl), themeMode: themeMode);
}
```

`session()` returns a widget factory for the actor's app instance. Each actor gets its own isolated widget tree.

## TestSuite.entry

Full wiring — one `testWidgets` is produced per actor × flow combination:

```dart
void main() {
  TestSuite.entry<PokeWorld>(
    fixture: PokeFixture(),
    actors: [
      Trainer('trainer_light', themeMode: ThemeMode.light),
      Trainer('trainer_dark', themeMode: ThemeMode.dark),
    ],
    flows: [buildMyTeamFlow],
  );
}
```

## knownDefects

Document real issues so the AI judge doesn't flag them as regressions. A known defect is a substring match against error text or step output, paired with a reason.

```dart
knownDefects: {
  'RenderFlex overflowed': 'The abilities row does not wrap on phone width. Visible in the photo.',
},
```

Rules:
- Use a specific substring, never a wildcard or empty string.
- Write a reason that explains why it is tolerated and what the photo shows.
- Never delete a step to suppress the error — declare it here.

## viewport

Default is `ViewportPreset.phone`. Override per flow:

```dart
UiTestFlow<MyWorld>(
  name: 'tablet_checkout',
  viewport: ViewportPreset.tablet,
  steps: [...],
)
```

## setUpAll

Required in every test file that uses testeador:

```dart
setUpAll(() async {
  await setUpEvidence();                          // initializes capture infrastructure
  await (FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  HttpOverrides.global = null;                    // allows real HTTP in tests
});
```

`FontLoader` for MaterialIcons is mandatory — without it, icons render as empty squares and diff every run.

`HttpOverrides.global = null` is mandatory — without it, all HTTP returns 400 in the test environment.

## Common mistakes

| Mistake | Fix |
|---|---|
| Intent written after seeing the result | Write intent before implementation; it should describe what _should_ be visible, not what is |
| Body manually takes a photo | Remove it — the camera fires automatically after body |
| `ensureVisible` on a lazy list | Use `$.scrollTo(finder)` instead |
| Missing `HttpOverrides.global = null` | Add to `setUpAll`; all real HTTP silently returns 400 without it |
| Missing `FontLoader` | Add to `setUpAll`; icons render as squares and generate noise diffs |
| Single actor for a multi-theme app | Add one `UiActor` per meaningful visual variant |
