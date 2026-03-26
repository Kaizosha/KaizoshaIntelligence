# Providers and Models

Kaizosha Intelligence separates the high-level API surface from provider implementations.

## Package Structure

- `KaizoshaIntelligence` exposes top-level convenience functions such as ``generateText(using:request:)``.
- `KaizoshaProvider` defines the shared contracts: ``LanguageModel``, ``EmbeddingModel``, ``ImageModel``, ``SpeechModel``, and ``TranscriptionModel``.
- Provider packages vend concrete model handles that conform to those contracts.

## Direct Providers

### OpenAI

```swift
let provider = try OpenAIProvider()
let model = provider.languageModel("gpt-4o-mini")
```

### Anthropic

```swift
let provider = try AnthropicProvider()
let model = provider.languageModel("claude-3-5-haiku-latest")
```

### Google

```swift
let provider = try GoogleProvider()
let model = provider.languageModel("gemini-2.0-flash")
```

### Gateway

```swift
let provider = try GatewayProvider()
let model = provider.languageModel("openai/gpt-4o-mini")
```

## Provider Options

Shared settings live in ``GenerationConfig``. Provider-specific options belong in ``ProviderOptions`` and should remain namespaced by adapter.
