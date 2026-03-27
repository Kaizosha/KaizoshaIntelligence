# Google Files and Cached Contents

`KaizoshaGoogle` exposes explicit file and cache clients because Gemini file reuse and prompt caching are provider-specific workflows.

## Uploading Files

```swift
let provider = try GoogleProvider()
let file = try await provider.files.upload(
    data: Data("Swift actors protect mutable state.".utf8),
    fileName: "swift.txt",
    mimeType: "text/plain"
)
```

Uploaded files can be converted into reusable prompt parts with ``GoogleFile/asFileContent()``.

```swift
let promptFile = try file.asFileContent()
```

The Google adapter maps that back into Gemini `fileData.fileUri` instead of forcing inline bytes on every request.

## Cached Contents

```swift
let cached = try await provider.cachedContents.create(
    GoogleCachedContent(
        displayName: "swift-cache",
        model: "models/gemini-2.5-flash",
        contents: [
            GoogleContent(parts: [GoogleContentPart(text: "Swift uses actors and structured concurrency.")])
        ],
        ttl: "3600s"
    )
)
```

Use the returned cached-content resource name with either ``GoogleProviderOptions`` or ``GoogleCountTokensRequest``.

## Registering Existing URIs

The files client also exposes `register(uris:)` for provider-managed cloud URIs when Gemini supports resource registration instead of direct upload.
