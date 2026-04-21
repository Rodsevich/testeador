# Testeador

A package for grouping and executing Dart tests in sequence, designed for environments that may not have Dart installed when compiled as a standalone binary.

## Features

- **TestFlow**: Sequentially chain a series of integration tests (TestSteps).
- **TestStep**: Execute an integration test (e.g., frontend against a backend, often across different repositories).
- **Fixture**: Pre-load models, database connections, or any necessary data.
- **Tags**: Filter and run specific test groups.
- **Sequential Execution**: Ensures tests run in the order they are defined.

## Usage

```dart
import 'package:testeador/testeador.dart';

void main() async {
  final flow = TestFlowTransient(
    name: 'Simple Flow',
    steps: [
      TestStep(
        name: 'Step 1',
        action: () => print('Hello'),
      ),
    ],
    rollbackStrategy: RollbackStrategyCustom(
      revertAction: () async {
        print('Reverting changes...');
      },
    ),
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

- `TestFlow`: Sequentially chains a series of `TestStep`s to form an integration flow. Divided into two types:
  - `TestFlowTransient`: Must not alter the database state permanently. Steps should revert changes on success, and on failure, rollback mechanisms are triggered via a `RollbackStrategy`.
  - `TestFlowLasting`: Database changes are expected to remain without issues.
- `TestStep`: Executes an integration test of a frontend package against a backend, typically orchestrating logic across repositories.
- `Fixture`: An abstract class to handle setup and teardown of resources.

## For AI Agents

When interacting with this codebase, remember the following principles:

1. **Purpose**: `testeador` is built to run integration/e2e flows *sequentially* and compile into standalone binaries for CI/CD systems without Dart SDKs.
2. **Architecture**: Never write concurrent tests. Rely on `TestRunner` to execute `TestFlow`s sequentially. Use `Fixture` to load external resources (like DBs or AI models) and clean them up automatically during teardown.
3. **Reference**: See [`AGENTS.md`](./AGENTS.md) for deeper architectural guidelines and coding tasks context.
