# Support Matrix

This table describes the feature surface implemented by the SDK in v1.

| Provider | Text | Native Streaming | Structured Output | Tools | Image Input | Audio Input | File Input | Embeddings | Image Generation | Speech | Transcription |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OpenAI | Yes | Yes | Yes | Yes | Yes | No | No | Yes | Yes | Yes | Yes |
| Anthropic | Yes | Yes | Yes | Yes | Yes | No | No | No | No | No | No |
| Google | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | No | No |
| Gateway | Yes | Yes | Yes | Yes | Yes | No | No | Yes | Yes | No | No |

## Notes

- Gateway inherits the OpenAI-compatible request shape used by the current adapter.
- “Structured Output” means the SDK can request and decode JSON-shaped results through the unified `Schema<Value>` API.
- Capability validation happens before the HTTP request is sent, so unsupported combinations fail early with ``KaizoshaError/unsupportedCapability(modelID:capability:)``.
