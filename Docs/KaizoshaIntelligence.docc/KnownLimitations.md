# Known Limitations

These constraints are intentional in v1.

## Scope Boundaries

- The SDK does not include a chat state store, UI hooks, or SwiftUI view layer.
- The SDK does not include a full autonomous multi-step agent runtime.
- Tool execution is intentionally limited to manual mode or a single deterministic automatic follow-up round.

## Provider Notes

- Anthropic support in v1 is focused on text, tool use, structured output, and image input.
- Google support in v1 is focused on Gemini text, streaming, tools, embeddings, image-capable generation, and multimodal prompt parts.
- Gateway support in v1 follows the OpenAI-compatible route used by the current adapter.

## Compatibility Notes

- Provider APIs evolve independently. The shared capability layer is designed to fail early when the SDK does not implement a specific combination.
