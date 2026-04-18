# Agent Memory Bank - Testeador

This file provides context and instructions for AI agents working on the `testeador` repository.

## Repository Purpose
`testeador` is a Dart package designed to group and execute tests in sequence. It is specifically optimized for being compiled into standalone binaries for use in CI/CD environments where Dart might not be pre-installed.

## Core Architecture

### 1. TestFlow (`lib/src/test_flow.dart`)
- Groups multiple `TestStep`s.
- Supports `tags` for filtering.
- Can have multiple `Fixture`s.
- Execution is always sequential.

### 2. TestStep (`lib/src/test_step.dart`)
- Represents a single action/assertion in a test.
- Contains a `name` and an `action` function.

### 3. Fixture (`lib/src/fixture.dart`)
- Abstract class for managing resources (e.g., pre-loading AI models, DB connections).
- `load()`: Called before the flow starts.
- `dispose()`: Called after the flow ends (even on failure).

### 4. TestRunner (`lib/src/runner.dart`)
- Orchestrates the execution of `TestFlow`s.
- Handles tag filtering and sequential execution.
- Manages fixture lifecycle.

## Common Tasks

### Creating a New Test Suite
1. Define any required `Fixture`s by extending the `Fixture` class.
2. Define a list of `TestFlow`s.
3. Instantiate `TestRunner` with the flows.
4. Call `runner.run()` in the `main` function.

### Compiling for CI/CD
To create a standalone binary:
```bash
dart compile exe path/to/your_test_suite.dart -o test_runner_bin
```

## Guidelines
- Always prioritize sequential execution as this package is intended for integration/flow testing.
- Ensure all fixtures are properly disposed of in the `TestRunner`.
- When adding new features, update the `example/main.dart` to reflect usage.
