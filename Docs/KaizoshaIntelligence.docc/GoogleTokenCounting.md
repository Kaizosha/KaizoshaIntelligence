# Google Token Counting

Gemini token counting is exposed through both the raw content model and the dedicated tokens service.

## Using the Tokens Service

```swift
let provider = try GoogleProvider()
let count = try await provider.tokens.countTokens(
    modelID: "gemini-2.5-flash",
    request: GoogleCountTokensRequest(
        generateContentRequest: GoogleContentRequest(
            contents: [
                GoogleContent(parts: [GoogleContentPart(text: "Explain actors briefly.")])
            ]
        )
    )
)
```

## Counting Cached Requests

`GoogleCountTokensRequest` can include a full ``GoogleContentRequest`` so token counts reflect:

- system instructions
- tools
- safety settings
- cached content references
- generation config

That matches the Google API more closely than trying to estimate on the client.
