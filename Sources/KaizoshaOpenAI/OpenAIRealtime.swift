import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// The Realtime session type requested from OpenAI.
public enum OpenAIRealtimeSessionType: String, Sendable, Hashable {
    case realtime
    case transcription
}

/// A client-secret lifetime request for the Realtime GA API.
public struct OpenAIRealtimeClientSecretExpiry: Sendable, Hashable {
    /// The expiry anchor. OpenAI currently documents `created_at`.
    public var anchor: String

    /// The number of seconds after the anchor that the secret should expire.
    public var seconds: Int

    /// Creates a Realtime client-secret lifetime request.
    public init(anchor: String = "created_at", seconds: Int) {
        self.anchor = anchor
        self.seconds = seconds
    }

    var jsonValue: JSONValue {
        .object([
            "anchor": .string(anchor),
            "seconds": .number(Double(seconds)),
        ])
    }
}

/// An audio format descriptor for Realtime audio input or output.
public struct OpenAIRealtimeAudioFormat: Sendable, Hashable {
    /// The MIME-like format identifier such as `audio/pcm`.
    public var type: String

    /// The sample rate when required by the format.
    public var rate: Int?

    /// Creates a Realtime audio format descriptor.
    public init(type: String, rate: Int? = nil) {
        self.type = type
        self.rate = rate
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["type": .string(type)]
        if let rate {
            object["rate"] = .number(Double(rate))
        }
        return .object(object)
    }
}

/// A Realtime input-audio transcription configuration.
public struct OpenAIRealtimeInputTranscription: Sendable, Hashable {
    /// The transcription model identifier.
    public var modelID: String

    /// The optional language hint in ISO-639-1 format.
    public var language: String?

    /// An optional transcription prompt.
    public var prompt: String?

    /// Creates an input-audio transcription configuration.
    public init(modelID: String, language: String? = nil, prompt: String? = nil) {
        self.modelID = modelID
        self.language = language
        self.prompt = prompt
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["model": .string(modelID)]
        if let language {
            object["language"] = .string(language)
        }
        if let prompt {
            object["prompt"] = .string(prompt)
        }
        return .object(object)
    }
}

/// A server-VAD turn-detection configuration for Realtime sessions.
public struct OpenAIRealtimeServerVAD: Sendable, Hashable {
    /// The optional speech threshold.
    public var threshold: Double?

    /// The optional prefix padding in milliseconds.
    public var prefixPaddingMilliseconds: Int?

    /// The optional silence duration in milliseconds.
    public var silenceDurationMilliseconds: Int?

    /// Whether OpenAI should automatically create a response after each turn.
    public var createResponse: Bool?

    /// Whether speaking over output should interrupt the current response.
    public var interruptResponse: Bool?

    /// The idle timeout in milliseconds.
    public var idleTimeoutMilliseconds: Int?

    /// Creates a server-VAD configuration.
    public init(
        threshold: Double? = nil,
        prefixPaddingMilliseconds: Int? = nil,
        silenceDurationMilliseconds: Int? = nil,
        createResponse: Bool? = nil,
        interruptResponse: Bool? = nil,
        idleTimeoutMilliseconds: Int? = nil
    ) {
        self.threshold = threshold
        self.prefixPaddingMilliseconds = prefixPaddingMilliseconds
        self.silenceDurationMilliseconds = silenceDurationMilliseconds
        self.createResponse = createResponse
        self.interruptResponse = interruptResponse
        self.idleTimeoutMilliseconds = idleTimeoutMilliseconds
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["type": .string("server_vad")]
        if let threshold {
            object["threshold"] = .number(threshold)
        }
        if let prefixPaddingMilliseconds {
            object["prefix_padding_ms"] = .number(Double(prefixPaddingMilliseconds))
        }
        if let silenceDurationMilliseconds {
            object["silence_duration_ms"] = .number(Double(silenceDurationMilliseconds))
        }
        if let createResponse {
            object["create_response"] = .bool(createResponse)
        }
        if let interruptResponse {
            object["interrupt_response"] = .bool(interruptResponse)
        }
        if let idleTimeoutMilliseconds {
            object["idle_timeout_ms"] = .number(Double(idleTimeoutMilliseconds))
        }
        return .object(object)
    }
}

/// A semantic-VAD turn-detection configuration for Realtime sessions.
public struct OpenAIRealtimeSemanticVAD: Sendable, Hashable {
    /// The semantic eagerness setting.
    public var eagerness: String?

    /// Whether OpenAI should automatically create a response after each turn.
    public var createResponse: Bool?

    /// Whether speaking over output should interrupt the current response.
    public var interruptResponse: Bool?

    /// Creates a semantic-VAD configuration.
    public init(eagerness: String? = nil, createResponse: Bool? = nil, interruptResponse: Bool? = nil) {
        self.eagerness = eagerness
        self.createResponse = createResponse
        self.interruptResponse = interruptResponse
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["type": .string("semantic_vad")]
        if let eagerness {
            object["eagerness"] = .string(eagerness)
        }
        if let createResponse {
            object["create_response"] = .bool(createResponse)
        }
        if let interruptResponse {
            object["interrupt_response"] = .bool(interruptResponse)
        }
        return .object(object)
    }
}

/// Turn-detection strategies for Realtime sessions.
public enum OpenAIRealtimeTurnDetection: Sendable, Hashable {
    case disabled
    case serverVAD(OpenAIRealtimeServerVAD = OpenAIRealtimeServerVAD())
    case semanticVAD(OpenAIRealtimeSemanticVAD = OpenAIRealtimeSemanticVAD())

    var jsonValue: JSONValue {
        switch self {
        case .disabled:
            return .null
        case .serverVAD(let configuration):
            return configuration.jsonValue
        case .semanticVAD(let configuration):
            return configuration.jsonValue
        }
    }
}

/// Input-audio options for Realtime sessions.
public struct OpenAIRealtimeInputAudioConfiguration: Sendable, Hashable {
    /// The input audio format.
    public var format: OpenAIRealtimeAudioFormat?

    /// Optional input-audio transcription.
    public var transcription: OpenAIRealtimeInputTranscription?

    /// Optional turn detection.
    public var turnDetection: OpenAIRealtimeTurnDetection?

    /// Optional noise-reduction configuration.
    public var noiseReduction: JSONValue?

    /// Creates input-audio configuration.
    public init(
        format: OpenAIRealtimeAudioFormat? = nil,
        transcription: OpenAIRealtimeInputTranscription? = nil,
        turnDetection: OpenAIRealtimeTurnDetection? = nil,
        noiseReduction: JSONValue? = nil
    ) {
        self.format = format
        self.transcription = transcription
        self.turnDetection = turnDetection
        self.noiseReduction = noiseReduction
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let format {
            object["format"] = format.jsonValue
        }
        if let transcription {
            object["transcription"] = transcription.jsonValue
        }
        if let turnDetection {
            object["turn_detection"] = turnDetection.jsonValue
        }
        if let noiseReduction {
            object["noise_reduction"] = noiseReduction
        }
        return .object(object)
    }
}

/// Output-audio options for Realtime sessions.
public struct OpenAIRealtimeOutputAudioConfiguration: Sendable, Hashable {
    /// The output audio format.
    public var format: OpenAIRealtimeAudioFormat?

    /// The output voice.
    public var voice: String?

    /// The output speed multiplier.
    public var speed: Double?

    /// Creates output-audio configuration.
    public init(format: OpenAIRealtimeAudioFormat? = nil, voice: String? = nil, speed: Double? = nil) {
        self.format = format
        self.voice = voice
        self.speed = speed
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let format {
            object["format"] = format.jsonValue
        }
        if let voice {
            object["voice"] = .string(voice)
        }
        if let speed {
            object["speed"] = .number(speed)
        }
        return .object(object)
    }
}

/// Audio configuration for Realtime sessions.
public struct OpenAIRealtimeAudioConfiguration: Sendable, Hashable {
    /// Input-audio settings.
    public var input: OpenAIRealtimeInputAudioConfiguration?

    /// Output-audio settings.
    public var output: OpenAIRealtimeOutputAudioConfiguration?

    /// Creates audio configuration for a Realtime session.
    public init(
        input: OpenAIRealtimeInputAudioConfiguration? = nil,
        output: OpenAIRealtimeOutputAudioConfiguration? = nil
    ) {
        self.input = input
        self.output = output
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let input {
            object["input"] = input.jsonValue
        }
        if let output {
            object["output"] = output.jsonValue
        }
        return .object(object)
    }
}

/// Tool selection strategies for Realtime sessions.
public enum OpenAIRealtimeToolChoice: Sendable, Hashable {
    case auto
    case none
    case required
    case function(name: String)
    case raw(JSONValue)

    var jsonValue: JSONValue {
        switch self {
        case .auto:
            return .string("auto")
        case .none:
            return .string("none")
        case .required:
            return .string("required")
        case .function(let name):
            return .object([
                "type": .string("function"),
                "name": .string(name),
            ])
        case .raw(let value):
            return value
        }
    }
}

/// A Realtime tool descriptor.
public struct OpenAIRealtimeTool: Sendable, Hashable {
    /// The raw tool payload sent to OpenAI.
    public var payload: JSONValue

    /// Creates a Realtime tool from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }

    /// Creates a Realtime tool from an OpenAI native tool definition.
    public static func native(_ tool: OpenAINativeTool) -> OpenAIRealtimeTool {
        OpenAIRealtimeTool(payload: tool.jsonValue)
    }

    /// Creates a function tool for Realtime sessions.
    public static func function(name: String, description: String, parameters: JSONValue) -> OpenAIRealtimeTool {
        OpenAIRealtimeTool(
            payload: .object([
                "type": .string("function"),
                "name": .string(name),
                "description": .string(description),
                "parameters": parameters,
            ])
        )
    }
}

/// Realtime truncation strategies.
public enum OpenAIRealtimeTruncation: String, Sendable, Hashable {
    case auto
    case disabled

    var jsonValue: JSONValue {
        .string(rawValue)
    }
}

/// Max-output-token options for Realtime sessions.
public enum OpenAIRealtimeMaxOutputTokens: Sendable, Hashable {
    case automatic
    case limit(Int)

    var jsonValue: JSONValue {
        switch self {
        case .automatic:
            return .string("inf")
        case .limit(let value):
            return .number(Double(value))
        }
    }
}

/// A Realtime session creation request.
public struct OpenAIRealtimeSessionRequest: Sendable, Hashable {
    /// The session type.
    public var type: OpenAIRealtimeSessionType

    /// The realtime model identifier.
    public var modelID: String

    /// Optional session instructions.
    public var instructions: String?

    /// Optional output voice.
    public var voice: String?

    /// Legacy `/realtime/sessions` modalities.
    public var modalities: [String]

    /// Output modalities for the GA `client_secrets` session payload.
    public var outputModalities: [String]

    /// Structured audio configuration.
    public var audio: OpenAIRealtimeAudioConfiguration?

    /// Realtime tools available to the session.
    public var tools: [OpenAIRealtimeTool]

    /// The tool selection strategy.
    public var toolChoice: OpenAIRealtimeToolChoice?

    /// Extra fields to stream back on events.
    public var include: [String]

    /// The truncation strategy for long sessions.
    public var truncation: OpenAIRealtimeTruncation?

    /// The maximum output-token policy.
    public var maxOutputTokens: OpenAIRealtimeMaxOutputTokens?

    /// The requested client-secret lifetime.
    public var expiresAfter: OpenAIRealtimeClientSecretExpiry?

    /// Additional raw session options.
    public var options: JSONValue?

    /// Creates a realtime session request.
    public init(
        type: OpenAIRealtimeSessionType = .realtime,
        modelID: String,
        instructions: String? = nil,
        voice: String? = nil,
        modalities: [String] = ["text", "audio"],
        outputModalities: [String] = [],
        audio: OpenAIRealtimeAudioConfiguration? = nil,
        tools: [OpenAIRealtimeTool] = [],
        toolChoice: OpenAIRealtimeToolChoice? = nil,
        include: [String] = [],
        truncation: OpenAIRealtimeTruncation? = nil,
        maxOutputTokens: OpenAIRealtimeMaxOutputTokens? = nil,
        expiresAfter: OpenAIRealtimeClientSecretExpiry? = nil,
        options: JSONValue? = nil
    ) {
        self.type = type
        self.modelID = modelID
        self.instructions = instructions
        self.voice = voice
        self.modalities = modalities
        self.outputModalities = outputModalities
        self.audio = audio
        self.tools = tools
        self.toolChoice = toolChoice
        self.include = include
        self.truncation = truncation
        self.maxOutputTokens = maxOutputTokens
        self.expiresAfter = expiresAfter
        self.options = options
    }
}

/// A Realtime session response returned by OpenAI.
public struct OpenAIRealtimeSession: Sendable, Hashable {
    /// The session identifier.
    public var id: String?

    /// The resolved model identifier.
    public var modelID: String

    /// The session type.
    public var type: OpenAIRealtimeSessionType

    /// The ephemeral client secret when returned by OpenAI.
    public var clientSecret: String?

    /// The expiration timestamp when present.
    public var expiresAt: Date?

    /// The raw payload returned by OpenAI.
    public var rawPayload: JSONValue

    /// Creates a realtime session response.
    public init(
        id: String? = nil,
        modelID: String,
        type: OpenAIRealtimeSessionType,
        clientSecret: String? = nil,
        expiresAt: Date? = nil,
        rawPayload: JSONValue
    ) {
        self.id = id
        self.modelID = modelID
        self.type = type
        self.clientSecret = clientSecret
        self.expiresAt = expiresAt
        self.rawPayload = rawPayload
    }
}

/// A client event sent to the OpenAI Realtime API.
public struct OpenAIRealtimeClientEvent: Sendable, Hashable {
    /// The event type.
    public var type: String

    /// The event payload.
    public var payload: JSONValue

    /// Creates a realtime client event.
    public init(type: String, payload: JSONValue = .object([:])) {
        self.type = type
        self.payload = payload
    }

    /// Creates a `session.update` event.
    public static func sessionUpdate(_ payload: JSONValue) -> OpenAIRealtimeClientEvent {
        OpenAIRealtimeClientEvent(type: "session.update", payload: payload)
    }

    /// Creates a `conversation.item.create` event.
    public static func conversationItemCreate(_ item: JSONValue) -> OpenAIRealtimeClientEvent {
        OpenAIRealtimeClientEvent(type: "conversation.item.create", payload: .object(["item": item]))
    }

    /// Creates a `response.create` event.
    public static func responseCreate(_ payload: JSONValue = .object([:])) -> OpenAIRealtimeClientEvent {
        OpenAIRealtimeClientEvent(type: "response.create", payload: payload)
    }

    package var jsonValue: JSONValue {
        JSONValue.object(["type": .string(type)]).mergingObject(with: payload)
    }
}

/// A parsed server event emitted by the OpenAI Realtime API.
public enum OpenAIRealtimeEvent: Sendable {
    case sessionCreated(JSONValue)
    case sessionUpdated(JSONValue)
    case responseTextDelta(String)
    case responseAudioDelta(Data)
    case responseAudioTranscriptDelta(String)
    case toolCall(ToolInvocation)
    case responseCompleted(JSONValue)
    case error(String, payload: JSONValue)
    case raw(type: String, payload: JSONValue)
}

/// An OpenAI-specific Realtime client.
public actor OpenAIRealtimeClient {
    private let request: WebSocketRequest
    private let transport: any WebSocketTransport
    private var connection: (any WebSocketConnection)?

    /// Creates a Realtime client.
    public init(
        modelID: String,
        apiKey: String? = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
        clientSecret: String? = nil,
        baseURL: URL = URL(string: "wss://api.openai.com/v1/realtime")!,
        transport: any WebSocketTransport = URLSessionWebSocketTransport()
    ) throws {
        let bearerToken: String
        if let clientSecret, clientSecret.isEmpty == false {
            bearerToken = clientSecret
        } else if let apiKey, apiKey.isEmpty == false {
            bearerToken = apiKey
        } else {
            throw KaizoshaError.missingAPIKey(namespace: "OPENAI_API_KEY or realtime client secret")
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "model", value: modelID))
        components.queryItems = queryItems

        self.request = WebSocketRequest(
            url: components.url!,
            headers: ["Authorization": "Bearer \(bearerToken)"]
        )
        self.transport = transport
    }

    /// Opens the websocket connection if needed.
    public func connect() async throws {
        if connection == nil {
            connection = try await transport.connect(request)
        }
    }

    /// Sends a typed Realtime client event.
    public func send(_ event: OpenAIRealtimeClientEvent) async throws {
        try await connect()
        guard let connection else {
            throw KaizoshaError.invalidResponse("The realtime websocket is not connected.")
        }
        try await connection.send(text: event.jsonValue.compactString())
    }

    /// Receives server events as an asynchronous stream.
    public func events() -> AsyncThrowingStream<OpenAIRealtimeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await connect()
                    guard let connection else {
                        throw KaizoshaError.invalidResponse("The realtime websocket is not connected.")
                    }

                    while Task.isCancelled == false {
                        let text = try await connection.receiveText()
                        let payload = try JSONValue.decode(Data(text.utf8))
                        continuation.yield(try Self.parseEvent(payload))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                Task {
                    await self?.disconnect()
                }
            }
        }
    }

    /// Closes the websocket connection.
    public func disconnect() async {
        await connection?.close()
        connection = nil
    }

    private static func parseEvent(_ payload: JSONValue) throws -> OpenAIRealtimeEvent {
        guard let object = payload.objectValue,
              let type = object["type"]?.stringValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned a realtime event without a type.")
        }

        switch type {
        case "session.created":
            return .sessionCreated(payload)
        case "session.updated":
            return .sessionUpdated(payload)
        case "response.output_text.delta":
            return .responseTextDelta(object["delta"]?.stringValue ?? "")
        case "response.output_audio.delta":
            if let base64 = object["delta"]?.stringValue,
               let data = Data(base64Encoded: base64) {
                return .responseAudioDelta(data)
            }
            return .raw(type: type, payload: payload)
        case "response.output_audio_transcript.delta":
            return .responseAudioTranscriptDelta(object["delta"]?.stringValue ?? "")
        case "response.function_call_arguments.done":
            guard let name = object["name"]?.stringValue ?? object["item"]?.objectValue?["name"]?.stringValue,
                  let callID = object["call_id"]?.stringValue ?? object["item"]?.objectValue?["call_id"]?.stringValue,
                  let arguments = object["arguments"]?.stringValue ?? object["item"]?.objectValue?["arguments"]?.stringValue,
                  let data = arguments.data(using: .utf8) else {
                return .raw(type: type, payload: payload)
            }
            return .toolCall(
                ToolInvocation(
                    id: callID,
                    name: name,
                    input: try JSONValue.decode(data)
                )
            )
        case "response.done":
            return .responseCompleted(payload)
        case "error":
            let message = object["message"]?.stringValue
                ?? object["error"]?.objectValue?["message"]?.stringValue
                ?? "OpenAI returned a realtime error."
            return .error(message, payload: payload)
        default:
            return .raw(type: type, payload: payload)
        }
    }
}

public extension OpenAIProvider {
    /// Creates a realtime session using `/realtime/sessions`.
    func createRealtimeSession(_ request: OpenAIRealtimeSessionRequest) async throws -> OpenAIRealtimeSession {
        try await createRealtimeSession(request, path: "realtime/sessions")
    }

    /// Creates a realtime client secret using `/realtime/client_secrets`.
    func createRealtimeClientSecret(_ request: OpenAIRealtimeSessionRequest) async throws -> OpenAIRealtimeSession {
        try await createRealtimeSession(request, path: "realtime/client_secrets")
    }

    /// Creates an authenticated Realtime websocket client.
    func realtimeClient(
        modelID: String,
        clientSecret: String? = nil,
        transport: any WebSocketTransport = URLSessionWebSocketTransport()
    ) throws -> OpenAIRealtimeClient {
        try OpenAIRealtimeClient(
            modelID: modelID,
            apiKey: apiKey,
            clientSecret: clientSecret,
            baseURL: realtimeWebSocketBaseURL(from: baseURL),
            transport: transport
        )
    }

    private func createRealtimeSession(
        _ request: OpenAIRealtimeSessionRequest,
        path: String
    ) async throws -> OpenAIRealtimeSession {
        let usesClientSecretsShape = (path == "realtime/client_secrets")
        let payload = try await client.sendJSON(
            HTTPRequest(
                url: baseURL.appendingPathComponents(path),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
                ],
                body: try realtimeSessionPayload(request, usesClientSecretsShape: usesClientSecretsShape).data()
            )
        )

        return try OpenAIRealtimeSession(payload: payload, fallbackType: request.type, fallbackModelID: request.modelID)
    }

    private func realtimeSessionPayload(
        _ request: OpenAIRealtimeSessionRequest,
        usesClientSecretsShape: Bool
    ) -> JSONValue {
        let session = realtimeSessionConfigurationPayload(
            request,
            usesOutputModalities: usesClientSecretsShape
        )

        guard usesClientSecretsShape else {
            return session
        }

        var object: [String: JSONValue] = ["session": session]
        if let expiresAfter = request.expiresAfter {
            object["expires_after"] = expiresAfter.jsonValue
        }
        return .object(object)
    }

    private func realtimeSessionConfigurationPayload(
        _ request: OpenAIRealtimeSessionRequest,
        usesOutputModalities: Bool
    ) -> JSONValue {
        var object: [String: JSONValue] = [
            "type": .string(request.type.rawValue),
            "model": .string(request.modelID),
        ]
        if let instructions = request.instructions {
            object["instructions"] = .string(instructions)
        }

        let modalities = request.outputModalities.isEmpty ? request.modalities : request.outputModalities
        if modalities.isEmpty == false {
            let key = usesOutputModalities ? "output_modalities" : "modalities"
            object[key] = .array(modalities.map(JSONValue.string))
        }

        var audio = request.audio
        if let voice = request.voice {
            var output = audio?.output ?? OpenAIRealtimeOutputAudioConfiguration()
            if output.voice == nil {
                output.voice = voice
            }

            if audio != nil {
                audio?.output = output
            } else {
                audio = OpenAIRealtimeAudioConfiguration(output: output)
            }
        }
        if let audio {
            object["audio"] = audio.jsonValue
        }

        if request.tools.isEmpty == false {
            object["tools"] = .array(request.tools.map(\.payload))
        }
        if let toolChoice = request.toolChoice {
            object["tool_choice"] = toolChoice.jsonValue
        }
        if request.include.isEmpty == false {
            object["include"] = .array(request.include.map(JSONValue.string))
        }
        if let truncation = request.truncation {
            object["truncation"] = truncation.jsonValue
        }
        if let maxOutputTokens = request.maxOutputTokens {
            object["max_output_tokens"] = maxOutputTokens.jsonValue
        }

        return JSONValue.object(object).mergingObject(with: request.options)
    }

    private func realtimeWebSocketBaseURL(from apiBaseURL: URL) -> URL {
        var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)!
        components.scheme = (components.scheme == "http") ? "ws" : "wss"
        let base = components.url ?? URL(string: "wss://api.openai.com/v1")!
        return base.appendingPathComponents("realtime")
    }
}

private extension OpenAIRealtimeSession {
    init(payload: JSONValue, fallbackType: OpenAIRealtimeSessionType, fallbackModelID: String) throws {
        guard let object = payload.objectValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an invalid realtime session payload.")
        }

        let sessionObject = object["session"]?.objectValue ?? object
        let clientSecret = object["value"]?.stringValue
            ?? object["client_secret"]?.objectValue?["value"]?.stringValue
            ?? sessionObject["client_secret"]?.objectValue?["value"]?.stringValue

        self.init(
            id: sessionObject["id"]?.stringValue,
            modelID: sessionObject["model"]?.stringValue ?? fallbackModelID,
            type: sessionObject["type"]?.stringValue.flatMap(OpenAIRealtimeSessionType.init(rawValue:)) ?? fallbackType,
            clientSecret: clientSecret,
            expiresAt: ModelCatalogDecoding.unixTimestamp(object["expires_at"] ?? sessionObject["expires_at"]),
            rawPayload: payload
        )
    }
}
