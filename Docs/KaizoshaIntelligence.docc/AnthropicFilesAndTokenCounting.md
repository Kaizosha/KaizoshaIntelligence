# Anthropic Files and Token Counting

Kaizosha Intelligence keeps the shared Anthropic text path on the Messages API and adds Anthropic-only helpers for file uploads, prompt caching, web search, and token counting in `KaizoshaAnthropic`.

## Files API

Use `AnthropicProvider.files` to upload, retrieve, list, delete, and download provider-managed files.

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

let filePart = uploaded.asFileContent()
```

`AnthropicFile.asFileContent()` converts the uploaded file into a reusable `MessagePart.file` reference that the shared language-model API can pass back to Anthropic with `file_id`.

## Shared File Input

Anthropic file input is now available through the shared `MessagePart.file` abstraction for the document shapes that the current adapter maps directly:

- Inline `application/pdf`
- Inline `text/plain`
- Uploaded Anthropic file IDs converted from `AnthropicFile`

```swift
let provider = try AnthropicProvider()
let model = provider.languageModel("claude-3-5-sonnet-latest")

let response = try await model.generate(
    request: TextGenerationRequest(
        messages: [
            .user(parts: [
                .file(filePart),
                .text("Summarize the document in two bullets.")
            ])
        ]
    )
)
```

## Token Counting

`AnthropicProvider.tokens` counts input tokens for the same Messages-style request shape you pass into generation.

```swift
let count = try await provider.tokens.countTokens(
    modelID: "claude-3-5-sonnet-latest",
    request: TextGenerationRequest(
        messages: [
            .system("You explain clearly."),
            .user("Explain actor isolation in one paragraph.")
        ]
    )
)

print(count.inputTokens)
```

## Prompt Caching

Anthropic prompt caching is available through `AnthropicProviderOptions.promptCaching`.

```swift
var providerOptions = ProviderOptions()
providerOptions.setAnthropic(
    AnthropicProviderOptions(
        promptCaching: AnthropicPromptCachingOptions(
            automatic: AnthropicPromptCacheControl(),
            system: AnthropicPromptCacheControl(ttl: .oneHour),
            messageParts: [
                AnthropicMessagePartCacheBreakpoint(messageIndex: 1, partIndex: 0)
            ]
        )
    )
)

let provider = try AnthropicProvider()
let response = try await provider.languageModel("claude-sonnet-4-5").generate(
    request: TextGenerationRequest(
        messages: [
            .system("You are a careful reviewer."),
            .user("Review this repository snapshot.")
        ],
        providerOptions: providerOptions
    )
)
```

Use `automatic` for Anthropic's top-level caching mode, or add explicit breakpoints on the combined system prompt, tool definitions, and specific message parts. Cache usage counters are surfaced in `Usage.cacheReadInputTokens` and `Usage.cacheCreationInputTokens`.

## Web Search

Anthropic's stable provider-managed web search tool is available through `AnthropicProviderOptions.serverTools`.

```swift
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
        prompt: "Find the latest Anthropic web-search guidance.",
        providerOptions: providerOptions
    )
)
```

Server tools are merged into Anthropic's top-level `tools` array alongside your custom tools, and Kaizosha validates name conflicts before the request is sent.

## Notes

- The Files API currently uses Anthropic's documented beta header.
- Anthropic prompt caching supports both top-level automatic caching and explicit block-level breakpoints through typed Anthropic provider options.
- Anthropic web search is available through the stable server-side `web_search_20250305` tool definition.
- Anthropic's newer dynamic web-search variant depends on code execution and is intentionally deferred until the SDK exposes Anthropic code execution.
- Shared Anthropic file input is intentionally conservative today. Inline file bytes are limited to PDF and plain text; reusable uploaded files should be passed back through Anthropic file IDs.
- Anthropic embeddings, audio input, speech, transcription, and Realtime are still outside the current Anthropic adapter surface.
