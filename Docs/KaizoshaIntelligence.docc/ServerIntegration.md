# Server Integration

Kaizosha Intelligence is designed to work in Apple apps and server-side Swift.

## Recommended Pattern

- Create providers once at startup.
- Pass model handles into request-scoped code.
- Keep tools deterministic and side-effect aware.
- Stream directly into HTTP responses when your framework supports it.

## Minimal Route Example

```swift
let provider = try GatewayProvider()

func summarize(_ prompt: String) async throws -> String {
    let response = try await generateText(
        prompt: prompt,
        using: provider.languageModel("openai/gpt-4o-mini")
    )
    return response.text
}
```

The package does not impose a specific server framework, which keeps it portable across Vapor, Hummingbird, and custom SwiftNIO stacks.
