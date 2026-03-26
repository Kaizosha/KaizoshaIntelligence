# Release Notes 0.1.0

## Summary

Kaizosha Intelligence `0.1.0` is the first public release of a Swift-first AI SDK with a provider-agnostic core and adapters for OpenAI, Anthropic, Google, and Vercel AI Gateway.

## Highlights

- Added a multi-product SwiftPM layout with a provider-neutral core.
- Added unified APIs for:
  - text generation
  - streaming generation
  - structured output
  - tool calling
  - embeddings
  - image generation
  - speech generation
  - transcription
- Added provider adapters for OpenAI, Anthropic, Google, and Gateway.
- Added native streaming implementations for OpenAI, Anthropic, and Google.
- Added capability metadata and early validation for unsupported feature combinations.
- Added DocC documentation, runnable examples, CI, release metadata, and Swift Testing coverage.

## Included Modules

- `KaizoshaIntelligence`
- `KaizoshaProvider`
- `KaizoshaOpenAI`
- `KaizoshaAnthropic`
- `KaizoshaGoogle`
- `KaizoshaGateway`

## Known Scope Boundaries

- No UI hook layer or SwiftUI chat state layer in v1.
- No full autonomous multi-step agent runtime in v1.
- Provider feature coverage varies by adapter and is documented in `SupportMatrix`.

## Suggested Commit Message

```text
Release 0.1.0: ship Kaizosha Intelligence Swift SDK v1
```

## Suggested Annotated Tag Message

```text
Kaizosha Intelligence 0.1.0

First public release of the Swift-first AI SDK with provider-neutral APIs,
native streaming, structured output, tool calling, multimodal abstractions,
and adapters for OpenAI, Anthropic, Google, and Vercel AI Gateway.
```
