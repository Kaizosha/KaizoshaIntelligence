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

    @Test("Streaming line buffer preserves chunk boundaries and blank lines")
    func streamingLineBufferHandlesChunkedData() {
        var buffer = StreamingLineBuffer()

        #expect(buffer.append(Data("data: hel".utf8)).isEmpty)
        #expect(buffer.append(Data("lo\n\nid: evt_1".utf8)) == ["data: hello", ""])
        #expect(buffer.finish() == ["id: evt_1"])
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

    @Test("OpenAI provider lists models from the live catalog endpoint")
    func openAIProviderListsModels() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "data": [
                        {
                          "id": "gpt-4o-mini",
                          "created": 1721173200,
                          "owned_by": "openai"
                        }
                      ]
                    }
                    """.utf8
                )
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let models = try await provider.listModels()

        #expect(models.count == 1)
        #expect(models.first?.id == "gpt-4o-mini")
        #expect(models.first?.ownedBy == "openai")
        #expect(models.first?.provider == OpenAIProvider.namespace)
    }

    @Test("Anthropic provider paginates model catalog responses")
    func anthropicProviderListsModelsAcrossPages() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "data": [
                        {
                          "id": "claude-3-5-haiku-latest",
                          "display_name": "Claude 3.5 Haiku",
                          "created_at": "2024-06-01T12:00:00Z"
                        }
                      ],
                      "has_more": true,
                      "last_id": "claude-3-5-haiku-latest"
                    }
                    """.utf8
                )
            )
        )
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "data": [
                        {
                          "id": "claude-3-7-sonnet-latest",
                          "display_name": "Claude 3.7 Sonnet",
                          "created_at": "2024-10-22T12:00:00Z"
                        }
                      ],
                      "has_more": false,
                      "last_id": "claude-3-7-sonnet-latest"
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let models = try await provider.listModels()

        #expect(models.map(\.id) == ["claude-3-5-haiku-latest", "claude-3-7-sonnet-latest"])
        #expect(models.first?.displayName == "Claude 3.5 Haiku")
        #expect(models.allSatisfy { $0.provider == AnthropicProvider.namespace })
    }

    @Test("Google provider normalizes live model catalog identifiers")
    func googleProviderListsModels() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "models": [
                        {
                          "name": "models/gemini-2.0-flash",
                          "baseModelId": "gemini-2.0-flash",
                          "displayName": "Gemini 2.0 Flash",
                          "inputTokenLimit": 1048576,
                          "outputTokenLimit": 8192,
                          "supportedGenerationMethods": ["generateContent"]
                        }
                      ],
                      "nextPageToken": "page-2"
                    }
                    """.utf8
                )
            )
        )
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "models": [
                        {
                          "name": "models/text-embedding-004",
                          "baseModelId": "text-embedding-004",
                          "displayName": "Text Embedding 004",
                          "supportedGenerationMethods": ["embedContent"]
                        }
                      ]
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let models = try await provider.listModels()

        #expect(models.count == 2)
        #expect(models.first?.id == "gemini-2.0-flash")
        #expect(models.first?.providerIdentifier == "models/gemini-2.0-flash")
        #expect(models.first?.contextWindow == 1_048_576)
        #expect(models.first?.supportedGenerationMethods == ["generateContent"])
        #expect(models.last?.id == "text-embedding-004")
    }

    @Test("Gateway provider lists routed models from the catalog endpoint")
    func gatewayProviderListsModels() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "data": [
                        {
                          "id": "openai/gpt-4o-mini",
                          "name": "GPT-4o mini",
                          "type": "language",
                          "context_window": 128000,
                          "max_tokens": 16384
                        }
                      ]
                    }
                    """.utf8
                )
            )
        )

        let provider = try GatewayProvider(apiKey: "test", transport: transport)
        let models = try await provider.listModels()

        #expect(models.count == 1)
        #expect(models.first?.id == "openai/gpt-4o-mini")
        #expect(models.first?.displayName == "GPT-4o mini")
        #expect(models.first?.type == "language")
        #expect(models.first?.provider == GatewayProvider.namespace)
    }

    @Test("OpenAI capability resolution differentiates text and audio response families")
    func openAICapabilityResolutionUsesExplicitFamilies() throws {
        let provider = try OpenAIProvider(apiKey: "test", transport: MockHTTPTransport())

        let textModel = provider.languageModel("gpt-4o-mini")
        #expect(textModel.capabilities.supportsStructuredOutput)
        #expect(textModel.capabilities.supportsToolCalling)
        #expect(textModel.capabilities.supportsImageInput)
        #expect(textModel.capabilities.supportsAudioInput == false)

        let audioModel = provider.languageModel("gpt-4o-audio-preview")
        #expect(audioModel.capabilities.supportsToolCalling)
        #expect(audioModel.capabilities.supportsStructuredOutput == false)
        #expect(audioModel.capabilities.supportsAudioInput)
        #expect(audioModel.capabilities.supportsImageInput == false)

        let reasoningModel = provider.languageModel("gpt-5")
        #expect(reasoningModel.capabilities.supportsReasoningControls)
    }

    @Test("Anthropic capability resolution gates image input to Claude 3 and 4 families")
    func anthropicCapabilityResolutionUsesModelFamilies() throws {
        let provider = try AnthropicProvider(apiKey: "test", transport: MockHTTPTransport())

        let legacyModel = provider.languageModel("claude-2.1")
        #expect(legacyModel.capabilities.supportsImageInput == false)
        #expect(legacyModel.capabilities.supportsToolCalling)
        #expect(legacyModel.capabilities.supportsStructuredOutput)
        #expect(legacyModel.capabilities.supportsFileInput == false)

        let modernModel = provider.languageModel("claude-3-7-sonnet-latest")
        #expect(modernModel.capabilities.supportsImageInput)
        #expect(modernModel.capabilities.supportsFileInput)
        #expect(modernModel.capabilities.supportsReasoningControls == false)
    }

    @Test("Google capability resolution avoids advertising provider-neutral reasoning controls")
    func googleCapabilityResolutionDisablesSharedReasoningControl() throws {
        let provider = try GoogleProvider(apiKey: "test", transport: MockHTTPTransport())

        let textModel = provider.languageModel("gemini-2.0-flash")
        #expect(textModel.capabilities.supportsToolCalling)
        #expect(textModel.capabilities.supportsStructuredOutput)
        #expect(textModel.capabilities.supportsImageInput)
        #expect(textModel.capabilities.supportsAudioInput)
        #expect(textModel.capabilities.supportsFileInput)
        #expect(textModel.capabilities.supportsReasoningControls == false)

        let imageGenerationModel = provider.languageModel("gemini-2.0-flash-preview-image-generation")
        #expect(imageGenerationModel.capabilities.supportsToolCalling == false)
        #expect(imageGenerationModel.capabilities.supportsStructuredOutput)
        #expect(imageGenerationModel.capabilities.supportsImageInput)
        #expect(imageGenerationModel.capabilities.supportsAudioInput)
        #expect(imageGenerationModel.capabilities.supportsReasoningControls == false)
    }

    @Test("OpenAI Responses adapter parses text and tool calls")
    func openAIAdapterParsesResponse() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "resp_123",
                      "model": "gpt-test",
                      "status": "completed",
                      "output": [
                        {
                          "id": "msg_1",
                          "type": "message",
                          "role": "assistant",
                          "content": [
                            {
                              "type": "output_text",
                              "text": "Hello from OpenAI"
                            }
                          ]
                        },
                        {
                          "id": "fc_1",
                          "type": "function_call",
                          "call_id": "call_1",
                          "name": "lookup_weather",
                          "arguments": "{\\"city\\":\\"Tokyo\\"}"
                        }
                      ],
                      "usage": {
                        "input_tokens": 5,
                        "output_tokens": 7,
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

    @Test("OpenAI Responses adapter streams text deltas and tool calls")
    func openAIStreamingParsesSSE() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_1\",\"model\":\"gpt-test\",\"status\":\"in_progress\"}}",
                "",
                "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Hel\"}",
                "",
                "data: {\"type\":\"response.output_text.delta\",\"delta\":\"lo\"}",
                "",
                "data: {\"type\":\"response.output_item.done\",\"item\":{\"id\":\"fc_1\",\"type\":\"function_call\",\"call_id\":\"call_1\",\"name\":\"lookup_weather\",\"arguments\":\"{}\"}}",
                "",
                "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_1\",\"model\":\"gpt-test\",\"status\":\"completed\",\"output\":[{\"id\":\"msg_1\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"Hello\"}]},{\"id\":\"fc_1\",\"type\":\"function_call\",\"call_id\":\"call_1\",\"name\":\"lookup_weather\",\"arguments\":\"{}\"}]}}",
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

    @Test("OpenAI Responses requests map advanced provider options")
    func openAIResponsesRequestsMapAdvancedOptions() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "resp_advanced",
                      "model": "gpt-5",
                      "status": "completed",
                      "output": [
                        {
                          "id": "msg_1",
                          "type": "message",
                          "role": "assistant",
                          "content": [
                            {
                              "type": "output_text",
                              "text": "Done"
                            }
                          ]
                        }
                      ]
                    }
                    """.utf8
                )
            )
        )

        var providerOptions = ProviderOptions()
        providerOptions.setOpenAI(
            OpenAIProviderOptions(
                user: "user_123",
                instructions: "Respond tersely.",
                conversationID: "conv_123",
                store: true,
                background: true,
                promptCacheKey: "cache-key",
                promptCacheRetention: .extended24Hours,
                include: ["reasoning.summary"],
                serviceTier: .flex,
                parallelToolCalls: false,
                safetyIdentifier: "safety-user",
                nativeTools: [.webSearch()],
                reasoningSummary: .concise,
                verbosity: .low
            )
        )

        let tools = ToolRegistry([
            AnyTool(
                name: "lookup_weather",
                description: "Look up the forecast.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("city")]),
                ]),
                execute: { _, _ in
                    .object(["forecast": .string("sunny")])
                }
            ),
        ])

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        _ = try await provider.languageModel("gpt-5").generate(
            request: TextGenerationRequest(
                messages: [
                    .system("System direction."),
                    .user("Hello"),
                ],
                generation: GenerationConfig(reasoning: .medium),
                tools: tools,
                providerOptions: providerOptions,
                metadata: ["trace_id": "trace-123"]
            )
        )

        let body = try decodeRequestBody(from: transport)
        let object = try #require(body.objectValue)
        let input = try #require(object["input"]?.arrayValue)
        let developerMessage = try #require(input.first?.objectValue)
        let toolsPayload = try #require(object["tools"]?.arrayValue)
        let reasoning = try #require(object["reasoning"]?.objectValue)
        let text = try #require(object["text"]?.objectValue)
        let metadata = try #require(object["metadata"]?.objectValue)

        #expect(object["instructions"]?.stringValue == "Respond tersely.")
        #expect(object["conversation"]?.objectValue?["id"]?.stringValue == "conv_123")
        #expect(object["store"]?.boolValue == true)
        #expect(object["background"]?.boolValue == true)
        #expect(object["prompt_cache_key"]?.stringValue == "cache-key")
        #expect(object["prompt_cache_retention"]?.stringValue == "24h")
        #expect(object["include"]?.arrayValue?.compactMap(\.stringValue) == ["reasoning.summary"])
        #expect(object["service_tier"]?.stringValue == "flex")
        #expect(object["parallel_tool_calls"]?.boolValue == false)
        #expect(object["safety_identifier"]?.stringValue == "safety-user")
        #expect(object["tool_choice"]?.stringValue == "auto")
        #expect(object["user"] == nil)
        #expect(reasoning["effort"]?.stringValue == "medium")
        #expect(reasoning["summary"]?.stringValue == "concise")
        #expect(text["verbosity"]?.stringValue == "low")
        #expect(metadata["trace_id"]?.stringValue == "trace-123")
        #expect(developerMessage["role"]?.stringValue == "developer")
        #expect(toolsPayload.count == 2)
        #expect(toolsPayload.last?.objectValue?["type"]?.stringValue == "web_search")
    }

    @Test("OpenAI Responses reject previousResponseID and conversationID together")
    func openAIResponsesRejectMixedConversationState() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)

        var providerOptions = ProviderOptions()
        providerOptions.setOpenAI(
            OpenAIProviderOptions(
                previousResponseID: "resp_previous",
                conversationID: "conv_123"
            )
        )

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.languageModel("gpt-5").generate(
                request: TextGenerationRequest(
                    prompt: "Hello",
                    providerOptions: providerOptions
                )
            )
        }
    }

    @Test("OpenAI Responses reject GPT-5 verbosity on unsupported model families")
    func openAIResponsesRejectUnsupportedVerbosity() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)

        var providerOptions = ProviderOptions()
        providerOptions.setOpenAI(OpenAIProviderOptions(verbosity: .low))

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.languageModel("gpt-4o-mini").generate(
                request: TextGenerationRequest(
                    prompt: "Hello",
                    providerOptions: providerOptions
                )
            )
        }
    }

    @Test("OpenAI raw response API preserves provider-specific output items")
    func openAIRawResponseAPIPreservesProviderSpecificItems() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "resp_raw",
                      "model": "gpt-5",
                      "status": "completed",
                      "output": [
                        {
                          "id": "msg_1",
                          "type": "message",
                          "role": "assistant",
                          "content": [
                            {
                              "type": "output_text",
                              "text": "Done"
                            }
                          ]
                        },
                        {
                          "id": "ws_1",
                          "type": "web_search_call",
                          "status": "completed",
                          "summary": [
                            {
                              "text": "Searched the web."
                            }
                          ]
                        }
                      ]
                    }
                    """.utf8
                )
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let response = try await provider.responsesModel("gpt-5").createResponse(
            OpenAIResponseRequest(input: [.user("Find the answer.")])
        )

        #expect(response.id == "resp_raw")
        #expect(response.output.count == 2)
        #expect(response.output.last?.type == "web_search_call")
        #expect(response.output.last?.summaries == ["Searched the web."])
    }

    @Test("OpenAI legacy chat completions adapter remains available")
    func openAILegacyChatCompletionsModelStillWorks() async throws {
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
                          "content": "Hello from legacy OpenAI",
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
        let response = try await provider.chatCompletionsModel("gpt-test").generate(
            request: TextGenerationRequest(prompt: "Hello")
        )

        #expect(response.text == "Hello from legacy OpenAI")
        #expect(response.toolInvocations.first?.name == "lookup_weather")
        #expect(response.usage?.totalTokens == 12)
    }

    @Test("OpenAI legacy chat completions ignore Responses-only provider options")
    func openAILegacyChatCompletionsIgnoreResponsesOnlyOptions() async throws {
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
                          "content": "Legacy OpenAI"
                        },
                        "finish_reason": "stop"
                      }]
                    }
                    """.utf8
                )
            )
        )

        var providerOptions = ProviderOptions()
        providerOptions.setOpenAI(
            OpenAIProviderOptions(
                user: "legacy-user",
                instructions: "Ignore this for chat completions.",
                previousResponseID: "resp_previous",
                conversationID: "conv_123",
                background: true,
                nativeTools: [.webSearch()]
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        _ = try await provider.chatCompletionsModel("gpt-test").generate(
            request: TextGenerationRequest(
                prompt: "Hello",
                providerOptions: providerOptions
            )
        )

        let body = try decodeRequestBody(from: transport)
        let object = try #require(body.objectValue)

        #expect(object["user"]?.stringValue == "legacy-user")
        #expect(object["instructions"] == nil)
        #expect(object["previous_response_id"] == nil)
        #expect(object["conversation_id"] == nil)
        #expect(object["background"] == nil)
        #expect(object["native_tools"] == nil)
    }

    @Test("OpenAI file helpers upload and retrieve file metadata")
    func openAIFileHelpersRoundTripMetadata() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "file_123",
                      "filename": "notes.txt",
                      "bytes": 12,
                      "purpose": "assistants"
                    }
                    """.utf8
                )
            )
        )
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "file_123",
                      "filename": "notes.txt",
                      "bytes": 12,
                      "purpose": "assistants"
                    }
                    """.utf8
                )
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let uploaded = try await provider.uploadFile(
            OpenAIFileUploadRequest(
                data: Data("hello world!".utf8),
                fileName: "notes.txt",
                mimeType: "text/plain"
            )
        )
        let retrieved = try await provider.retrieveFile("file_123")

        #expect(uploaded.id == "file_123")
        #expect(retrieved.fileName == "notes.txt")
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].url.path.hasSuffix("/files"))
        #expect(transport.requests[0].headers["Content-Type"]?.contains("multipart/form-data") == true)
        #expect(transport.requests[1].url.path.hasSuffix("/files/file_123"))
    }

    @Test("OpenAI realtime session helpers and websocket client work together")
    func openAIRealtimeHelpersWorkTogether() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "value": "ek_test_123",
                      "expires_at": 1735689600,
                      "session": {
                        "id": "sess_123",
                        "type": "realtime",
                        "model": "gpt-realtime",
                        "audio": {
                          "output": {
                            "voice": "marin"
                          }
                        }
                      },
                      "client_secret": {
                        "value": "ek_test_legacy"
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let session = try await provider.createRealtimeClientSecret(
            OpenAIRealtimeSessionRequest(
                modelID: "gpt-realtime",
                instructions: "Be helpful.",
                outputModalities: ["audio"],
                audio: OpenAIRealtimeAudioConfiguration(
                    output: OpenAIRealtimeOutputAudioConfiguration(voice: "marin")
                ),
                include: ["response.output_text.logprobs"]
            )
        )

        #expect(session.id == "sess_123")
        #expect(session.clientSecret == "ek_test_123")
        #expect(transport.requests.first?.url.path.hasSuffix("/realtime/client_secrets") == true)

        let sessionBody = try decodeRequestBody(from: transport)
        let sessionObject = try #require(sessionBody.objectValue?["session"]?.objectValue)
        #expect(sessionObject["instructions"]?.stringValue == "Be helpful.")
        #expect(sessionObject["output_modalities"]?.arrayValue?.compactMap(\.stringValue) == ["audio"])
        #expect(sessionObject["audio"]?.objectValue?["output"]?.objectValue?["voice"]?.stringValue == "marin")

        let websocket = MockWebSocketTransport()
        await websocket.connection.enqueue(text: #"{"type":"response.output_text.delta","delta":"Hello"}"#)
        await websocket.connection.enqueue(text: #"{"type":"response.done"}"#)

        let client = try provider.realtimeClient(
            modelID: "gpt-realtime",
            clientSecret: "ek_test_123",
            transport: websocket
        )

        try await client.send(.responseCreate())
        let sentTexts = await websocket.connection.sentTexts
        #expect(sentTexts.count == 1)
        let websocketRequests = await websocket.requests
        #expect(websocketRequests.first?.url.absoluteString.contains("model=gpt-realtime") == true)

        var sawTextDelta = false
        var sawCompletion = false
        for try await event in await client.events() {
            switch event {
            case .responseTextDelta(let delta):
                sawTextDelta = (delta == "Hello")
            case .responseCompleted:
                sawCompletion = true
            default:
                break
            }

            if sawTextDelta && sawCompletion {
                break
            }
        }

        #expect(sawTextDelta)
        #expect(sawCompletion)
    }

    @Test("OpenAI compatibility realtime sessions keep the flat request shape")
    func openAIRealtimeSessionCompatibilityHelperUsesFlatPayload() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "sess_compat",
                      "type": "realtime",
                      "model": "gpt-realtime",
                      "client_secret": {
                        "value": "ek_compat"
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let _ = try await provider.createRealtimeSession(
            OpenAIRealtimeSessionRequest(
                modelID: "gpt-realtime",
                voice: "alloy"
            )
        )

        let body = try decodeRequestBody(from: transport)
        #expect(body.objectValue?["model"]?.stringValue == "gpt-realtime")
        #expect(body.objectValue?["audio"]?.objectValue?["output"]?.objectValue?["voice"]?.stringValue == "alloy")
        #expect(body.objectValue?["session"] == nil)
    }

    @Test("OpenAI image variations reject non-dall-e-2 models")
    func openAIImageVariationsRejectUnsupportedModels() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.imageModel("gpt-image-1").varyImage(
                request: OpenAIImageVariationRequest(image: Data("png".utf8))
            )
        }
    }

    @Test("OpenAI speech streaming rejects legacy tts models")
    func openAISpeechStreamingRejectsLegacyTTSModels() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)
        let stream = provider.speechModel("tts-1").streamSpeech(
            request: SpeechGenerationRequest(prompt: "Hello", voice: "alloy")
        )

        var iterator = stream.makeAsyncIterator()
        await #expect(throws: KaizoshaError.self) {
            _ = try await iterator.next()
        }
    }

    @Test("OpenAI transcription validation rejects unsupported format combinations")
    func openAITranscriptionValidationRejectsUnsupportedFormats() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.transcriptionModel("gpt-4o-mini-transcribe").transcribeDetailed(
                request: TranscriptionRequest(
                    audio: Data("audio".utf8),
                    fileName: "clip.wav",
                    mimeType: "audio/wav"
                ),
                options: OpenAITranscriptionOptions(responseFormat: .verboseJSON)
            )
        }
    }

    @Test("OpenAI diarized transcription validation rejects prompt and logprobs")
    func openAIDiarizedTranscriptionValidationRejectsUnsupportedOptions() async throws {
        let transport = MockHTTPTransport()
        let provider = try OpenAIProvider(apiKey: "test", transport: transport)

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.transcriptionModel("gpt-4o-transcribe-diarize").transcribeDetailed(
                request: TranscriptionRequest(
                    audio: Data("audio".utf8),
                    fileName: "meeting.wav",
                    mimeType: "audio/wav",
                    prompt: "Continue the last segment."
                ),
                options: OpenAITranscriptionOptions(
                    responseFormat: .diarizedJSON,
                    includeLogprobs: true
                )
            )
        }
    }

    @Test("Anthropic adapter streams text deltas and tool calls")
    func anthropicStreamingParsesSSE() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "event: message_start",
                "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":3,\"cache_read_input_tokens\":10,\"cache_creation_input_tokens\":2}}}",
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
        var usage: Usage?
        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                text += delta
            case .toolCall(let invocation):
                toolName = invocation.name
            case .usage(let value):
                usage = value
            case .finished(let reason):
                finishReason = reason
            default:
                break
            }
        }

        #expect(text == "Hello")
        #expect(toolName == "lookup_weather")
        #expect(finishReason == .toolCalls)
        #expect(usage?.cacheReadInputTokens == 10)
        #expect(usage?.cacheCreationInputTokens == 2)
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
                      "usage": {
                        "input_tokens": 3,
                        "cache_read_input_tokens": 12,
                        "cache_creation_input_tokens": 1,
                        "output_tokens": 4
                      }
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
        #expect(response.usage?.cacheReadInputTokens == 12)
        #expect(response.usage?.cacheCreationInputTokens == 1)
    }

    @Test("Anthropic adapter maps provider-managed files into document blocks")
    func anthropicAdapterMapsProviderManagedFiles() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "model": "claude-3-5-sonnet-latest",
                      "content": [{ "type": "text", "text": "Loaded" }],
                      "stop_reason": "end_turn",
                      "usage": {
                        "input_tokens": 8,
                        "output_tokens": 2
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        _ = try await provider.languageModel("claude-3-5-sonnet-latest").generate(
            request: TextGenerationRequest(
                messages: [
                    .user(parts: [
                        .file(
                            FileContent(
                                providerFileID: "file_123",
                                providerNamespace: AnthropicProvider.namespace,
                                mimeType: "application/pdf"
                            )
                        ),
                        .text("Summarize this document."),
                    ]),
                ]
            )
        )

        let request = try #require(transport.requests[safe: 0])
        #expect(request.headers["anthropic-beta"] == anthropicFilesBeta)

        let body = try decodeRequestBody(from: transport)
        let content = try #require(
            body.objectValue?["messages"]?.arrayValue?.first?.objectValue?["content"]?.arrayValue
        )
        let document = try #require(content.first?.objectValue)

        #expect(document["type"]?.stringValue == "document")
        #expect(document["source"]?.objectValue?["type"]?.stringValue == "file")
        #expect(document["source"]?.objectValue?["file_id"]?.stringValue == "file_123")
    }

    @Test("Anthropic files upload uses the beta multipart API")
    func anthropicFilesUploadUsesMultipartBeta() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "id": "file_123",
                      "filename": "brief.pdf",
                      "mime_type": "application/pdf",
                      "size_bytes": 128
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let file = try await provider.files.upload(
            AnthropicFileUploadRequest(
                data: Data("brief".utf8),
                fileName: "brief.pdf",
                mimeType: "application/pdf"
            )
        )

        #expect(file.id == "file_123")
        #expect(file.mimeType == "application/pdf")

        let request = try #require(transport.requests[safe: 0])
        #expect(request.url.absoluteString.hasSuffix("/v1/files"))
        #expect(request.headers["anthropic-beta"] == anthropicFilesBeta)
        #expect(request.headers["Content-Type"]?.contains("multipart/form-data") == true)

        let bodyString = String(data: try #require(request.body), encoding: .utf8)
        #expect(bodyString?.contains("name=\"file\"; filename=\"brief.pdf\"") == true)
    }

    @Test("Anthropic token counting reuses the Messages payload shape")
    func anthropicTokenCountingMapsMessagesPayload() async throws {
        struct WeatherInput: Codable, Sendable {
            let city: String
        }

        struct WeatherOutput: Codable, Sendable {
            let summary: String
        }

        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "input_tokens": 42
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let tool = Tool<WeatherInput, WeatherOutput>(
            name: "lookup_weather",
            description: "Fetches weather.",
            inputSchema: Schema(
                name: "WeatherInput",
                description: "Weather lookup input.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                    "required": .array([.string("city")]),
                ])
            )
        ) { input, _ in
            WeatherOutput(summary: input.city)
        }

        let response = try await provider.tokens.countTokens(
            modelID: "claude-3-5-sonnet-latest",
            request: TextGenerationRequest(
                messages: [
                    .system("You are concise."),
                    .user(parts: [
                        .file(
                            FileContent(
                                providerFileID: "file_abc",
                                providerNamespace: AnthropicProvider.namespace,
                                mimeType: "application/pdf"
                            )
                        ),
                        .text("Summarize the document."),
                    ]),
                ],
                tools: ToolRegistry([tool])
            )
        )

        #expect(response.inputTokens == 42)

        let request = try #require(transport.requests[safe: 0])
        #expect(request.url.absoluteString.hasSuffix("/v1/messages/count_tokens"))
        #expect(request.headers["anthropic-beta"] == anthropicFilesBeta)

        let body = try decodeRequestBody(from: transport)
        #expect(body.objectValue?["model"]?.stringValue == "claude-3-5-sonnet-latest")
        #expect(body.objectValue?["system"]?.stringValue == "You are concise.")
        #expect(body.objectValue?["tools"]?.arrayValue?.first?.objectValue?["name"]?.stringValue == "lookup_weather")
        #expect(
            body.objectValue?["messages"]?.arrayValue?.first?.objectValue?["content"]?.arrayValue?.first?.objectValue?["source"]?.objectValue?["file_id"]?.stringValue == "file_abc"
        )
    }

    @Test("Anthropic prompt caching maps automatic and explicit breakpoints")
    func anthropicPromptCachingMapsAutomaticAndExplicitBreakpoints() async throws {
        struct WeatherInput: Codable, Sendable {
            let city: String
        }

        struct WeatherOutput: Codable, Sendable {
            let summary: String
        }

        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "model": "claude-sonnet-4-5",
                      "content": [{ "type": "text", "text": "Cached." }],
                      "stop_reason": "end_turn",
                      "usage": {
                        "input_tokens": 7,
                        "cache_read_input_tokens": 40,
                        "cache_creation_input_tokens": 3,
                        "output_tokens": 2
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let tool = Tool<WeatherInput, WeatherOutput>(
            name: "lookup_weather",
            description: "Fetches weather.",
            inputSchema: Schema(
                name: "WeatherInput",
                description: "Weather lookup input.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                    "required": .array([.string("city")]),
                ])
            )
        ) { input, _ in
            WeatherOutput(summary: input.city)
        }

        var providerOptions = ProviderOptions()
        providerOptions.setAnthropic(
            AnthropicProviderOptions(
                promptCaching: AnthropicPromptCachingOptions(
                    automatic: AnthropicPromptCacheControl(),
                    system: AnthropicPromptCacheControl(ttl: .oneHour),
                    tools: [
                        AnthropicToolCacheBreakpoint(toolIndex: 0),
                    ],
                    messageParts: [
                        AnthropicMessagePartCacheBreakpoint(messageIndex: 1, partIndex: 0),
                    ]
                )
            )
        )

        let response = try await provider.languageModel("claude-sonnet-4-5").generate(
            request: TextGenerationRequest(
                messages: [
                    .system("You are helpful."),
                    .user("Cache this stable prefix."),
                ],
                tools: ToolRegistry([tool]),
                providerOptions: providerOptions
            )
        )

        let body = try decodeRequestBody(from: transport)
        #expect(body.objectValue?["cache_control"]?.objectValue?["type"]?.stringValue == "ephemeral")
        #expect(body.objectValue?["system"]?.arrayValue?.first?.objectValue?["cache_control"]?.objectValue?["ttl"]?.stringValue == "1h")
        #expect(body.objectValue?["tools"]?.arrayValue?.first?.objectValue?["cache_control"]?.objectValue?["type"]?.stringValue == "ephemeral")
        #expect(
            body.objectValue?["messages"]?.arrayValue?.first?.objectValue?["content"]?.arrayValue?.first?.objectValue?["cache_control"]?.objectValue?["type"]?.stringValue == "ephemeral"
        )
        #expect(response.usage?.cacheReadInputTokens == 40)
        #expect(response.usage?.cacheCreationInputTokens == 3)
    }

    @Test("Anthropic web search server tools map into the tools array")
    func anthropicWebSearchMapsServerTools() async throws {
        struct WeatherInput: Codable, Sendable {
            let city: String
        }

        struct WeatherOutput: Codable, Sendable {
            let summary: String
        }

        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "model": "claude-sonnet-4-5",
                      "content": [{ "type": "text", "text": "Found it." }],
                      "stop_reason": "end_turn",
                      "usage": {
                        "input_tokens": 10,
                        "output_tokens": 3
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let tool = Tool<WeatherInput, WeatherOutput>(
            name: "lookup_weather",
            description: "Fetches weather.",
            inputSchema: Schema(
                name: "WeatherInput",
                description: "Weather lookup input.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                    "required": .array([.string("city")]),
                ])
            )
        ) { input, _ in
            WeatherOutput(summary: input.city)
        }

        var providerOptions = ProviderOptions()
        providerOptions.setAnthropic(
            AnthropicProviderOptions(
                serverTools: [
                    .webSearch(
                        maxUses: 2,
                        allowedDomains: ["docs.anthropic.com"],
                        blockedDomains: ["example.com"],
                        userLocation: AnthropicUserLocation(
                            city: "San Francisco",
                            region: "California",
                            country: "US",
                            timezone: "America/Los_Angeles"
                        )
                    ),
                ]
            )
        )

        _ = try await provider.languageModel("claude-sonnet-4-5").generate(
            request: TextGenerationRequest(
                messages: [.user("Find current Anthropic web-search guidance.")],
                tools: ToolRegistry([tool]),
                providerOptions: providerOptions
            )
        )

        let body = try decodeRequestBody(from: transport)
        let tools = try #require(body.objectValue?["tools"]?.arrayValue)
        #expect(tools.count == 2)
        #expect(tools[0].objectValue?["name"]?.stringValue == "lookup_weather")
        #expect(tools[1].objectValue?["type"]?.stringValue == "web_search_20250305")
        #expect(tools[1].objectValue?["name"]?.stringValue == "web_search")
        #expect(tools[1].objectValue?["max_uses"]?.numberValue == 2.0)
        #expect(tools[1].objectValue?["allowed_domains"]?.arrayValue?.compactMap(\.stringValue) == ["docs.anthropic.com"])
        #expect(tools[1].objectValue?["blocked_domains"]?.arrayValue?.compactMap(\.stringValue) == ["example.com"])
        #expect(tools[1].objectValue?["user_location"]?.objectValue?["type"]?.stringValue == "approximate")
        #expect(tools[1].objectValue?["user_location"]?.objectValue?["timezone"]?.stringValue == "America/Los_Angeles")
    }

    @Test("Anthropic web search validation rejects duplicate tool names")
    func anthropicWebSearchRejectsDuplicateToolNames() async throws {
        struct SearchInput: Codable, Sendable {
            let query: String
        }

        struct SearchOutput: Codable, Sendable {
            let summary: String
        }

        let transport = MockHTTPTransport()
        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let tool = Tool<SearchInput, SearchOutput>(
            name: "web_search",
            description: "Conflicts with Anthropic's server tool name.",
            inputSchema: Schema(
                name: "SearchInput",
                description: "Search query input.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                    "required": .array([.string("query")]),
                ])
            )
        ) { input, _ in
            SearchOutput(summary: input.query)
        }

        var providerOptions = ProviderOptions()
        providerOptions.setAnthropic(
            AnthropicProviderOptions(
                serverTools: [
                    .webSearch(maxUses: 1),
                ]
            )
        )

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.languageModel("claude-sonnet-4-5").generate(
                request: TextGenerationRequest(
                    prompt: "Search Anthropic docs.",
                    tools: ToolRegistry([tool]),
                    providerOptions: providerOptions
                )
            )
        }

        #expect(transport.requests.isEmpty)
    }

    @Test("Anthropic streaming ignores server tool events and preserves text output")
    func anthropicStreamingIgnoresServerToolEvents() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "event: message_start",
                "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":4}}}",
                "",
                "event: content_block_start",
                "data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"server_tool_use\",\"id\":\"srv_1\",\"name\":\"web_search\"}}",
                "",
                "event: content_block_delta",
                "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"signature_delta\",\"signature\":\"opaque\"}}",
                "",
                "event: content_block_stop",
                "data: {\"type\":\"content_block_stop\",\"index\":0}",
                "",
                "event: content_block_delta",
                "data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"text_delta\",\"text\":\"Grounded answer\"}}",
                "",
                "event: message_delta",
                "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":6}}",
                "",
                "event: message_stop",
                "data: {\"type\":\"message_stop\"}",
                "",
            ]
        )

        let provider = try AnthropicProvider(apiKey: "test", transport: transport)
        let stream = provider.languageModel("claude-sonnet-4-5").stream(
            request: TextGenerationRequest(prompt: "Search for current Anthropic guidance.")
        )

        var text = ""
        var toolCallCount = 0
        var finishReason: FinishReason?
        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                text += delta
            case .toolCall:
                toolCallCount += 1
            case .finished(let reason):
                finishReason = reason
            default:
                break
            }
        }

        #expect(text == "Grounded answer")
        #expect(toolCallCount == 0)
        #expect(finishReason == .stop)
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

    @Test("Google streaming preserves duplicate identical function calls at different positions")
    func googleStreamingPreservesDuplicateFunctionCalls() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "data: {\"candidates\":[{\"content\":{\"parts\":[{\"functionCall\":{\"name\":\"lookup_weather\",\"args\":{\"city\":\"Tokyo\"}}},{\"functionCall\":{\"name\":\"lookup_weather\",\"args\":{\"city\":\"Tokyo\"}}}]},\"finishReason\":\"STOP\"}]}",
                "",
            ]
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let stream = provider.languageModel("gemini-test").stream(
            request: TextGenerationRequest(prompt: "Hello")
        )

        var toolCalls: [ToolInvocation] = []
        for try await event in stream {
            if case .toolCall(let invocation) = event {
                toolCalls.append(invocation)
            }
        }

        #expect(toolCalls.count == 2)
        #expect(toolCalls.allSatisfy { $0.name == "lookup_weather" })
    }

    @Test("Google content model counts tokens with cached-content requests")
    func googleCountTokensMapsGenerateContentRequest() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "totalTokens": 42,
                      "cachedContentTokenCount": 8
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let response = try await provider.tokens.countTokens(
            modelID: "gemini-test",
            request: GoogleCountTokensRequest(
                generateContentRequest: GoogleContentRequest(
                    contents: [
                        GoogleContent(parts: [GoogleContentPart(text: "Hello Gemini")]),
                    ],
                    options: GoogleProviderOptions(cachedContent: "cachedContents/123")
                )
            )
        )

        #expect(response.totalTokens == 42)
        #expect(response.cachedContentTokenCount == 8)

        let body = try decodeRequestBody(from: transport)
        #expect(body.objectValue?["generateContentRequest"]?.objectValue?["model"]?.stringValue == "models/gemini-test")
        #expect(body.objectValue?["generateContentRequest"]?.objectValue?["cachedContent"]?.stringValue == "cachedContents/123")
    }

    @Test("Google files upload uses resumable upload flow")
    func googleFilesUploadUsesResumableProtocol() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                headers: ["X-Goog-Upload-URL": "https://upload.example.com/session-1"],
                body: Data()
            )
        )
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "file": {
                        "name": "files/abc",
                        "displayName": "notes.txt",
                        "mimeType": "text/plain",
                        "uri": "https://files.example.com/abc"
                      }
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let file = try await provider.files.upload(
            data: Data("hello".utf8),
            fileName: "notes.txt",
            mimeType: "text/plain"
        )

        #expect(file.name == "files/abc")
        #expect(file.uri == "https://files.example.com/abc")

        let reusable = try file.asFileContent()
        #expect(reusable.providerFileURI == "https://files.example.com/abc")
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].headers["X-Goog-Upload-Protocol"] == "resumable")
        #expect(transport.requests[1].headers["X-Goog-Upload-Command"] == "upload, finalize")

        let startBody = try decodeRequestBody(from: transport, at: 0)
        #expect(startBody.objectValue?["file"]?.objectValue?["displayName"]?.stringValue == "notes.txt")
    }

    @Test("Google prompt file reuse maps provider file URIs")
    func googlePromptFileReuseUsesFileURI() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "candidates": [{
                        "content": {
                          "parts": [{ "text": "Read complete." }]
                        },
                        "finishReason": "STOP"
                      }]
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        _ = try await provider.languageModel("gemini-test").generate(
            request: TextGenerationRequest(
                messages: [
                    .user(parts: [
                        .text("Summarize this."),
                        .file(
                            FileContent(
                                providerFileID: "files/abc",
                                providerNamespace: GoogleProvider.namespace,
                                providerFileURI: "https://files.example.com/abc",
                                fileName: "notes.txt",
                                mimeType: "text/plain"
                            )
                        ),
                    ]),
                ]
            )
        )

        let body = try decodeRequestBody(from: transport)
        let filePart = body.objectValue?["contents"]?.arrayValue?.first?.objectValue?["parts"]?.arrayValue?[1]
        #expect(filePart?.objectValue?["fileData"]?.objectValue?["fileUri"]?.stringValue == "https://files.example.com/abc")
    }

    @Test("Google interactions reject background mode without storage")
    func googleInteractionsValidateBackgroundAndStore() async throws {
        let transport = MockHTTPTransport()
        let provider = try GoogleProvider(apiKey: "test", transport: transport)

        await #expect(throws: KaizoshaError.self) {
            _ = try await provider.interactions.create(
                GoogleInteractionRequest(
                    model: "gemini-3-flash-preview",
                    input: .text("Hi"),
                    store: false,
                    background: true
                )
            )
        }
    }

    @Test("Google interactions stream deltas and completion events")
    func googleInteractionsStreamEvents() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            stream: [
                "data: {\"type\":\"content.delta\",\"delta\":\"Hello\"}",
                "",
                "data: {\"type\":\"interaction.complete\",\"id\":\"int_1\",\"status\":\"completed\",\"outputs\":[]}",
                "",
            ]
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let stream = provider.interactions.stream(
            GoogleInteractionRequest(
                model: "gemini-3-flash-preview",
                input: .text("Hi")
            )
        )

        var delta = ""
        var completedID: String?
        for try await event in stream {
            switch event {
            case .contentDelta(let value):
                delta += value
            case .complete(let response):
                completedID = response.id
            default:
                break
            }
        }

        #expect(delta == "Hello")
        #expect(completedID == "int_1")
    }

    @Test("Google Live auth tokens and websocket setup use documented routes")
    func googleLiveAuthAndSetup() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "name": "ephemeral-token",
                      "expireTime": "2026-03-26T01:00:00Z",
                      "uses": 1
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let authToken = try await provider.live.createAuthToken(
            GoogleLiveAuthTokenRequest(
                setup: GoogleLiveSetup(model: "models/gemini-live-2.5-flash-preview")
            )
        )

        #expect(authToken.value == "ephemeral-token")

        let webSocketTransport = MockWebSocketTransport()
        let client = try await provider.live.connect(
            setup: GoogleLiveSetup(model: "models/gemini-live-2.5-flash-preview"),
            authorization: .authToken("ephemeral-token"),
            webSocketTransport: webSocketTransport
        )
        _ = client

        let requests = await webSocketTransport.requests
        let sentTexts = await webSocketTransport.connection.sentTexts
        #expect(requests.first?.url.absoluteString.contains("BidiGenerateContentConstrained") == true)
        #expect(requests.first?.url.absoluteString.contains("access_token=ephemeral-token") == true)
        #expect(sentTexts.first?.contains("\"setup\"") == true)
    }

    @Test("Google file-search-store imports include chunking metadata")
    func googleFileSearchImportMapsChunking() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "name": "operations/import-1",
                      "done": false
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let operation = try await provider.fileSearchStores.importFile(
            fileSearchStoreName: "fileSearchStores/store-1",
            fileName: "files/abc",
            customMetadata: [GoogleCustomMetadata(key: "team", stringValue: "search")],
            chunkingConfig: GoogleChunkingConfiguration(maxTokensPerChunk: 256, maxOverlapTokens: 32)
        )

        #expect(operation.name == "operations/import-1")

        let body = try decodeRequestBody(from: transport)
        #expect(body.objectValue?["fileName"]?.stringValue == "files/abc")
        #expect(body.objectValue?["chunkingConfig"]?.objectValue?["whiteSpaceConfig"]?.objectValue?["maxTokensPerChunk"]?.numberValue == 256)
    }

    @Test("Google batch embeddings use the native batch endpoint")
    func googleBatchEmbeddingsUseNativeEndpoint() async throws {
        let transport = MockHTTPTransport()
        transport.enqueue(
            response: HTTPResponse(
                statusCode: 200,
                body: Data(
                    """
                    {
                      "embeddings": [
                        { "values": [0.1, 0.2] },
                        { "values": [0.3, 0.4] }
                      ]
                    }
                    """.utf8
                )
            )
        )

        let provider = try GoogleProvider(apiKey: "test", transport: transport)
        let response = try await provider.batches.batchEmbedContents(
            modelID: "text-embedding-004",
            requests: [
                GoogleBatchEmbeddingRequest(text: "alpha"),
                GoogleBatchEmbeddingRequest(text: "beta"),
            ]
        )

        #expect(response.embeddings.count == 2)
        #expect(response.embeddings.first?.first == 0.1)

        let body = try decodeRequestBody(from: transport)
        #expect(body.objectValue?["requests"]?.arrayValue?.count == 2)
        #expect(body.objectValue?["requests"]?.arrayValue?.first?.objectValue?["model"]?.stringValue == "models/text-embedding-004")
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

private func decodeRequestBody(from transport: MockHTTPTransport, at index: Int = 0) throws -> JSONValue {
    let request = try #require(transport.requests[safe: index])
    let body = try #require(request.body)
    return try JSONValue.decode(body)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
