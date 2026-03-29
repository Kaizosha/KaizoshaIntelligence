# Support Matrix

This table describes the feature surface implemented by the SDK in v1.

| Provider | Text | Native Streaming | Structured Output | Tools | Image Input | Audio Input | File Input | Embeddings | Image Generation | Speech | Transcription | Realtime |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OpenAI | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Anthropic | Yes | Yes | Yes | Yes | Yes | No | Yes | No | No | No | No | No |
| Google | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Google-only Preview | Google-only Preview | Google-only Preview |
| Gateway | Yes | Yes | Yes | Yes | Yes | No | No | Yes | Yes | No | No | No |

## Notes

- Gateway inherits the OpenAI-compatible request shape used by the current adapter.
- OpenAI file input, audio input, reasoning controls, and Realtime are model-family dependent. The capability layer resolves those features from the selected model identifier before sending the request.
- Anthropic image input is model-family dependent. The current adapter treats Claude 3 and Claude 4 era models as vision-capable, and shared file input is available on Claude 3.5+/4 era models for inline PDF/plain-text documents and Anthropic `file_id` references.
- Google now exposes provider-specific models, token counting, files, cached contents, file-search stores, generated files, batch operations, Interactions, and Live from `KaizoshaGoogle` without forcing those resource models into the provider-neutral core.
- Google Realtime, speech, and transcription support currently live in Google-only preview APIs instead of the shared `SpeechModel` and `TranscriptionModel` protocols.
- Google provider-specific thinking controls exist through Google options, but provider-neutral reasoning controls remain disabled until the shared `GenerationConfig.reasoning` knob is mapped explicitly for Gemini requests.
- OpenAI image variations are limited to `dall-e-2`, even though GPT image models still support generations, edits, and partial-image streaming.
- OpenAI speech streaming is available on GPT TTS models, not on `tts-1` or `tts-1-hd`.
- OpenAI transcription response formats are model dependent. The SDK validates those combinations before dispatch, including diarization-only options and the current Realtime diarization gap.
- “Structured Output” means the SDK can request and decode JSON-shaped results through the unified `Schema<Value>` API.
- Capability validation happens before the HTTP request is sent, so unsupported combinations fail early with ``KaizoshaError/unsupportedCapability(modelID:capability:)``.
