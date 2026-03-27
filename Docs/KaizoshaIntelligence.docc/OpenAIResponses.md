# OpenAI Responses

Kaizosha OpenAI uses the OpenAI Responses API as the default language-model backend.

## Default Language Model

```swift
import KaizoshaIntelligence
import KaizoshaOpenAI

let provider = try OpenAIProvider()
let response = try await generateText(
    prompt: "Summarize actor isolation in one sentence.",
    using: provider.languageModel("gpt-5")
)
```

`languageModel(_:)` returns a Responses-backed model. Use `responsesModel(_:)` when you want direct access to raw OpenAI response items, and `chatCompletionsModel(_:)` only for legacy compatibility.

## Raw Responses Access

```swift
let provider = try OpenAIProvider()
let model = provider.responsesModel("gpt-5")

let response = try await model.createResponse(
    OpenAIResponseRequest(
        input: [
            .system("You explain Swift clearly."),
            .user("What does Sendable mean?")
        ],
        instructions: "Prefer plain language.",
        reasoningSummary: .concise,
        verbosity: .low
    )
)
```

`OpenAIResponse` preserves provider-specific output items such as reasoning summaries, built-in tool calls, background response metadata, and raw response items that do not fit the provider-neutral `TextGenerationResponse`.

## Provider Options

Use ``OpenAIProviderOptions`` with provider-neutral requests when you need Responses-specific behavior:

- `instructions`
- `previousResponseID`
- `conversationID`
- `store`
- `background`
- `promptCacheKey`
- `promptCacheRetention`
- `include`
- `serviceTier`
- `parallelToolCalls`
- `safetyIdentifier`
- `nativeTools`
- `reasoningSummary`
- `verbosity`

`previousResponseID` and `conversationID` are intentionally mutually exclusive because that matches the current Responses API. `promptCacheKey` is the preferred replacement for the deprecated `user` field on the Responses path, so Kaizosha does not forward `user` to `languageModel(_:)` or `responsesModel(_:)`.

These options are namespaced under the OpenAI adapter, so the shared request types remain portable across providers.

## Legacy Chat Completions

```swift
let provider = try OpenAIProvider()
let legacy = provider.chatCompletionsModel("gpt-4o-mini")
```

The legacy adapter is intentionally separate. It preserves existing Chat Completions behavior, while the default OpenAI path stays aligned with Responses-first development.
