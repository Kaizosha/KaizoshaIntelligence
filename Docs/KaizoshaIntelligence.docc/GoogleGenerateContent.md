# Google Generate Content

`KaizoshaGoogle` keeps the provider-neutral `languageModel(_:)` path on Gemini `generateContent`, and also exposes a raw ``GoogleContentModel`` for Google-specific features that do not fit the shared abstractions.

## Provider-Neutral Text Generation

```swift
let provider = try GoogleProvider()
let response = try await provider.languageModel("gemini-2.5-flash").generate(
    request: TextGenerationRequest(prompt: "Explain Swift actors in one sentence.")
)
```

That path continues to power:

- text generation
- SSE streaming
- structured output through `Schema<Value>`
- custom function tools
- multimodal image, audio, and file prompt parts

## Raw Gemini Content Access

Use ``GoogleProvider/contentModel(_:)`` when you need direct access to the Gemini request or response shape.

```swift
let provider = try GoogleProvider()
let model = provider.contentModel("gemini-2.5-flash")

let response = try await model.generateContent(
    GoogleContentRequest(
        contents: [
            GoogleContent(parts: [
                GoogleContentPart(text: "Summarize actor isolation.")
            ])
        ]
    )
)
```

``GoogleContentModel`` also exposes:

- ``GoogleContentModel/streamGenerateContent(_:)``
- ``GoogleContentModel/countTokens(_:)``
- ``GoogleContentModel/generateAnswer(_:)``

## Capability Resolution

The Google adapter keeps a live model catalog cache from `models.list` and `models.get`. When metadata is available, the adapter uses the advertised `supportedGenerationMethods` to validate Google-only calls like `countTokens` before sending the request.
