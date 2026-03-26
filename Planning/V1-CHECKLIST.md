# V1 Checklist

This file tracks the v1 release scope for Kaizosha Intelligence. Update it as work lands so the repo stays aligned with what “v1 ready” means.

## Core SDK

- [x] Multi-product SwiftPM layout
- [x] Provider-neutral core types and protocols
- [x] High-level APIs for text, streaming, structured output, tools, embeddings, images, speech, and transcription
- [x] Shared HTTP transport, retries, multipart handling, and SSE parsing
- [x] Capability metadata for models
- [x] Early capability validation before provider calls
- [x] Namespaced provider options for OpenAI, Anthropic, and Google
- [x] Public API pass for coherent Swift naming across the core surface

## Providers

- [x] OpenAI adapter
- [x] Anthropic adapter
- [x] Google adapter
- [x] Gateway adapter
- [x] Native incremental OpenAI streaming
- [x] Native incremental Anthropic streaming
- [x] Native incremental Google streaming
- [x] Routed `vendor/model` support for Gateway
- [x] Provider capability matrix documented in DocC

## Structured Output and Tools

- [x] `Schema<Value>`-based structured output
- [x] Typed tool definitions and registry
- [x] Single-step automatic tool execution
- [x] Tests for malformed structured output extraction
- [x] Tests for tool round-tripping
- [x] Clear docs for manual vs automatic tool execution

## Multimodal

- [x] Shared multimodal message parts
- [x] Provider-side validation for unsupported multimodal inputs
- [x] OpenAI image generation
- [x] OpenAI speech generation
- [x] OpenAI transcription
- [x] Google image generation
- [x] Support matrix documenting implemented vs unsupported modality flows

## Testing

- [x] Core SDK tests
- [x] Transport tests
- [x] Provider contract tests
- [x] Native streaming tests for OpenAI, Anthropic, and Google
- [x] Capability validation tests
- [x] Env-gated live integration tests
- [x] CI build and test workflow
- [x] DocC generation smoke check

## Documentation and Examples

- [x] Root DocC catalog
- [x] Quick Start guide
- [x] Providers and Models guide
- [x] Streaming guide
- [x] Structured Output guide
- [x] Tool Calling guide
- [x] Multimodal guide
- [x] Gateway guide
- [x] Error Handling guide
- [x] Server Integration guide
- [x] Support Matrix guide
- [x] Package Layout guide
- [x] Known Limitations guide
- [x] Runnable example targets
- [x] Repository README

## Release Hygiene

- [x] CHANGELOG
- [x] CONTRIBUTING guide
- [x] RELEASING guide
- [x] License file
- [x] Issue templates

## Notes

- Gateway currently uses the OpenAI-compatible provider path and inherits that capability profile.
- Anthropic and Google language streaming are implemented natively, but the SDK intentionally stays out of full multi-step agent-runtime orchestration for v1.
