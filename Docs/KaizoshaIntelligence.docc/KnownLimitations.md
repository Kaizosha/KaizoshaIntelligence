# Known Limitations

These constraints are intentional in v1.

## Scope Boundaries

- The SDK does not include a chat state store, UI hooks, or SwiftUI view layer.
- The SDK does not include a full autonomous multi-step agent runtime.
- Tool execution is intentionally limited to manual mode or a single deterministic automatic follow-up round.

## Provider Notes

- OpenAI built-in voice discovery is exposed as a documented built-in list plus custom-voice creation; there is no separate provider-neutral voice abstraction in v1.
- OpenAI Realtime is GA-first around `createRealtimeClientSecret(_:)`; `createRealtimeSession(_:)` remains as a compatibility helper because OpenAI still publishes the older endpoint shape in its OpenAPI spec.
- OpenAI image variations follow the current provider API and are restricted to `dall-e-2`.
- OpenAI diarized transcription is implemented for `/audio/transcriptions` and is not presented as a Realtime capability.
- OpenAI `chatCompletionsModel(_:)` is retained for migration safety and intentionally accepts only the subset of provider options that make sense for the legacy API.
- Anthropic support in v1 is focused on text, tool use, structured output, image input, file/document input, and token counting.
- Anthropic shared file input is intentionally conservative: inline file bytes currently support PDF and plain text, while broader file reuse should flow through Anthropic file uploads and `file_id` references.
- Anthropic prompt caching is typed and supported, but the current system-prompt mapping still treats all system messages as one combined block for explicit cache breakpoints.
- Anthropic stable web search is supported through typed server tools, but the newer dynamic filtering variant still needs a dedicated typed SDK surface.
- Anthropic code execution is supported on the documented compatible model families, but long-running `pause_turn` continuation is not yet modeled as a provider-neutral continuation API.
- Google support now covers most of the modern Gemini Developer API surface, but some pieces intentionally remain Google-only instead of being forced into the shared provider-neutral contracts.
- Google Interactions and Live are implemented as preview Google-specific APIs. The shared `SpeechModel` and `TranscriptionModel` abstractions are still reserved for providers with stable dedicated REST surfaces that map cleanly to those contracts.
- Gateway support in v1 follows the OpenAI-compatible route used by the current adapter.

## Compatibility Notes

- Provider APIs evolve independently. The shared capability layer is designed to fail early when the SDK does not implement a specific combination.
