# Package Layout

Kaizosha Intelligence is intentionally split into small modules so adopters only import the pieces they need.

## Modules

- `KaizoshaIntelligence`: high-level Swift-first APIs such as ``generateText(using:request:)`` and ``streamText(using:request:)``.
- `KaizoshaProvider`: shared protocols, message types, structured output types, tool abstractions, and capability metadata.
- `KaizoshaTransport`: shared HTTP transport utilities used by provider adapters.
- `KaizoshaOpenAI`: OpenAI-backed adapters.
- `KaizoshaAnthropic`: Anthropic-backed adapters.
- `KaizoshaGoogle`: Google Gemini-backed adapters.
- `KaizoshaGateway`: routed-model adapter backed by the OpenAI-compatible gateway API.

## Design Principle

The package keeps the public application-facing API provider-neutral, while letting each provider own its request mapping and capability profile.
