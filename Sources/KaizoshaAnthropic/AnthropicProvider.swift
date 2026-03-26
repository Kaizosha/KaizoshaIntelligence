import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Provider-specific options for the Anthropic adapter.
public struct AnthropicProviderOptions: Sendable, Hashable {
    /// An optional user identifier for request metadata.
    public var userID: String?

    /// An optional top-k sampling value.
    public var topK: Int?

    /// Creates Anthropic-specific options.
    public init(userID: String? = nil, topK: Int? = nil) {
        self.userID = userID
        self.topK = topK
    }

    /// Encodes the options into a JSON payload.
    public func jsonValue() -> JSONValue {
        var object: [String: JSONValue] = [:]

        if let userID {
            object["metadata"] = .object(["user_id": .string(userID)])
        }

        if let topK {
            object["top_k"] = .number(Double(topK))
        }

        return .object(object)
    }
}

/// A provider factory for Anthropic-backed language models.
public struct AnthropicProvider: Sendable {
    /// The provider namespace used in namespaced options.
    public static let namespace = "anthropic"

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    /// Creates an Anthropic provider.
    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        transport: (any HTTPTransport)? = nil,
        retryPolicy: RetryPolicy = .default
    ) throws {
        guard let apiKey, apiKey.isEmpty == false else {
            throw KaizoshaError.missingAPIKey(namespace: "ANTHROPIC_API_KEY")
        }

        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = HTTPClient(transport: transport, retryPolicy: retryPolicy)
    }

    /// Creates a language model handle.
    public func languageModel(_ id: String) -> AnthropicLanguageModel {
        AnthropicLanguageModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }
}

/// An Anthropic messages-backed language model.
public struct AnthropicLanguageModel: LanguageModel, Sendable {
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
        let body = try messagePayload(for: request, stream: false)
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appending(path: "messages"),
                headers: headers,
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(AnthropicMessageResponse.self, from: response.body)
        let text = decoded.content.compactMap(\.text).joined()
        let toolInvocations = decoded.content.compactMap { block -> ToolInvocation? in
            guard block.type == "tool_use", let name = block.name, let id = block.id, let input = block.input else {
                return nil
            }
            return ToolInvocation(id: id, name: name, input: input)
        }

        let parts = (text.isEmpty ? [] : [MessagePart.text(text)]) + toolInvocations.map(MessagePart.toolCall)
        return TextGenerationResponse(
            modelID: decoded.model,
            message: Message(role: .assistant, parts: parts),
            text: text,
            toolInvocations: toolInvocations,
            usage: decoded.usage.usage,
            finishReason: FinishReason(anthropicValue: decoded.stopReason),
            rawPayload: try? JSONValue.decode(response.body)
        )
    }

    public func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try CapabilityValidator.validate(request, for: self, streaming: true)
                    continuation.yield(.status("started"))
                    let body = try messagePayload(for: request, stream: true)
                    let httpRequest = HTTPRequest(
                        url: baseURL.appending(path: "messages"),
                        headers: headers,
                        body: try body.data()
                    )
                    let events = await client.streamEvents(httpRequest)

                    var inputTokens: Int?
                    var outputTokens: Int?
                    var finishReason: FinishReason = .unknown
                    var toolBlocks: [Int: AnthropicStreamingToolUse] = [:]

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }

                        let data = Data(event.data.utf8)
                        let envelope = try JSONDecoder().decode(AnthropicStreamingEnvelope.self, from: data)

                        if envelope.type == "ping" {
                            continue
                        }

                        if envelope.type == "error", let error = envelope.error {
                            throw KaizoshaError.invalidResponse("Anthropic stream error: \(error.type) \(error.message)")
                        }

                        if envelope.type == "message_start" {
                            inputTokens = envelope.message?.usage?.inputTokens
                            if let inputTokens {
                                continuation.yield(.usage(Usage(inputTokens: inputTokens, outputTokens: outputTokens)))
                            }
                            continue
                        }

                        if envelope.type == "content_block_start",
                           let index = envelope.index,
                           let contentBlock = envelope.contentBlock,
                           contentBlock.type == "tool_use" {
                            toolBlocks[index] = AnthropicStreamingToolUse(
                                id: contentBlock.id ?? UUID().uuidString,
                                name: contentBlock.name ?? "tool",
                                initialInput: contentBlock.input
                            )
                            continue
                        }

                        if envelope.type == "content_block_delta",
                           let index = envelope.index,
                           let delta = envelope.delta {
                            switch delta.type {
                            case "text_delta":
                                if let text = delta.text, text.isEmpty == false {
                                    continuation.yield(.textDelta(text))
                                }
                            case "input_json_delta":
                                if var tool = toolBlocks[index] {
                                    tool.partialJSON += delta.partialJSON ?? ""
                                    toolBlocks[index] = tool
                                }
                            default:
                                break
                            }
                            continue
                        }

                        if envelope.type == "content_block_stop",
                           let index = envelope.index,
                           let tool = toolBlocks[index] {
                            continuation.yield(.toolCall(try tool.invocation()))
                            toolBlocks.removeValue(forKey: index)
                            continue
                        }

                        if envelope.type == "message_delta" {
                            outputTokens = envelope.usage?.outputTokens ?? outputTokens
                            finishReason = FinishReason(anthropicValue: envelope.delta?.stopReason)
                            continuation.yield(
                                .usage(
                                    Usage(
                                        inputTokens: inputTokens,
                                        outputTokens: outputTokens,
                                        totalTokens: [inputTokens, outputTokens].compactMap { $0 }.reduce(0, +)
                                    )
                                )
                            )
                            continue
                        }

                        if envelope.type == "message_stop" {
                            for index in toolBlocks.keys.sorted() {
                                if let tool = toolBlocks[index] {
                                    continuation.yield(.toolCall(try tool.invocation()))
                                }
                            }
                            continuation.yield(.finished(finishReason))
                            continuation.finish()
                            return
                        }
                    }

                    for index in toolBlocks.keys.sorted() {
                        if let tool = toolBlocks[index] {
                            continuation.yield(.toolCall(try tool.invocation()))
                        }
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

    private var headers: [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        ]
    }

    private func messagePayload(for request: TextGenerationRequest, stream: Bool) throws -> JSONValue {
        let normalized = MessagePipeline.normalize(request.messages)
        let conversation = normalized.filter { $0.role != .system }

        var object: [String: JSONValue] = [
            "model": .string(id),
            "max_tokens": .number(Double(request.generation.maxOutputTokens ?? 1024)),
            "messages": .array(try conversation.flatMap(mapMessage)),
        ]

        if let systemPrompt = MessagePipeline.systemPrompt(from: normalized) {
            object["system"] = .string(systemPrompt)
        }
        if let temperature = request.generation.temperature {
            object["temperature"] = .number(temperature)
        }
        if let topP = request.generation.topP {
            object["top_p"] = .number(topP)
        }
        if stream {
            object["stream"] = .bool(true)
        }
        if request.tools.isEmpty == false {
            object["tools"] = .array(request.tools.tools.map { tool in
                .object([
                    "name": .string(tool.name),
                    "description": .string(tool.description),
                    "input_schema": tool.inputSchema,
                ])
            })
        }
        if let structuredOutput = request.structuredOutput {
            object["system"] = .string(
                """
                \(object["system"]?.stringValue ?? "")

                Return only valid JSON matching the schema named \(structuredOutput.name):
                \(String(data: try structuredOutput.schema.data(prettyPrinted: true), encoding: .utf8) ?? "{}")
                """
                .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return JSONValue.object(object).mergingObject(with: request.providerOptions.options(for: AnthropicProvider.namespace))
    }

    private func mapMessage(_ message: ModelMessage) throws -> [JSONValue] {
        switch message.role {
        case .system:
            return []
        case .user:
            return [
                .object([
                    "role": .string("user"),
                    "content": .array(try mapUserParts(message.parts)),
                ]),
            ]
        case .assistant:
            return [
                .object([
                    "role": .string("assistant"),
                    "content": .array(try mapAssistantParts(message.parts)),
                ]),
            ]
        case .tool:
            let parts = try message.parts.compactMap { part -> JSONValue? in
                guard case .toolResult(let result) = part else { return nil }
                return .object([
                    "type": .string("tool_result"),
                    "tool_use_id": .string(result.invocationID),
                    "content": .string(try result.output.compactString()),
                    "is_error": .bool(result.isError),
                ])
            }
            return [
                .object([
                    "role": .string("user"),
                    "content": .array(parts),
                ]),
            ]
        }
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
                guard let data = image.data ?? (try? Data(contentsOf: image.url!)) else {
                    throw KaizoshaError.invalidRequest("Anthropic image parts require inline data or a reachable local URL.")
                }
                return .object([
                    "type": .string("image"),
                    "source": .object([
                        "type": .string("base64"),
                        "media_type": .string(image.mimeType),
                        "data": .string(data.base64EncodedString()),
                    ]),
                ])
            case .audio:
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "audio prompt parts")
            case .file:
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "file prompt parts")
            case .toolCall, .toolResult:
                throw KaizoshaError.invalidRequest("Tool parts are not valid inside Anthropic user messages.")
            }
        }
    }

    private func mapAssistantParts(_ parts: [ModelPart]) throws -> [JSONValue] {
        try parts.map { part in
            switch part {
            case .text(let text):
                return .object([
                    "type": .string("text"),
                    "text": .string(text),
                ])
            case .toolCall(let invocation):
                return .object([
                    "type": .string("tool_use"),
                    "id": .string(invocation.id),
                    "name": .string(invocation.name),
                    "input": invocation.input,
                ])
            case .image, .audio, .file, .toolResult:
                throw KaizoshaError.invalidRequest("Anthropic assistant messages only support text and tool call parts.")
            }
        }
    }
}

public extension ProviderOptions {
    /// Stores Anthropic-specific options under the Anthropic namespace.
    mutating func setAnthropic(_ options: AnthropicProviderOptions) {
        set(options.jsonValue(), for: AnthropicProvider.namespace)
    }
}

private struct AnthropicStreamingToolUse {
    var id: String
    var name: String
    var initialInput: JSONValue?
    var partialJSON: String = ""

    func invocation() throws -> ToolInvocation {
        let input: JSONValue

        if partialJSON.isEmpty == false {
            guard let data = partialJSON.data(using: .utf8) else {
                throw KaizoshaError.invalidResponse("Anthropic streamed non-UTF8 tool input.")
            }
            input = try JSONValue.decode(data)
        } else {
            input = initialInput ?? .object([:])
        }

        return ToolInvocation(id: id, name: name, input: input)
    }
}

private struct AnthropicMessageResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: JSONValue?
    }

    struct UsagePayload: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }

        var usage: Usage {
            Usage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                totalTokens: [inputTokens, outputTokens].compactMap { $0 }.reduce(0, +)
            )
        }
    }

    let model: String
    let content: [Block]
    let stopReason: String?
    let usage: UsagePayload

    private enum CodingKeys: String, CodingKey {
        case model
        case content
        case stopReason = "stop_reason"
        case usage
    }
}

private struct AnthropicStreamingEnvelope: Decodable {
    struct MessagePayload: Decodable {
        let usage: AnthropicMessageResponse.UsagePayload?
    }

    struct ContentBlock: Decodable {
        let type: String
        let id: String?
        let name: String?
        let input: JSONValue?
    }

    struct DeltaPayload: Decodable {
        let type: String?
        let text: String?
        let partialJSON: String?
        let stopReason: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case partialJSON = "partial_json"
            case stopReason = "stop_reason"
        }
    }

    struct ErrorPayload: Decodable {
        let type: String
        let message: String
    }

    let type: String
    let index: Int?
    let message: MessagePayload?
    let contentBlock: ContentBlock?
    let delta: DeltaPayload?
    let usage: AnthropicMessageResponse.UsagePayload?
    let error: ErrorPayload?

    private enum CodingKeys: String, CodingKey {
        case type
        case index
        case message
        case contentBlock = "content_block"
        case delta
        case usage
        case error
    }
}

private extension FinishReason {
    init(anthropicValue: String?) {
        switch anthropicValue {
        case "end_turn":
            self = .stop
        case "max_tokens":
            self = .length
        case "tool_use":
            self = .toolCalls
        case nil:
            self = .unknown
        default:
            self = .unknown
        }
    }
}
