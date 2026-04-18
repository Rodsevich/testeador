# Testeador

A package for grouping and executing Dart tests in sequence, designed for environments that may not have Dart installed when compiled as a standalone binary.

## Features

- **TestFlow**: Group tests into logical flows.
- **TestStep**: Define individual steps within a flow.
- **Fixture**: Pre-load models, database connections, or any necessary data.
- **Tags**: Filter and run specific test groups.
- **Sequential Execution**: Ensures tests run in the order they are defined.

## Usage

```dart
import 'package:testeador/testeador.dart';

void main() async {
  final flow = TestFlow(
    name: 'Simple Flow',
    steps: [
      TestStep(
        name: 'Step 1',
        action: () => print('Hello'),
      ),
    ],
  );

  final runner = TestRunner(flows: [flow]);
  await runner.run();
}
```

## Running in environments without Dart

You can compile your test suite into a standalone executable using `dart compile exe`. This allows you to run your tests in CI/CD pipelines (like GitHub Actions or GitLab CI) without needing to install the Dart SDK.

1. Create a Dart file (e.g., `test_suite.dart`) with your `TestFlow`s and `TestRunner`.
2. Compile it:
   ```bash
   dart compile exe example/main.dart -o test_suite
   ```
3. Run the resulting binary:
   ```bash
   ./test_suite
   ```

## Core Classes

- `TestFlow`: The main container for a sequence of tests.
- `TestStep`: A single unit of work within a flow.
- `Fixture`: An abstract class to handle setup and teardown of resources.
