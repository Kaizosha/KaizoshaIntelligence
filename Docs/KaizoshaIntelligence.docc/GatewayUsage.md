# Gateway Usage

Use the Vercel AI Gateway adapter when you want routed `vendor/model` identifiers behind a single endpoint.

## Example

```swift
let provider = try GatewayProvider()

let response = try await generateText(
    prompt: "Reply with exactly the word gateway.",
    using: provider.languageModel("openai/gpt-4o-mini")
)
```

## Why Gateway

- One endpoint for multiple vendors
- Routed model identifiers
- A provider-neutral Swift API on the client side

Gateway models conform to the same core contracts as direct adapters.
