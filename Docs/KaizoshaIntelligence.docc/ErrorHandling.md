# Error Handling

Kaizosha Intelligence throws ``KaizoshaError`` for package-level failures.

## Common Cases

- Missing credentials
- Invalid request construction
- Invalid provider responses
- Unsupported capabilities
- HTTP failures
- Structured decoding failures
- Tool execution failures

## Example

```swift
do {
    let response = try await generateText(
        prompt: "Hello",
        using: provider.languageModel("gpt-4o-mini")
    )
    print(response.text)
} catch let error as KaizoshaError {
    print(error.localizedDescription)
}
```
