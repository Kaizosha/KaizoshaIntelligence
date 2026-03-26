import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Provider-specific options for the Google adapter.
public struct GoogleProviderOptions: Sendable, Hashable {
    /// The number of candidate responses to request.
    public var candidateCount: Int?

    /// An optional top-k sampling value.
    public var topK: Int?

    /// Creates Google-specific options.
    public init(candidateCount: Int? = nil, topK: Int? = nil) {
        self.candidateCount = candidateCount
        self.topK = topK
    }

    /// Encodes the options into a JSON payload.
    public func jsonValue() -> JSONValue {
        var generationConfig: [String: JSONValue] = [:]

        if let candidateCount {
            generationConfig["candidateCount"] = .number(Double(candidateCount))
        }

        if let topK {
            generationConfig["topK"] = .number(Double(topK))
        }

        guard generationConfig.isEmpty == false else { return .object([:]) }
        return .object(["generationConfig": .object(generationConfig)])
    }
}

/// A provider factory for Google Gemini-backed models.
public struct GoogleProvider: Sendable {
    /// The provider namespace used in namespaced options.
    public static let namespace = "google"

    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    /// Creates a Google provider.
    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"],
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
        transport: (any HTTPTransport)? = nil,
        retryPolicy: RetryPolicy = .default
    ) throws {
        guard let apiKey, apiKey.isEmpty == false else {
            throw KaizoshaError.missingAPIKey(namespace: "GOOGLE_API_KEY")
        }

        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = HTTPClient(transport: transport, retryPolicy: retryPolicy)
    }

    /// Creates a Gemini language model handle.
    public func languageModel(_ id: String) -> GoogleLanguageModel {
        GoogleLanguageModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Creates a Gemini embedding model handle.
    public func embeddingModel(_ id: String) -> GoogleEmbeddingModel {
        GoogleEmbeddingModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }

    /// Creates a Gemini image-capable model handle.
    public func imageModel(_ id: String) -> GoogleImageModel {
        GoogleImageModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
    }
}

/// A Google language model.
public struct GoogleLanguageModel: LanguageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportsStreaming: true,
        supportsToolCalling: true,
        supportsStructuredOutput: true,
        supportsImageInput: true,
        supportsAudioInput: true,
        supportsFileInput: true,
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
        let body = try payload(for: request, imageResponse: false)
        let response = try await client.send(
            HTTPRequest(
                url: endpoint(":generateContent"),
                headers: ["Content-Type": "application/json"],
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: response.body)
        guard let candidate = decoded.candidates.first else {
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
            modelID: id,
            message: Message(role: .assistant, parts: parts),
            text: text,
            toolInvocations: toolInvocations,
            usage: decoded.usageMetadata?.usage,
            finishReason: FinishReason(googleValue: candidate.finishReason),
            rawPayload: try? JSONValue.decode(response.body)
        )
    }

    public func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try CapabilityValidator.validate(request, for: self, streaming: true)
                    continuation.yield(.status("started"))
                    let body = try payload(for: request, imageResponse: false)
                    let events = await client.streamEvents(
                        HTTPRequest(
                            url: endpoint(":streamGenerateContent", extraQueryItems: [URLQueryItem(name: "alt", value: "sse")]),
                            headers: ["Content-Type": "application/json"],
                            body: try body.data()
                        )
                    )

                    var finishReason: FinishReason = .unknown
                    var emittedToolCalls: Set<String> = []

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }

                        let decoded = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: Data(event.data.utf8))
                        if let usage = decoded.usageMetadata?.usage {
                            continuation.yield(.usage(usage))
                        }

                        for candidate in decoded.candidates {
                            for part in candidate.content.parts {
                                if let text = part.text, text.isEmpty == false {
                                    continuation.yield(.textDelta(text))
                                }

                                if let functionCall = part.functionCall {
                                    let argsSignature = try functionCall.args?.compactString() ?? "{}"
                                    let signature = [functionCall.name, argsSignature].joined(separator: "|")

                                    if emittedToolCalls.contains(signature) == false {
                                        emittedToolCalls.insert(signature)
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

                            if let reason = candidate.finishReason {
                                finishReason = FinishReason(googleValue: reason)
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

    fileprivate func payload(for request: TextGenerationRequest, imageResponse: Bool) throws -> JSONValue {
        let normalized = MessagePipeline.normalize(request.messages)
        let contents = try normalized
            .filter { $0.role != .system }
            .map(mapContent)

        var object: [String: JSONValue] = [
            "contents": .array(contents),
        ]

        if let system = MessagePipeline.systemPrompt(from: normalized) {
            object["systemInstruction"] = .object([
                "parts": .array([
                    .object(["text": .string(system)]),
                ]),
            ])
        }

        var generationConfig: [String: JSONValue] = [:]
        if let temperature = request.generation.temperature {
            generationConfig["temperature"] = .number(temperature)
        }
        if let topP = request.generation.topP {
            generationConfig["topP"] = .number(topP)
        }
        if let maxOutputTokens = request.generation.maxOutputTokens {
            generationConfig["maxOutputTokens"] = .number(Double(maxOutputTokens))
        }
        if request.generation.stopSequences.isEmpty == false {
            generationConfig["stopSequences"] = .array(request.generation.stopSequences.map(JSONValue.string))
        }
        if let structuredOutput = request.structuredOutput {
            generationConfig["responseMimeType"] = .string("application/json")
            generationConfig["responseSchema"] = structuredOutput.schema
        }
        if imageResponse {
            generationConfig["responseModalities"] = .array([.string("TEXT"), .string("IMAGE")])
        }
        if generationConfig.isEmpty == false {
            object["generationConfig"] = .object(generationConfig)
        }
        if request.tools.isEmpty == false {
            object["tools"] = .array([
                .object([
                    "functionDeclarations": .array(request.tools.tools.map { tool in
                        .object([
                            "name": .string(tool.name),
                            "description": .string(tool.description),
                            "parameters": tool.inputSchema,
                        ])
                    }),
                ]),
            ])
        }

        return mergeGoogleProviderOptions(
            JSONValue.object(object),
            with: request.providerOptions.options(for: GoogleProvider.namespace)
        )
    }

    private func endpoint(_ suffix: String, extraQueryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "models/\(id)\(suffix)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)] + extraQueryItems
        return components.url!
    }

    private func mapContent(_ message: ModelMessage) throws -> JSONValue {
        let role: String = switch message.role {
        case .user, .tool:
            "user"
        case .assistant:
            "model"
        case .system:
            "user"
        }

        return .object([
            "role": .string(role),
            "parts": .array(try message.parts.map(mapPart)),
        ])
    }

    private func mapPart(_ part: ModelPart) throws -> JSONValue {
        switch part {
        case .text(let text):
            return .object(["text": .string(text)])
        case .image(let image):
            let data: Data
            if let inline = image.data {
                data = inline
            } else if let url = image.url, url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                throw KaizoshaError.invalidRequest("Google image prompt parts require inline data or a file URL.")
            }
            return .object([
                "inlineData": .object([
                    "mimeType": .string(image.mimeType),
                    "data": .string(data.base64EncodedString()),
                ]),
            ])
        case .audio(let audio):
            return .object([
                "inlineData": .object([
                    "mimeType": .string(audio.mimeType),
                    "data": .string(audio.data.base64EncodedString()),
                ]),
            ])
        case .file(let file):
            return .object([
                "inlineData": .object([
                    "mimeType": .string(file.mimeType),
                    "data": .string(file.data.base64EncodedString()),
                ]),
            ])
        case .toolCall(let invocation):
            return .object([
                "functionCall": .object([
                    "name": .string(invocation.name),
                    "args": invocation.input,
                ]),
            ])
        case .toolResult(let result):
            return .object([
                "functionResponse": .object([
                    "name": .string(result.name),
                    "response": .object([
                        "name": .string(result.name),
                        "content": result.output,
                    ]),
                ]),
            ])
        }
    }
}

/// A Google embedding model.
public struct GoogleEmbeddingModel: EmbeddingModel, Sendable {
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
        var vectors: [[Double]] = []

        for text in request.texts {
            let body = mergeGoogleProviderOptions(
                JSONValue.object([
                "model": .string("models/\(id)"),
                "content": .object([
                    "parts": .array([
                        .object(["text": .string(text)]),
                    ]),
                ]),
                ]),
                with: request.providerOptions.options(for: GoogleProvider.namespace)
            )

            let response = try await client.send(
                HTTPRequest(
                    url: endpoint(":embedContent"),
                    headers: ["Content-Type": "application/json"],
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

    private func endpoint(_ suffix: String) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "models/\(id)\(suffix)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components.url!
    }
}

/// A Google image-capable model.
public struct GoogleImageModel: ImageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities = ModelCapabilities(
        supportsMultipleImageOutputs: false
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
        let model = GoogleLanguageModel(id: id, apiKey: apiKey, baseURL: baseURL, client: client)
        var textRequest = TextGenerationRequest(
            prompt: request.prompt,
            providerOptions: request.providerOptions,
            metadata: request.metadata
        )
        textRequest.generation = GenerationConfig(maxOutputTokens: 1024)

        let body = try model.payload(for: textRequest, imageResponse: true)
        let response = try await client.send(
            HTTPRequest(
                url: endpoint(":generateContent"),
                headers: ["Content-Type": "application/json"],
                body: try body.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let decoded = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: response.body)
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

    private func endpoint(_ suffix: String, extraQueryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "models/\(id)\(suffix)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)] + extraQueryItems
        return components.url!
    }
}

public extension ProviderOptions {
    /// Stores Google-specific options under the Google namespace.
    mutating func setGoogle(_ options: GoogleProviderOptions) {
        set(options.jsonValue(), for: GoogleProvider.namespace)
    }
}

private func mergeGoogleProviderOptions(_ base: JSONValue, with providerOptions: JSONValue?) -> JSONValue {
    guard
        case .object(var merged) = base,
        let providerOptions,
        case .object(var providerObject) = providerOptions
    else {
        return base.mergingObject(with: providerOptions)
    }

    if let providerGenerationConfig = providerObject["generationConfig"] {
        let existingConfig = merged["generationConfig"] ?? .object([:])
        merged["generationConfig"] = existingConfig.mergingObject(with: providerGenerationConfig)
        providerObject.removeValue(forKey: "generationConfig")
    }

    for (key, value) in providerObject {
        merged[key] = value
    }

    return .object(merged)
}

private struct GoogleGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                struct FunctionCall: Decodable {
                    let name: String
                    let args: JSONValue?
                }

                struct InlineData: Decodable {
                    let mimeType: String
                    let data: String

                    private enum CodingKeys: String, CodingKey {
                        case mimeType
                        case data
                    }
                }

                let text: String?
                let functionCall: FunctionCall?
                let inlineData: InlineData?

                private enum CodingKeys: String, CodingKey {
                    case text
                    case functionCall
                    case inlineData
                }
            }

            let parts: [Part]
        }

        let content: Content
        let finishReason: String?
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?

        var usage: Usage {
            Usage(
                inputTokens: promptTokenCount,
                outputTokens: candidatesTokenCount,
                totalTokens: totalTokenCount
            )
        }
    }

    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?
}

private struct GoogleEmbeddingResponse: Decodable {
    struct Embedding: Decodable {
        let values: [Double]
    }

    let embedding: Embedding
}

private extension FinishReason {
    init(googleValue: String?) {
        switch googleValue {
        case "STOP":
            self = .stop
        case "MAX_TOKENS":
            self = .length
        case "SAFETY":
            self = .contentFilter
        case nil:
            self = .unknown
        default:
            self = .unknown
        }
    }
}
