import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Provider-specific options for the Anthropic adapter.
public struct AnthropicProviderOptions: Sendable, Hashable {
    /// An optional user identifier for request metadata.
    public var userID: String?

    /// An optional top-k sampling value.
    public var topK: Int?

    /// Anthropic prompt-caching controls.
    public var promptCaching: AnthropicPromptCachingOptions?

    /// Anthropic server-side tools, such as web search.
    public var serverTools: [AnthropicServerTool]

    /// An optional code-execution container identifier to reuse between requests.
    public var containerID: String?

    /// Creates Anthropic-specific options.
    public init(
        userID: String? = nil,
        topK: Int? = nil,
        promptCaching: AnthropicPromptCachingOptions? = nil,
        serverTools: [AnthropicServerTool] = [],
        containerID: String? = nil
    ) {
        self.userID = userID
        self.topK = topK
        self.promptCaching = promptCaching
        self.serverTools = serverTools
        self.containerID = containerID
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
        if let promptCaching {
            object[anthropicPromptCachingSentinelKey] = promptCaching.jsonValue
        }
        if serverTools.isEmpty == false {
            object[anthropicServerToolsSentinelKey] = .array(serverTools.map(\.jsonValue))
        }
        if let containerID {
            object[anthropicContainerIDSentinelKey] = .string(containerID)
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

    /// Access to Anthropic file operations.
    public var files: AnthropicFilesService {
        AnthropicFilesService(apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Access to Anthropic token-count operations.
    public var tokens: AnthropicTokensService {
        AnthropicTokensService(apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Fetches the live model catalog from Anthropic.
    public func listModels() async throws -> [AvailableModel] {
        var models: [AvailableModel] = []
        var afterID: String?

        repeat {
            let page = try await listModelsPage(afterID: afterID)
            models.append(contentsOf: page.models)
            afterID = page.nextAfterID
        } while afterID != nil

        return models
    }

    private func listModelsPage(afterID: String?) async throws -> (models: [AvailableModel], nextAfterID: String?) {
        var components = URLComponents(url: baseURL.appendingPathComponents("models"), resolvingAgainstBaseURL: false)!
        if let afterID {
            components.queryItems = [URLQueryItem(name: "after_id", value: afterID)]
        }

        let payload = try await client.sendJSON(
            HTTPRequest(
                url: components.url!,
                method: .get,
                headers: catalogHeaders
            )
        )

        guard let object = payload.objectValue, let entries = object["data"]?.arrayValue else {
            throw KaizoshaError.invalidResponse("Anthropic returned an invalid model list payload.")
        }

        let models = try entries.map(Self.mapAvailableModel)
        let nextAfterID = object["has_more"]?.boolValue == true ? object["last_id"]?.stringValue : nil
        return (models, nextAfterID)
    }

    private static func mapAvailableModel(_ value: JSONValue) throws -> AvailableModel {
        guard let object = value.objectValue, let id = object["id"]?.stringValue else {
            throw KaizoshaError.invalidResponse("Anthropic returned a model entry without an id.")
        }

        return AvailableModel(
            id: id,
            provider: namespace,
            displayName: object["display_name"]?.stringValue,
            type: "language",
            createdAt: ModelCatalogDecoding.iso8601Date(object["created_at"]),
            rawMetadata: value
        )
    }

    private var catalogHeaders: [String: String] {
        AnthropicRequestHeaders.make(apiKey: apiKey, contentType: nil)
    }
}

/// An Anthropic messages-backed language model.
public struct AnthropicLanguageModel: LanguageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    fileprivate init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.capabilities = AnthropicCapabilityResolver.profile(for: id).capabilities
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    public func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        try CapabilityValidator.validate(request, for: self, streaming: false)
        try validateServerTools(for: request)
        let body = try AnthropicMessagePayloadBuilder.messagePayload(modelID: id, request: request, stream: false)
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("messages"),
                headers: headers(for: request),
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
                    try validateServerTools(for: request)
                    continuation.yield(.status("started"))
                    let body = try AnthropicMessagePayloadBuilder.messagePayload(modelID: id, request: request, stream: true)
                    let httpRequest = HTTPRequest(
                        url: baseURL.appendingPathComponents("messages"),
                        headers: headers(for: request),
                        body: try body.data()
                    )
                    let events = await client.streamEvents(httpRequest)

                    var inputTokens: Int?
                    var cacheReadInputTokens: Int?
                    var cacheCreationInputTokens: Int?
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
                            cacheReadInputTokens = envelope.message?.usage?.cacheReadInputTokens
                            cacheCreationInputTokens = envelope.message?.usage?.cacheCreationInputTokens
                            if let inputTokens {
                                continuation.yield(
                                    .usage(
                                        Usage(
                                            inputTokens: inputTokens,
                                            cacheReadInputTokens: cacheReadInputTokens,
                                            cacheCreationInputTokens: cacheCreationInputTokens,
                                            outputTokens: outputTokens,
                                            totalTokens: [inputTokens, cacheReadInputTokens, cacheCreationInputTokens, outputTokens]
                                                .compactMap { $0 }
                                                .reduce(0, +)
                                        )
                                    )
                                )
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
                            inputTokens = envelope.usage?.inputTokens ?? inputTokens
                            cacheReadInputTokens = envelope.usage?.cacheReadInputTokens ?? cacheReadInputTokens
                            cacheCreationInputTokens = envelope.usage?.cacheCreationInputTokens ?? cacheCreationInputTokens
                            outputTokens = envelope.usage?.outputTokens ?? outputTokens
                            finishReason = FinishReason(anthropicValue: envelope.delta?.stopReason)
                            continuation.yield(
                                .usage(
                                    Usage(
                                        inputTokens: inputTokens,
                                        cacheReadInputTokens: cacheReadInputTokens,
                                        cacheCreationInputTokens: cacheCreationInputTokens,
                                        outputTokens: outputTokens,
                                        totalTokens: [inputTokens, cacheReadInputTokens, cacheCreationInputTokens, outputTokens]
                                            .compactMap { $0 }
                                            .reduce(0, +)
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

    private func headers(for request: TextGenerationRequest) -> [String: String] {
        AnthropicRequestHeaders.make(
            apiKey: apiKey,
            betas: AnthropicMessagePayloadBuilder.requiredBetas(for: request)
        )
    }

    private func validateServerTools(for request: TextGenerationRequest) throws {
        let splitOptions = AnthropicRequestOptionsParser.split(
            from: request.providerOptions.options(for: AnthropicProvider.namespace)
        )
        let profile = AnthropicCapabilityResolver.profile(for: id)
        try AnthropicServerToolValidator.validate(
            splitOptions.serverTools,
            alongside: request.tools,
            hasContainerUploadFiles: AnthropicMessagePayloadBuilder.usesContainerUploads(messages: request.messages),
            containerID: splitOptions.containerID,
            modelID: id,
            profile: profile
        )
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
        let cacheReadInputTokens: Int?
        let cacheCreationInputTokens: Int?
        let outputTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case outputTokens = "output_tokens"
        }

        var usage: Usage {
            Usage(
                inputTokens: inputTokens,
                cacheReadInputTokens: cacheReadInputTokens,
                cacheCreationInputTokens: cacheCreationInputTokens,
                outputTokens: outputTokens,
                totalTokens: [inputTokens, cacheReadInputTokens, cacheCreationInputTokens, outputTokens]
                    .compactMap { $0 }
                    .reduce(0, +)
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
