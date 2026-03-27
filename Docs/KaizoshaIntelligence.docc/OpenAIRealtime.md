# OpenAI Realtime

Realtime support lives in `KaizoshaOpenAI` as an explicit OpenAI-only layer.

## Create a Session

```swift
import KaizoshaOpenAI

let provider = try OpenAIProvider()
let session = try await provider.createRealtimeClientSecret(
    OpenAIRealtimeSessionRequest(
        modelID: "gpt-realtime",
        instructions: "Answer naturally and briefly.",
        outputModalities: ["audio"],
        audio: OpenAIRealtimeAudioConfiguration(
            output: OpenAIRealtimeOutputAudioConfiguration(voice: "marin")
        )
    )
)
```

Use `createRealtimeClientSecret(_:)` as the primary helper for new integrations. It follows the current GA `POST /v1/realtime/client_secrets` shape with a nested `session` payload. `createRealtimeSession(_:)` remains available as a compatibility helper for `/realtime/sessions`.

## Connect a Client

```swift
let client = try provider.realtimeClient(
    modelID: session.modelID,
    clientSecret: session.clientSecret
)

try await client.send(.responseCreate())

eventLoop: for try await event in await client.events() {
    switch event {
    case .responseTextDelta(let delta):
        print(delta, terminator: "")
    case .responseCompleted:
        print("")
        break eventLoop
    default:
        continue
    }
}
```

`OpenAIRealtimeEvent` includes typed cases for session lifecycle events, response text deltas, output audio chunks, transcript deltas, tool calls, completion, and errors.

`OpenAIRealtimeSessionRequest` also exposes typed fields for audio input and output configuration, turn detection, input transcription, tools, tool choice, include fields, truncation, and max output tokens.
