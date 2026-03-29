import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Inline binary data returned by Gemini or sent in prompts.
public struct GoogleInlineData: Sendable, Hashable, Codable {
    /// The MIME type of the payload.
    public var mimeType: String

    /// The base64-encoded payload.
    public var data: String

    /// Creates inline data.
    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
}

/// A provider-managed file reference used by Gemini.
public struct GoogleFileReference: Sendable, Hashable, Codable {
    /// The MIME type associated with the file.
    public var mimeType: String?

    /// The reusable file URI.
    public var fileUri: String

    /// An optional display name.
    public var displayName: String?

    /// Creates a file reference.
    public init(mimeType: String? = nil, fileUri: String, displayName: String? = nil) {
        self.mimeType = mimeType
        self.fileUri = fileUri
        self.displayName = displayName
    }
}

/// A Gemini function call part.
public struct GoogleFunctionCall: Sendable, Hashable, Codable {
    /// The function name.
    public var name: String

    /// The function arguments.
    public var args: JSONValue?

    /// Creates a function call part.
    public init(name: String, args: JSONValue? = nil) {
        self.name = name
        self.args = args
    }
}

/// A Gemini function response part.
public struct GoogleFunctionResponse: Sendable, Hashable, Codable {
    /// The function name.
    public var name: String

    /// The response payload.
    public var response: JSONValue?

    /// Creates a function response part.
    public init(name: String, response: JSONValue? = nil) {
        self.name = name
        self.response = response
    }
}

/// Executable code emitted by Gemini.
public struct GoogleExecutableCode: Sendable, Hashable, Codable {
    /// The language of the code block.
    public var language: String?

    /// The source code.
    public var code: String?

    /// Creates executable code metadata.
    public init(language: String? = nil, code: String? = nil) {
        self.language = language
        self.code = code
    }
}

/// A code-execution result emitted by Gemini.
public struct GoogleCodeExecutionResult: Sendable, Hashable, Codable {
    /// The execution outcome.
    public var outcome: String?

    /// The stdout or textual result.
    public var output: String?

    /// Creates a code execution result.
    public init(outcome: String? = nil, output: String? = nil) {
        self.outcome = outcome
        self.output = output
    }
}

/// A Gemini content part.
public struct GoogleContentPart: Sendable, Hashable, Codable {
    /// Text content.
    public var text: String?

    /// Inline binary data.
    public var inlineData: GoogleInlineData?

    /// A provider-managed file reference.
    public var fileData: GoogleFileReference?

    /// A function call emitted by Gemini.
    public var functionCall: GoogleFunctionCall?

    /// A function response sent back to Gemini.
    public var functionResponse: GoogleFunctionResponse?

    /// Executable code emitted by the model.
    public var executableCode: GoogleExecutableCode?

    /// The result of code execution.
    public var codeExecutionResult: GoogleCodeExecutionResult?

    /// Whether the part represents a thought-like provider annotation.
    public var thought: Bool?

    /// Creates a content part.
    public init(
        text: String? = nil,
        inlineData: GoogleInlineData? = nil,
        fileData: GoogleFileReference? = nil,
        functionCall: GoogleFunctionCall? = nil,
        functionResponse: GoogleFunctionResponse? = nil,
        executableCode: GoogleExecutableCode? = nil,
        codeExecutionResult: GoogleCodeExecutionResult? = nil,
        thought: Bool? = nil
    ) {
        self.text = text
        self.inlineData = inlineData
        self.fileData = fileData
        self.functionCall = functionCall
        self.functionResponse = functionResponse
        self.executableCode = executableCode
        self.codeExecutionResult = codeExecutionResult
        self.thought = thought
    }
}

/// A Gemini content object.
public struct GoogleContent: Sendable, Hashable, Codable {
    /// The content role, usually `user` or `model`.
    public var role: String?

    /// The ordered content parts.
    public var parts: [GoogleContentPart]

    /// Creates a content object.
    public init(role: String? = nil, parts: [GoogleContentPart]) {
        self.role = role
        self.parts = parts
    }
}

/// A Gemini safety rating.
public struct GoogleSafetyRating: Sendable, Hashable, Codable {
    /// The harm category.
    public var category: String?

    /// The provider probability rating.
    public var probability: String?

    /// The severity label when present.
    public var severity: String?

    /// Whether the content was blocked.
    public var blocked: Bool?

    /// Creates a safety rating.
    public init(
        category: String? = nil,
        probability: String? = nil,
        severity: String? = nil,
        blocked: Bool? = nil
    ) {
        self.category = category
        self.probability = probability
        self.severity = severity
        self.blocked = blocked
    }
}

/// Citation metadata returned by Gemini.
public struct GoogleCitationMetadata: Sendable, Hashable, Codable {
    /// Individual citation objects.
    public var citationSources: [JSONValue]

    /// Creates citation metadata.
    public init(citationSources: [JSONValue] = []) {
        self.citationSources = citationSources
    }

    private enum CodingKeys: String, CodingKey {
        case citationSources
    }
}

/// Grounding metadata returned by Gemini built-in tools.
public struct GoogleGroundingMetadata: Sendable, Hashable, Codable {
    /// The web search queries issued on the model's behalf.
    public var webSearchQueries: [String]

    /// Raw grounding chunks.
    public var groundingChunks: [JSONValue]

    /// Raw grounding supports.
    public var groundingSupports: [JSONValue]

    /// A Google Maps widget context token when returned.
    public var googleMapsWidgetContextToken: String?

    /// The entry point metadata returned by Google Search.
    public var searchEntryPoint: JSONValue?

    /// Creates grounding metadata.
    public init(
        webSearchQueries: [String] = [],
        groundingChunks: [JSONValue] = [],
        groundingSupports: [JSONValue] = [],
        googleMapsWidgetContextToken: String? = nil,
        searchEntryPoint: JSONValue? = nil
    ) {
        self.webSearchQueries = webSearchQueries
        self.groundingChunks = groundingChunks
        self.groundingSupports = groundingSupports
        self.googleMapsWidgetContextToken = googleMapsWidgetContextToken
        self.searchEntryPoint = searchEntryPoint
    }

    private enum CodingKeys: String, CodingKey {
        case webSearchQueries
        case groundingChunks
        case groundingSupports
        case googleMapsWidgetContextToken
        case searchEntryPoint
    }
}

/// Prompt feedback returned by Gemini.
public struct GooglePromptFeedback: Sendable, Hashable, Codable {
    /// The block reason when the prompt is rejected.
    public var blockReason: String?

    /// Prompt safety ratings.
    public var safetyRatings: [GoogleSafetyRating]

    /// Creates prompt feedback.
    public init(blockReason: String? = nil, safetyRatings: [GoogleSafetyRating] = []) {
        self.blockReason = blockReason
        self.safetyRatings = safetyRatings
    }
}

/// A Gemini generation candidate.
public struct GoogleContentCandidate: Sendable, Hashable, Codable {
    /// The generated content.
    public var content: GoogleContent

    /// The finish reason.
    public var finishReason: String?

    /// Candidate safety ratings.
    public var safetyRatings: [GoogleSafetyRating]

    /// Citation metadata.
    public var citationMetadata: GoogleCitationMetadata?

    /// Grounding metadata.
    public var groundingMetadata: GoogleGroundingMetadata?

    /// Average log probabilities.
    public var avgLogprobs: Double?

    /// Candidate index when returned.
    public var index: Int?

    /// Creates a content candidate.
    public init(
        content: GoogleContent,
        finishReason: String? = nil,
        safetyRatings: [GoogleSafetyRating] = [],
        citationMetadata: GoogleCitationMetadata? = nil,
        groundingMetadata: GoogleGroundingMetadata? = nil,
        avgLogprobs: Double? = nil,
        index: Int? = nil
    ) {
        self.content = content
        self.finishReason = finishReason
        self.safetyRatings = safetyRatings
        self.citationMetadata = citationMetadata
        self.groundingMetadata = groundingMetadata
        self.avgLogprobs = avgLogprobs
        self.index = index
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(GoogleContent.self, forKey: .content)
        finishReason = try container.decodeIfPresent(String.self, forKey: .finishReason)
        safetyRatings = try container.decodeIfPresent([GoogleSafetyRating].self, forKey: .safetyRatings) ?? []
        citationMetadata = try container.decodeIfPresent(GoogleCitationMetadata.self, forKey: .citationMetadata)
        groundingMetadata = try container.decodeIfPresent(GoogleGroundingMetadata.self, forKey: .groundingMetadata)
        avgLogprobs = try container.decodeIfPresent(Double.self, forKey: .avgLogprobs)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
    }
}

/// Usage metadata returned by Gemini content generation.
public struct GoogleContentUsageMetadata: Sendable, Hashable, Codable {
    /// Prompt token count.
    public var promptTokenCount: Int?

    /// Candidate token count.
    public var candidatesTokenCount: Int?

    /// Total token count.
    public var totalTokenCount: Int?

    /// Cached content token count.
    public var cachedContentTokenCount: Int?

    /// Creates usage metadata.
    public init(
        promptTokenCount: Int? = nil,
        candidatesTokenCount: Int? = nil,
        totalTokenCount: Int? = nil,
        cachedContentTokenCount: Int? = nil
    ) {
        self.promptTokenCount = promptTokenCount
        self.candidatesTokenCount = candidatesTokenCount
        self.totalTokenCount = totalTokenCount
        self.cachedContentTokenCount = cachedContentTokenCount
    }

    /// Normalized usage metadata for the provider-neutral layer.
    public var usage: Usage {
        Usage(
            inputTokens: promptTokenCount,
            outputTokens: candidatesTokenCount,
            totalTokens: totalTokenCount
        )
    }
}

/// A raw Gemini content-generation response.
public struct GoogleContentResponse: Sendable, Hashable, Codable {
    /// The response candidates.
    public var candidates: [GoogleContentCandidate]

    /// Prompt feedback.
    public var promptFeedback: GooglePromptFeedback?

    /// Usage metadata.
    public var usageMetadata: GoogleContentUsageMetadata?

    /// The resolved provider model version.
    public var modelVersion: String?

    /// Creates a content-generation response.
    public init(
        candidates: [GoogleContentCandidate],
        promptFeedback: GooglePromptFeedback? = nil,
        usageMetadata: GoogleContentUsageMetadata? = nil,
        modelVersion: String? = nil
    ) {
        self.candidates = candidates
        self.promptFeedback = promptFeedback
        self.usageMetadata = usageMetadata
        self.modelVersion = modelVersion
    }
}

/// A raw Gemini content-generation request.
public struct GoogleContentRequest: Sendable, Hashable {
    /// An optional explicit model name such as `models/gemini-2.5-flash`.
    public var model: String?

    /// A system instruction.
    public var systemInstruction: GoogleContent?

    /// The conversation contents.
    public var contents: [GoogleContent]

    /// Tool definitions appended to the request.
    public var tools: [GoogleToolDefinition]

    /// Explicit tool configuration.
    public var toolConfig: GoogleToolConfiguration?

    /// Safety settings.
    public var safetySettings: [GoogleSafetySetting]

    /// Google generation and request options.
    public var options: GoogleProviderOptions

    /// Extra raw fields merged into the request body.
    public var extraOptions: JSONValue?

    /// Creates a raw content request.
    public init(
        model: String? = nil,
        systemInstruction: GoogleContent? = nil,
        contents: [GoogleContent],
        tools: [GoogleToolDefinition] = [],
        toolConfig: GoogleToolConfiguration? = nil,
        safetySettings: [GoogleSafetySetting] = [],
        options: GoogleProviderOptions = GoogleProviderOptions(),
        extraOptions: JSONValue? = nil
    ) {
        self.model = model
        self.systemInstruction = systemInstruction
        self.contents = contents
        self.tools = tools
        self.toolConfig = toolConfig
        self.safetySettings = safetySettings
        self.options = options
        self.extraOptions = extraOptions
    }

    func jsonValue(defaultModelID: String) throws -> JSONValue {
        var object: [String: JSONValue] = [
            "model": .string(model ?? "models/\(defaultModelID)"),
            "contents": .array(try contents.map { try JSONValue.encode($0) }),
        ]

        if let systemInstruction {
            object["systemInstruction"] = try JSONValue.encode(systemInstruction)
        }
        if tools.isEmpty == false {
            object["tools"] = .array(tools.map(\.payload))
        }
        if let toolConfig {
            object["toolConfig"] = toolConfig.jsonValue
        }
        if safetySettings.isEmpty == false {
            object["safetySettings"] = .array(safetySettings.map(\.jsonValue))
        }

        let withTypedOptions = mergeGoogleProviderOptions(.object(object), with: options.jsonValue())
        return mergeGoogleProviderOptions(withTypedOptions, with: extraOptions)
    }
}

/// A raw Gemini count-tokens request.
public struct GoogleCountTokensRequest: Sendable, Hashable {
    /// Contents to count when a full generate-content request is not provided.
    public var contents: [GoogleContent]

    /// The full generate-content request to count.
    public var generateContentRequest: GoogleContentRequest?

    /// Creates a count-tokens request.
    public init(
        contents: [GoogleContent] = [],
        generateContentRequest: GoogleContentRequest? = nil
    ) {
        self.contents = contents
        self.generateContentRequest = generateContentRequest
    }

    func jsonValue(defaultModelID: String) throws -> JSONValue {
        var object: [String: JSONValue] = [:]
        if contents.isEmpty == false {
            object["contents"] = .array(try contents.map { try JSONValue.encode($0) })
        }
        if let generateContentRequest {
            object["generateContentRequest"] = try generateContentRequest.jsonValue(defaultModelID: defaultModelID)
        }
        return .object(object)
    }
}

/// A token-count response from Gemini.
public struct GoogleTokenCountResponse: Sendable, Hashable, Codable {
    /// Total tokens in the request.
    public var totalTokens: Int?

    /// Tokens coming from cached content.
    public var cachedContentTokenCount: Int?

    /// Prompt-token details when returned.
    public var promptTokensDetails: [JSONValue]

    /// Cache-token details when returned.
    public var cacheTokensDetails: [JSONValue]

    /// Creates a token-count response.
    public init(
        totalTokens: Int? = nil,
        cachedContentTokenCount: Int? = nil,
        promptTokensDetails: [JSONValue] = [],
        cacheTokensDetails: [JSONValue] = []
    ) {
        self.totalTokens = totalTokens
        self.cachedContentTokenCount = cachedContentTokenCount
        self.promptTokensDetails = promptTokensDetails
        self.cacheTokensDetails = cacheTokensDetails
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
        cachedContentTokenCount = try container.decodeIfPresent(Int.self, forKey: .cachedContentTokenCount)
        promptTokensDetails = try container.decodeIfPresent([JSONValue].self, forKey: .promptTokensDetails) ?? []
        cacheTokensDetails = try container.decodeIfPresent([JSONValue].self, forKey: .cacheTokensDetails) ?? []
    }
}

/// A raw `generateAnswer` request wrapper.
public struct GoogleGenerateAnswerRequest: Sendable, Hashable {
    /// The raw request payload.
    public var payload: JSONValue

    /// Creates a raw answer request.
    public init(payload: JSONValue) {
        self.payload = payload
    }
}

/// A raw `generateAnswer` response wrapper.
public struct GoogleGenerateAnswerResponse: Sendable, Hashable {
    /// The raw response payload.
    public var payload: JSONValue

    /// Creates a raw answer response.
    public init(payload: JSONValue) {
        self.payload = payload
    }
}

/// Streaming events emitted by the raw Gemini content API.
public enum GoogleContentStreamEvent: Sendable {
    /// The stream has started.
    case status(String)

    /// A raw streamed response chunk.
    case chunk(GoogleContentResponse)

    /// A text delta extracted from the chunk.
    case textDelta(String)

    /// A provider-neutral tool call extracted from the chunk.
    case toolCall(ToolInvocation)

    /// Usage metadata extracted from the chunk.
    case usage(Usage)

    /// Grounding metadata extracted from a chunk.
    case grounding(GoogleGroundingMetadata)

    /// The stream has finished.
    case finished(FinishReason)
}

/// A raw Gemini content model that exposes the full `generateContent` surface.
public struct GoogleContentModel: Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let configuration: GoogleServiceConfiguration

    init(id: String, configuration: GoogleServiceConfiguration) {
        self.id = id
        self.configuration = configuration
        self.capabilities = GoogleCapabilityResolver.profile(for: id).capabilities
    }

    /// Generates content with the raw Gemini API.
    public func generateContent(_ request: GoogleContentRequest) async throws -> GoogleContentResponse {
        try await ensure(method: "generateContent")
        let response = try await configuration.client.send(
            HTTPRequest(
                url: configuration.stableURL("models/\(id):generateContent"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try request.jsonValue(defaultModelID: id).data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        return try JSONDecoder().decode(GoogleContentResponse.self, from: response.body)
    }

    /// Streams content with the raw Gemini API.
    public func streamGenerateContent(_ request: GoogleContentRequest) -> AsyncThrowingStream<GoogleContentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await ensure(method: "generateContent")
                    continuation.yield(.status("started"))
                    let stream = await configuration.client.streamEvents(
                        HTTPRequest(
                            url: configuration.stableURL(
                                "models/\(id):streamGenerateContent",
                                queryItems: [URLQueryItem(name: "alt", value: "sse")]
                            ),
                            method: .post,
                            headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                            body: try request.jsonValue(defaultModelID: id).data()
                        )
                    )

                    var finishReason: FinishReason = .unknown
                    var emittedToolCalls: Set<StreamedToolCallKey> = []

                    for try await event in stream {
                        guard event.data.isEmpty == false else { continue }

                        let decoded = try JSONDecoder().decode(GoogleContentResponse.self, from: Data(event.data.utf8))
                        continuation.yield(.chunk(decoded))

                        if let usage = decoded.usageMetadata?.usage {
                            continuation.yield(.usage(usage))
                        }

                        for (candidateOffset, candidate) in decoded.candidates.enumerated() {
                            if let groundingMetadata = candidate.groundingMetadata {
                                continuation.yield(.grounding(groundingMetadata))
                            }

                            for (partOffset, part) in candidate.content.parts.enumerated() {
                                if let text = part.text, text.isEmpty == false {
                                    continuation.yield(.textDelta(text))
                                }

                                if let functionCall = part.functionCall {
                                    let key = StreamedToolCallKey(
                                        candidateIndex: candidate.index ?? candidateOffset,
                                        partIndex: partOffset
                                    )
                                    if emittedToolCalls.insert(key).inserted {
                                        continuation.yield(
                                            .toolCall(
                                                ToolInvocation(
                                                    name: functionCall.name,
                                                    input: functionCall.args ?? .object([:])
                                                )
                                            )
                                        )
                                    }
                                }
                            }

                            if let candidateFinishReason = candidate.finishReason {
                                finishReason = FinishReason(googleValue: candidateFinishReason)
                            }
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

    /// Counts tokens for a Gemini request.
    public func countTokens(_ request: GoogleCountTokensRequest) async throws -> GoogleTokenCountResponse {
        try await ensure(method: "countTokens")
        let payload = try await configuration.client.send(
            HTTPRequest(
                url: configuration.stableURL("models/\(id):countTokens"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try request.jsonValue(defaultModelID: id).data()
            )
        )

        guard (200..<300).contains(payload.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: payload.statusCode,
                body: String(data: payload.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        return try JSONDecoder().decode(GoogleTokenCountResponse.self, from: payload.body)
    }

    /// Calls the raw `generateAnswer` endpoint for answer-capable models.
    public func generateAnswer(_ request: GoogleGenerateAnswerRequest) async throws -> GoogleGenerateAnswerResponse {
        try await ensure(method: "generateAnswer")
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("models/\(id):generateAnswer"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try request.payload.data()
            )
        )
        return GoogleGenerateAnswerResponse(payload: payload)
    }

    private func ensure(method: String) async throws {
        let metadata = await configuration.catalog.model(id: id)
        let profile = GoogleCapabilityResolver.profile(for: id, metadata: metadata)

        switch method {
        case "generateContent":
            guard profile.supportsGenerateContent else {
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "generateContent")
            }
        case "countTokens":
            guard profile.supportsCountTokens else {
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "countTokens")
            }
        case "generateAnswer":
            guard profile.supportsGenerateAnswer else {
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "generateAnswer")
            }
        default:
            return
        }
    }
}

private struct StreamedToolCallKey: Hashable {
    let candidateIndex: Int
    let partIndex: Int
}

/// A provider-neutral Gemini language model.
public struct GoogleLanguageModel: LanguageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let contentModel: GoogleContentModel

    init(id: String, configuration: GoogleServiceConfiguration) {
        self.id = id
        self.contentModel = GoogleContentModel(id: id, configuration: configuration)
        self.capabilities = contentModel.capabilities
    }

    public func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        try CapabilityValidator.validate(request, for: self, streaming: false)
        let contentRequest = try GoogleLanguageModel.makeContentRequest(
            from: request,
            modelID: id,
            imageResponse: false
        )
        let decoded = try await contentModel.generateContent(contentRequest)
        return try Self.normalize(response: decoded, modelID: id)
    }

    public func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try CapabilityValidator.validate(request, for: self, streaming: true)
                    let contentRequest = try GoogleLanguageModel.makeContentRequest(
                        from: request,
                        modelID: id,
                        imageResponse: false
                    )
                    let stream = contentModel.streamGenerateContent(contentRequest)

                    for try await event in stream {
                        switch event {
                        case .status(let status):
                            continuation.yield(.status(status))
                        case .textDelta(let delta):
                            continuation.yield(.textDelta(delta))
                        case .toolCall(let invocation):
                            continuation.yield(.toolCall(invocation))
                        case .usage(let usage):
                            continuation.yield(.usage(usage))
                        case .finished(let reason):
                            continuation.yield(.finished(reason))
                        case .chunk, .grounding:
                            continue
                        }
                    }

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

    fileprivate static func makeContentRequest(
        from request: TextGenerationRequest,
        modelID: String,
        imageResponse: Bool
    ) throws -> GoogleContentRequest {
        let normalized = MessagePipeline.normalize(request.messages)
        let contents = try normalized
            .filter { $0.role != .system }
            .map(mapContent)

        let systemInstruction: GoogleContent? = if let system = MessagePipeline.systemPrompt(from: normalized) {
            GoogleContent(parts: [GoogleContentPart(text: system)])
        } else {
            nil
        }

        var options = GoogleProviderOptions(
            temperature: request.generation.temperature,
            topP: request.generation.topP,
            maxOutputTokens: request.generation.maxOutputTokens,
            stopSequences: request.generation.stopSequences,
            responseMimeType: request.structuredOutput == nil ? nil : "application/json",
            responseSchema: request.structuredOutput?.schema,
            responseModalities: imageResponse ? ["TEXT", "IMAGE"] : []
        )

        var tools: [GoogleToolDefinition] = []
        if request.tools.isEmpty == false {
            tools.append(
                .functionDeclarations(
                    request.tools.tools.map { tool in
                        GoogleFunctionDeclaration(
                            name: tool.name,
                            description: tool.description,
                            parameters: tool.inputSchema
                        )
                    }
                )
            )
            options.toolConfig = GoogleToolConfiguration(
                functionCalling: GoogleFunctionCallingConfiguration(mode: .auto)
            )
        }

        return GoogleContentRequest(
            model: "models/\(modelID)",
            systemInstruction: systemInstruction,
            contents: contents,
            tools: tools,
            options: options,
            extraOptions: request.providerOptions.options(for: GoogleProvider.namespace)
        )
    }

    fileprivate static func normalize(
        response: GoogleContentResponse,
        modelID: String
    ) throws -> TextGenerationResponse {
        guard let candidate = response.candidates.first else {
            throw KaizoshaError.invalidResponse("Google returned no candidates.")
        }

        let text = candidate.content.parts.compactMap(\.text).joined()
        let toolInvocations = candidate.content.parts.compactMap { part -> ToolInvocation? in
            guard let functionCall = part.functionCall else { return nil }
            return ToolInvocation(
                name: functionCall.name,
                input: functionCall.args ?? .object([:])
            )
        }

        let parts = (text.isEmpty ? [] : [MessagePart.text(text)]) + toolInvocations.map(MessagePart.toolCall)
        return TextGenerationResponse(
            modelID: modelID,
            message: Message(role: .assistant, parts: parts),
            text: text,
            toolInvocations: toolInvocations,
            usage: response.usageMetadata?.usage,
            finishReason: FinishReason(googleValue: candidate.finishReason),
            rawPayload: try JSONValue.encode(response)
        )
    }

    private static func mapContent(_ message: ModelMessage) throws -> GoogleContent {
        let role: String = switch message.role {
        case .user, .tool:
            "user"
        case .assistant:
            "model"
        case .system:
            "user"
        }

        return GoogleContent(
            role: role,
            parts: try message.parts.map(mapPart)
        )
    }

    private static func mapPart(_ part: ModelPart) throws -> GoogleContentPart {
        switch part {
        case .text(let text):
            return GoogleContentPart(text: text)
        case .image(let image):
            let data: Data
            if let inline = image.data {
                data = inline
            } else if let url = image.url, url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                throw KaizoshaError.invalidRequest("Google image prompt parts require inline data or a file URL.")
            }
            return GoogleContentPart(
                inlineData: GoogleInlineData(
                    mimeType: image.mimeType,
                    data: data.base64EncodedString()
                )
            )
        case .audio(let audio):
            return GoogleContentPart(
                inlineData: GoogleInlineData(
                    mimeType: audio.mimeType,
                    data: audio.data.base64EncodedString()
                )
            )
        case .file(let file):
            let value = try GoogleRequestSupport.validate(file)
            guard let part = try? JSONDecoder().decode(GoogleContentPart.self, from: value.data()) else {
                throw KaizoshaError.invalidRequest("Unable to encode Google file prompt content.")
            }
            return part
        case .toolCall(let invocation):
            return GoogleContentPart(
                functionCall: GoogleFunctionCall(
                    name: invocation.name,
                    args: invocation.input
                )
            )
        case .toolResult(let result):
            return GoogleContentPart(
                functionResponse: GoogleFunctionResponse(
                    name: result.name,
                    response: .object([
                        "name": .string(result.name),
                        "content": result.output,
                    ])
                )
            )
        }
    }
}

/// A Gemini embedding model.
public struct GoogleEmbeddingModel: EmbeddingModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let configuration: GoogleServiceConfiguration

    init(id: String, configuration: GoogleServiceConfiguration) {
        self.id = id
        self.configuration = configuration
        self.capabilities = GoogleCapabilityResolver.profile(for: id).capabilities
    }

    public func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        try CapabilityValidator.validate(request, for: self)
        var vectors: [[Double]] = []

        for text in request.texts {
            let body = mergeGoogleProviderOptions(
                .object([
                    "model": .string("models/\(id)"),
                    "content": .object([
                        "parts": .array([
                            .object(["text": .string(text)]),
                        ]),
                    ]),
                ]),
                with: request.providerOptions.options(for: GoogleProvider.namespace)
            )

            let response = try await configuration.client.send(
                HTTPRequest(
                    url: configuration.stableURL("models/\(id):embedContent"),
                    method: .post,
                    headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                    body: try body.data()
                )
            )

            guard (200..<300).contains(response.statusCode) else {
                throw KaizoshaError.httpFailure(
                    statusCode: response.statusCode,
                    body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
                )
            }

            let decoded = try JSONDecoder().decode(GoogleEmbeddingResponse.self, from: response.body)
            vectors.append(decoded.embedding.values)
        }

        return EmbeddingResponse(modelID: id, embeddings: vectors, usage: nil)
    }
}

/// A Gemini image-capable model.
public struct GoogleImageModel: ImageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let configuration: GoogleServiceConfiguration

    init(id: String, configuration: GoogleServiceConfiguration) {
        self.id = id
        self.configuration = configuration
        self.capabilities = GoogleCapabilityResolver.profile(for: id).capabilities
    }

    public func generateImage(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        try CapabilityValidator.validate(request, for: self)
        var textRequest = TextGenerationRequest(
            prompt: request.prompt,
            providerOptions: request.providerOptions,
            metadata: request.metadata
        )
        textRequest.generation = GenerationConfig(maxOutputTokens: 1024)

        let contentRequest = try GoogleLanguageModel.makeContentRequest(
            from: textRequest,
            modelID: id,
            imageResponse: true
        )
        let decoded = try await GoogleContentModel(id: id, configuration: configuration).generateContent(contentRequest)
        let inlineParts = decoded.candidates
            .flatMap(\.content.parts)
            .compactMap(\.inlineData)

        let images = try inlineParts.map { part in
            guard let data = Data(base64Encoded: part.data) else {
                throw KaizoshaError.invalidResponse("Google returned invalid inline image data.")
            }
            return GeneratedImage(data: data, mimeType: part.mimeType)
        }

        guard images.isEmpty == false else {
            throw KaizoshaError.invalidResponse("Google did not return any inline image data.")
        }

        return ImageGenerationResponse(modelID: id, images: images)
    }
}

private struct GoogleEmbeddingResponse: Decodable {
    struct Embedding: Decodable {
        let values: [Double]
    }

    let embedding: Embedding
}
