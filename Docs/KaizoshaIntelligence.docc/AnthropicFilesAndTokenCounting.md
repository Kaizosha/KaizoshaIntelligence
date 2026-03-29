# Anthropic Files and Token Counting

Kaizosha Intelligence keeps the shared Anthropic text path on the Messages API and adds Anthropic-only helpers for file uploads and token counting in `KaizoshaAnthropic`.

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

## Notes

- The Files API currently uses Anthropic's documented beta header.
- Shared Anthropic file input is intentionally conservative today. Inline file bytes are limited to PDF and plain text; reusable uploaded files should be passed back through Anthropic file IDs.
- Anthropic embeddings, audio input, speech, transcription, and Realtime are still outside the current Anthropic adapter surface.
