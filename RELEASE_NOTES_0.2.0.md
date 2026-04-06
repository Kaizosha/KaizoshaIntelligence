# Release Notes 0.2.0

## Summary

Kaizosha Intelligence `0.2.0` is the first major feature release after `0.1.0`, expanding all three direct providers substantially and hardening the shared streaming and capability layers.

## Highlights

- Expanded OpenAI support into a Responses-first adapter with:
  - raw Responses APIs
  - richer OpenAI-specific options and validation
  - file helpers
  - GPT-image edits and DALL-E 2 variations
  - speech and transcription improvements
  - GA-first Realtime support
- Expanded Google support across much more of the Gemini Developer API with:
  - raw content models
  - token counting
  - files and cached contents
  - file-search stores
  - generated files
  - batch jobs
  - Interactions
  - Live APIs
- Expanded Anthropic support with:
  - Files and token counting
  - typed prompt caching
  - stable web search
  - stable code execution
  - `container_upload` file mapping
  - container reuse
  - execution-artifact helpers
- Added live model discovery for OpenAI, Anthropic, Google, and Gateway.
- Hardened text streaming across providers, including Linux incremental streaming and improved streamed tool handling.
- Refined provider capability resolution and expanded live provider-matrix test coverage.
- Updated DocC, examples, CI smoke builds, and provider-specific docs to match the new adapter surfaces.

## Compatibility Notes

- `OpenAIProvider.languageModel(_:)` remains Responses-backed by default.
- `OpenAIProvider.chatCompletionsModel(_:)` remains available as the legacy compatibility path.
- Anthropic dynamic web-search variants and `pause_turn` continuation are still intentionally outside the current typed SDK surface.
- Google preview APIs remain Google-specific instead of being forced into the shared provider-neutral contracts.

## Suggested Commit Message

```text
Release 0.2.0: expand provider coverage and harden streaming
```

## Suggested Annotated Tag Message

```text
Kaizosha Intelligence 0.2.0

Expanded OpenAI, Google, and Anthropic support with fuller provider-specific
surfaces, live model discovery, stronger capability validation, improved
cross-provider streaming, and updated docs, examples, and CI coverage.
```
