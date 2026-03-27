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

OpenAI also exposes file uploads for inference, GPT-image edits, DALL-E 2 variations, streamed speech on compatible TTS models, streamed transcription, and translation through ``KaizoshaOpenAI``.

Provider support varies by adapter. The shared abstractions stay stable even when capabilities differ.
