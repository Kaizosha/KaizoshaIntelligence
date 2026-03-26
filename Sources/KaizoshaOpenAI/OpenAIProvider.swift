import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Provider-specific options for the OpenAI adapter.
public struct OpenAIProviderOptions: Sendable, Hashable {
    /// An optional end-user identifier.
    public var user: String?

    /// Whether the provider may execute tool calls in parallel.
    public var parallelToolCalls: Bool?

    /// Creates provider-specific OpenAI options.
    public init(user: String? = nil, parallelToolCalls: Bool? = nil) {
        self.user = user
        self.parallelToolCalls = parallelToolCalls
    }

    /// Encodes the options into a JSON payload.
    public func jsonValue() -> JSONValue {
        var object: [String: JSONValue] = [:]
        if let user {
            object["user"] = .string(user)
        }
        if let parallelToolCalls {
            object["parallel_tool_calls"] = .bool(parallelToolCalls)
        }
        return .object(object)
    }
}

/// A provider factory for OpenAI-backed models.
public struct OpenAIProvider: Sendable {
    /// The provider namespace used in namespaced options.
    public static let namespace = "openai"

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    /// Creates an OpenAI provider.
    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        transport: (any HTTPTransport)? = nil,
        retryPolicy: RetryPolicy = .default
    ) throws {
        guard let apiKey, apiKey.isEmpty == false else {
            throw KaizoshaError.missingAPIKey(namespace: "OPENAI_API_KEY")
        }

        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = HTTPClient(transport: transport, retryPolicy: retryPolicy)
    }

    /// Creates a language model handle.
    public func languageModel(_ id: String) -> OpenAILanguageModel {
        OpenAILanguageModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Creates an embedding model handle.
    public func embeddingModel(_ id: String) -> OpenAIEmbeddingModel {
        OpenAIEmbeddingModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Creates an image generation model handle.
    public func imageModel(_ id: String = "gpt-image-1") -> OpenAIImageModel {
        OpenAIImageModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Creates a speech synthesis model handle.
    public func speechModel(_ id: String = "gpt-4o-mini-tts") -> OpenAISpeechModel {
        OpenAISpeechModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Creates a transcription model handle.
    public func transcriptionModel(_ id: String = "gpt-4o-mini-transcribe") -> OpenAITranscriptionModel {
        OpenAITranscriptionModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }
}

/// A chat-completions-backed language model.
public struct OpenAILanguageModel: LanguageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportsStreaming: true,
        supportsToolCalling: true,
        supportsStructuredOutput: true,
        supportsImageInput: true,
        supportsAudioInput: false,
        supportsFileInput: false,
        supportsReasoningControls: false
    )

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    fileprivate init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    public func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        try CapabilityValidator.validate(request, for: self, streaming: false)
        let body = try chatPayload(for: request, stream: false)
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appending(path: "chat/completions"),
                headers: headers(contentType: "application/json"),
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: response.body)
        guard let choice = decoded.choices.first else {
            throw KaizoshaError.invalidResponse("OpenAI returned no choices.")
        }

        let text = choice.message.content ?? ""
        let toolInvocations = try choice.message.toolCalls?.map(Self.mapToolInvocation) ?? []
        let parts = (text.isEmpty ? [] : [MessagePart.text(text)]) + toolInvocations.map(MessagePart.toolCall)

        return TextGenerationResponse(
            modelID: decoded.model,
            message: Message(role: .assistant, parts: parts),
            text: text,
            toolInvocations: toolInvocations,
            usage: decoded.usage?.usage,
            finishReason: FinishReason(openAIValue: choice.finishReason),
            rawPayload: try? JSONValue.decode(response.body)
        )
    }

    public func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try CapabilityValidator.validate(request, for: self, streaming: true)
                    continuation.yield(.status("started"))
                    let body = try chatPayload(for: request, stream: true)
                    let httpRequest = HTTPRequest(
                        url: baseURL.appending(path: "chat/completions"),
                        headers: headers(contentType: "application/json"),
                        body: try body.data()
                    )
                    let events = await client.streamEvents(httpRequest)

                    var toolCallsByIndex: [Int: StreamingToolCall] = [:]
                    var finishReason: FinishReason = .unknown

                    for try await event in events {
                        if event.data == "[DONE]" {
                            for index in toolCallsByIndex.keys.sorted() {
                                guard let call = toolCallsByIndex[index] else { continue }
                                continuation.yield(.toolCall(try call.invocation()))
                            }
                            continuation.yield(.finished(finishReason))
                            continuation.finish()
                            return
                        }

                        let chunkData = Data(event.data.utf8)
                        let chunk = try JSONDecoder().decode(OpenAIChatCompletionChunk.self, from: chunkData)

                        if let usage = chunk.usage?.usage {
                            continuation.yield(.usage(usage))
                        }

                        for choice in chunk.choices {
                            if let content = choice.delta?.content, content.isEmpty == false {
                                continuation.yield(.textDelta(content))
                            }

                            if let toolCalls = choice.delta?.toolCalls {
                                for toolCall in toolCalls {
                                    let key = toolCall.index ?? toolCallsByIndex.count
                                    var accumulated = toolCallsByIndex[key] ?? StreamingToolCall()
                                    accumulated.id = toolCall.id ?? accumulated.id
                                    accumulated.name = toolCall.function?.name ?? accumulated.name
                                    accumulated.arguments += toolCall.function?.arguments ?? ""
                                    toolCallsByIndex[key] = accumulated
                                }
                            }

                            if let reason = choice.finishReason {
                                finishReason = FinishReason(openAIValue: reason)
                            }
                        }
                    }

                    for index in toolCallsByIndex.keys.sorted() {
                        guard let call = toolCallsByIndex[index] else { continue }
                        continuation.yield(.toolCall(try call.invocation()))
                    }
                    continuation.yield(.finished(finishReason))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func chatPayload(for request: TextGenerationRequest, stream: Bool) throws -> JSONValue {
        var object: [String: JSONValue] = [
            "model": .string(id),
            "messages": .array(try mapMessages(request.messages)),
        ]

        if let temperature = request.generation.temperature {
            object["temperature"] = .number(temperature)
        }
        if let topP = request.generation.topP {
            object["top_p"] = .number(topP)
        }
        if let maxOutputTokens = request.generation.maxOutputTokens {
            object["max_tokens"] = .number(Double(maxOutputTokens))
        }
        if request.generation.stopSequences.isEmpty == false {
            object["stop"] = .array(request.generation.stopSequences.map(JSONValue.string))
        }
        if stream {
            object["stream"] = .bool(true)
            object["stream_options"] = .object(["include_usage": .bool(true)])
        }
        if request.tools.isEmpty == false {
            object["tools"] = .array(request.tools.tools.map(mapTool))
            object["tool_choice"] = .string("auto")
        }
        if let structuredOutput = request.structuredOutput {
            object["response_format"] = .object([
                "type": .string("json_schema"),
                "json_schema": .object([
                    "name": .string(structuredOutput.name),
                    "strict": .bool(true),
                    "schema": structuredOutput.schema,
                ]),
            ])
        }

        return JSONValue.object(object).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))
    }

    private func mapMessages(_ messages: [Message]) throws -> [JSONValue] {
        let normalized = MessagePipeline.normalize(messages)
        var payloads: [JSONValue] = []

        for message in normalized {
            switch message.role {
            case .system:
                payloads.append(
                    .object([
                        "role": .string("system"),
                        "content": .string(MessagePipeline.text(from: message)),
                    ])
                )
            case .user:
                payloads.append(
                    .object([
                        "role": .string("user"),
                        "content": .array(try mapUserParts(message.parts)),
                    ])
                )
            case .assistant:
                var payload: [String: JSONValue] = [
                    "role": .string("assistant"),
                ]

                let text = message.parts.compactMap { part -> String? in
                    guard case .text(let value) = part else { return nil }
                    return value
                }
                .joined(separator: "\n")

                if text.isEmpty == false {
                    payload["content"] = .string(text)
                }

                let toolCalls = message.parts.compactMap { part -> ToolInvocation? in
                    guard case .toolCall(let invocation) = part else { return nil }
                    return invocation
                }

                if toolCalls.isEmpty == false {
                    payload["tool_calls"] = .array(try toolCalls.map { invocation in
                        .object([
                            "id": .string(invocation.id),
                            "type": .string("function"),
                            "function": .object([
                                "name": .string(invocation.name),
                                "arguments": try JSONValue.string(invocation.input.compactString()),
                            ]),
                        ])
                    })
                }

                payloads.append(.object(payload))
            case .tool:
                for part in message.parts {
                    guard case .toolResult(let result) = part else { continue }
                    payloads.append(
                        .object([
                            "role": .string("tool"),
                            "tool_call_id": .string(result.invocationID),
                            "content": .string(try result.output.compactString()),
                        ])
                    )
                }
            }
        }

        return payloads
    }

    private func mapUserParts(_ parts: [ModelPart]) throws -> [JSONValue] {
        try parts.map { part in
            switch part {
            case .text(let text):
                return .object([
                    "type": .string("text"),
                    "text": .string(text),
                ])
            case .image(let image):
                let urlString: String
                if let url = image.url {
                    urlString = url.absoluteString
                } else if let data = image.data {
                    urlString = "data:\(image.mimeType);base64,\(data.base64EncodedString())"
                } else {
                    throw KaizoshaError.invalidRequest("An image part must contain either data or a URL.")
                }

                return .object([
                    "type": .string("image_url"),
                    "image_url": .object([
                        "url": .string(urlString),
                    ]),
                ])
            case .audio:
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "audio prompt parts via chat completions")
            case .file:
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "file prompt parts via chat completions")
            case .toolCall, .toolResult:
                throw KaizoshaError.invalidRequest("Tool parts are not valid inside OpenAI user messages.")
            }
        }
    }

    private func mapTool(_ tool: AnyTool) -> JSONValue {
        .object([
            "type": .string("function"),
            "function": .object([
                "name": .string(tool.name),
                "description": .string(tool.description),
                "parameters": tool.inputSchema,
            ]),
        ])
    }

    private func headers(contentType: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": contentType,
        ]
    }

    private static func mapToolInvocation(_ toolCall: OpenAIChatCompletionResponse.ToolCall) throws -> ToolInvocation {
        guard let data = toolCall.function.arguments.data(using: .utf8) else {
            throw KaizoshaError.invalidResponse("OpenAI returned non-UTF8 tool arguments.")
        }
        return ToolInvocation(
            id: toolCall.id,
            name: toolCall.function.name,
            input: try JSONValue.decode(data)
        )
    }
}

/// An OpenAI embedding model.
public struct OpenAIEmbeddingModel: EmbeddingModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportsBatchEmbeddings: true
    )

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    fileprivate init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    public func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        try CapabilityValidator.validate(request, for: self)
        let input: JSONValue = request.texts.count == 1 ? .string(request.texts[0]) : .array(request.texts.map(JSONValue.string))
        let body = JSONValue.object([
            "model": .string(id),
            "input": input,
        ]).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appending(path: "embeddings"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
                ],
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: response.body)
        return EmbeddingResponse(
            modelID: decoded.model,
            embeddings: decoded.data.sorted(by: { $0.index < $1.index }).map(\.embedding),
            usage: decoded.usage?.usage
        )
    }
}

/// An OpenAI image generation model.
public struct OpenAIImageModel: ImageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportsMultipleImageOutputs: true
    )

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    fileprivate init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    public func generateImage(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        try CapabilityValidator.validate(request, for: self)
        var object: [String: JSONValue] = [
            "model": .string(id),
            "prompt": .string(request.prompt),
            "n": .number(Double(request.count)),
            "response_format": .string("b64_json"),
        ]
        if let size = request.size {
            object["size"] = .string(size)
        }

        let body = JSONValue.object(object).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appending(path: "images/generations"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
                ],
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: response.body)
        let images = try decoded.data.map { item in
            guard let bytes = Data(base64Encoded: item.b64JSON) else {
                throw KaizoshaError.invalidResponse("OpenAI returned invalid base64 image data.")
            }
            return GeneratedImage(data: bytes, mimeType: "image/png", revisedPrompt: item.revisedPrompt)
        }
        return ImageGenerationResponse(modelID: id, images: images)
    }
}

/// An OpenAI speech generation model.
public struct OpenAISpeechModel: SpeechModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportedSpeechFormats: [.mp3, .wav, .aac, .flac, .opus, .pcm16]
    )

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    fileprivate init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    public func generateSpeech(request: SpeechGenerationRequest) async throws -> SpeechGenerationResponse {
        try CapabilityValidator.validate(request, for: self)
        let body = JSONValue.object([
            "model": .string(id),
            "input": .string(request.prompt),
            "voice": .string(request.voice),
            "response_format": .string(request.format.rawValue),
        ]).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appending(path: "audio/speech"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
                ],
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let mimeType = response.headers["Content-Type"] ?? "audio/mpeg"
        return SpeechGenerationResponse(modelID: id, audio: response.body, mimeType: mimeType)
    }
}

/// An OpenAI transcription model.
public struct OpenAITranscriptionModel: TranscriptionModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportsTranscriptionPrompt: true,
        supportsTranscriptionLanguageHint: true
    )

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    fileprivate init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    public func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResponse {
        try CapabilityValidator.validate(request, for: self)
        var multipart = MultipartFormData()
        multipart.addText(name: "model", value: id)
        multipart.addData(name: "file", fileName: request.fileName, mimeType: request.mimeType, data: request.audio)
        if let prompt = request.prompt {
            multipart.addText(name: "prompt", value: prompt)
        }
        if let language = request.language {
            multipart.addText(name: "language", value: language)
        }

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appending(path: "audio/transcriptions"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": multipart.contentType,
                ],
                body: multipart.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: response.body)
        return TranscriptionResponse(
            modelID: id,
            text: decoded.text,
            segments: decoded.segments?.map {
                TranscriptionSegment(startTime: $0.start, endTime: $0.end, text: $0.text)
            } ?? []
        )
    }
}

public extension ProviderOptions {
    /// Stores OpenAI-specific options under the OpenAI namespace.
    mutating func setOpenAI(_ options: OpenAIProviderOptions) {
        set(options.jsonValue(), for: OpenAIProvider.namespace)
    }
}

private struct StreamingToolCall {
    var id = UUID().uuidString
    var name = ""
    var arguments = ""

    func invocation() throws -> ToolInvocation {
        guard let data = arguments.data(using: .utf8) else {
            throw KaizoshaError.invalidResponse("OpenAI streamed non-UTF8 tool arguments.")
        }
        return ToolInvocation(id: id, name: name, input: try JSONValue.decode(data))
    }
}

private struct OpenAIChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
            let toolCalls: [ToolCall]?

            private enum CodingKeys: String, CodingKey {
                case content
                case toolCalls = "tool_calls"
            }
        }

        let message: Message
        let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct ToolCall: Decodable {
        struct Function: Decodable {
            let name: String
            let arguments: String
        }

        let id: String
        let function: Function
    }

    let model: String
    let choices: [Choice]
    let usage: TokenUsagePayload?
}

private struct OpenAIChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            struct ToolCall: Decodable {
                struct Function: Decodable {
                    let name: String?
                    let arguments: String?
                }

                let index: Int?
                let id: String?
                let function: Function?
            }

            let content: String?
            let toolCalls: [ToolCall]?

            private enum CodingKeys: String, CodingKey {
                case content
                case toolCalls = "tool_calls"
            }
        }

        let delta: Delta?
        let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]
    let usage: TokenUsagePayload?
}

private struct OpenAIEmbeddingResponse: Decodable {
    struct Item: Decodable {
        let index: Int
        let embedding: [Double]
    }

    let model: String
    let data: [Item]
    let usage: TokenUsagePayload?
}

private struct OpenAIImageResponse: Decodable {
    struct Item: Decodable {
        let b64JSON: String
        let revisedPrompt: String?

        private enum CodingKeys: String, CodingKey {
            case b64JSON = "b64_json"
            case revisedPrompt = "revised_prompt"
        }
    }

    let data: [Item]
}

private struct OpenAITranscriptionResponse: Decodable {
    struct Segment: Decodable {
        let start: Double
        let end: Double
        let text: String
    }

    let text: String
    let segments: [Segment]?
}

private struct TokenUsagePayload: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }

    var usage: Usage {
        Usage(
            inputTokens: promptTokens,
            outputTokens: completionTokens,
            totalTokens: totalTokens
        )
    }
}

private extension FinishReason {
    init(openAIValue: String?) {
        switch openAIValue {
        case "stop":
            self = .stop
        case "length":
            self = .length
        case "tool_calls":
            self = .toolCalls
        case "content_filter":
            self = .contentFilter
        case nil:
            self = .unknown
        default:
            self = .unknown
        }
    }
}
