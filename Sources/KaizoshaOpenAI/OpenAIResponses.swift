import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// A full-fidelity OpenAI Responses API request.
public struct OpenAIResponseRequest: Sendable {
    /// The conversation input items.
    public var input: [Message]

    /// Shared generation controls.
    public var generation: GenerationConfig

    /// Function tools exposed to the model.
    public var tools: ToolRegistry

    /// Native OpenAI tools exposed to the model.
    public var nativeTools: [OpenAINativeTool]

    /// Additional provider-specific options.
    public var providerOptions: ProviderOptions

    /// Arbitrary metadata attached to the request.
    public var metadata: [String: String]

    /// High-level instructions inserted ahead of input items.
    public var instructions: String?

    /// The previous response identifier used for stateless conversation chaining.
    public var previousResponseID: String?

    /// The server-managed conversation identifier.
    public var conversationID: String?

    /// Whether to store the response for later retrieval.
    public var store: Bool?

    /// Whether to run the response in the background.
    public var background: Bool?

    /// The prompt-cache key used to improve cache hits.
    public var promptCacheKey: String?

    /// The prompt-cache retention policy.
    public var promptCacheRetention: OpenAIPromptCacheRetention

    /// Additional response fields to include in the output.
    public var include: [String]

    /// The requested service tier.
    public var serviceTier: OpenAIServiceTier?

    /// Whether the model may call tools in parallel.
    public var parallelToolCalls: Bool?

    /// A stable safety identifier for the end user.
    public var safetyIdentifier: String?

    /// The reasoning summary detail to request when reasoning is enabled.
    public var reasoningSummary: OpenAIReasoningSummary?

    /// The GPT-5 text verbosity preference.
    public var verbosity: OpenAITextVerbosity?

    /// The explicit tool choice used for the request.
    public var toolChoice: OpenAIToolChoice?

    package var structuredOutput: StructuredOutputDirective?
    package var passthroughOptions: [String: JSONValue]

    /// Creates a full-fidelity OpenAI Responses request.
    public init(
        input: [Message],
        generation: GenerationConfig = GenerationConfig(),
        tools: ToolRegistry = ToolRegistry(),
        nativeTools: [OpenAINativeTool] = [],
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:],
        instructions: String? = nil,
        previousResponseID: String? = nil,
        conversationID: String? = nil,
        store: Bool? = nil,
        background: Bool? = nil,
        promptCacheKey: String? = nil,
        promptCacheRetention: OpenAIPromptCacheRetention = .providerDefault,
        include: [String] = [],
        serviceTier: OpenAIServiceTier? = nil,
        parallelToolCalls: Bool? = nil,
        safetyIdentifier: String? = nil,
        reasoningSummary: OpenAIReasoningSummary? = nil,
        verbosity: OpenAITextVerbosity? = nil,
        toolChoice: OpenAIToolChoice? = nil
    ) {
        self.input = input
        self.generation = generation
        self.tools = tools
        self.nativeTools = nativeTools
        self.providerOptions = providerOptions
        self.metadata = metadata
        self.instructions = instructions
        self.previousResponseID = previousResponseID
        self.conversationID = conversationID
        self.store = store
        self.background = background
        self.promptCacheKey = promptCacheKey
        self.promptCacheRetention = promptCacheRetention
        self.include = include
        self.serviceTier = serviceTier
        self.parallelToolCalls = parallelToolCalls
        self.safetyIdentifier = safetyIdentifier
        self.reasoningSummary = reasoningSummary
        self.verbosity = verbosity
        self.toolChoice = toolChoice
        self.structuredOutput = nil
        self.passthroughOptions = [:]
    }
}

/// A parsed OpenAI Responses API content item.
public struct OpenAIResponseContent: Sendable, Hashable {
    /// The content type.
    public var type: String

    /// The text payload when present.
    public var text: String?

    /// The transcript payload when present.
    public var transcript: String?

    /// The file identifier when present.
    public var fileID: String?

    /// The image URL when present.
    public var imageURL: URL?

    /// The full raw payload for this content item.
    public var payload: JSONValue

    /// Creates a parsed OpenAI content item.
    public init(
        type: String,
        text: String? = nil,
        transcript: String? = nil,
        fileID: String? = nil,
        imageURL: URL? = nil,
        payload: JSONValue
    ) {
        self.type = type
        self.text = text
        self.transcript = transcript
        self.fileID = fileID
        self.imageURL = imageURL
        self.payload = payload
    }
}

/// A parsed OpenAI Responses API output item.
public struct OpenAIResponseItem: Sendable, Hashable {
    /// The provider item identifier.
    public var id: String?

    /// The item type.
    public var type: String

    /// The role, when the item is a message.
    public var role: String?

    /// The provider status, when present.
    public var status: String?

    /// The function or tool name, when present.
    public var name: String?

    /// The call identifier for function or native tool items.
    public var callID: String?

    /// The serialized JSON arguments for function calls.
    public var arguments: String?

    /// The structured output payload for tool outputs.
    public var output: JSONValue?

    /// Parsed content blocks for message items.
    public var content: [OpenAIResponseContent]

    /// Parsed reasoning summaries, when present.
    public var summaries: [String]

    /// The full raw payload for the item.
    public var payload: JSONValue

    /// Creates a parsed OpenAI response item.
    public init(
        id: String? = nil,
        type: String,
        role: String? = nil,
        status: String? = nil,
        name: String? = nil,
        callID: String? = nil,
        arguments: String? = nil,
        output: JSONValue? = nil,
        content: [OpenAIResponseContent] = [],
        summaries: [String] = [],
        payload: JSONValue
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.status = status
        self.name = name
        self.callID = callID
        self.arguments = arguments
        self.output = output
        self.content = content
        self.summaries = summaries
        self.payload = payload
    }

    /// The flattened output text represented by this item.
    public var outputText: String {
        content.compactMap { $0.text ?? $0.transcript }.joined()
    }

    /// Returns a provider-neutral tool invocation when the item is a custom function call.
    public func toolInvocation() throws -> ToolInvocation? {
        guard type == "function_call",
              let name,
              let callID,
              let arguments,
              let data = arguments.data(using: .utf8) else {
            return nil
        }

        return ToolInvocation(
            id: callID,
            name: name,
            input: try JSONValue.decode(data)
        )
    }
}

/// A parsed OpenAI Responses API response payload.
public struct OpenAIResponse: Sendable, Hashable {
    /// The response identifier.
    public var id: String?

    /// The model identifier that generated the response.
    public var modelID: String

    /// The OpenAI response status.
    public var status: String?

    /// The flattened text output for convenience.
    public var outputText: String

    /// The parsed output items.
    public var output: [OpenAIResponseItem]

    /// Token usage metadata, when present.
    public var usage: Usage?

    /// The inferred finish reason.
    public var finishReason: FinishReason

    /// The previous response identifier, when present.
    public var previousResponseID: String?

    /// The conversation identifier, when present.
    public var conversationID: String?

    /// The service tier used to process the request, when present.
    public var serviceTier: String?

    /// The full raw response payload.
    public var rawPayload: JSONValue

    /// Creates a parsed OpenAI response payload.
    public init(
        id: String? = nil,
        modelID: String,
        status: String? = nil,
        outputText: String,
        output: [OpenAIResponseItem],
        usage: Usage? = nil,
        finishReason: FinishReason = .unknown,
        previousResponseID: String? = nil,
        conversationID: String? = nil,
        serviceTier: String? = nil,
        rawPayload: JSONValue
    ) {
        self.id = id
        self.modelID = modelID
        self.status = status
        self.outputText = outputText
        self.output = output
        self.usage = usage
        self.finishReason = finishReason
        self.previousResponseID = previousResponseID
        self.conversationID = conversationID
        self.serviceTier = serviceTier
        self.rawPayload = rawPayload
    }
}

/// Streaming events emitted by the OpenAI Responses API.
public enum OpenAIResponseStreamEvent: Sendable {
    case status(String)
    case responseCreated(id: String)
    case outputTextDelta(String)
    case reasoningSummaryDelta(String)
    case functionCallArgumentsDelta(itemID: String, delta: String)
    case outputItemAdded(OpenAIResponseItem)
    case outputItemDone(OpenAIResponseItem)
    case usage(Usage)
    case responseCompleted(OpenAIResponse)
    case error(String, payload: JSONValue?)
    case raw(type: String, payload: JSONValue)
}

/// An OpenAI language model backed by the Responses API.
public struct OpenAIResponsesLanguageModel: LanguageModel, Sendable {
    /// The model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let capabilityProfile: OpenAICapabilityProfile
    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    init(id: String, apiKey: String, baseURL: URL, client: HTTPClient) {
        self.id = id
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
        self.capabilityProfile = OpenAICapabilityResolver.profile(for: id)
        self.capabilities = capabilityProfile.capabilities
    }

    /// Creates a raw OpenAI response.
    public func createResponse(_ request: OpenAIResponseRequest) async throws -> OpenAIResponse {
        try validate(request)
        let body = try await responsePayload(for: request, stream: false)
        let payload = try await client.sendJSON(
            HTTPRequest(
                url: baseURL.appendingPathComponents("responses"),
                headers: headers(contentType: "application/json"),
                body: try body.data()
            )
        )

        return try OpenAIResponseParser.parseResponse(payload, fallbackModelID: id)
    }

    /// Streams a raw OpenAI response.
    public func streamResponse(_ request: OpenAIResponseRequest) -> AsyncThrowingStream<OpenAIResponseStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try validate(request)
                    var accumulator = OpenAIResponseAccumulator(modelID: id)
                    continuation.yield(.status("started"))

                    let body = try await responsePayload(for: request, stream: true)
                    let events = await client.streamEvents(
                        HTTPRequest(
                            url: baseURL.appendingPathComponents("responses"),
                            headers: headers(contentType: "application/json"),
                            body: try body.data()
                        )
                    )

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }
                        let payload = try JSONValue.decode(Data(event.data.utf8))
                        guard let object = payload.objectValue,
                              let type = object["type"]?.stringValue else {
                            continuation.yield(.raw(type: event.event ?? "message", payload: payload))
                            continue
                        }

                        if let usage = OpenAIRequestSupport.parseUsage(from: object["usage"]?.objectValue) {
                            continuation.yield(.usage(usage))
                            accumulator.usage = usage
                        }

                        switch type {
                        case "response.created":
                            accumulator.absorb(responsePayload: object["response"] ?? payload)
                            if let responseID = object["response"]?.objectValue?["id"]?.stringValue
                                ?? object["id"]?.stringValue {
                                continuation.yield(.responseCreated(id: responseID))
                            }
                        case "response.output_text.delta":
                            let delta = object["delta"]?.stringValue ?? ""
                            accumulator.outputText += delta
                            continuation.yield(.outputTextDelta(delta))
                        case "response.output_item.added":
                            if let itemValue = object["item"] {
                                let item = try OpenAIResponseParser.parseItem(itemValue)
                                accumulator.upsert(item: item)
                                continuation.yield(.outputItemAdded(item))
                            }
                        case "response.output_item.done":
                            if let itemValue = object["item"] {
                                let item = try OpenAIResponseParser.parseItem(itemValue)
                                accumulator.upsert(item: item)
                                continuation.yield(.outputItemDone(item))
                            }
                        case "response.function_call_arguments.delta":
                            let itemID = object["item_id"]?.stringValue ?? object["id"]?.stringValue ?? ""
                            let delta = object["delta"]?.stringValue ?? ""
                            accumulator.appendFunctionArguments(delta, for: itemID)
                            continuation.yield(.functionCallArgumentsDelta(itemID: itemID, delta: delta))
                        case "response.function_call_arguments.done":
                            if let itemValue = object["item"] {
                                let item = try OpenAIResponseParser.parseItem(itemValue)
                                accumulator.upsert(item: item)
                                continuation.yield(.outputItemDone(item))
                            }
                        case "response.completed", "response.done":
                            let responseValue = object["response"] ?? accumulator.responsePayload()
                            let response = try OpenAIResponseParser.parseResponse(responseValue, fallbackModelID: id)
                            continuation.yield(.responseCompleted(response))
                            continuation.finish()
                            return
                        case "error":
                            let message = object["message"]?.stringValue
                                ?? object["error"]?.objectValue?["message"]?.stringValue
                                ?? "OpenAI returned a streaming error."
                            continuation.yield(.error(message, payload: payload))
                        default:
                            if type.contains("reasoning"),
                               let delta = object["delta"]?.stringValue ?? object["text"]?.stringValue {
                                continuation.yield(.reasoningSummaryDelta(delta))
                            }

                            if let responseValue = object["response"] {
                                accumulator.absorb(responsePayload: responseValue)
                            }

                            continuation.yield(.raw(type: type, payload: payload))
                        }
                    }

                    let response = try OpenAIResponseParser.parseResponse(accumulator.responsePayload(), fallbackModelID: id)
                    continuation.yield(.responseCompleted(response))
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

    public func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        try CapabilityValidator.validate(request, for: self, streaming: false)
        let response = try await createResponse(Self.responseRequest(from: request))
        return try normalize(response: response)
    }

    public func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try CapabilityValidator.validate(request, for: self, streaming: true)
                    var emittedToolInvocationIDs = Set<String>()

                    for try await event in streamResponse(Self.responseRequest(from: request)) {
                        switch event {
                        case .status(let status):
                            continuation.yield(.status(status))
                        case .responseCreated:
                            continue
                        case .outputTextDelta(let delta):
                            continuation.yield(.textDelta(delta))
                        case .reasoningSummaryDelta:
                            continue
                        case .functionCallArgumentsDelta:
                            continue
                        case .outputItemAdded:
                            continue
                        case .outputItemDone(let item):
                            if let invocation = try item.toolInvocation(),
                               emittedToolInvocationIDs.insert(invocation.id).inserted {
                                continuation.yield(.toolCall(invocation))
                            }
                        case .usage(let usage):
                            continuation.yield(.usage(usage))
                        case .responseCompleted(let response):
                            for item in response.output {
                                if let invocation = try item.toolInvocation(),
                                   emittedToolInvocationIDs.insert(invocation.id).inserted {
                                    continuation.yield(.toolCall(invocation))
                                }
                            }
                            continuation.yield(.finished(response.finishReason))
                        case .error(let message, _):
                            throw KaizoshaError.invalidResponse(message)
                        case .raw:
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

    private func responsePayload(for request: OpenAIResponseRequest, stream: Bool) async throws -> JSONValue {
        var object: [String: JSONValue] = [
            "model": .string(id),
            "input": .array(try await mapInputItems(request.input)),
        ]

        if let instructions = request.instructions {
            object["instructions"] = .string(instructions)
        }
        if let previousResponseID = request.previousResponseID {
            object["previous_response_id"] = .string(previousResponseID)
        }
        if let conversationID = request.conversationID {
            object["conversation"] = .object(["id": .string(conversationID)])
        }
        if let store = request.store {
            object["store"] = .bool(store)
        }
        if let background = request.background {
            object["background"] = .bool(background)
        }
        if let promptCacheKey = request.promptCacheKey {
            object["prompt_cache_key"] = .string(promptCacheKey)
        }
        if request.promptCacheRetention != .providerDefault {
            object["prompt_cache_retention"] = .string(request.promptCacheRetention.rawValue)
        }
        if request.include.isEmpty == false {
            object["include"] = .array(request.include.map(JSONValue.string))
        }
        if let serviceTier = request.serviceTier {
            object["service_tier"] = .string(serviceTier.rawValue)
        }
        if let parallelToolCalls = request.parallelToolCalls {
            object["parallel_tool_calls"] = .bool(parallelToolCalls)
        }
        if let safetyIdentifier = request.safetyIdentifier {
            object["safety_identifier"] = .string(safetyIdentifier)
        }
        if let temperature = request.generation.temperature {
            object["temperature"] = .number(temperature)
        }
        if let topP = request.generation.topP {
            object["top_p"] = .number(topP)
        }
        if let maxOutputTokens = request.generation.maxOutputTokens {
            object["max_output_tokens"] = .number(Double(maxOutputTokens))
        }
        if stream {
            object["stream"] = .bool(true)
        }

        let tools = mapTools(request.tools, nativeTools: request.nativeTools)
        if tools.isEmpty == false {
            object["tools"] = .array(tools)
            object["tool_choice"] = (request.toolChoice ?? .auto).jsonValue
        }

        var textObject: [String: JSONValue] = [:]
        if request.generation.stopSequences.isEmpty == false {
            textObject["stop"] = .array(request.generation.stopSequences.map(JSONValue.string))
        }
        if let verbosity = request.verbosity {
            textObject["verbosity"] = .string(verbosity.rawValue)
        }
        if let structuredOutput = request.structuredOutput {
            textObject["format"] = .object([
                "type": .string("json_schema"),
                "name": .string(structuredOutput.name),
                "strict": .bool(true),
                "schema": structuredOutput.schema,
            ])
        }
        if textObject.isEmpty == false {
            object["text"] = .object(textObject)
        }

        var reasoningObject: [String: JSONValue] = [:]
        if request.generation.reasoning != .providerDefault {
            reasoningObject["effort"] = .string(request.generation.reasoning.rawValue)
        }
        if let reasoningSummary = request.reasoningSummary {
            reasoningObject["summary"] = .string(reasoningSummary.rawValue)
        }
        if reasoningObject.isEmpty == false {
            object["reasoning"] = .object(reasoningObject)
        }

        if request.metadata.isEmpty == false {
            object["metadata"] = .object(request.metadata.mapValues(JSONValue.string))
        }

        return JSONValue.object(object).mergingObject(with: .object(request.passthroughOptions))
    }

    private func validate(_ request: OpenAIResponseRequest) throws {
        if request.previousResponseID != nil, request.conversationID != nil {
            throw KaizoshaError.invalidRequest(
                "OpenAI Responses requests cannot use previousResponseID and conversationID at the same time."
            )
        }

        if request.instructions != nil, capabilityProfile.supportsInstructions == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "Responses instructions")
        }

        if request.previousResponseID != nil || request.conversationID != nil,
           capabilityProfile.supportsConversationState == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "Responses conversation state")
        }

        if request.nativeTools.isEmpty == false, capabilityProfile.supportsNativeTools == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "OpenAI built-in tools")
        }

        if request.reasoningSummary != nil, capabilities.supportsReasoningControls == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "OpenAI reasoning summaries")
        }

        if request.verbosity != nil, OpenAIRequestSupport.supportsTextVerbosity(modelID: id) == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "OpenAI text verbosity")
        }
    }

    private func mapInputItems(_ messages: [Message]) async throws -> [JSONValue] {
        let normalized = MessagePipeline.normalize(messages)
        var payloads: [JSONValue] = []

        for message in normalized {
            switch message.role {
            case .system:
                payloads.append(
                    .object([
                        "role": .string("developer"),
                        "content": .array(message.parts.map(Self.mapDeveloperPart)),
                    ])
                )
            case .user:
                payloads.append(
                    .object([
                        "role": .string("user"),
                        "content": .array(try await mapUserParts(message.parts)),
                    ])
                )
            case .assistant:
                let textParts = message.parts.compactMap { part -> String? in
                    guard case .text(let text) = part else { return nil }
                    return text
                }

                if textParts.isEmpty == false {
                    payloads.append(
                        .object([
                            "role": .string("assistant"),
                            "content": .array([
                                .object([
                                    "type": .string("output_text"),
                                    "text": .string(textParts.joined(separator: "\n")),
                                ]),
                            ]),
                        ])
                    )
                }

                for part in message.parts {
                    guard case .toolCall(let invocation) = part else { continue }
                    payloads.append(
                        .object([
                            "type": .string("function_call"),
                            "call_id": .string(invocation.id),
                            "name": .string(invocation.name),
                            "arguments": .string(try invocation.input.compactString()),
                        ])
                    )
                }
            case .tool:
                for part in message.parts {
                    guard case .toolResult(let result) = part else { continue }
                    payloads.append(
                        .object([
                            "type": .string("function_call_output"),
                            "call_id": .string(result.invocationID),
                            "output": .string(try result.output.compactString()),
                        ])
                    )
                }
            }
        }

        return payloads
    }

    private static func mapDeveloperPart(_ part: ModelPart) -> JSONValue {
        switch part {
        case .text(let text):
            return .object([
                "type": .string("input_text"),
                "text": .string(text),
            ])
        case .image, .audio, .file, .toolCall, .toolResult:
            return .object([
                "type": .string("input_text"),
                "text": .string(""),
            ])
        }
    }

    private func mapUserParts(_ parts: [ModelPart]) async throws -> [JSONValue] {
        var payloads: [JSONValue] = []

        for part in parts {
            switch part {
            case .text(let text):
                payloads.append(
                    .object([
                        "type": .string("input_text"),
                        "text": .string(text),
                    ])
                )
            case .image(let image):
                let imageURL: String
                if let url = image.url {
                    imageURL = url.absoluteString
                } else if let data = image.data {
                    imageURL = "data:\(image.mimeType);base64,\(data.base64EncodedString())"
                } else {
                    throw KaizoshaError.invalidRequest("An image input must contain bytes or a URL.")
                }

                payloads.append(
                    .object([
                        "type": .string("input_image"),
                        "image_url": .string(imageURL),
                    ])
                )
            case .audio(let audio):
                payloads.append(
                    .object([
                        "type": .string("input_audio"),
                        "input_audio": .object([
                            "data": .string(audio.data.base64EncodedString()),
                            "format": .string(OpenAIRequestSupport.mimeSubtype(from: audio.mimeType)),
                        ]),
                    ])
                )
            case .file(let file):
                if let providerFileID = file.providerFileID, file.providerNamespace == OpenAIProvider.namespace {
                    payloads.append(
                        .object([
                            "type": .string("input_file"),
                            "file_id": .string(providerFileID),
                        ])
                    )
                    continue
                }

                guard let data = file.data else {
                    throw KaizoshaError.invalidRequest("OpenAI file input parts require inline data or an OpenAI file id.")
                }

                let uploaded = try await uploadInlineFile(data: data, fileName: file.fileName ?? "attachment", mimeType: file.mimeType)
                payloads.append(
                    .object([
                        "type": .string("input_file"),
                        "file_id": .string(uploaded.id),
                    ])
                )
            case .toolCall, .toolResult:
                throw KaizoshaError.invalidRequest("Tool parts are not valid inside OpenAI user messages.")
            }
        }

        return payloads
    }

    private func uploadInlineFile(data: Data, fileName: String, mimeType: String) async throws -> OpenAIFileDescriptor {
        var multipart = MultipartFormData()
        multipart.addText(name: "purpose", value: "assistants")
        multipart.addData(name: "file", fileName: fileName, mimeType: mimeType, data: data)

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files"),
                headers: headers(contentType: multipart.contentType),
                body: multipart.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(decoding: response.body, as: UTF8.self)
            )
        }

        let payload = try JSONValue.decode(response.body)
        return try OpenAIFileDescriptor(payload: payload)
    }

    private func mapTools(_ tools: ToolRegistry, nativeTools: [OpenAINativeTool]) -> [JSONValue] {
        let customTools = tools.tools.map { tool in
            JSONValue.object([
                "type": .string("function"),
                "name": .string(tool.name),
                "description": .string(tool.description),
                "parameters": tool.inputSchema,
                "strict": .bool(true),
            ])
        }

        return customTools + nativeTools.map(\.jsonValue)
    }

    private func normalize(response: OpenAIResponse) throws -> TextGenerationResponse {
        let toolInvocations = try response.output.compactMap { try $0.toolInvocation() }
        let parts = (response.outputText.isEmpty ? [] : [MessagePart.text(response.outputText)]) + toolInvocations.map(MessagePart.toolCall)

        return TextGenerationResponse(
            modelID: response.modelID,
            message: Message(role: .assistant, parts: parts),
            text: response.outputText,
            toolInvocations: toolInvocations,
            usage: response.usage,
            finishReason: response.finishReason,
            rawPayload: response.rawPayload
        )
    }

    private func headers(contentType: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": contentType,
        ]
    }
}

package extension OpenAIResponsesLanguageModel {
    static func responseRequest(from request: TextGenerationRequest) -> OpenAIResponseRequest {
        let options = OpenAIRequestOptionsView(request.providerOptions.options(for: OpenAIProvider.namespace))

        var responseRequest = OpenAIResponseRequest(
            input: request.messages,
            generation: request.generation,
            tools: request.tools,
            nativeTools: options.nativeTools,
            providerOptions: request.providerOptions,
            metadata: request.metadata,
            instructions: options.instructions,
            previousResponseID: options.previousResponseID,
            conversationID: options.conversationID,
            store: options.store,
            background: options.background,
            promptCacheKey: options.promptCacheKey,
            promptCacheRetention: options.promptCacheRetention,
            include: options.include,
            serviceTier: options.serviceTier,
            parallelToolCalls: options.parallelToolCalls,
            safetyIdentifier: options.safetyIdentifier,
            reasoningSummary: options.reasoningSummary,
            verbosity: options.verbosity
        )
        responseRequest.structuredOutput = request.structuredOutput
        responseRequest.passthroughOptions = options.passthrough
        return responseRequest
    }
}

package struct OpenAIFileDescriptor: Sendable, Hashable {
    package var id: String
    package var fileName: String
    package var bytes: Int?
    package var purpose: String?

    package init(payload: JSONValue) throws {
        guard let object = payload.objectValue,
              let id = object["id"]?.stringValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an invalid file payload.")
        }

        self.id = id
        self.fileName = object["filename"]?.stringValue ?? "file"
        self.bytes = ModelCatalogDecoding.intValue(object["bytes"])
        self.purpose = object["purpose"]?.stringValue
    }
}

package struct OpenAIRequestOptionsView {
    package var instructions: String?
    package var previousResponseID: String?
    package var conversationID: String?
    package var store: Bool?
    package var background: Bool?
    package var promptCacheKey: String?
    package var promptCacheRetention: OpenAIPromptCacheRetention = .providerDefault
    package var include: [String] = []
    package var serviceTier: OpenAIServiceTier?
    package var parallelToolCalls: Bool?
    package var safetyIdentifier: String?
    package var nativeTools: [OpenAINativeTool] = []
    package var reasoningSummary: OpenAIReasoningSummary?
    package var verbosity: OpenAITextVerbosity?
    package var passthrough: [String: JSONValue]

    package init(_ value: JSONValue?) {
        let object = value?.objectValue ?? [:]
        self.instructions = object["instructions"]?.stringValue
        self.previousResponseID = object["previous_response_id"]?.stringValue
        self.conversationID = object["conversation_id"]?.stringValue
        self.store = object["store"]?.boolValue
        self.background = object["background"]?.boolValue
        self.promptCacheKey = object["prompt_cache_key"]?.stringValue
        if let retention = object["prompt_cache_retention"]?.stringValue,
           let parsed = OpenAIPromptCacheRetention(rawValue: retention) {
            self.promptCacheRetention = parsed
        }
        self.include = object["include"]?.arrayValue?.compactMap(\.stringValue) ?? []
        if let tier = object["service_tier"]?.stringValue {
            self.serviceTier = OpenAIServiceTier(rawValue: tier)
        }
        self.parallelToolCalls = object["parallel_tool_calls"]?.boolValue
        self.safetyIdentifier = object["safety_identifier"]?.stringValue
        self.reasoningSummary = object["reasoning_summary"]?.stringValue.flatMap(OpenAIReasoningSummary.init(rawValue:))
        self.verbosity = object["verbosity"]?.stringValue.flatMap(OpenAITextVerbosity.init(rawValue:))
        self.nativeTools = object["native_tools"]?.arrayValue?.compactMap { value in
            guard let object = value.objectValue,
                  let type = object["type"]?.stringValue else {
                return nil
            }

            var configuration = object
            configuration.removeValue(forKey: "type")
            return OpenAINativeTool(type: type, configuration: .object(configuration))
        } ?? []

        var passthrough = object
        [
            "user",
            "instructions",
            "previous_response_id",
            "conversation_id",
            "store",
            "background",
            "prompt_cache_key",
            "prompt_cache_retention",
            "include",
            "service_tier",
            "parallel_tool_calls",
            "safety_identifier",
            "native_tools",
            "reasoning_summary",
            "verbosity",
        ]
        .forEach { passthrough.removeValue(forKey: $0) }
        self.passthrough = passthrough
    }
}

package struct OpenAIResponseAccumulator {
    package var id: String?
    package var modelID: String
    package var status: String?
    package var outputText: String = ""
    package var itemsByKey: [String: OpenAIResponseItem] = [:]
    package var itemOrder: [String] = []
    package var usage: Usage?
    package var rawResponse: JSONValue?

    package init(modelID: String) {
        self.modelID = modelID
    }

    package mutating func absorb(responsePayload: JSONValue) {
        rawResponse = responsePayload
        guard let object = responsePayload.objectValue else { return }

        id = object["id"]?.stringValue ?? id
        modelID = object["model"]?.stringValue ?? modelID
        status = object["status"]?.stringValue ?? status
        if let usage = OpenAIRequestSupport.parseUsage(from: object["usage"]?.objectValue) {
            self.usage = usage
        }
    }

    package mutating func upsert(item: OpenAIResponseItem) {
        let key = item.id ?? item.callID ?? UUID().uuidString
        if itemOrder.contains(key) == false {
            itemOrder.append(key)
        }

        if var existing = itemsByKey[key] {
            existing.status = item.status ?? existing.status
            existing.arguments = item.arguments ?? existing.arguments
            existing.output = item.output ?? existing.output
            if item.content.isEmpty == false {
                existing.content = item.content
            }
            if item.summaries.isEmpty == false {
                existing.summaries = item.summaries
            }
            existing.payload = item.payload
            itemsByKey[key] = existing
        } else {
            itemsByKey[key] = item
        }
    }

    package mutating func appendFunctionArguments(_ delta: String, for itemID: String) {
        guard itemID.isEmpty == false else { return }

        if var existing = itemsByKey[itemID] {
            existing.arguments = (existing.arguments ?? "") + delta
            itemsByKey[itemID] = existing
            return
        }

        itemOrder.append(itemID)
        itemsByKey[itemID] = OpenAIResponseItem(
            id: itemID,
            type: "function_call",
            arguments: delta,
            payload: .object([
                "id": .string(itemID),
                "type": .string("function_call"),
                "arguments": .string(delta),
            ])
        )
    }

    package func responsePayload() -> JSONValue {
        if let rawResponse {
            return rawResponse
        }

        let items = itemOrder.compactMap { itemsByKey[$0] }
        let output = items.map(\.payload)
        return .object([
            "id": id.map(JSONValue.string) ?? .null,
            "model": .string(modelID),
            "status": status.map(JSONValue.string) ?? .null,
            "output_text": .string(outputText),
            "output": .array(output),
            "usage": usage.map(Self.usageJSON) ?? .null,
        ])
    }

    private static func usageJSON(_ usage: Usage) -> JSONValue {
        var object: [String: JSONValue] = [:]
        if let inputTokens = usage.inputTokens {
            object["input_tokens"] = .number(Double(inputTokens))
        }
        if let outputTokens = usage.outputTokens {
            object["output_tokens"] = .number(Double(outputTokens))
        }
        if let totalTokens = usage.totalTokens {
            object["total_tokens"] = .number(Double(totalTokens))
        }
        return .object(object)
    }
}

package enum OpenAIResponseParser {
    package static func parseResponse(_ value: JSONValue, fallbackModelID: String) throws -> OpenAIResponse {
        guard let object = value.objectValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned a malformed response payload.")
        }

        let output = try (object["output"]?.arrayValue ?? []).map(parseItem)
        let topLevelOutputText = object["output_text"]?.stringValue
        let outputText = topLevelOutputText ?? output.map(\.outputText).joined()
        let usage = OpenAIRequestSupport.parseUsage(from: object["usage"]?.objectValue)
        let finishReason = inferFinishReason(from: object, output: output)
        let conversationID = object["conversation"]?.objectValue?["id"]?.stringValue
            ?? object["conversation_id"]?.stringValue

        return OpenAIResponse(
            id: object["id"]?.stringValue,
            modelID: object["model"]?.stringValue ?? fallbackModelID,
            status: object["status"]?.stringValue,
            outputText: outputText,
            output: output,
            usage: usage,
            finishReason: finishReason,
            previousResponseID: object["previous_response_id"]?.stringValue,
            conversationID: conversationID,
            serviceTier: object["service_tier"]?.stringValue,
            rawPayload: value
        )
    }

    package static func parseItem(_ value: JSONValue) throws -> OpenAIResponseItem {
        guard let object = value.objectValue,
              let type = object["type"]?.stringValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an output item without a type.")
        }

        let content = (object["content"]?.arrayValue ?? []).compactMap(parseContent)
        let summaries = (object["summary"]?.arrayValue ?? []).compactMap { entry in
            entry.objectValue?["text"]?.stringValue ?? entry.stringValue
        }

        return OpenAIResponseItem(
            id: object["id"]?.stringValue,
            type: type,
            role: object["role"]?.stringValue,
            status: object["status"]?.stringValue,
            name: object["name"]?.stringValue,
            callID: object["call_id"]?.stringValue ?? object["id"]?.stringValue,
            arguments: object["arguments"]?.stringValue,
            output: object["output"],
            content: content,
            summaries: summaries,
            payload: value
        )
    }

    package static func parseContent(_ value: JSONValue) -> OpenAIResponseContent? {
        guard let object = value.objectValue,
              let type = object["type"]?.stringValue else {
            return nil
        }

        let imageURLString = object["image_url"]?.stringValue
            ?? object["image_url"]?.objectValue?["url"]?.stringValue

        return OpenAIResponseContent(
            type: type,
            text: object["text"]?.stringValue,
            transcript: object["transcript"]?.stringValue,
            fileID: object["file_id"]?.stringValue,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            payload: value
        )
    }

    private static func inferFinishReason(from object: [String: JSONValue], output: [OpenAIResponseItem]) -> FinishReason {
        if object["error"] != nil {
            return .error
        }

        if let reason = object["incomplete_details"]?.objectValue?["reason"]?.stringValue {
            if reason.contains("max") || reason == "length" {
                return .length
            }
            if reason.contains("content_filter") {
                return .contentFilter
            }
        }

        if output.contains(where: { $0.type == "function_call" }) {
            return .toolCalls
        }

        if object["status"]?.stringValue == "completed" {
            return .stop
        }

        return .unknown
    }
}
