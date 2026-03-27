# ``KaizoshaIntelligence``

@Metadata {
    @TechnologyRoot
}

Build provider-agnostic AI features in Swift with a unified, Apple-style API surface.

## Overview

Kaizosha Intelligence gives you a single Swift-first interface for:

- Text generation
- Streaming responses with `AsyncThrowingStream`
- Structured output with typed schemas
- Tool calling
- Embeddings
- Image generation
- Speech generation
- Transcription

The package is split into a provider-neutral core plus provider-specific adapters:

- ``KaizoshaProvider``
- ``KaizoshaOpenAI``
- ``KaizoshaAnthropic``
- ``KaizoshaGoogle``
- ``KaizoshaGateway``

## Topics

### Essentials

- <doc:QuickStart>
- <doc:ProvidersAndModels>
- <doc:PackageLayout>
- <doc:Streaming>

### Structured Workflows

- <doc:StructuredOutput>
- <doc:ToolCalling>
- <doc:Multimodal>
- <doc:SupportMatrix>

### OpenAI

- <doc:OpenAIResponses>
- <doc:OpenAIMedia>
- <doc:OpenAIRealtime>
- <doc:OpenAIParityNotes>

### Deployment

- <doc:GatewayUsage>
- <doc:ErrorHandling>
- <doc:ServerIntegration>
- <doc:KnownLimitations>
