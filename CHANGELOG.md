# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0 - 2026-04-06

- Expanded `KaizoshaOpenAI` into a Responses-first OpenAI adapter with raw Responses APIs, richer request validation, file helpers, GPT-image/media coverage, and GA-first Realtime support.
- Expanded `KaizoshaGoogle` to cover much more of the Gemini Developer API, including raw content models, token counting, files, cached contents, file-search stores, generated files, batch jobs, Interactions, and Live APIs.
- Expanded `KaizoshaAnthropic` with Files and token counting, typed prompt caching, stable web search, and stable code execution including `container_upload` mapping, container reuse, and execution-artifact helpers.
- Added live provider model discovery for OpenAI, Anthropic, Google, and Gateway.
- Hardened streaming across providers, including incremental Linux line streaming, better streamed tool handling, and CI coverage for the streaming fixes.
- Refined provider capability resolution and added a stronger live provider matrix covering text generation, streaming, structured output, and tool calling.
- Expanded docs, examples, CI smoke builds, and provider-specific guidance across OpenAI, Google, and Anthropic.

## 0.1.0 - 2026-03-25

- Added a multi-product SwiftPM SDK layout with provider-neutral core contracts.
- Added high-level APIs for text generation, streaming, structured output, tool calling, embeddings, image generation, speech generation, and transcription.
- Added provider adapters for OpenAI, Anthropic, Google, and Vercel AI Gateway.
- Added native streaming implementations for OpenAI, Anthropic, and Google text generation.
- Added DocC documentation, runnable examples, Swift Testing coverage, CI, and release metadata.
