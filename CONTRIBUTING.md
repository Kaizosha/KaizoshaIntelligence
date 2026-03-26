# Contributing

## Workflow

1. Create a branch from `main`.
2. Make focused changes with tests.
3. Run `swift build` and `swift test`.
4. If public APIs changed, regenerate documentation locally and update DocC articles as needed.
5. Update `CHANGELOG.md` for user-facing changes.

## Coding Guidelines

- Keep the public API provider-neutral where possible.
- Prefer Swift-native naming and value types.
- Add concise doc comments for public symbols.
- Add tests for new provider mappings and failure paths.

## Pull Requests

- Explain the user-facing impact.
- Call out any provider-specific behavior differences.
- Mention whether live integration coverage was exercised.
