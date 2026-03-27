# Google Parity Notes

`KaizoshaGoogle` now covers much more of the modern Gemini Developer API surface, but a few boundaries are still intentional.

## Stable vs Preview

- `generateContent`, model discovery, files, caches, file-search stores, batches, embeddings, and image-capable generation are treated as the main Google adapter surface.
- Interactions and Live stay in the same SwiftPM product, but they are documented as preview Google-only APIs.

## Provider-Neutral Boundaries

- Google audio generation and transcription are not forced into the shared `SpeechModel` and `TranscriptionModel` contracts yet.
- Those audio flows remain Google-specific through Live and Interactions until Google exposes stable dedicated REST surfaces that map cleanly to the shared abstractions.

## File Reuse

- Gemini prompt reuse relies on provider-managed file URIs.
- The shared `FileContent` type now carries both a provider file ID and a provider file URI so Google uploads can round-trip without forcing inline bytes.
