# OpenAI Parity Notes

These notes call out the OpenAI-specific constraints that Kaizosha now enforces directly in the adapter.

## Realtime

- `createRealtimeClientSecret(_:)` is the primary helper for new work and follows the current GA `POST /v1/realtime/client_secrets` request shape with a nested `session` object.
- `createRealtimeSession(_:)` remains available as a compatibility helper for the older `/realtime/sessions` endpoint shape that is still present in the OpenAPI spec.
- Realtime voice selection is configured through `OpenAIRealtimeSessionRequest.audio.output.voice`, not through the speech endpoint helper APIs.

## Images

- GPT image models support generations, edits, and partial-image streaming.
- `images/variations` is currently a DALL-E 2-only endpoint, so `OpenAIImageModel.varyImage(request:)` fails early when used with GPT image models.

## Speech and Transcription

- `OpenAISpeechModel.builtInVoices` reflects the documented speech-endpoint voices. Custom voices are created with `createVoice(_:)`.
- `streamSpeech` is intentionally limited to GPT TTS models because the current OpenAI API does not support SSE speech streaming for `tts-1` or `tts-1-hd`.
- File transcription validates model-specific response-format rules before the request is sent.
- `gpt-4o-transcribe-diarize` supports diarized file transcription with known-speaker references, but diarization is not presented as a Realtime capability because the current OpenAI docs do not support that flow.
