# Tool Calling

Tool calling lets you expose deterministic Swift functions to supported models without building a full autonomous agent runtime.

## Define a Tool

```swift
struct WeatherInput: Codable, Sendable {
    let city: String
}

struct WeatherOutput: Codable, Sendable {
    let forecast: String
}

let tool = Tool<WeatherInput, WeatherOutput>(
    name: "lookup_weather",
    description: "Returns a simple weather forecast.",
    inputSchema: Schema(
        name: "WeatherInput",
        description: "Weather lookup arguments.",
        jsonSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "city": .object(["type": .string("string")]),
            ]),
            "required": .array([.string("city")]),
        ])
    ),
    execute: { input, _ in
        WeatherOutput(forecast: "Sunny in \\(input.city)")
    }
)
```

## Execute One Tool Round Automatically

```swift
let response = try await generateText(
    using: provider.languageModel("gpt-4o-mini"),
    request: TextGenerationRequest(
        prompt: "What is the weather in Tokyo?",
        tools: ToolRegistry([tool]),
        toolExecution: .automaticSingleStep
    )
)
```

Automatic execution is intentionally limited to a single deterministic follow-up round in v1.
