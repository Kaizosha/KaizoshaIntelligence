# Support Matrix

This table describes the feature surface implemented by the SDK in v1.

| Provider | Text | Native Streaming | Structured Output | Tools | Image Input | Audio Input | File Input | Embeddings | Image Generation | Speech | Transcription | Realtime |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OpenAI | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Anthropic | Yes | Yes | Yes | Yes | Yes | No | No | No | No | No | No | No |
| Google | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | No | No | No |
| Gateway | Yes | Yes | Yes | Yes | Yes | No | No | Yes | Yes | No | No | No |

## Notes

- Gateway inherits the OpenAI-compatible request shape used by the current adapter.
- OpenAI file input, audio input, reasoning controls, and Realtime are model-family dependent. The capability layer resolves those features from the selected model identifier before sending the request.
- OpenAI image variations are limited to `dall-e-2`, even though GPT image models still support generations, edits, and partial-image streaming.
- OpenAI speech streaming is available on GPT TTS models, not on `tts-1` or `tts-1-hd`.
- OpenAI transcription response formats are model dependent. The SDK validates those combinations before dispatch, including diarization-only options and the current Realtime diarization gap.
- “Structured Output” means the SDK can request and decode JSON-shaped results through the unified `Schema<Value>` API.
- Capability validation happens before the HTTP request is sent, so unsupported combinations fail early with ``KaizoshaError/unsupportedCapability(modelID:capability:)``.
