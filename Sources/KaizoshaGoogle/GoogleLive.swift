import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Activity detection settings for Google Live sessions.
public struct GoogleLiveAutomaticActivityDetection: Sendable, Hashable {
    /// Whether automatic detection is disabled.
    public var disabled: Bool?

    /// Creates activity detection settings.
    public init(disabled: Bool? = nil) {
        self.disabled = disabled
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let disabled {
            object["disabled"] = .bool(disabled)
        }
        return .object(object)
    }
}

/// Input configuration for a Google Live session.
public struct GoogleLiveRealtimeInputConfiguration: Sendable, Hashable {
    /// Automatic activity detection settings.
    public var automaticActivityDetection: GoogleLiveAutomaticActivityDetection?

    /// How activity boundaries should be handled.
    public var activityHandling: String?

    /// Turn coverage behavior.
    public var turnCoverage: String?

    /// Creates realtime input configuration.
    public init(
        automaticActivityDetection: GoogleLiveAutomaticActivityDetection? = nil,
        activityHandling: String? = nil,
        turnCoverage: String? = nil
    ) {
        self.automaticActivityDetection = automaticActivityDetection
        self.activityHandling = activityHandling
        self.turnCoverage = turnCoverage
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let automaticActivityDetection {
            object["automaticActivityDetection"] = automaticActivityDetection.jsonValue
        }
        if let activityHandling {
            object["activityHandling"] = .string(activityHandling)
        }
        if let turnCoverage {
            object["turnCoverage"] = .string(turnCoverage)
        }
        return .object(object)
    }
}

/// Session-resumption configuration for Google Live sessions.
public struct GoogleLiveSessionResumptionConfiguration: Sendable, Hashable {
    /// An optional resumption handle.
    public var handle: String?

    /// Creates session-resumption configuration.
    public init(handle: String? = nil) {
        self.handle = handle
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]
        if let handle {
            object["handle"] = .string(handle)
        }
        return .object(object)
    }
}

/// The setup payload for a Google Live session.
public struct GoogleLiveSetup: Sendable, Hashable {
    /// The model resource name.
    public var model: String

    /// Generation configuration.
    public var options: GoogleProviderOptions

    /// A system instruction.
    public var systemInstruction: GoogleContent?

    /// Available tools.
    public var tools: [GoogleToolDefinition]

    /// Realtime input configuration.
    public var realtimeInputConfiguration: GoogleLiveRealtimeInputConfiguration?

    /// Session-resumption configuration.
    public var sessionResumption: GoogleLiveSessionResumptionConfiguration?

    /// Input-audio transcription configuration.
    public var inputAudioTranscription: JSONValue?

    /// Output-audio transcription configuration.
    public var outputAudioTranscription: JSONValue?

    /// Extra raw fields merged into the setup payload.
    public var extraOptions: JSONValue?

    /// Creates a Google Live setup payload.
    public init(
        model: String,
        options: GoogleProviderOptions = GoogleProviderOptions(),
        systemInstruction: GoogleContent? = nil,
        tools: [GoogleToolDefinition] = [],
        realtimeInputConfiguration: GoogleLiveRealtimeInputConfiguration? = nil,
        sessionResumption: GoogleLiveSessionResumptionConfiguration? = nil,
        inputAudioTranscription: JSONValue? = nil,
        outputAudioTranscription: JSONValue? = nil,
        extraOptions: JSONValue? = nil
    ) {
        self.model = model
        self.options = options
        self.systemInstruction = systemInstruction
        self.tools = tools
        self.realtimeInputConfiguration = realtimeInputConfiguration
        self.sessionResumption = sessionResumption
        self.inputAudioTranscription = inputAudioTranscription
        self.outputAudioTranscription = outputAudioTranscription
        self.extraOptions = extraOptions
    }

    var jsonValue: JSONValue {
        var object: [String: JSONValue] = [
            "model": .string(model),
        ]

        if let systemInstruction {
            object["systemInstruction"] = (try? JSONValue.encode(systemInstruction)) ?? .null
        }
        if tools.isEmpty == false {
            object["tools"] = .array(tools.map(\.payload))
        }
        if let realtimeInputConfiguration {
            object["realtimeInputConfig"] = realtimeInputConfiguration.jsonValue
        }
        if let sessionResumption {
            object["sessionResumption"] = sessionResumption.jsonValue
        }
        if let inputAudioTranscription {
            object["inputAudioTranscription"] = inputAudioTranscription
        }
        if let outputAudioTranscription {
            object["outputAudioTranscription"] = outputAudioTranscription
        }

        let withOptions = mergeGoogleProviderOptions(.object(object), with: options.jsonValue())
        return mergeGoogleProviderOptions(withOptions, with: extraOptions)
    }
}

/// A Google Live auth token request.
public struct GoogleLiveAuthTokenRequest: Sendable, Hashable {
    /// The session setup allowed by the token.
    public var setup: GoogleLiveSetup

    /// The token expiry time.
    public var expireTime: Date?

    /// The maximum token uses.
    public var uses: Int?

    /// The field mask used for partial updates.
    public var fieldMask: String?

    /// Creates an auth token request.
    public init(
        setup: GoogleLiveSetup,
        expireTime: Date? = nil,
        uses: Int? = nil,
        fieldMask: String? = nil
    ) {
        self.setup = setup
        self.expireTime = expireTime
        self.uses = uses
        self.fieldMask = fieldMask
    }

    func jsonValue() -> JSONValue {
        var object: [String: JSONValue] = [
            "bidiGenerateContentSetup": setup.jsonValue,
        ]
        if let expireTime {
            object["expireTime"] = .string(GoogleEncoding.iso8601(expireTime))
        }
        if let uses {
            object["uses"] = .number(Double(uses))
        }
        if let fieldMask {
            object["fieldMask"] = .string(fieldMask)
        }
        return .object(object)
    }
}

/// A Google Live auth token.
public struct GoogleLiveAuthToken: Sendable, Hashable {
    /// The token value. Google returns the ephemeral token in `name`.
    public var value: String?

    /// The token expiry time.
    public var expireTime: Date?

    /// The new-session expiry time.
    public var newSessionExpireTime: Date?

    /// The number of remaining uses.
    public var uses: Int?

    /// The allowed setup associated with the token.
    public var setup: GoogleLiveSetup?

    /// Creates an auth token object.
    public init(
        value: String? = nil,
        expireTime: Date? = nil,
        newSessionExpireTime: Date? = nil,
        uses: Int? = nil,
        setup: GoogleLiveSetup? = nil
    ) {
        self.value = value
        self.expireTime = expireTime
        self.newSessionExpireTime = newSessionExpireTime
        self.uses = uses
        self.setup = setup
    }
}

/// Authentication methods for Google Live websocket sessions.
public enum GoogleLiveAuthorization: Sendable, Hashable {
    /// Authenticate with the provider API key.
    case apiKey

    /// Authenticate with an ephemeral auth token.
    case authToken(String)
}

/// A typed client message for Google Live sessions.
public struct GoogleLiveClientMessage: Sendable, Hashable {
    /// The raw websocket payload.
    public var payload: JSONValue

    /// Creates a client message from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }

    /// Creates the initial setup message.
    public static func setup(_ setup: GoogleLiveSetup) -> GoogleLiveClientMessage {
        GoogleLiveClientMessage(payload: .object(["setup": setup.jsonValue]))
    }

    /// Creates a client-content message.
    public static func clientContent(_ payload: JSONValue) -> GoogleLiveClientMessage {
        GoogleLiveClientMessage(payload: .object(["clientContent": payload]))
    }

    /// Creates a realtime-input message.
    public static func realtimeInput(_ payload: JSONValue) -> GoogleLiveClientMessage {
        GoogleLiveClientMessage(payload: .object(["realtimeInput": payload]))
    }

    /// Creates a tool-response message.
    public static func toolResponse(_ payload: JSONValue) -> GoogleLiveClientMessage {
        GoogleLiveClientMessage(payload: .object(["toolResponse": payload]))
    }
}

/// Streamed events received from Google Live sessions.
public enum GoogleLiveServerEvent: Sendable {
    /// The setup handshake completed.
    case setupComplete

    /// A model text delta.
    case textDelta(String)

    /// Output audio bytes from the model.
    case outputAudioData(Data, mimeType: String?)

    /// An input-audio transcription delta.
    case inputTranscriptionDelta(String)

    /// An output-audio transcription delta.
    case outputTranscriptionDelta(String)

    /// A tool call request.
    case toolCall(JSONValue)

    /// A tool-call cancellation event.
    case toolCallCancellation(JSONValue)

    /// A session resumption update.
    case sessionResumptionUpdate(JSONValue)

    /// Usage metadata associated with the event.
    case usage(Usage)

    /// An error event.
    case error(JSONValue)

    /// Any raw event not covered by a specialized case.
    case raw(JSONValue)
}

/// A connected Google Live websocket client.
public struct GoogleLiveClient: Sendable {
    private let connection: any WebSocketConnection

    fileprivate init(connection: any WebSocketConnection) {
        self.connection = connection
    }

    /// Sends a typed client message.
    public func send(_ message: GoogleLiveClientMessage) async throws {
        try await connection.send(text: message.payload.compactString())
    }

    /// Receives typed server events.
    public func events() -> AsyncThrowingStream<GoogleLiveServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while Task.isCancelled == false {
                        let text = try await connection.receiveText()
                        let payload = try JSONValue.decode(Data(text.utf8))
                        for event in GoogleLiveService.parseServerEvents(from: payload) {
                            continuation.yield(event)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Closes the websocket connection.
    public func close() async {
        await connection.close()
    }
}

/// Access to Google Live auth-token and websocket session helpers.
public struct GoogleLiveService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Creates an ephemeral auth token for a constrained Live session.
    public func createAuthToken(_ request: GoogleLiveAuthTokenRequest) async throws -> GoogleLiveAuthToken {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.previewURL("auth_tokens"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try request.jsonValue().data()
            )
        )
        return GoogleLiveService.mapAuthToken(payload)
    }

    /// Opens a Google Live websocket and sends the initial setup message.
    public func connect(
        setup: GoogleLiveSetup,
        authorization: GoogleLiveAuthorization = .apiKey,
        webSocketTransport: any WebSocketTransport = URLSessionWebSocketTransport()
    ) async throws -> GoogleLiveClient {
        let request = WebSocketRequest(
            url: websocketURL(for: authorization),
            headers: webSocketHeaders(for: authorization)
        )

        let connection = try await webSocketTransport.connect(request)
        let client = GoogleLiveClient(connection: connection)
        try await client.send(.setup(setup))
        return client
    }

    private func websocketURL(for authorization: GoogleLiveAuthorization) -> URL {
        switch authorization {
        case .apiKey:
            return configuration.websocketURL(
                queryItems: [URLQueryItem(name: "key", value: configuration.apiKey)]
            )
        case .authToken(let token):
            let constrained = URL(
                string: configuration.liveSocketURL.absoluteString.replacingOccurrences(
                    of: ".BidiGenerateContent",
                    with: ".BidiGenerateContentConstrained"
                )
            )!
            var components = URLComponents(url: constrained, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "access_token", value: token)]
            return components.url!
        }
    }

    private func webSocketHeaders(for authorization: GoogleLiveAuthorization) -> [String: String] {
        switch authorization {
        case .apiKey:
            return [:]
        case .authToken:
            return [:]
        }
    }

    private static func mapAuthToken(_ value: JSONValue) -> GoogleLiveAuthToken {
        let object = value.objectValue ?? [:]
        let setup: GoogleLiveSetup? = if
            let rawSetup = object["bidiGenerateContentSetup"]?.objectValue
        {
            GoogleLiveSetup(
                model: rawSetup["model"]?.stringValue ?? "",
                options: GoogleProviderOptions(),
                systemInstruction: rawSetup["systemInstruction"].flatMap {
                    try? JSONDecoder().decode(GoogleContent.self, from: $0.data())
                },
                tools: (rawSetup["tools"]?.arrayValue ?? []).map { GoogleToolDefinition(payload: $0) },
                realtimeInputConfiguration: nil,
                sessionResumption: rawSetup["sessionResumption"]?.objectValue.map {
                    GoogleLiveSessionResumptionConfiguration(handle: $0["handle"]?.stringValue)
                },
                inputAudioTranscription: rawSetup["inputAudioTranscription"],
                outputAudioTranscription: rawSetup["outputAudioTranscription"],
                extraOptions: nil
            )
        } else {
            nil
        }

        return GoogleLiveAuthToken(
            value: object["name"]?.stringValue,
            expireTime: ModelCatalogDecoding.iso8601Date(object["expireTime"]),
            newSessionExpireTime: ModelCatalogDecoding.iso8601Date(object["newSessionExpireTime"]),
            uses: ModelCatalogDecoding.intValue(object["uses"]),
            setup: setup
        )
    }

    fileprivate static func parseServerEvents(from value: JSONValue) -> [GoogleLiveServerEvent] {
        let object = value.objectValue ?? [:]
        var events: [GoogleLiveServerEvent] = []

        if object["setupComplete"] != nil {
            events.append(.setupComplete)
        }

        if let usage = GoogleRequestSupport.usage(from: object["usageMetadata"]?.objectValue) {
            events.append(.usage(usage))
        }

        if let toolCall = object["toolCall"] {
            events.append(.toolCall(toolCall))
        }

        if let toolCallCancellation = object["toolCallCancellation"] {
            events.append(.toolCallCancellation(toolCallCancellation))
        }

        if let sessionResumptionUpdate = object["sessionResumptionUpdate"] {
            events.append(.sessionResumptionUpdate(sessionResumptionUpdate))
        }

        if let serverContent = object["serverContent"]?.objectValue {
            if let modelTurn = serverContent["modelTurn"]?.objectValue,
               let parts = modelTurn["parts"]?.arrayValue {
                for part in parts {
                    if let text = part.objectValue?["text"]?.stringValue, text.isEmpty == false {
                        events.append(.textDelta(text))
                    }

                    if let inlineData = part.objectValue?["inlineData"]?.objectValue,
                       let dataString = inlineData["data"]?.stringValue,
                       let data = Data(base64Encoded: dataString) {
                        events.append(.outputAudioData(data, mimeType: inlineData["mimeType"]?.stringValue))
                    }
                }
            }

            if let inputTranscription = serverContent["inputTranscription"]?.objectValue?["text"]?.stringValue,
               inputTranscription.isEmpty == false {
                events.append(.inputTranscriptionDelta(inputTranscription))
            }

            if let outputTranscription = serverContent["outputTranscription"]?.objectValue?["text"]?.stringValue,
               outputTranscription.isEmpty == false {
                events.append(.outputTranscriptionDelta(outputTranscription))
            }
        }

        if let error = object["error"] {
            events.append(.error(error))
        }

        if events.isEmpty {
            events.append(.raw(value))
        }

        return events
    }
}
