# Kaizosha Intelligence

Kaizosha Intelligence is a Swift-first AI SDK with a provider-agnostic core and dedicated adapters for OpenAI, Anthropic, Google, and Vercel AI Gateway.

## Highlights

- Unified text generation and streaming APIs
- Typed structured output with `Schema<Value>`
- Deterministic tool calling
- Embeddings, image generation, speech generation, and transcription abstractions
- Apple-style DocC documentation
- SwiftPM-native package structure with separate provider libraries

## Packages

- `KaizoshaIntelligence`
- `KaizoshaProvider`
- `KaizoshaOpenAI`
- `KaizoshaAnthropic`
- `KaizoshaGoogle`
- `KaizoshaGateway`

## Quick Start

```swift
import KaizoshaIntelligence
import KaizoshaOpenAI

let provider = try OpenAIProvider()
let response = try await generateText(
    prompt: "Explain actors in one sentence.",
    using: provider.languageModel("gpt-4o-mini")
)

print(response.text)
```

## Documentation

Generate the DocC archive locally:

```bash
swift package --allow-writing-to-directory ./docs-build \
  generate-documentation \
  --target KaizoshaIntelligence \
  --output-path ./docs-build \
  --disable-indexing
```

The DocC bundle lives in `Docs/KaizoshaIntelligence.docc`.
