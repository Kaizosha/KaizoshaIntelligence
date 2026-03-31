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
let model = provider.languageModel("gpt-5")
```

`languageModel(_:)` is Responses-backed by default. OpenAI also exposes:

```swift
let responses = provider.responsesModel("gpt-5")
let legacy = provider.chatCompletionsModel("gpt-4o-mini")
```

### Anthropic

```swift
let provider = try AnthropicProvider()
let model = provider.languageModel("claude-3-5-haiku-latest")
```

Anthropic also exposes Anthropic-only service clients for files and token counting:

```swift
let files = provider.files
let tokens = provider.tokens
```

### Google

```swift
let provider = try GoogleProvider()
let model = provider.languageModel("gemini-2.0-flash")
```

Google also exposes Google-only service clients and a raw content model:

```swift
let contentModel = provider.contentModel("gemini-2.5-flash")
let modelCatalog = provider.models
let files = provider.files
let cachedContents = provider.cachedContents
let fileSearchStores = provider.fileSearchStores
let batches = provider.batches
let interactions = provider.interactions
let live = provider.live
```

### Gateway

```swift
let provider = try GatewayProvider()
let model = provider.languageModel("openai/gpt-4o-mini")
```

## Live Model Catalogs

Providers can fetch their live model catalogs directly from the upstream API instead of relying on hardcoded lists.

```swift
let provider = try OpenAIProvider()
let models = try await provider.listModels()

for model in models {
    print(model.id)
}
```

``AvailableModel`` includes the normalized SDK identifier plus any provider metadata the adapter can surface, such as display names, token limits, supported generation methods, and the raw provider payload.

## Provider Options

Shared settings live in ``GenerationConfig``. Provider-specific options belong in ``ProviderOptions`` and should remain namespaced by adapter.

For OpenAI, ``OpenAIProviderOptions`` maps Responses-specific settings such as `instructions`, `previousResponseID`, `conversationID`, `include`, `promptCacheKey`, `serviceTier`, native tools, and reasoning detail. The `user` field remains available only for the legacy Chat Completions adapter; the Responses path follows OpenAI's `promptCacheKey` and `safetyIdentifier` guidance instead.

For Anthropic, the shared request path stays on the Messages API, while Anthropic-only helpers expose the Files API and `messages/count_tokens`. Shared Anthropic file input maps inline PDF/plain-text documents and Anthropic `file_id` references into Messages document blocks, and prompt caching is available through `AnthropicProviderOptions.promptCaching`.

For Google, ``GoogleProviderOptions`` maps `generationConfig`, `safetySettings`, `toolConfig`, cached-content references, storage/service-tier settings, and Google built-in tools while keeping the provider-neutral `GenerationConfig` surface stable.
