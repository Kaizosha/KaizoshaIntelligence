# Releasing

## Release Checklist

1. Ensure `Planning/V1-CHECKLIST.md` is up to date.
2. Run:

```bash
swift build
swift test
swift package --allow-writing-to-directory ./docs-build \
  generate-documentation \
  --target KaizoshaIntelligence \
  --output-path ./docs-build \
  --disable-indexing
```

3. Update `CHANGELOG.md`.
4. Tag the release with a semantic version, starting with `0.x.y`.
5. Publish release notes summarizing major API additions, provider coverage, and breaking changes.
