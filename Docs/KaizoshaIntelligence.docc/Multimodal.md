# Multimodal APIs

The shared message system supports text, images, audio, files, tool calls, and tool results.

## Image Input

```swift
let image = ImageContent(data: imageData, mimeType: "image/png")
let request = TextGenerationRequest(
    messages: [
        .user(parts: [
            .text("Describe this screenshot."),
            .image(image),
        ]),
    ]
)
```

## Dedicated Modalities

Use provider-specific handles for dedicated endpoints:

- ``ImageModel/generateImage(request:)``
- ``SpeechModel/generateSpeech(request:)``
- ``TranscriptionModel/transcribe(request:)``

Provider support varies by adapter. The shared abstractions stay stable even when capabilities differ.
