import Foundation
import KaizoshaAnthropic
import KaizoshaGateway
import KaizoshaGoogle
import KaizoshaOpenAI
import KaizoshaProvider
import KaizoshaTransport
import Testing

@Suite("Transport and Providers")
struct TransportAndProviderTests {
    @Test("SSE parser assembles events from line streams")
    func sseParserBuildsEvents() async throws {
        let lines = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("event: delta")
            continuation.yield("data: hello")
            continuation.yield("")
            continuation.yield("data: world")
            continuation.yield("")
            continuation.finish()
        }

        var events: [String] = []
        for try await event in ServerSentEventParser.parse(lines: lines) {
            events.append("\(event.event ?? "message"):\(event.data)")
        }

        #expect(events == ["delta:hello", "message:world"])
    }

    @Test("HTTP client retries retryable status codes")
    func httpClientRetries() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 503,
                body: Data("{\"error\":\"busy\"}".utf8)
            )
        )
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data("{\"ok\":true}".utf8)
            )
        )

        let client = HTTPClient(
            transport: transport,
            retryPolicy: RetryPolicy(maxAttempts: 2, backoff: .zero, retryStatusCodes: [503])
        )
        let value = try await client.sendJSON(
            HTTPRequest(url: URL(string: "https://example.com")!)
        )

        #expect(value.objectValue?["ok"]?.boolValue == true)
    }

    @Test("OpenAI adapter parses text and tool calls")
    func openAIAdapterParsesResponse() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "model": "gpt-test",
                      "choices": [{
                        "message": {
                          "content": "Hello from OpenAI",
                          "tool_calls": [{
                            "id": "call_1",
                            "function": {
                              "name": "lookup_weather",
                              "arguments": "{\\"city\\":\\"Tokyo\\"}"
                            }
                          }]
                        },
                        "finish_reason": "tool_calls"
                      }],
                      "usage": {
                        "prompt_tokens": 5,
                        "completion_tokens": 7,
                        "total_tokens": 12
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let response = try await provider.languageModel("gpt-test").generate(
            request: TextGenerationRequest(prompt: "Hello")
        )

        #expect(response.text == "Hello from OpenAI")
        #expect(response.toolInvocations.first?.name == "lookup_weather")
        #expect(response.usage?.totalTokens == 12)
    }

    @Test("OpenAI adapter streams text deltas and tool calls")
    func openAIStreamingParsesSSE() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}",
                "",
                "data: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}",
                "",
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"function\":{\"name\":\"lookup_weather\",\"arguments\":\"{}\"}}]},\"finish_reason\":\"tool_calls\"}]}",
                "",
                "data: [DONE]",
                "",
            ]
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let stream = provider.languageModel("gpt-test").stream(
            request: TextGenerationRequest(prompt: "Hello")
        )

        var text = ""
        var toolName: String?
        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                text += delta
            case .toolCall(let invocation):
                toolName = invocation.name
            default:
                break
            }
        }

        #expect(text == "Hello")
        #expect(toolName == "lookup_weather")
    }

    @Test("Anthropic adapter streams text deltas and tool calls")
    func anthropicStreamingParsesSSE() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "event: message_start",
                "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":3}}}",
                "",
                "event: content_block_delta",
                "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}",
                "",
                "event: content_block_start",
                "data: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"tool_1\",\"name\":\"lookup_weather\",\"input\":{}}}",
                "",
                "event: content_block_delta",
                "data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{}\"}}",
                "",
                "event: content_block_stop",
                "data: {\"type\":\"content_block_stop\",\"index\":1}",
                "",
                "event: message_delta",
                "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"},\"usage\":{\"output_tokens\":5}}",
                "",
                "event: message_stop",
                "data: {\"type\":\"message_stop\"}",
                "",
            ]
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let stream = provider.languageModel("claude-test").stream(
            request: TextGenerationRequest(prompt: "Hello")
        )

        var text = ""
        var toolName: String?
        var finishReason: FinishReason?
        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                text += delta
            case .toolCall(let invocation):
                toolName = invocation.name
            case .finished(let reason):
                finishReason = reason
            default:
                break
            }
        }

        #expect(text == "Hello")
        #expect(toolName == "lookup_weather")
        #expect(finishReason == .toolCalls)
    }

    @Test("Anthropic adapter parses text and tool use blocks")
    func anthropicAdapterParsesResponse() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "model": "claude-test",
                      "content": [
                        { "type": "text", "text": "Need a tool." },
                        { "type": "tool_use", "id": "tool_1", "name": "lookup_weather", "input": { "city": "Tokyo" } }
                      ],
                      "stop_reason": "tool_use",
                      "usage": { "input_tokens": 3, "output_tokens": 4 }
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let response = try await provider.languageModel("claude-test").generate(
            request: TextGenerationRequest(prompt: "Hello")
        )

        #expect(response.text == "Need a tool.")
        #expect(response.toolInvocations.first?.name == "lookup_weather")
        #expect(response.finishReason == .toolCalls)
    }

    @Test("Google adapter parses text and function calls")
    func googleAdapterParsesResponse() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "candidates": [{
                        "content": {
                          "parts": [
                            { "text": "Hi from Gemini" },
                            { "functionCall": { "name": "lookup_weather", "args": { "city": "Tokyo" } } }
                          ]
                        },
                        "finishReason": "STOP"
                      }],
                      "usageMetadata": {
                        "promptTokenCount": 4,
                        "candidatesTokenCount": 6,
                        "totalTokenCount": 10
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let response = try await provider.languageModel("gemini-test").generate(
            request: TextGenerationRequest(prompt: "Hello")
        )

        #expect(response.text == "Hi from Gemini")
        #expect(response.toolInvocations.first?.name == "lookup_weather")
        #expect(response.usage?.totalTokens == 10)
    }

    @Test("Google adapter streams text deltas and function calls")
    func googleStreamingParsesSSE() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hello \"}]}}]}",
                "",
                "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Gemini\"},{\"functionCall\":{\"name\":\"lookup_weather\",\"args\":{}}}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":2,\"candidatesTokenCount\":3,\"totalTokenCount\":5}}",
                "",
            ]
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let stream = provider.languageModel("gemini-test").stream(
            request: TextGenerationRequest(prompt: "Hello")
        )

        var text = ""
        var toolName: String?
        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                text += delta
            case .toolCall(let invocation):
                toolName = invocation.name
            default:
                break
            }
        }

        #expect(text == "Hello Gemini")
        #expect(toolName == "lookup_weather")
    }

    @Test("Capability validation rejects unsupported prompt parts")
    func capabilityValidationRejectsUnsupportedInputs() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.languageModel("gpt-test").generate(
                request: TextGenerationRequest(
                    messages: [
                        .user(parts: [
                            .text("Transcribe this."),
                            .audio(AudioContent(data: Data("audio".utf8))),
                        ]),
                    ]
                )
            )
        }
    }

    @Test("Gateway adapter supports routed model identifiers")
    func gatewayAdapterUsesRoutedModelID() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "model": "openai/gpt-test",
                      "choices": [{
                        "message": { "content": "Hello from Gateway" },
                        "finish_reason": "stop"
                      }]
                    }
                    """.utf8
                )
            )
        )

        let provider = try GatewayProvider(apiKey: "test", transport: transport)
        let response = try await provider.languageModel("openai/gpt-test").generate(
            request: TextGenerationRequest(prompt: "Hello")
        )

        #expect(response.text == "Hello from Gateway")
        #expect(response.modelID == "openai/gpt-test")
    }
}
