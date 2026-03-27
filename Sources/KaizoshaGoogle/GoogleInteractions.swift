import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// A Google Interactions input payload.
public struct GoogleInteractionInput: Sendable, Hashable {
    /// The raw input payload accepted by the Interactions API.
    public var payload: JSONValue

    /// Creates an interaction input from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }

    /// Creates a plain-text interaction input.
    public static func text(_ value: String) -> GoogleInteractionInput {
        GoogleInteractionInput(payload: .string(value))
    }

    /// Creates an interaction input from normalized Gemini contents.
    public static func contents(_ contents: [GoogleContent]) throws -> GoogleInteractionInput {
        GoogleInteractionInput(payload: .array(try contents.map { try JSONValue.encode($0) }))
    }
}

/// A Google Interactions tool definition.
public struct GoogleInteractionTool: Sendable, Hashable {
    /// The raw tool payload.
    public var payload: JSONValue

    /// Creates an interaction tool from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }

    /// Creates a function tool definition.
    public static func function(name: String, description: String, parameters: JSONValue) -> GoogleInteractionTool {
        GoogleInteractionTool(
            payload: .object([
                "type": .string("function"),
                "name": .string(name),
                "description": .string(description),
                "parameters": parameters,
            ])
        )
    }

    /// Creates a Google Search tool definition.
    public static func googleSearch() -> GoogleInteractionTool {
        GoogleInteractionTool(payload: .object(["type": .string("google_search")]))
    }

    /// Creates a URL Context tool definition.
    public static func urlContext() -> GoogleInteractionTool {
        GoogleInteractionTool(payload: .object(["type": .string("url_context")]))
    }

    /// Creates a Google Maps tool definition.
    public static func googleMaps() -> GoogleInteractionTool {
        GoogleInteractionTool(payload: .object(["type": .string("google_maps")]))
    }

    /// Creates a code-execution tool definition.
    public static func codeExecution() -> GoogleInteractionTool {
        GoogleInteractionTool(payload: .object(["type": .string("code_execution")]))
    }

    /// Creates a computer-use tool definition.
    public static func computerUse(environment: String? = nil) -> GoogleInteractionTool {
        var object: [String: JSONValue] = ["type": .string("computer_use")]
        if let environment {
            object["environment"] = .string(environment)
        }
        return GoogleInteractionTool(payload: .object(object))
    }

    /// Creates a file-search-store tool definition.
    public static func fileSearchStore(name: String) -> GoogleInteractionTool {
        GoogleInteractionTool(
            payload: .object([
                "type": .string("file_search"),
                "file_search_store_name": .string(name),
            ])
        )
    }
}

/// A request to the Google Interactions API.
public struct GoogleInteractionRequest: Sendable, Hashable {
    /// The model identifier to use.
    public var model: String?

    /// The agent identifier to use instead of a raw model.
    public var agent: String?

    /// The input payload.
    public var input: GoogleInteractionInput

    /// The previous interaction identifier for stateful continuation.
    public var previousInteractionID: String?

    /// Tools available to the interaction.
    public var tools: [GoogleInteractionTool]

    /// A JSON schema-style response format.
    public var responseFormat: JSONValue?

    /// Whether the server should store the interaction.
    public var store: Bool?

    /// Whether the interaction should execute in the background.
    public var background: Bool?

    /// Whether the REST response should be streamed as SSE.
    public var stream: Bool?

    /// Extra raw fields forwarded into the request body.
    public var extraOptions: JSONValue?

    /// Creates an interaction request.
    public init(
        model: String? = nil,
        agent: String? = nil,
        input: GoogleInteractionInput,
        previousInteractionID: String? = nil,
        tools: [GoogleInteractionTool] = [],
        responseFormat: JSONValue? = nil,
        store: Bool? = nil,
        background: Bool? = nil,
        stream: Bool? = nil,
        extraOptions: JSONValue? = nil
    ) {
        self.model = model
        self.agent = agent
        self.input = input
        self.previousInteractionID = previousInteractionID
        self.tools = tools
        self.responseFormat = responseFormat
        self.store = store
        self.background = background
        self.stream = stream
        self.extraOptions = extraOptions
    }

    func jsonValue() -> JSONValue {
        var object: [String: JSONValue] = [
            "input": input.payload,
        ]
        if let model {
            object["model"] = .string(model)
        }
        if let agent {
            object["agent"] = .string(agent)
        }
        if let previousInteractionID {
            object["previous_interaction_id"] = .string(previousInteractionID)
        }
        if tools.isEmpty == false {
            object["tools"] = .array(tools.map(\.payload))
        }
        if let responseFormat {
            object["response_format"] = responseFormat
        }
        if let store {
            object["store"] = .bool(store)
        }
        if let background {
            object["background"] = .bool(background)
        }
        if let stream {
            object["stream"] = .bool(stream)
        }
        return mergeGoogleProviderOptions(.object(object), with: extraOptions)
    }
}

/// A response returned by the Google Interactions API.
public struct GoogleInteractionResponse: Sendable, Hashable {
    /// The interaction identifier.
    public var id: String?

    /// The interaction status.
    public var status: String?

    /// The model identifier, when present.
    public var model: String?

    /// The agent identifier, when present.
    public var agent: String?

    /// The original input when requested.
    public var input: JSONValue?

    /// Output items returned by the interaction.
    public var outputs: [JSONValue]

    /// Usage metadata when available.
    public var usage: Usage?

    /// The raw response payload.
    public var rawPayload: JSONValue

    /// Creates an interaction response.
    public init(
        id: String? = nil,
        status: String? = nil,
        model: String? = nil,
        agent: String? = nil,
        input: JSONValue? = nil,
        outputs: [JSONValue] = [],
        usage: Usage? = nil,
        rawPayload: JSONValue
    ) {
        self.id = id
        self.status = status
        self.model = model
        self.agent = agent
        self.input = input
        self.outputs = outputs
        self.usage = usage
        self.rawPayload = rawPayload
    }
}

/// A page of Google interactions.
public struct GoogleInteractionsPage: Sendable, Hashable {
    /// The interactions returned on the page.
    public var interactions: [GoogleInteractionResponse]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates an interactions page.
    public init(interactions: [GoogleInteractionResponse], nextPageToken: String? = nil) {
        self.interactions = interactions
        self.nextPageToken = nextPageToken
    }
}

/// Stream events emitted by the Google Interactions API.
public enum GoogleInteractionStreamEvent: Sendable {
    /// The stream has started.
    case status(String)

    /// A content delta string.
    case contentDelta(String)

    /// A raw tool-call event payload.
    case toolCall(JSONValue)

    /// Usage information emitted by the stream.
    case usage(Usage)

    /// The final completed interaction.
    case complete(GoogleInteractionResponse)

    /// Any raw event that does not have a specialized case.
    case raw(type: String, payload: JSONValue)
}

/// Access to the Google Interactions API.
public struct GoogleInteractionsService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Creates an interaction.
    public func create(_ request: GoogleInteractionRequest) async throws -> GoogleInteractionResponse {
        try validate(request)
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("interactions"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try request.jsonValue().data()
            )
        )
        return GoogleInteractionsService.mapInteractionResponse(payload)
    }

    /// Streams an interaction as server-sent events.
    public func stream(_ request: GoogleInteractionRequest) -> AsyncThrowingStream<GoogleInteractionStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try validate(request)
                    var streamedRequest = request
                    streamedRequest.stream = true
                    continuation.yield(.status("started"))

                    let events = await configuration.client.streamEvents(
                        HTTPRequest(
                            url: configuration.stableURL("interactions", queryItems: [URLQueryItem(name: "alt", value: "sse")]),
                            method: .post,
                            headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                            body: try streamedRequest.jsonValue().data()
                        )
                    )

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }
                        let payload = try JSONValue.decode(Data(event.data.utf8))
                        let type = payload.objectValue?["type"]?.stringValue
                            ?? payload.objectValue?["event"]?.stringValue
                            ?? "message"

                        if type == "content.delta" {
                            if let delta = GoogleInteractionsService.extractContentDelta(from: payload) {
                                continuation.yield(.contentDelta(delta))
                            } else {
                                continuation.yield(.raw(type: type, payload: payload))
                            }
                            continue
                        }

                        if type.contains("tool"), let call = GoogleInteractionsService.extractToolCall(from: payload) {
                            continuation.yield(.toolCall(call))
                            continue
                        }

                        if type == "interaction.complete" || type == "interaction.completed" {
                            let response = GoogleInteractionsService.mapInteractionResponse(payload)
                            if let usage = response.usage {
                                continuation.yield(.usage(usage))
                            }
                            continuation.yield(.complete(response))
                            continue
                        }

                        if let usage = GoogleRequestSupport.usage(from: payload.objectValue?["usage"]?.objectValue ?? payload.objectValue?["usageMetadata"]?.objectValue) {
                            continuation.yield(.usage(usage))
                        }

                        continuation.yield(.raw(type: type, payload: payload))
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

    /// Retrieves an interaction by identifier.
    public func get(_ id: String, includeInput: Bool = false) async throws -> GoogleInteractionResponse {
        var queryItems: [URLQueryItem] = []
        if includeInput {
            queryItems.append(URLQueryItem(name: "include_input", value: "true"))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("interactions/\(id)", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return GoogleInteractionsService.mapInteractionResponse(payload)
    }

    /// Lists interactions.
    public func list(pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleInteractionsPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("interactions", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let entries = payload.objectValue?["interactions"]?.arrayValue
            ?? payload.objectValue?["data"]?.arrayValue
            ?? []
        let interactions = entries.map(GoogleInteractionsService.mapInteractionResponse)
        return GoogleInteractionsPage(
            interactions: interactions,
            nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue
        )
    }

    /// Deletes an interaction.
    public func delete(_ id: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("interactions/\(id)"),
                method: .delete,
                headers: configuration.apiKeyHeaders
            )
        )
    }

    private func validate(_ request: GoogleInteractionRequest) throws {
        if request.store == false, request.background == true {
            throw KaizoshaError.invalidRequest("Google interactions cannot set `background=true` when `store=false`.")
        }

        if request.model == nil, request.agent == nil {
            throw KaizoshaError.invalidRequest("Google interactions require either a `model` or an `agent`.")
        }
    }

    private static func mapInteractionResponse(_ value: JSONValue) -> GoogleInteractionResponse {
        let object = value.objectValue ?? [:]
        return GoogleInteractionResponse(
            id: object["id"]?.stringValue,
            status: object["status"]?.stringValue,
            model: object["model"]?.stringValue,
            agent: object["agent"]?.stringValue,
            input: object["input"],
            outputs: object["outputs"]?.arrayValue ?? [],
            usage: GoogleRequestSupport.usage(from: object["usage"]?.objectValue ?? object["usageMetadata"]?.objectValue),
            rawPayload: value
        )
    }

    private static func extractContentDelta(from value: JSONValue) -> String? {
        let object = value.objectValue ?? [:]
        if let delta = object["delta"]?.stringValue {
            return delta
        }
        if let content = object["content"]?.objectValue, let delta = content["delta"]?.stringValue {
            return delta
        }
        if let content = object["content"]?.arrayValue {
            return content.compactMap(\.stringValue).joined()
        }
        return nil
    }

    private static func extractToolCall(from value: JSONValue) -> JSONValue? {
        let object = value.objectValue ?? [:]
        return object["tool_call"] ?? object["toolCall"] ?? object["call"] ?? object["function_call"]
    }
}
