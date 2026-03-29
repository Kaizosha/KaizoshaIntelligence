# Provider Hardening Roadmap

This roadmap tracks the next quality and completeness improvements for the three primary direct providers: OpenAI, Anthropic, and Google.

## Current Priorities

- [x] Add a stronger provider-neutral live matrix for OpenAI, Anthropic, and Google covering shared language-model behavior:
  text generation, streaming, structured output, and tool calling.
- [ ] Refine capability resolution across all three providers so fewer features rely on model-name heuristics and more rely on provider metadata or explicit family rules.
- [ ] Expand Anthropic support beyond the current text-first surface where the provider API cleanly supports it.
- [ ] Enrich the shared streaming story with better retained metadata and more advanced provider-specific stream fidelity where it can be exposed safely.

## Why This Order

- Live/provider-matrix tests are the fastest way to catch drift across three providers without widening the public API.
- Capability resolution improvements reduce false positives and false negatives before requests are sent.
- Anthropic is the least complete of the three direct providers and will benefit most from targeted expansion work next.
- Streaming fidelity is already solid for the current v1 surface, so it is worth improving after the contract and capability layers are better protected.

## Notes

- The live matrix remains gated by provider API keys so the default local test run stays fast and inexpensive.
- Gateway work is intentionally excluded here because it follows the OpenAI-compatible route and should be validated separately from direct-provider behavior.
