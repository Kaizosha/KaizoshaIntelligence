# Google File Search Stores

Gemini file-search stores are exposed directly under ``GoogleProvider/fileSearchStores``.

## Creating a Store

```swift
let provider = try GoogleProvider()
let store = try await provider.fileSearchStores.create(
    GoogleFileSearchStore(displayName: "swift-search-store")
)
```

## Importing Uploaded Files

```swift
let operation = try await provider.fileSearchStores.importFile(
    fileSearchStoreName: store.name ?? "",
    fileName: "files/abc",
    chunkingConfig: GoogleChunkingConfiguration(
        maxTokensPerChunk: 256,
        maxOverlapTokens: 32
    )
)
```

## Direct Store Uploads

Use `upload(...)` when you want to send bytes directly to the store ingestion endpoint instead of uploading a reusable file first.

## Documents and Operations

The file-search-store client also supports:

- `listDocuments(parent:pageSize:pageToken:)`
- `getDocument(_:)`
- `deleteDocument(_:)`
- `getOperation(_:)`

Those APIs intentionally stay Google-specific because the resource model and ingestion lifecycle do not map cleanly to the provider-neutral core.
