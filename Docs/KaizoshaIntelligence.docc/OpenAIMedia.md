# OpenAI Media

`KaizoshaOpenAI` exposes the OpenAI-specific media APIs that sit alongside the provider-neutral abstractions.

## Files

Upload a file for later inference use:

```swift
let provider = try OpenAIProvider()
let file = try await provider.uploadFile(
    OpenAIFileUploadRequest(
        data: fileData,
        fileName: "notes.txt",
        mimeType: "text/plain"
    )
)
```

`FileContent` can then reference either inline bytes or an existing OpenAI file identifier.

## Images

OpenAI image models support generation, GPT-image edits, DALL-E 2 variations, and partial-image streaming:

```swift
let provider = try OpenAIProvider()
let imageModel = provider.imageModel("gpt-image-1")

let result = try await imageModel.editImage(
    request: OpenAIImageEditRequest(
        prompt: "Turn this into a diagram with a clean background.",
        images: [sourceImage]
    )
)
```

Use `OpenAIImageModel.varyImage(request:)` only with `dall-e-2`. The current OpenAI `images/variations` endpoint is not shared with GPT image models.

## Speech

OpenAI speech models support one-shot synthesis plus event streaming on compatible TTS models:

```swift
let provider = try OpenAIProvider()
let speechModel = provider.speechModel()

let stream = speechModel.streamSpeech(
    request: SpeechGenerationRequest(
        prompt: "Welcome to Kaizosha Intelligence.",
        voice: "alloy"
    )
)
```

`OpenAISpeechModel.builtInVoices` exposes the currently documented speech-endpoint voices, while Realtime voice selection lives on `OpenAIRealtimeSessionRequest.audio.output.voice`. `streamSpeech` is available on GPT TTS models, but not on `tts-1` or `tts-1-hd`.

## Transcription and Translation

OpenAI transcription models support detailed transcription metadata, streaming transcript events, and translation:

```swift
let provider = try OpenAIProvider()
let transcriptionModel = provider.transcriptionModel()

let translated = try await transcriptionModel.translate(
    OpenAITranslationRequest(
        audio: audioData,
        fileName: "meeting.wav",
        mimeType: "audio/wav"
    )
)
```

For file transcription, the SDK now validates model-specific response-format rules before sending the request. Speaker diarization is available through `gpt-4o-transcribe-diarize` on `/audio/transcriptions`, supports structured known-speaker references, and is intentionally documented separately from Realtime transcription.
