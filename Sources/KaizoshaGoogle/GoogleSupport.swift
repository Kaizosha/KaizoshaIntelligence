import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// The media resolution hint used by Gemini generation requests.
public enum GoogleMediaResolution: String, Sendable, Hashable, Codable {
    case mediaResolutionUnspecified = "MEDIA_RESOLUTION_UNSPECIFIED"
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

/// Function-calling modes supported by Gemini tool configuration.
public enum GoogleFunctionCallingMode: String, Sendable, Hashable, Codable {
    case unspecified = "MODE_UNSPECIFIED"
    case auto = "AUTO"
    case any = "ANY"
    case none = "NONE"
}

/// A Google Search time range filter.
public struct GoogleSearchTimeRange: Sendable, Hashable, Codable {
    /// The inclusive start time.
    public var startTime: Date?

    /// The exclusive end time.
    public var endTime: Date?

    /// Creates a time range filter.
    public init(startTime: Date? = nil, endTime: Date? = nil) {
        self.startTime = startTime
        self.endTime = endTime
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let startTime {
            object["startTime"] = .string(GoogleEncoding.iso8601(startTime))
        }
        if let endTime {
            object["endTime"] = .string(GoogleEncoding.iso8601(endTime))
        }
        return .object(object)
    }
}

/// Search types used by the Google Search built-in tool.
public struct GoogleSearchTypes: Sendable, Hashable {
    /// Whether web search is enabled.
    public var web: Bool

    /// Creates a search-types configuration.
    public init(web: Bool = true) {
        self.web = web
    }

    var jsonValue: JSONValue {
        .object([
            "webSearch": .bool(web),
        ])
    }
}

/// The Gemini thinking configuration.
public struct GoogleThinkingConfig: Sendable, Hashable, Codable {
    /// Whether the model should include thought summaries in the response.
    public var includeThoughts: Bool?

    /// The provider-defined thinking budget.
    public var thinkingBudget: Int?

    /// The provider-defined thinking level.
    public var thinkingLevel: String?

    /// Creates a thinking configuration.
    public init(
        includeThoughts: Bool? = nil,
        thinkingBudget: Int? = nil,
        thinkingLevel: String? = nil
    ) {
        self.includeThoughts = includeThoughts
        self.thinkingBudget = thinkingBudget
        self.thinkingLevel = thinkingLevel
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let includeThoughts {
            object["includeThoughts"] = .bool(includeThoughts)
        }
        if let thinkingBudget {
            object["thinkingBudget"] = .number(Double(thinkingBudget))
        }
        if let thinkingLevel {
            object["thinkingLevel"] = .string(thinkingLevel)
        }
        return .object(object)
    }
}

/// Image output configuration for Gemini requests.
public struct GoogleImageConfiguration: Sendable, Hashable, Codable {
    /// The requested aspect ratio, such as `16:9`.
    public var aspectRatio: String?

    /// The requested image size, such as `1024x1024`.
    public var imageSize: String?

    /// Creates image-generation configuration.
    public init(aspectRatio: String? = nil, imageSize: String? = nil) {
        self.aspectRatio = aspectRatio
        self.imageSize = imageSize
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let aspectRatio {
            object["aspectRatio"] = .string(aspectRatio)
        }
        if let imageSize {
            object["imageSize"] = .string(imageSize)
        }
        return .object(object)
    }
}

/// A speech voice configuration used by Gemini speech-capable generation.
public struct GoogleSpeechConfiguration: Sendable, Hashable {
    /// The output language code.
    public var languageCode: String?

    /// The prebuilt voice name.
    public var voiceName: String?

    /// Optional multi-speaker voice configuration.
    public var multiSpeakerVoiceConfiguration: JSONValue?

    /// Creates speech configuration.
    public init(
        languageCode: String? = nil,
        voiceName: String? = nil,
        multiSpeakerVoiceConfiguration: JSONValue? = nil
    ) {
        self.languageCode = languageCode
        self.voiceName = voiceName
        self.multiSpeakerVoiceConfiguration = multiSpeakerVoiceConfiguration
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let languageCode {
            object["languageCode"] = .string(languageCode)
        }
        if let voiceName {
            object["voiceConfig"] = .object([
                "prebuiltVoiceConfig": .object([
                    "voiceName": .string(voiceName),
                ]),
            ])
        }
        if let multiSpeakerVoiceConfiguration {
            object["multiSpeakerVoiceConfig"] = multiSpeakerVoiceConfiguration
        }
        return .object(object)
    }
}

/// A Gemini safety setting.
public struct GoogleSafetySetting: Sendable, Hashable, Codable {
    /// The harm category.
    public var category: String

    /// The block threshold.
    public var threshold: String

    /// Creates a safety setting.
    public init(category: String, threshold: String) {
        self.category = category
        self.threshold = threshold
    }

    var jsonValue: JSONValue {
        .object([
            "category": .string(category),
            "threshold": .string(threshold),
        ])
    }
}

/// A geographic location used by retrieval configuration.
public struct GoogleLocation: Sendable, Hashable, Codable {
    /// Latitude in degrees.
    public var latitude: Double

    /// Longitude in degrees.
    public var longitude: Double

    /// Creates a location value.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var jsonValue: JSONValue {
        .object([
            "latitude": .number(latitude),
            "longitude": .number(longitude),
        ])
    }
}

/// Function-calling controls for Gemini requests.
public struct GoogleFunctionCallingConfiguration: Sendable, Hashable, Codable {
    /// The function-calling mode.
    public var mode: GoogleFunctionCallingMode

    /// The functions explicitly allowed when `mode` is restrictive.
    public var allowedFunctionNames: [String]

    /// Creates function-calling configuration.
    public init(
        mode: GoogleFunctionCallingMode = .auto,
        allowedFunctionNames: [String] = []
    ) {
        self.mode = mode
        self.allowedFunctionNames = allowedFunctionNames
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [
            "mode": .string(mode.rawValue),
        ]
        if allowedFunctionNames.isEmpty == false {
            object["allowedFunctionNames"] = .array(allowedFunctionNames.map(JSONValue.string))
        }
        return .object(object)
    }
}

/// Retrieval configuration for Google built-in retrieval tools.
public struct GoogleRetrievalConfiguration: Sendable, Hashable {
    /// The optional location hint.
    public var location: GoogleLocation?

    /// The optional language code.
    public var languageCode: String?

    /// Creates retrieval configuration.
    public init(location: GoogleLocation? = nil, languageCode: String? = nil) {
        self.location = location
        self.languageCode = languageCode
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let location {
            object["latLng"] = location.jsonValue
        }
        if let languageCode {
            object["languageCode"] = .string(languageCode)
        }
        return .object(object)
    }
}

/// Tool configuration for Gemini content generation.
public struct GoogleToolConfiguration: Sendable, Hashable {
    /// Function-calling controls.
    public var functionCalling: GoogleFunctionCallingConfiguration?

    /// Retrieval configuration for built-in search tools.
    public var retrieval: GoogleRetrievalConfiguration?

    /// Whether server-side tool invocations should be included in responses.
    public var includeServerSideToolInvocations: Bool?

    /// Creates tool configuration.
    public init(
        functionCalling: GoogleFunctionCallingConfiguration? = nil,
        retrieval: GoogleRetrievalConfiguration? = nil,
        includeServerSideToolInvocations: Bool? = nil
    ) {
        self.functionCalling = functionCalling
        self.retrieval = retrieval
        self.includeServerSideToolInvocations = includeServerSideToolInvocations
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let functionCalling {
            object["functionCallingConfig"] = functionCalling.jsonValue
        }
        if let retrieval {
            object["retrievalConfig"] = retrieval.jsonValue
        }
        if let includeServerSideToolInvocations {
            object["includeServerSideToolInvocations"] = .bool(includeServerSideToolInvocations)
        }
        return .object(object)
    }
}

/// A custom function declaration exposed to Gemini.
public struct GoogleFunctionDeclaration: Sendable, Hashable {
    /// The function name.
    public var name: String

    /// The function description.
    public var description: String

    /// The JSON schema describing the input parameters.
    public var parameters: JSONValue

    /// Creates a function declaration.
    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    var jsonValue: JSONValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "parameters": parameters,
        ])
    }
}

/// A raw Gemini tool definition.
public struct GoogleToolDefinition: Sendable, Hashable {
    /// The raw tool payload.
    public var payload: JSONValue

    /// Creates a tool definition from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }

    /// Creates a tool definition containing custom function declarations.
    public static func functionDeclarations(_ declarations: [GoogleFunctionDeclaration]) -> GoogleToolDefinition {
        GoogleToolDefinition(
            payload: .object([
                "functionDeclarations": .array(declarations.map(\.jsonValue)),
            ])
        )
    }
}

/// A namespace of Google built-in tool helpers.
public enum GoogleTools {
    /// Creates a Google Search tool definition.
    public static func googleSearch(
        timeRange: GoogleSearchTimeRange? = nil,
        searchTypes: GoogleSearchTypes? = nil
    ) -> GoogleToolDefinition {
        var configuration: [String: JSONValue] = [:]
        if let timeRange {
            configuration["timeRangeFilter"] = timeRange.jsonValue
        }
        if let searchTypes {
            configuration["searchTypes"] = searchTypes.jsonValue
        }
        return GoogleToolDefinition(payload: .object(["googleSearch": .object(configuration)]))
    }

    /// Creates a URL Context tool definition.
    public static func urlContext() -> GoogleToolDefinition {
        GoogleToolDefinition(payload: .object(["urlContext": .object([:])]))
    }

    /// Creates a Google Maps tool definition.
    public static func googleMaps(enableWidget: Bool? = nil) -> GoogleToolDefinition {
        var configuration: [String: JSONValue] = [:]
        if let enableWidget {
            configuration["enableWidget"] = .bool(enableWidget)
        }
        return GoogleToolDefinition(payload: .object(["googleMaps": .object(configuration)]))
    }

    /// Creates a code-execution tool definition.
    public static func codeExecution() -> GoogleToolDefinition {
        GoogleToolDefinition(payload: .object(["codeExecution": .object([:])]))
    }

    /// Creates a computer-use tool definition.
    public static func computerUse(
        environment: String? = nil,
        excludedPredefinedFunctions: [String] = []
    ) -> GoogleToolDefinition {
        var configuration: [String: JSONValue] = [:]
        if let environment {
            configuration["environment"] = .string(environment)
        }
        if excludedPredefinedFunctions.isEmpty == false {
            configuration["excludedPredefinedFunctions"] = .array(excludedPredefinedFunctions.map(JSONValue.string))
        }
        return GoogleToolDefinition(payload: .object(["computerUse": .object(configuration)]))
    }

    /// Creates a file-search tool definition bound to one or more file search stores.
    public static func fileSearchStore(
        names: [String],
        topK: Int? = nil,
        metadataFilter: String? = nil
    ) -> GoogleToolDefinition {
        var configuration: [String: JSONValue] = [
            "fileSearchStoreNames": .array(names.map(JSONValue.string)),
        ]
        if let topK {
            configuration["topK"] = .number(Double(topK))
        }
        if let metadataFilter {
            configuration["metadataFilter"] = .string(metadataFilter)
        }
        return GoogleToolDefinition(payload: .object(["fileSearch": .object(configuration)]))
    }

    /// Creates an MCP server tool definition.
    public static func mcpServer(
        name: String,
        streamableHTTPTransport: JSONValue
    ) -> GoogleToolDefinition {
        GoogleToolDefinition(
            payload: .object([
                "mcpServers": .array([
                    .object([
                        "name": .string(name),
                        "streamableHttpTransport": streamableHTTPTransport,
                    ]),
                ]),
            ])
        )
    }
}

/// Provider-specific options for the Google adapter.
public struct GoogleProviderOptions: Sendable, Hashable {
    /// The number of candidate responses to request.
    public var candidateCount: Int?

    /// The sampling temperature.
    public var temperature: Double?

    /// The nucleus sampling value.
    public var topP: Double?

    /// The optional top-k sampling value.
    public var topK: Int?

    /// The maximum output tokens.
    public var maxOutputTokens: Int?

    /// Stop sequences applied to generation.
    public var stopSequences: [String]

    /// The random seed.
    public var seed: Int?

    /// The response MIME type, such as `application/json`.
    public var responseMimeType: String?

    /// The response schema used for structured outputs.
    public var responseSchema: JSONValue?

    /// An explicit response JSON schema.
    public var responseJSONSchema: JSONValue?

    /// Presence penalty.
    public var presencePenalty: Double?

    /// Frequency penalty.
    public var frequencyPenalty: Double?

    /// Whether response logprobs should be returned.
    public var responseLogprobs: Bool?

    /// The number of log probabilities to include.
    public var logprobs: Int?

    /// Whether enhanced civic answers should be enabled.
    public var enableEnhancedCivicAnswers: Bool?

    /// Response modalities, such as `TEXT` or `IMAGE`.
    public var responseModalities: [String]

    /// Optional speech configuration.
    public var speech: GoogleSpeechConfiguration?

    /// Optional thinking configuration.
    public var thinking: GoogleThinkingConfig?

    /// Optional image output configuration.
    public var image: GoogleImageConfiguration?

    /// The media resolution hint.
    public var mediaResolution: GoogleMediaResolution?

    /// Safety settings applied to the request.
    public var safetySettings: [GoogleSafetySetting]

    /// Tool configuration for the request.
    public var toolConfig: GoogleToolConfiguration?

    /// Provider-built-in tools appended to the request.
    public var builtInTools: [GoogleToolDefinition]

    /// A cached content resource name to reuse.
    public var cachedContent: String?

    /// The Google service tier.
    public var serviceTier: String?

    /// Whether the provider should store the request for server-side state.
    public var store: Bool?

    /// Creates Google-specific options.
    public init(
        candidateCount: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        maxOutputTokens: Int? = nil,
        stopSequences: [String] = [],
        seed: Int? = nil,
        responseMimeType: String? = nil,
        responseSchema: JSONValue? = nil,
        responseJSONSchema: JSONValue? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        responseLogprobs: Bool? = nil,
        logprobs: Int? = nil,
        enableEnhancedCivicAnswers: Bool? = nil,
        responseModalities: [String] = [],
        speech: GoogleSpeechConfiguration? = nil,
        thinking: GoogleThinkingConfig? = nil,
        image: GoogleImageConfiguration? = nil,
        mediaResolution: GoogleMediaResolution? = nil,
        safetySettings: [GoogleSafetySetting] = [],
        toolConfig: GoogleToolConfiguration? = nil,
        builtInTools: [GoogleToolDefinition] = [],
        cachedContent: String? = nil,
        serviceTier: String? = nil,
        store: Bool? = nil
    ) {
        self.candidateCount = candidateCount
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxOutputTokens = maxOutputTokens
        self.stopSequences = stopSequences
        self.seed = seed
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema
        self.responseJSONSchema = responseJSONSchema
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.responseLogprobs = responseLogprobs
        self.logprobs = logprobs
        self.enableEnhancedCivicAnswers = enableEnhancedCivicAnswers
        self.responseModalities = responseModalities
        self.speech = speech
        self.thinking = thinking
        self.image = image
        self.mediaResolution = mediaResolution
        self.safetySettings = safetySettings
        self.toolConfig = toolConfig
        self.builtInTools = builtInTools
        self.cachedContent = cachedContent
        self.serviceTier = serviceTier
        self.store = store
    }

    /// Encodes the options into a Google request payload.
    public func jsonValue() -> JSONValue {
        var generationConfig: [String: JSONValue] = [:]

        if let candidateCount {
            generationConfig["candidateCount"] = .number(Double(candidateCount))
        }
        if let temperature {
            generationConfig["temperature"] = .number(temperature)
        }
        if let topP {
            generationConfig["topP"] = .number(topP)
        }
        if let topK {
            generationConfig["topK"] = .number(Double(topK))
        }
        if let maxOutputTokens {
            generationConfig["maxOutputTokens"] = .number(Double(maxOutputTokens))
        }
        if stopSequences.isEmpty == false {
            generationConfig["stopSequences"] = .array(stopSequences.map(JSONValue.string))
        }
        if let seed {
            generationConfig["seed"] = .number(Double(seed))
        }
        if let responseMimeType {
            generationConfig["responseMimeType"] = .string(responseMimeType)
        }
        if let responseSchema {
            generationConfig["responseSchema"] = responseSchema
        }
        if let responseJSONSchema {
            generationConfig["responseJsonSchema"] = responseJSONSchema
        }
        if let presencePenalty {
            generationConfig["presencePenalty"] = .number(presencePenalty)
        }
        if let frequencyPenalty {
            generationConfig["frequencyPenalty"] = .number(frequencyPenalty)
        }
        if let responseLogprobs {
            generationConfig["responseLogprobs"] = .bool(responseLogprobs)
        }
        if let logprobs {
            generationConfig["logprobs"] = .number(Double(logprobs))
        }
        if let enableEnhancedCivicAnswers {
            generationConfig["enableEnhancedCivicAnswers"] = .bool(enableEnhancedCivicAnswers)
        }
        if responseModalities.isEmpty == false {
            generationConfig["responseModalities"] = .array(responseModalities.map(JSONValue.string))
        }
        if let speech {
            generationConfig["speechConfig"] = speech.jsonValue
        }
        if let thinking {
            generationConfig["thinkingConfig"] = thinking.jsonValue
        }
        if let image {
            generationConfig["imageConfig"] = image.jsonValue
        }
        if let mediaResolution {
            generationConfig["mediaResolution"] = .string(mediaResolution.rawValue)
        }

        var object: [String: JSONValue] = [:]
        if generationConfig.isEmpty == false {
            object["generationConfig"] = .object(generationConfig)
        }
        if safetySettings.isEmpty == false {
            object["safetySettings"] = .array(safetySettings.map(\.jsonValue))
        }
        if let toolConfig {
            object["toolConfig"] = toolConfig.jsonValue
        }
        if builtInTools.isEmpty == false {
            object["tools"] = .array(builtInTools.map(\.payload))
        }
        if let cachedContent {
            object["cachedContent"] = .string(cachedContent)
        }
        if let serviceTier {
            object["serviceTier"] = .string(serviceTier)
        }
        if let store {
            object["store"] = .bool(store)
        }
        return .object(object)
    }
}

public extension ProviderOptions {
    /// Stores Google-specific options under the Google namespace.
    mutating func setGoogle(_ options: GoogleProviderOptions) {
        set(options.jsonValue(), for: GoogleProvider.namespace)
    }
}

package struct GoogleServiceConfiguration: Sendable {
    package var apiKey: String
    package var stableBaseURL: URL
    package var previewBaseURL: URL
    package var liveSocketURL: URL
    package var client: HTTPClient
    package var catalog: GoogleModelCatalogCache

    package var apiKeyHeaders: [String: String] {
        ["x-goog-api-key": apiKey]
    }

    package func stableURL(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        url(baseURL: stableBaseURL, path: path, queryItems: queryItems)
    }

    package func previewURL(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        url(baseURL: previewBaseURL, path: path, queryItems: queryItems)
    }

    package func stableUploadURL(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        let uploadBase = GoogleEncoding.uploadBaseURL(for: stableBaseURL)
        return url(baseURL: uploadBase, path: path, queryItems: queryItems)
    }

    package func websocketURL(queryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: liveSocketURL, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        return components.url!
    }

    private func url(baseURL: URL, path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponents(path), resolvingAgainstBaseURL: false)!
        if queryItems.isEmpty == false {
            components.queryItems = queryItems
        }
        return components.url!
    }
}

package actor GoogleModelCatalogCache {
    private var modelsByID: [String: AvailableModel] = [:]

    package func model(id: String) -> AvailableModel? {
        modelsByID[id]
    }

    package func store(_ model: AvailableModel) {
        modelsByID[model.id] = model
        if let providerIdentifier = model.providerIdentifier {
            modelsByID[providerIdentifier.replacingOccurrences(of: "models/", with: "")] = model
        }
    }

    package func store(_ models: [AvailableModel]) {
        for model in models {
            store(model)
        }
    }
}

package struct GoogleCapabilityProfile: Sendable, Hashable {
    package var capabilities: ModelCapabilities
    package var supportsGenerateContent: Bool
    package var supportsStreamGenerateContent: Bool
    package var supportsCountTokens: Bool
    package var supportsEmbeddings: Bool
    package var supportsImageResponses: Bool
    package var supportsGenerateAnswer: Bool
}

package enum GoogleCapabilityResolver {
    package static func profile(for modelID: String, metadata: AvailableModel? = nil) -> GoogleCapabilityProfile {
        let normalized = modelID.lowercased()
        let methods = Set(metadata?.supportedGenerationMethods ?? [])
        let methodAware = methods.isEmpty == false
        let isEmbeddingFamily = normalized.contains("embedding")
        let isImagenFamily = normalized.contains("imagen")
        let isImageGenerationFamily = normalized.contains("preview-image-generation") || isImagenFamily
        let isGeminiFamily = normalized.hasPrefix("gemini")
        let isGeneralGeminiFamily = isGeminiFamily && isEmbeddingFamily == false

        let supportsGenerateContent = methodAware ? methods.contains("generateContent") : isGeneralGeminiFamily || isImageGenerationFamily
        let supportsStreamGenerateContent = methodAware ? methods.contains("generateContent") : supportsGenerateContent
        let supportsCountTokens = methodAware ? methods.contains("countTokens") : supportsGenerateContent
        let supportsEmbeddings = methodAware ? methods.contains("embedContent") || methods.contains("batchEmbedContents") : isEmbeddingFamily
        let supportsGenerateAnswer = methodAware ? methods.contains("generateAnswer") : isGeneralGeminiFamily && isImageGenerationFamily == false
        let supportsImageResponses = isImageGenerationFamily || normalized.contains("image") || normalized.contains("vision")
        let supportsToolCalling = supportsGenerateContent && isImageGenerationFamily == false
        let supportsStructuredOutput = supportsGenerateContent
        let supportsPromptMedia = supportsGenerateContent && isImagenFamily == false

        return GoogleCapabilityProfile(
            capabilities: ModelCapabilities(
                supportsStreaming: supportsStreamGenerateContent,
                supportsToolCalling: supportsToolCalling,
                supportsStructuredOutput: supportsStructuredOutput,
                supportsImageInput: supportsPromptMedia,
                supportsAudioInput: supportsPromptMedia,
                supportsFileInput: supportsPromptMedia,
                supportsBatchEmbeddings: supportsEmbeddings,
                supportsMultipleImageOutputs: false,
                supportsReasoningControls: false
            ),
            supportsGenerateContent: supportsGenerateContent,
            supportsStreamGenerateContent: supportsStreamGenerateContent,
            supportsCountTokens: supportsCountTokens,
            supportsEmbeddings: supportsEmbeddings,
            supportsImageResponses: supportsImageResponses,
            supportsGenerateAnswer: supportsGenerateAnswer
        )
    }
}

package enum GoogleRequestSupport {
    package static func usage(from object: [String: JSONValue]?) -> Usage? {
        guard let object else { return nil }

        let inputTokens = ModelCatalogDecoding.intValue(object["promptTokenCount"])
            ?? ModelCatalogDecoding.intValue(object["inputTokenCount"])
        let outputTokens = ModelCatalogDecoding.intValue(object["candidatesTokenCount"])
            ?? ModelCatalogDecoding.intValue(object["outputTokenCount"])
        let totalTokens = ModelCatalogDecoding.intValue(object["totalTokenCount"])

        if inputTokens == nil, outputTokens == nil, totalTokens == nil {
            return nil
        }

        return Usage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens
        )
    }

    package static func validate(_ part: FileContent) throws -> JSONValue {
        if part.providerNamespace == GoogleProvider.namespace, let providerFileURI = part.providerFileURI {
            var fileData: [String: JSONValue] = [
                "mimeType": .string(part.mimeType),
                "fileUri": .string(providerFileURI),
            ]
            if let fileName = part.fileName {
                fileData["displayName"] = .string(fileName)
            }
            return .object(["fileData": .object(fileData)])
        }

        guard let data = part.data else {
            throw KaizoshaError.invalidRequest("Google file prompt parts require inline bytes or a Google provider file URI.")
        }

        return .object([
            "inlineData": .object([
                "mimeType": .string(part.mimeType),
                "data": .string(data.base64EncodedString()),
            ]),
        ])
    }
}

package enum GoogleEncoding {
    package static func uploadBaseURL(for stableBaseURL: URL) -> URL {
        let host = stableBaseURL.host ?? "generativelanguage.googleapis.com"
        return URL(string: "\(stableBaseURL.scheme ?? "https")://\(host)")!
    }

    package static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

package func mergeGoogleProviderOptions(_ base: JSONValue, with providerOptions: JSONValue?) -> JSONValue {
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

    if let providerTools = providerObject["tools"]?.arrayValue {
        let existingTools = merged["tools"]?.arrayValue ?? []
        merged["tools"] = .array(existingTools + providerTools)
        providerObject.removeValue(forKey: "tools")
    }

    if let providerSafety = providerObject["safetySettings"]?.arrayValue {
        let existingSafety = merged["safetySettings"]?.arrayValue ?? []
        merged["safetySettings"] = .array(existingSafety + providerSafety)
        providerObject.removeValue(forKey: "safetySettings")
    }

    for (key, value) in providerObject {
        merged[key] = value
    }

    return .object(merged)
}

package extension FinishReason {
    init(googleValue: String?) {
        switch googleValue {
        case "STOP":
            self = .stop
        case "MAX_TOKENS":
            self = .length
        case "SAFETY":
            self = .contentFilter
        case "MALFORMED_FUNCTION_CALL":
            self = .error
        case nil:
            self = .unknown
        default:
            self = .unknown
        }
    }
}
