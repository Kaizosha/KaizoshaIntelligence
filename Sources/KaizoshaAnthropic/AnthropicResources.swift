import Foundation
import KaizoshaProvider
import KaizoshaTransport

package let anthropicAPIVersion = "2023-06-01"
package let anthropicFilesBeta = "files-api-2025-04-14"

package enum AnthropicRequestHeaders {
    package static func make(
        apiKey: String,
        contentType: String? = "application/json",
        includeFilesBeta: Bool = false
    ) -> [String: String] {
        var headers: [String: String] = [
            "x-api-key": apiKey,
            "anthropic-version": anthropicAPIVersion,
        ]

        if let contentType {
            headers["Content-Type"] = contentType
        }

        if includeFilesBeta {
            headers["anthropic-beta"] = anthropicFilesBeta
        }

        return headers
    }
}

package enum AnthropicMessagePayloadBuilder {
    package static func messagePayload(modelID: String, request: TextGenerationRequest, stream: Bool) throws -> JSONValue {
        let splitOptions = AnthropicPromptCachingParser.split(from: request.providerOptions.options(for: AnthropicProvider.namespace))
        var object = try basePayload(
            modelID: modelID,
            messages: request.messages,
            tools: request.tools,
            structuredOutput: request.structuredOutput,
            caching: splitOptions.caching
        )

        object["max_tokens"] = .number(Double(request.generation.maxOutputTokens ?? 1024))

        if let temperature = request.generation.temperature {
            object["temperature"] = .number(temperature)
        }
        if let topP = request.generation.topP {
            object["top_p"] = .number(topP)
        }
        if stream {
            object["stream"] = .bool(true)
        }
        if let automatic = splitOptions.caching.automatic {
            object["cache_control"] = automatic
        }

        return JSONValue.object(object).mergingObject(with: splitOptions.passthrough)
    }

    package static func countTokensPayload(modelID: String, request: TextGenerationRequest) throws -> JSONValue {
        let splitOptions = AnthropicPromptCachingParser.split(from: request.providerOptions.options(for: AnthropicProvider.namespace))
        var object = try basePayload(
            modelID: modelID,
            messages: request.messages,
            tools: request.tools,
            structuredOutput: request.structuredOutput,
            caching: splitOptions.caching
        )

        if let automatic = splitOptions.caching.automatic {
            object["cache_control"] = automatic
        }

        return JSONValue.object(object).mergingObject(with: splitOptions.passthrough)
    }

    package static func usesFilesBeta(messages: [Message]) -> Bool {
        messages.contains { message in
            message.parts.contains { part in
                guard case .file(let file) = part else { return false }
                return file.providerNamespace == AnthropicProvider.namespace && file.providerFileID != nil
            }
        }
    }

    private static func basePayload(
        modelID: String,
        messages: [Message],
        tools: ToolRegistry,
        structuredOutput: StructuredOutputDirective?,
        caching: AnthropicPromptCachingConfiguration
    ) throws -> [String: JSONValue] {
        let normalized = MessagePipeline.normalize(messages)
        let conversation = normalized.enumerated().filter { $0.element.role != .system }

        var object: [String: JSONValue] = [
            "model": .string(modelID),
            "messages": .array(try conversation.flatMap { index, message in
                try mapMessage(message, originalMessageIndex: index, modelID: modelID, caching: caching)
            }),
        ]

        if let systemPrompt = try systemPrompt(from: normalized, structuredOutput: structuredOutput) {
            if let systemCacheControl = caching.system {
                object["system"] = .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(systemPrompt),
                        "cache_control": systemCacheControl,
                    ]),
                ])
            } else {
                object["system"] = .string(systemPrompt)
            }
        }

        if tools.isEmpty == false {
            object["tools"] = .array(
                tools.tools.enumerated().map { index, tool in
                    var payload: [String: JSONValue] = [
                        "name": .string(tool.name),
                        "description": .string(tool.description),
                        "input_schema": tool.inputSchema,
                    ]
                    if let cacheControl = caching.tools[index] {
                        payload["cache_control"] = cacheControl
                    }
                    return .object(payload)
                }
            )
        }

        return object
    }

    private static func systemPrompt(
        from messages: [ModelMessage],
        structuredOutput: StructuredOutputDirective?
    ) throws -> String? {
        let baseSystemPrompt = MessagePipeline.systemPrompt(from: messages)

        guard let structuredOutput else {
            return baseSystemPrompt
        }

        let schema = String(data: try structuredOutput.schema.data(prettyPrinted: true), encoding: .utf8) ?? "{}"

        return """
        \(baseSystemPrompt ?? "")

        Return only valid JSON matching the schema named \(structuredOutput.name):
        \(schema)
        """
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mapMessage(
        _ message: ModelMessage,
        originalMessageIndex: Int,
        modelID: String,
        caching: AnthropicPromptCachingConfiguration
    ) throws -> [JSONValue] {
        switch message.role {
        case .system:
            return []
        case .user:
            return [
                .object([
                    "role": .string("user"),
                    "content": .array(try mapUserParts(
                        message.parts,
                        originalMessageIndex: originalMessageIndex,
                        modelID: modelID,
                        caching: caching
                    )),
                ]),
            ]
        case .assistant:
            return [
                .object([
                    "role": .string("assistant"),
                    "content": .array(try mapAssistantParts(
                        message.parts,
                        originalMessageIndex: originalMessageIndex,
                        caching: caching
                    )),
                ]),
            ]
        case .tool:
            let parts = try message.parts.enumerated().compactMap { partIndex, part -> JSONValue? in
                guard case .toolResult(let result) = part else { return nil }
                var payload: [String: JSONValue] = [
                    "type": .string("tool_result"),
                    "tool_use_id": .string(result.invocationID),
                    "content": .string(try result.output.compactString()),
                    "is_error": .bool(result.isError),
                ]
                if let cacheControl = caching.messageParts[AnthropicMessagePartKey(messageIndex: originalMessageIndex, partIndex: partIndex)] {
                    payload["cache_control"] = cacheControl
                }
                return .object(payload)
            }

            return [
                .object([
                    "role": .string("user"),
                    "content": .array(parts),
                ]),
            ]
        }
    }

    private static func mapUserParts(
        _ parts: [ModelPart],
        originalMessageIndex: Int,
        modelID: String,
        caching: AnthropicPromptCachingConfiguration
    ) throws -> [JSONValue] {
        try parts.enumerated().map { partIndex, part in
            let cacheControl = caching.messageParts[AnthropicMessagePartKey(messageIndex: originalMessageIndex, partIndex: partIndex)]

            switch part {
            case .text(let text):
                var payload: [String: JSONValue] = [
                    "type": .string("text"),
                    "text": .string(text),
                ]
                if let cacheControl {
                    payload["cache_control"] = cacheControl
                }
                return .object(payload)
            case .image(let image):
                guard let data = image.data ?? (try? Data(contentsOf: image.url!)) else {
                    throw KaizoshaError.invalidRequest("Anthropic image parts require inline data or a reachable local URL.")
                }

                var payload: [String: JSONValue] = [
                    "type": .string("image"),
                    "source": .object([
                        "type": .string("base64"),
                        "media_type": .string(image.mimeType),
                        "data": .string(data.base64EncodedString()),
                    ]),
                ]
                if let cacheControl {
                    payload["cache_control"] = cacheControl
                }
                return .object(payload)
            case .audio:
                throw KaizoshaError.unsupportedCapability(modelID: modelID, capability: "audio prompt parts")
            case .file(let file):
                return try mapFile(file, cacheControl: cacheControl)
            case .toolCall, .toolResult:
                throw KaizoshaError.invalidRequest("Tool parts are not valid inside Anthropic user messages.")
            }
        }
    }

    private static func mapAssistantParts(
        _ parts: [ModelPart],
        originalMessageIndex: Int,
        caching: AnthropicPromptCachingConfiguration
    ) throws -> [JSONValue] {
        try parts.enumerated().map { partIndex, part in
            let cacheControl = caching.messageParts[AnthropicMessagePartKey(messageIndex: originalMessageIndex, partIndex: partIndex)]

            switch part {
            case .text(let text):
                var payload: [String: JSONValue] = [
                    "type": .string("text"),
                    "text": .string(text),
                ]
                if let cacheControl {
                    payload["cache_control"] = cacheControl
                }
                return .object(payload)
            case .toolCall(let invocation):
                var payload: [String: JSONValue] = [
                    "type": .string("tool_use"),
                    "id": .string(invocation.id),
                    "name": .string(invocation.name),
                    "input": invocation.input,
                ]
                if let cacheControl {
                    payload["cache_control"] = cacheControl
                }
                return .object(payload)
            case .image, .audio, .file, .toolResult:
                throw KaizoshaError.invalidRequest("Anthropic assistant messages only support text and tool call parts.")
            }
        }
    }

    private static func mapFile(_ file: FileContent, cacheControl: JSONValue?) throws -> JSONValue {
        if let providerFileID = file.providerFileID {
            guard file.providerNamespace == AnthropicProvider.namespace else {
                throw KaizoshaError.invalidRequest("Anthropic file prompt parts only support Anthropic file identifiers.")
            }

            var payload: [String: JSONValue] = [
                "type": .string("document"),
                "source": .object([
                    "type": .string("file"),
                    "file_id": .string(providerFileID),
                ]),
            ]
            if let cacheControl {
                payload["cache_control"] = cacheControl
            }
            return .object(payload)
        }

        guard let data = file.data else {
            throw KaizoshaError.invalidRequest(
                "Anthropic file prompt parts require inline data or an Anthropic provider-managed file identifier."
            )
        }

        switch file.mimeType.lowercased() {
        case "application/pdf":
            var payload: [String: JSONValue] = [
                "type": .string("document"),
                "source": .object([
                    "type": .string("base64"),
                    "media_type": .string("application/pdf"),
                    "data": .string(data.base64EncodedString()),
                ]),
            ]
            if let cacheControl {
                payload["cache_control"] = cacheControl
            }
            return .object(payload)
        case "text/plain":
            guard let text = String(data: data, encoding: .utf8) else {
                throw KaizoshaError.invalidRequest("Anthropic plain-text file parts must contain UTF-8 data.")
            }

            var payload: [String: JSONValue] = [
                "type": .string("document"),
                "source": .object([
                    "type": .string("text"),
                    "media_type": .string("text/plain"),
                    "data": .string(text),
                ]),
            ]
            if let cacheControl {
                payload["cache_control"] = cacheControl
            }
            return .object(payload)
        default:
            throw KaizoshaError.invalidRequest(
                "Anthropic inline file prompt parts currently support application/pdf and text/plain. Upload reusable files first to pass provider-managed Anthropic file identifiers."
            )
        }
    }
}

/// A file upload request for the Anthropic Files API.
public struct AnthropicFileUploadRequest: Sendable, Hashable {
    /// The file bytes to upload.
    public var data: Data

    /// The file name to report to Anthropic.
    public var fileName: String

    /// The file MIME type.
    public var mimeType: String

    /// Creates a file upload request.
    public init(data: Data, fileName: String, mimeType: String = "application/octet-stream") {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

/// A file descriptor returned by the Anthropic Files API.
public struct AnthropicFile: Sendable, Hashable {
    /// The file identifier.
    public var id: String

    /// The file name, when Anthropic returns one.
    public var fileName: String?

    /// The MIME type, when Anthropic returns one.
    public var mimeType: String?

    /// The file size in bytes, when Anthropic returns one.
    public var sizeBytes: Int?

    /// The creation timestamp, when available.
    public var createdAt: Date?

    /// The provider-defined state string, when available.
    public var state: String?

    /// Whether Anthropic marks the file content as downloadable.
    public var downloadable: Bool?

    /// The original provider payload.
    public var rawPayload: JSONValue

    /// Creates a file descriptor.
    public init(
        id: String,
        fileName: String? = nil,
        mimeType: String? = nil,
        sizeBytes: Int? = nil,
        createdAt: Date? = nil,
        state: String? = nil,
        downloadable: Bool? = nil,
        rawPayload: JSONValue
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.state = state
        self.downloadable = downloadable
        self.rawPayload = rawPayload
    }

    /// Converts the uploaded file into a reusable provider-managed file prompt part.
    public func asFileContent() -> FileContent {
        FileContent(
            providerFileID: id,
            providerNamespace: AnthropicProvider.namespace,
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream"
        )
    }
}

/// A page of Anthropic files.
public struct AnthropicFilesPage: Sendable, Hashable {
    /// Files returned on the page.
    public var files: [AnthropicFile]

    /// The next pagination cursor, when Anthropic indicates there are more files.
    public var nextAfterID: String?

    /// Creates a page of files.
    public init(files: [AnthropicFile], nextAfterID: String? = nil) {
        self.files = files
        self.nextAfterID = nextAfterID
    }
}

/// A token-counting response returned by Anthropic.
public struct AnthropicTokenCountResponse: Sendable, Hashable {
    /// The counted input tokens for the request payload.
    public var inputTokens: Int

    /// The original provider payload.
    public var rawPayload: JSONValue?

    /// Creates a token-counting response.
    public init(inputTokens: Int, rawPayload: JSONValue? = nil) {
        self.inputTokens = inputTokens
        self.rawPayload = rawPayload
    }
}

/// Access to Anthropic file operations.
public struct AnthropicFilesService: Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    init(apiKey: String, baseURL: URL, client: HTTPClient) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    /// Uploads a file to Anthropic's Files API.
    ///
    /// - Parameter request: The file upload request.
    /// - Returns: The uploaded file descriptor.
    /// - Throws: ``KaizoshaError`` when Anthropic rejects the upload or returns an invalid payload.
    public func upload(_ request: AnthropicFileUploadRequest) async throws -> AnthropicFile {
        var multipart = MultipartFormData()
        multipart.addData(name: "file", fileName: request.fileName, mimeType: request.mimeType, data: request.data)

        let payload = try await client.sendJSON(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files"),
                headers: AnthropicRequestHeaders.make(
                    apiKey: apiKey,
                    contentType: multipart.contentType,
                    includeFilesBeta: true
                ),
                body: multipart.data()
            )
        )

        return try AnthropicFileDecoding.file(from: payload)
    }

    /// Retrieves Anthropic metadata for a previously uploaded file.
    ///
    /// - Parameter id: The provider-managed file identifier.
    /// - Returns: The file descriptor.
    /// - Throws: ``KaizoshaError`` when the file cannot be retrieved.
    public func retrieve(_ id: String) async throws -> AnthropicFile {
        let payload = try await client.sendJSON(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files/\(id)"),
                method: .get,
                headers: AnthropicRequestHeaders.make(apiKey: apiKey, contentType: nil, includeFilesBeta: true)
            )
        )

        return try AnthropicFileDecoding.file(from: payload)
    }

    /// Lists uploaded Anthropic files.
    ///
    /// - Parameters:
    ///   - limit: The maximum page size to request.
    ///   - afterID: An optional cursor for forward pagination.
    ///   - beforeID: An optional cursor for reverse pagination.
    /// - Returns: A page of files and the next cursor when Anthropic reports more results.
    /// - Throws: ``KaizoshaError`` when Anthropic returns an invalid payload.
    public func list(
        limit: Int? = nil,
        afterID: String? = nil,
        beforeID: String? = nil
    ) async throws -> AnthropicFilesPage {
        var components = URLComponents(url: baseURL.appendingPathComponents("files"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let afterID {
            queryItems.append(URLQueryItem(name: "after_id", value: afterID))
        }
        if let beforeID {
            queryItems.append(URLQueryItem(name: "before_id", value: beforeID))
        }
        if queryItems.isEmpty == false {
            components.queryItems = queryItems
        }

        let payload = try await client.sendJSON(
            HTTPRequest(
                url: components.url!,
                method: .get,
                headers: AnthropicRequestHeaders.make(apiKey: apiKey, contentType: nil, includeFilesBeta: true)
            )
        )

        guard let object = payload.objectValue, let entries = object["data"]?.arrayValue else {
            throw KaizoshaError.invalidResponse("Anthropic returned an invalid file list payload.")
        }

        return AnthropicFilesPage(
            files: try entries.map(AnthropicFileDecoding.file),
            nextAfterID: object["has_more"]?.boolValue == true ? object["last_id"]?.stringValue : nil
        )
    }

    /// Deletes a previously uploaded Anthropic file.
    ///
    /// - Parameter id: The provider-managed file identifier.
    /// - Throws: ``KaizoshaError`` when Anthropic rejects the deletion request.
    public func delete(_ id: String) async throws {
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files/\(id)"),
                method: .delete,
                headers: AnthropicRequestHeaders.make(apiKey: apiKey, contentType: nil, includeFilesBeta: true)
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }
    }

    /// Downloads the raw content bytes for a file when Anthropic exposes them.
    ///
    /// - Parameter id: The provider-managed file identifier.
    /// - Returns: The raw file bytes.
    /// - Throws: ``KaizoshaError`` when Anthropic rejects the request.
    public func downloadContent(_ id: String) async throws -> Data {
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files/\(id)/content"),
                method: .get,
                headers: AnthropicRequestHeaders.make(apiKey: apiKey, contentType: nil, includeFilesBeta: true)
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        return response.body
    }
}

/// Access to Anthropic token-count operations.
public struct AnthropicTokensService: Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let client: HTTPClient

    init(apiKey: String, baseURL: URL, client: HTTPClient) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.client = client
    }

    /// Counts Anthropic input tokens for a Messages-style request payload.
    ///
    /// - Parameters:
    ///   - modelID: The Anthropic model identifier to validate and count against.
    ///   - request: The provider-neutral request payload to count.
    /// - Returns: The token-count response.
    /// - Throws: ``KaizoshaError`` when Anthropic rejects the request or returns an invalid payload.
    public func countTokens(modelID: String, request: TextGenerationRequest) async throws -> AnthropicTokenCountResponse {
        let payload = try AnthropicMessagePayloadBuilder.countTokensPayload(modelID: modelID, request: request)
        let includeFilesBeta = AnthropicMessagePayloadBuilder.usesFilesBeta(messages: request.messages)

        let responsePayload = try await client.sendJSON(
            HTTPRequest(
                url: baseURL.appendingPathComponents("messages/count_tokens"),
                headers: AnthropicRequestHeaders.make(
                    apiKey: apiKey,
                    includeFilesBeta: includeFilesBeta
                ),
                body: try payload.data()
            )
        )

        guard let inputTokens = ModelCatalogDecoding.intValue(responsePayload.objectValue?["input_tokens"]) else {
            throw KaizoshaError.invalidResponse("Anthropic returned an invalid token count payload.")
        }

        return AnthropicTokenCountResponse(inputTokens: inputTokens, rawPayload: responsePayload)
    }
}

package enum AnthropicFileDecoding {
    package static func file(from value: JSONValue) throws -> AnthropicFile {
        let payload = unwrapFilePayload(value)

        guard let object = payload.objectValue, let id = object["id"]?.stringValue else {
            throw KaizoshaError.invalidResponse("Anthropic returned a file payload without an id.")
        }

        return AnthropicFile(
            id: id,
            fileName: object["filename"]?.stringValue ?? object["file_name"]?.stringValue ?? object["name"]?.stringValue,
            mimeType: object["mime_type"]?.stringValue ?? object["media_type"]?.stringValue,
            sizeBytes: ModelCatalogDecoding.intValue(object["size_bytes"] ?? object["bytes"]),
            createdAt: ModelCatalogDecoding.iso8601Date(object["created_at"]) ?? ModelCatalogDecoding.unixTimestamp(object["created_at"]),
            state: object["state"]?.stringValue,
            downloadable: object["downloadable"]?.boolValue,
            rawPayload: payload
        )
    }

    private static func unwrapFilePayload(_ value: JSONValue) -> JSONValue {
        if let file = value.objectValue?["file"] {
            return file
        }

        return value
    }
}
