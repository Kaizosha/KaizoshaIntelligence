# Google Live API

The Live API is exposed as a Google-only websocket layer through ``GoogleProvider/live``.

## Auth Tokens

```swift
let provider = try GoogleProvider()
let token = try await provider.live.createAuthToken(
    GoogleLiveAuthTokenRequest(
        setup: GoogleLiveSetup(
            model: "models/gemini-live-2.5-flash-preview"
        ),
        uses: 1
    )
)
```

Google currently returns the ephemeral token value in the `name` field, which the SDK surfaces as ``GoogleLiveAuthToken/value``.

## Connecting

```swift
let client = try await provider.live.connect(
    setup: GoogleLiveSetup(model: "models/gemini-live-2.5-flash-preview"),
    authorization: .authToken(token.value ?? "")
)
```

The Live client exposes:

- ``GoogleLiveClient/send(_:)``
- ``GoogleLiveClient/events()``
- ``GoogleLiveClient/close()``

## Event Coverage

The typed parser currently covers:

- setup completion
- text deltas
- output audio data
- input and output transcription deltas
- tool calls
- tool-call cancellation
- session resumption updates
- usage metadata
- raw fallback events
