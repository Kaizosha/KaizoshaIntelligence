# Google Interactions API

The Interactions API is exposed as a Google-only preview layer through ``GoogleProvider/interactions``.

## Basic Usage

```swift
let provider = try GoogleProvider()
let interaction = try await provider.interactions.create(
    GoogleInteractionRequest(
        model: "gemini-3-flash-preview",
        input: .text("Tell me a short joke about Swift."),
        tools: [.googleSearch()]
    )
)
```

## Stateful Continuations

Use `previousInteractionID` to continue a stored interaction without resending the full history.

```swift
let next = GoogleInteractionRequest(
    model: "gemini-3-flash-preview",
    input: .text("Now make it shorter."),
    previousInteractionID: interaction.id
)
```

## Validation

The SDK validates one current server-side constraint before dispatch: `background=true` cannot be combined with `store=false`.

## Streaming

```swift
let stream = provider.interactions.stream(
    GoogleInteractionRequest(
        model: "gemini-3-flash-preview",
        input: .text("Explain actor isolation."),
        stream: true
    )
)
```

The stream surfaces incremental `content.delta` events plus the terminal completed interaction payload.
