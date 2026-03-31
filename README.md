# Kaizosha Intelligence

Kaizosha Intelligence is a Swift-first AI SDK with a provider-agnostic core and dedicated adapters for OpenAI, Anthropic, Google, and Vercel AI Gateway.

## Highlights

- Unified text generation and streaming APIs
- OpenAI Responses-first language adapter with explicit legacy Chat Completions fallback
- OpenAI-only raw Responses, files, GPT-image edits, DALL-E 2 variations, speech streaming on compatible TTS models, translation, and Realtime APIs
- Anthropic Messages plus Anthropic-only files, prompt caching, web search, and token-counting APIs
- Google Gemini `generateContent` plus Google-only models, token counting, files, cached contents, file-search stores, batch jobs, Interactions, and Live APIs
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
    using: provider.languageModel("gpt-5")
)

print(response.text)
```

`OpenAIProvider.languageModel(_:)` is Responses-backed by default. Use `responsesModel(_:)` for explicit raw Responses access and `chatCompletionsModel(_:)` only when you need legacy compatibility.

## OpenAI Responses API

```swift
import KaizoshaOpenAI

let provider = try OpenAIProvider()
let model = provider.responsesModel("gpt-5")

let response = try await model.createResponse(
    OpenAIResponseRequest(
        input: [
            .system("You explain Swift clearly."),
            .user("Describe actor isolation in one sentence.")
        ],
        instructions: "Prefer plain language.",
        reasoningSummary: .concise,
        verbosity: .low
    )
)
```

## OpenAI Realtime API

```swift
import KaizoshaOpenAI

let provider = try OpenAIProvider()
let session = try await provider.createRealtimeClientSecret(
    OpenAIRealtimeSessionRequest(
        modelID: "gpt-realtime",
        outputModalities: ["audio"],
        audio: OpenAIRealtimeAudioConfiguration(
            output: OpenAIRealtimeOutputAudioConfiguration(voice: "marin")
        )
    )
)

let client = try provider.realtimeClient(
    modelID: session.modelID,
    clientSecret: session.clientSecret
)
```

`createRealtimeClientSecret(_:)` is the primary Realtime helper. `createRealtimeSession(_:)` remains available as a compatibility helper for the legacy `/realtime/sessions` shape.

## Live Model Discovery

```swift
import KaizoshaGoogle

let provider = try GoogleProvider()
let models = try await provider.listModels()

for model in models.prefix(5) {
    print(model.id)
}
```

## Google Gemini APIs

```swift
import KaizoshaGoogle

let provider = try GoogleProvider()
let contentModel = provider.contentModel("gemini-2.5-flash")
let tokenCount = try await provider.tokens.countTokens(
    modelID: "gemini-2.5-flash",
    request: GoogleCountTokensRequest(
        generateContentRequest: GoogleContentRequest(
            contents: [
                GoogleContent(parts: [GoogleContentPart(text: "Explain actor isolation.")])
            ]
        )
    )
)

print(tokenCount.totalTokens ?? 0)
```

## Anthropic Files and Token Counting

```swift
import KaizoshaAnthropic

let provider = try AnthropicProvider()
let uploaded = try await provider.files.upload(
    AnthropicFileUploadRequest(
        data: pdfData,
        fileName: "brief.pdf",
        mimeType: "application/pdf"
    )
)

let tokenCount = try await provider.tokens.countTokens(
    modelID: "claude-3-5-sonnet-latest",
    request: TextGenerationRequest(
        messages: [
            .user(parts: [
                .file(uploaded.asFileContent()),
                .text("Summarize the document.")
            ])
        ]
    )
)

print(tokenCount.inputTokens)
```

## Anthropic Prompt Caching

```swift
import KaizoshaAnthropic

var providerOptions = ProviderOptions()
providerOptions.setAnthropic(
    AnthropicProviderOptions(
        promptCaching: AnthropicPromptCachingOptions(
            automatic: AnthropicPromptCacheControl(),
            system: AnthropicPromptCacheControl(ttl: .oneHour)
        )
    )
)

let provider = try AnthropicProvider()
let response = try await provider.languageModel("claude-sonnet-4-5").generate(
    request: TextGenerationRequest(
        messages: [
            .system("You are a careful reviewer."),
            .user("Review this diff.")
        ],
        providerOptions: providerOptions
    )
)

print(response.usage?.cacheReadInputTokens ?? 0)
```

## Anthropic Web Search

```swift
import KaizoshaAnthropic

var providerOptions = ProviderOptions()
providerOptions.setAnthropic(
    AnthropicProviderOptions(
        serverTools: [
            .webSearch(
                maxUses: 3,
                allowedDomains: ["docs.anthropic.com"],
                userLocation: AnthropicUserLocation(
                    city: "San Francisco",
                    region: "California",
                    country: "US",
                    timezone: "America/Los_Angeles"
                )
            ),
        ]
    )
)

let provider = try AnthropicProvider()
let response = try await provider.languageModel("claude-sonnet-4-5").generate(
    request: TextGenerationRequest(
        prompt: "Find the current Anthropic web search guidance.",
        providerOptions: providerOptions
    )
)

print(response.text)
```

Stable Anthropic web search is exposed as a typed Anthropic server tool. Dynamic filtering variants that require Anthropic code execution are intentionally deferred until the code-execution tool is implemented.

## Example Executables

- `KaizoshaCLIExample`
- `KaizoshaServerExample`
- `KaizoshaProviderComparisonExample`
- `KaizoshaOpenAIResponsesExample`
- `KaizoshaOpenAIBuiltInToolsExample`
- `KaizoshaOpenAIRealtimeExample`
- `KaizoshaGoogleGroundingExample`
- `KaizoshaGoogleCachingExample`
- `KaizoshaGoogleFilesExample`
- `KaizoshaGoogleFileSearchExample`
- `KaizoshaGoogleBatchExample`
- `KaizoshaGoogleInteractionsExample`
- `KaizoshaGoogleLiveExample`

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
