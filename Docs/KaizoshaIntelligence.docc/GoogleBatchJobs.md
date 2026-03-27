# Google Batch Jobs

Gemini exposes both synchronous batch embeddings and long-running batch jobs. `KaizoshaGoogle` keeps both on ``GoogleProvider/batches``.

## Synchronous Batch Embeddings

```swift
let provider = try GoogleProvider()
let response = try await provider.batches.batchEmbedContents(
    modelID: "text-embedding-004",
    requests: [
        GoogleBatchEmbeddingRequest(text: "Swift"),
        GoogleBatchEmbeddingRequest(text: "Concurrency")
    ]
)
```

## Long-Running Content Batches

```swift
let operation = try await provider.batches.createGenerateContentBatch(
    modelID: "gemini-2.5-flash",
    batch: GoogleGenerateContentBatch(payload: .object([:]))
)
```

## Long-Running Embedding Batches

```swift
let operation = try await provider.batches.createEmbedContentBatch(
    modelID: "text-embedding-004",
    batch: GoogleEmbedContentBatch(payload: .object([:]))
)
```

The batches client also exposes `get`, `list`, `cancel`, `delete`, and update helpers for the provider-defined batch resources.
