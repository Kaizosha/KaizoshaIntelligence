# Quick Start

Create a provider, choose a model, and call the high-level generation API.

## OpenAI

```swift
import KaizoshaIntelligence
import KaizoshaOpenAI

let provider = try OpenAIProvider()
let response = try await generateText(
    prompt: "Explain actor isolation in one sentence.",
    using: provider.languageModel("gpt-4o-mini")
)

print(response.text)
```

## Gateway

```swift
import KaizoshaGateway
import KaizoshaIntelligence

let provider = try GatewayProvider()
let response = try await generateText(
    prompt: "Reply with a JSON object containing `service` and `status`.",
    using: provider.languageModel("openai/gpt-4o-mini")
)
```

## Next Steps

- Read <doc:ProvidersAndModels> to understand the package split.
- Read <doc:StructuredOutput> to decode typed values from model output.
- Read <doc:ToolCalling> to attach deterministic tools to generation requests.
