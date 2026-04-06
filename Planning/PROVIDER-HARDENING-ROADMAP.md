# Provider Hardening Roadmap

This roadmap tracks the next quality and completeness improvements for the three primary direct providers: OpenAI, Anthropic, and Google.

## Current Priorities

- [x] Add a stronger provider-neutral live matrix for OpenAI, Anthropic, and Google covering shared language-model behavior:
  text generation, streaming, structured output, and tool calling.
- [x] Refine capability resolution across all three providers so fewer features rely on model-name heuristics and more rely on provider metadata or explicit family rules.
- [x] Expand Anthropic support beyond the current text-first surface where the provider API cleanly supports it.
- [ ] Enrich the shared streaming story with better retained metadata and more advanced provider-specific stream fidelity where it can be exposed safely.

## Why This Order

- Live/provider-matrix tests are the fastest way to catch drift across three providers without widening the public API.
- Capability resolution improvements reduce false positives and false negatives before requests are sent.
- Anthropic is the least complete of the three direct providers and will benefit most from targeted expansion work next.
- Streaming fidelity is already solid for the current v1 surface, so it is worth improving after the contract and capability layers are better protected.

## Completed Capability Refinements

- OpenAI capability resolution now distinguishes general Responses text models from audio-specialized models, so audio input and structured output are no longer over-claimed on the wrong families.
- Anthropic capability resolution now gates vision support to Claude 3 and Claude 4 era families instead of treating every Anthropic model identifier as vision-capable.
- Google capability resolution now treats provider-neutral reasoning controls as unsupported until they are actually mapped in requests, while keeping multimodal and tool support tied more closely to Gemini family rules.

## Completed Anthropic Expansion

- Anthropic now exposes provider-specific Files and token-counting services from `KaizoshaAnthropic`.
- Shared `MessagePart.file` input now maps to Anthropic Messages document blocks for inline PDF/plain-text documents and Anthropic `file_id` references.
- Anthropic capability resolution now exposes shared file input on Claude 3.5+/4 era families instead of leaving the feature disabled across the board.
- Anthropic prompt caching is now available through typed provider options, including automatic caching, explicit breakpoints, and surfaced cache usage counters.
- Anthropic stable web search is now available through typed server tools in `AnthropicProviderOptions.serverTools`, with early validation for name conflicts and unsupported dynamic-filtering variants.
- Anthropic stable code execution is now available through typed server tools, including `container_upload` file mapping, typed container reuse, and response helpers for container IDs plus generated file IDs.

## Notes

- The live matrix remains gated by provider API keys so the default local test run stays fast and inexpensive.
- Gateway work is intentionally excluded here because it follows the OpenAI-compatible route and should be validated separately from direct-provider behavior.
