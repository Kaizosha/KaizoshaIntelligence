# Structured Output

Use ``Schema`` to define a typed JSON contract, then decode directly into Swift models.

## Example

```swift
struct Summary: Codable, Sendable {
    let title: String
    let bullets: [String]
}

let schema = Schema<Summary>(
    name: "Summary",
    description: "A concise summary object.",
    jsonSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object(["type": .string("string")]),
            "bullets": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
        ]),
        "required": .array([.string("title"), .string("bullets")]),
    ])
)

let result = try await generateStructured(
    schema: schema,
    using: provider.languageModel("gpt-4o-mini"),
    request: TextGenerationRequest(prompt: "Summarize actor isolation.")
)
```

## Streaming Structured Output

Use ``streamStructured(schema:using:request:)`` when you want incremental text plus a final decoded value.
