# Streaming

Streaming APIs return `AsyncThrowingStream` so they fit naturally into modern Swift concurrency.

## Text Streaming

```swift
let stream = streamText(
    prompt: "List three uses for embeddings.",
    using: provider.languageModel("gpt-4o-mini")
)

for try await event in stream {
    switch event {
    case .textDelta(let delta):
        print(delta, terminator: "")
    case .toolCall(let invocation):
        print("tool:", invocation.name)
    case .finished:
        print("")
    default:
        break
    }
}
```

## Event Model

``TextStreamEvent`` includes:

- Status changes
- Text deltas
- Tool calls
- Tool results
- Usage metadata
- Finish reasons
