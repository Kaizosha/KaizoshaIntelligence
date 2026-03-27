import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// A Google API status object.
public struct GoogleStatus: Sendable, Hashable, Codable {
    /// The status code.
    public var code: Int?

    /// The status message.
    public var message: String?

    /// Provider-defined details.
    public var details: [JSONValue]

    /// Creates a status object.
    public init(code: Int? = nil, message: String? = nil, details: [JSONValue] = []) {
        self.code = code
        self.message = message
        self.details = details
    }
}

/// A Google model descriptor.
public struct GoogleModelDescriptor: Sendable, Hashable, Codable {
    /// The full provider resource name.
    public var name: String

    /// The short model identifier suitable for the SDK.
    public var id: String

    /// The base model identifier.
    public var baseModelID: String?

    /// The provider version string.
    public var version: String?

    /// The display name.
    public var displayName: String?

    /// The provider description.
    public var description: String?

    /// The input token limit.
    public var inputTokenLimit: Int?

    /// The output token limit.
    public var outputTokenLimit: Int?

    /// Supported generation methods.
    public var supportedGenerationMethods: [String]

    /// The default temperature.
    public var temperature: Double?

    /// The maximum temperature.
    public var maxTemperature: Double?

    /// The default top-p value.
    public var topP: Double?

    /// The default top-k value.
    public var topK: Int?

    /// Whether the model advertises thinking support.
    public var thinking: Bool?

    /// The raw provider payload.
    public var rawMetadata: JSONValue?

    /// Creates a model descriptor.
    public init(
        name: String,
        id: String,
        baseModelID: String? = nil,
        version: String? = nil,
        displayName: String? = nil,
        description: String? = nil,
        inputTokenLimit: Int? = nil,
        outputTokenLimit: Int? = nil,
        supportedGenerationMethods: [String] = [],
        temperature: Double? = nil,
        maxTemperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        thinking: Bool? = nil,
        rawMetadata: JSONValue? = nil
    ) {
        self.name = name
        self.id = id
        self.baseModelID = baseModelID
        self.version = version
        self.displayName = displayName
        self.description = description
        self.inputTokenLimit = inputTokenLimit
        self.outputTokenLimit = outputTokenLimit
        self.supportedGenerationMethods = supportedGenerationMethods
        self.temperature = temperature
        self.maxTemperature = maxTemperature
        self.topP = topP
        self.topK = topK
        self.thinking = thinking
        self.rawMetadata = rawMetadata
    }

    /// Normalizes the descriptor to the provider-neutral catalog shape.
    public var availableModel: AvailableModel {
        AvailableModel(
            id: id,
            providerIdentifier: name,
            provider: GoogleProvider.namespace,
            displayName: displayName,
            contextWindow: inputTokenLimit,
            maxOutputTokens: outputTokenLimit,
            supportedGenerationMethods: supportedGenerationMethods,
            rawMetadata: rawMetadata
        )
    }
}

/// A page of Google model descriptors.
public struct GoogleModelsPage: Sendable, Hashable {
    /// The models returned on the page.
    public var models: [GoogleModelDescriptor]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates a models page.
    public init(models: [GoogleModelDescriptor], nextPageToken: String? = nil) {
        self.models = models
        self.nextPageToken = nextPageToken
    }
}

/// A Google file resource.
public struct GoogleFile: Sendable, Hashable, Codable {
    /// The full provider resource name.
    public var name: String

    /// The display name.
    public var displayName: String?

    /// The MIME type.
    public var mimeType: String?

    /// The byte size.
    public var sizeBytes: String?

    /// The creation time.
    public var createTime: Date?

    /// The update time.
    public var updateTime: Date?

    /// The expiration time.
    public var expirationTime: Date?

    /// The provider file URI.
    public var uri: String?

    /// A download URI when available.
    public var downloadUri: String?

    /// The provider state string.
    public var state: String?

    /// The source string.
    public var source: String?

    /// Any provider-side error.
    public var error: GoogleStatus?

    /// Creates a file resource.
    public init(
        name: String,
        displayName: String? = nil,
        mimeType: String? = nil,
        sizeBytes: String? = nil,
        createTime: Date? = nil,
        updateTime: Date? = nil,
        expirationTime: Date? = nil,
        uri: String? = nil,
        downloadUri: String? = nil,
        state: String? = nil,
        source: String? = nil,
        error: GoogleStatus? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createTime = createTime
        self.updateTime = updateTime
        self.expirationTime = expirationTime
        self.uri = uri
        self.downloadUri = downloadUri
        self.state = state
        self.source = source
        self.error = error
    }

    /// Converts the uploaded file into a reusable provider-managed message part.
    public func asFileContent() throws -> FileContent {
        guard let uri else {
            throw KaizoshaError.invalidResponse("Google file resources must include a reusable `uri` to be converted into a prompt file reference.")
        }

        return FileContent(
            providerFileID: name,
            providerNamespace: GoogleProvider.namespace,
            providerFileURI: uri,
            fileName: displayName,
            mimeType: mimeType ?? "application/octet-stream"
        )
    }
}

/// A page of Google files.
public struct GoogleFilesPage: Sendable, Hashable {
    /// Files returned on the page.
    public var files: [GoogleFile]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates a files page.
    public init(files: [GoogleFile], nextPageToken: String? = nil) {
        self.files = files
        self.nextPageToken = nextPageToken
    }
}

/// A cached-content resource.
public struct GoogleCachedContent: Sendable, Hashable {
    /// The resource name.
    public var name: String?

    /// The display name.
    public var displayName: String?

    /// The target model name.
    public var model: String?

    /// The system instruction.
    public var systemInstruction: GoogleContent?

    /// The cached contents.
    public var contents: [GoogleContent]

    /// The cached tools.
    public var tools: [GoogleToolDefinition]

    /// The tool configuration.
    public var toolConfig: JSONValue?

    /// The TTL duration string.
    public var ttl: String?

    /// The expiration time.
    public var expireTime: Date?

    /// The creation time.
    public var createTime: Date?

    /// The update time.
    public var updateTime: Date?

    /// Creates a cached-content resource.
    public init(
        name: String? = nil,
        displayName: String? = nil,
        model: String? = nil,
        systemInstruction: GoogleContent? = nil,
        contents: [GoogleContent] = [],
        tools: [GoogleToolDefinition] = [],
        toolConfig: JSONValue? = nil,
        ttl: String? = nil,
        expireTime: Date? = nil,
        createTime: Date? = nil,
        updateTime: Date? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.model = model
        self.systemInstruction = systemInstruction
        self.contents = contents
        self.tools = tools
        self.toolConfig = toolConfig
        self.ttl = ttl
        self.expireTime = expireTime
        self.createTime = createTime
        self.updateTime = updateTime
    }
}

/// A page of cached-content resources.
public struct GoogleCachedContentsPage: Sendable, Hashable {
    /// Cached contents returned on the page.
    public var cachedContents: [GoogleCachedContent]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates a page of cached contents.
    public init(cachedContents: [GoogleCachedContent], nextPageToken: String? = nil) {
        self.cachedContents = cachedContents
        self.nextPageToken = nextPageToken
    }
}

/// Custom metadata attached to a file-search-store document.
public struct GoogleCustomMetadata: Sendable, Hashable, Codable {
    /// The metadata key.
    public var key: String

    /// The string value.
    public var stringValue: String

    /// Creates custom metadata.
    public init(key: String, stringValue: String) {
        self.key = key
        self.stringValue = stringValue
    }

    var jsonValue: JSONValue {
        .object([
            "key": .string(key),
            "stringValue": .string(stringValue),
        ])
    }
}

/// Chunking configuration for file-search-store ingestion.
public struct GoogleChunkingConfiguration: Sendable, Hashable, Codable {
    /// The maximum tokens in a chunk.
    public var maxTokensPerChunk: Int

    /// The maximum overlapping tokens between chunks.
    public var maxOverlapTokens: Int

    /// Creates chunking configuration.
    public init(maxTokensPerChunk: Int, maxOverlapTokens: Int) {
        self.maxTokensPerChunk = maxTokensPerChunk
        self.maxOverlapTokens = maxOverlapTokens
    }

    var jsonValue: JSONValue {
        .object([
            "whiteSpaceConfig": .object([
                "maxTokensPerChunk": .number(Double(maxTokensPerChunk)),
                "maxOverlapTokens": .number(Double(maxOverlapTokens)),
            ]),
        ])
    }
}

/// A file-search-store resource.
public struct GoogleFileSearchStore: Sendable, Hashable, Codable {
    /// The resource name.
    public var name: String?

    /// The display name.
    public var displayName: String?

    /// The creation time.
    public var createTime: Date?

    /// The update time.
    public var updateTime: Date?

    /// The active document count.
    public var activeDocumentsCount: String?

    /// The pending document count.
    public var pendingDocumentsCount: String?

    /// The failed document count.
    public var failedDocumentsCount: String?

    /// The total size in bytes.
    public var sizeBytes: String?

    /// Creates a file-search-store resource.
    public init(
        name: String? = nil,
        displayName: String? = nil,
        createTime: Date? = nil,
        updateTime: Date? = nil,
        activeDocumentsCount: String? = nil,
        pendingDocumentsCount: String? = nil,
        failedDocumentsCount: String? = nil,
        sizeBytes: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.createTime = createTime
        self.updateTime = updateTime
        self.activeDocumentsCount = activeDocumentsCount
        self.pendingDocumentsCount = pendingDocumentsCount
        self.failedDocumentsCount = failedDocumentsCount
        self.sizeBytes = sizeBytes
    }
}

/// A page of file-search stores.
public struct GoogleFileSearchStoresPage: Sendable, Hashable {
    /// Stores returned on the page.
    public var stores: [GoogleFileSearchStore]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates a page of file-search stores.
    public init(stores: [GoogleFileSearchStore], nextPageToken: String? = nil) {
        self.stores = stores
        self.nextPageToken = nextPageToken
    }
}

/// A document stored in a file-search store.
public struct GoogleFileSearchDocument: Sendable, Hashable, Codable {
    /// The resource name.
    public var name: String

    /// The display name.
    public var displayName: String?

    /// Custom metadata.
    public var customMetadata: [JSONValue]

    /// The update time.
    public var updateTime: Date?

    /// The creation time.
    public var createTime: Date?

    /// The state string.
    public var state: String?

    /// The size in bytes.
    public var sizeBytes: String?

    /// The MIME type.
    public var mimeType: String?

    /// Creates a document descriptor.
    public init(
        name: String,
        displayName: String? = nil,
        customMetadata: [JSONValue] = [],
        updateTime: Date? = nil,
        createTime: Date? = nil,
        state: String? = nil,
        sizeBytes: String? = nil,
        mimeType: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.customMetadata = customMetadata
        self.updateTime = updateTime
        self.createTime = createTime
        self.state = state
        self.sizeBytes = sizeBytes
        self.mimeType = mimeType
    }
}

/// A page of file-search-store documents.
public struct GoogleFileSearchDocumentsPage: Sendable, Hashable {
    /// Documents returned on the page.
    public var documents: [GoogleFileSearchDocument]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates a documents page.
    public init(documents: [GoogleFileSearchDocument], nextPageToken: String? = nil) {
        self.documents = documents
        self.nextPageToken = nextPageToken
    }
}

/// A generic long-running operation returned by Google.
public struct GoogleOperation: Sendable, Hashable, Codable {
    /// The resource name.
    public var name: String

    /// Whether the operation is complete.
    public var done: Bool?

    /// Provider-defined metadata.
    public var metadata: JSONValue?

    /// Provider-defined response payload.
    public var response: JSONValue?

    /// Provider-defined error metadata.
    public var error: GoogleStatus?

    /// Creates an operation.
    public init(
        name: String,
        done: Bool? = nil,
        metadata: JSONValue? = nil,
        response: JSONValue? = nil,
        error: GoogleStatus? = nil
    ) {
        self.name = name
        self.done = done
        self.metadata = metadata
        self.response = response
        self.error = error
    }
}

/// A page of long-running operations.
public struct GoogleOperationsPage: Sendable, Hashable {
    /// Operations returned on the page.
    public var operations: [GoogleOperation]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates an operations page.
    public init(operations: [GoogleOperation], nextPageToken: String? = nil) {
        self.operations = operations
        self.nextPageToken = nextPageToken
    }
}

/// A generated file entry from Gemini.
public struct GoogleGeneratedFile: Sendable, Hashable, Codable {
    /// The resource name.
    public var name: String

    /// The MIME type.
    public var mimeType: String?

    /// The provider state.
    public var state: String?

    /// The provider error when available.
    public var error: GoogleStatus?

    /// Creates a generated file entry.
    public init(name: String, mimeType: String? = nil, state: String? = nil, error: GoogleStatus? = nil) {
        self.name = name
        self.mimeType = mimeType
        self.state = state
        self.error = error
    }
}

/// A page of generated files.
public struct GoogleGeneratedFilesPage: Sendable, Hashable {
    /// Generated files returned on the page.
    public var generatedFiles: [GoogleGeneratedFile]

    /// The next page token.
    public var nextPageToken: String?

    /// Creates a generated-files page.
    public init(generatedFiles: [GoogleGeneratedFile], nextPageToken: String? = nil) {
        self.generatedFiles = generatedFiles
        self.nextPageToken = nextPageToken
    }
}

/// A content-generation batch configuration.
public struct GoogleGenerateContentBatch: Sendable, Hashable {
    /// The raw batch payload.
    public var payload: JSONValue

    /// Creates a content batch from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }
}

/// An embedding batch configuration.
public struct GoogleEmbedContentBatch: Sendable, Hashable {
    /// The raw batch payload.
    public var payload: JSONValue

    /// Creates an embedding batch from a raw payload.
    public init(payload: JSONValue) {
        self.payload = payload
    }
}

/// A synchronous batch embedding request item.
public struct GoogleBatchEmbeddingRequest: Sendable, Hashable {
    /// The text content to embed.
    public var text: String

    /// Creates a batch embedding item.
    public init(text: String) {
        self.text = text
    }

    var jsonValue: JSONValue {
        .object([
            "model": .string(""),
            "content": .object([
                "parts": .array([
                    .object(["text": .string(text)]),
                ]),
            ]),
        ])
    }
}

/// Access to Google model catalog methods.
public struct GoogleModelsService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Lists a page of models.
    public func list(pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleModelsPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("models", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        guard let object = payload.objectValue else {
            throw KaizoshaError.invalidResponse("Google returned an invalid model list payload.")
        }

        let models = try (object["models"]?.arrayValue ?? []).map(Self.mapModelDescriptor)
        await configuration.catalog.store(models.map(\.availableModel))
        return GoogleModelsPage(models: models, nextPageToken: object["nextPageToken"]?.stringValue)
    }

    /// Lists all models across every page.
    public func listAll() async throws -> [AvailableModel] {
        var all: [AvailableModel] = []
        var pageToken: String?

        repeat {
            let page = try await list(pageToken: pageToken)
            all.append(contentsOf: page.models.map(\.availableModel))
            pageToken = page.nextPageToken
        } while pageToken != nil

        return all
    }

    /// Retrieves a single model descriptor.
    public func get(_ idOrName: String) async throws -> GoogleModelDescriptor {
        let name = idOrName.hasPrefix("models/") ? idOrName : "models/\(idOrName)"
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let model = try Self.mapModelDescriptor(payload)
        await configuration.catalog.store(model.availableModel)
        return model
    }

    private static func mapModelDescriptor(_ value: JSONValue) throws -> GoogleModelDescriptor {
        guard let object = value.objectValue, let name = object["name"]?.stringValue else {
            throw KaizoshaError.invalidResponse("Google returned a model entry without a name.")
        }

        let id = object["baseModelId"]?.stringValue ?? name.replacingOccurrences(of: "models/", with: "")

        return GoogleModelDescriptor(
            name: name,
            id: id,
            baseModelID: object["baseModelId"]?.stringValue,
            version: object["version"]?.stringValue,
            displayName: object["displayName"]?.stringValue,
            description: object["description"]?.stringValue,
            inputTokenLimit: ModelCatalogDecoding.intValue(object["inputTokenLimit"]),
            outputTokenLimit: ModelCatalogDecoding.intValue(object["outputTokenLimit"]),
            supportedGenerationMethods: ModelCatalogDecoding.stringArray(object["supportedGenerationMethods"]),
            temperature: object["temperature"]?.numberValue,
            maxTemperature: object["maxTemperature"]?.numberValue,
            topP: object["topP"]?.numberValue,
            topK: ModelCatalogDecoding.intValue(object["topK"]),
            thinking: object["thinking"]?.boolValue,
            rawMetadata: value
        )
    }
}

/// Access to Google token-counting methods.
public struct GoogleTokensService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Counts tokens for a Gemini model.
    public func countTokens(modelID: String, request: GoogleCountTokensRequest) async throws -> GoogleTokenCountResponse {
        try await GoogleContentModel(id: modelID, configuration: configuration).countTokens(request)
    }
}

/// Access to Google file resources.
public struct GoogleFilesService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Uploads a file and returns the created Google file resource.
    public func upload(
        data: Data,
        fileName: String,
        mimeType: String,
        displayName: String? = nil
    ) async throws -> GoogleFile {
        let metadata = JSONValue.object([
            "file": .object([
                "displayName": .string(displayName ?? fileName),
                "mimeType": .string(mimeType),
            ]),
        ])

        let start = try await configuration.client.send(
            HTTPRequest(
                url: configuration.stableUploadURL("upload/v1beta/files"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging([
                    "Content-Type": "application/json",
                    "X-Goog-Upload-Protocol": "resumable",
                    "X-Goog-Upload-Command": "start",
                    "X-Goog-Upload-Header-Content-Length": String(data.count),
                    "X-Goog-Upload-Header-Content-Type": mimeType,
                ]) { $1 },
                body: try metadata.data()
            )
        )

        guard (200..<300).contains(start.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: start.statusCode,
                body: String(data: start.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        guard let uploadURL = start.headers["X-Goog-Upload-URL"].flatMap(URL.init(string:)) else {
            throw KaizoshaError.invalidResponse("Google did not return an upload URL for the resumable file upload.")
        }

        let finalize = try await configuration.client.send(
            HTTPRequest(
                url: uploadURL,
                method: .post,
                headers: [
                    "X-Goog-Upload-Offset": "0",
                    "X-Goog-Upload-Command": "upload, finalize",
                    "Content-Length": String(data.count),
                ],
                body: data
            )
        )

        guard (200..<300).contains(finalize.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: finalize.statusCode,
                body: String(data: finalize.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let payload = try JSONValue.decode(finalize.body)
        guard let file = payload.objectValue?["file"] else {
            throw KaizoshaError.invalidResponse("Google returned an invalid file-upload payload.")
        }
        return try JSONDecoder().decode(GoogleFile.self, from: file.data())
    }

    /// Registers existing cloud-hosted files.
    public func register(uris: [String]) async throws -> [GoogleFile] {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("files:register"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try JSONValue.object([
                    "uris": .array(uris.map(JSONValue.string)),
                ]).data()
            )
        )

        return try (payload.objectValue?["files"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleFile.self, from: $0.data())
        }
    }

    /// Retrieves a file resource.
    public func get(_ name: String) async throws -> GoogleFile {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try JSONDecoder().decode(GoogleFile.self, from: payload.data())
    }

    /// Lists a page of file resources.
    public func list(pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleFilesPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("files", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let files = try (payload.objectValue?["files"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleFile.self, from: $0.data())
        }
        return GoogleFilesPage(files: files, nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue)
    }

    /// Deletes a file resource.
    public func delete(_ name: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .delete,
                headers: configuration.apiKeyHeaders
            )
        )
    }
}

/// Access to Google generated-file resources.
public struct GoogleGeneratedFilesService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Lists a page of generated files.
    public func list(pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleGeneratedFilesPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("generatedFiles", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let generatedFiles = try (payload.objectValue?["generatedFiles"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleGeneratedFile.self, from: $0.data())
        }
        return GoogleGeneratedFilesPage(
            generatedFiles: generatedFiles,
            nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue
        )
    }

    /// Retrieves a generated-file operation.
    public func getOperation(_ name: String) async throws -> GoogleOperation {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }
}

/// Access to Google cached-content resources.
public struct GoogleCachedContentsService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Creates cached content.
    public func create(_ request: GoogleCachedContent) async throws -> GoogleCachedContent {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("cachedContents"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try GoogleCachedContentsService.encode(request).data()
            )
        )
        return try GoogleCachedContentsService.decode(payload)
    }

    /// Retrieves cached content.
    public func get(_ name: String) async throws -> GoogleCachedContent {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try GoogleCachedContentsService.decode(payload)
    }

    /// Lists cached contents.
    public func list(pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleCachedContentsPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("cachedContents", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let cachedContents = try (payload.objectValue?["cachedContents"]?.arrayValue ?? []).map {
            try GoogleCachedContentsService.decode($0)
        }

        return GoogleCachedContentsPage(
            cachedContents: cachedContents,
            nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue
        )
    }

    /// Patches cached content.
    public func patch(_ request: GoogleCachedContent) async throws -> GoogleCachedContent {
        guard let name = request.name else {
            throw KaizoshaError.invalidRequest("Google cached-content patch requests require a `name`.")
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .patch,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try GoogleCachedContentsService.encode(request).data()
            )
        )
        return try GoogleCachedContentsService.decode(payload)
    }

    /// Deletes cached content.
    public func delete(_ name: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .delete,
                headers: configuration.apiKeyHeaders
            )
        )
    }

    private static func encode(_ request: GoogleCachedContent) throws -> JSONValue {
        var object: [String: JSONValue] = [:]
        if let name = request.name {
            object["name"] = .string(name)
        }
        if let displayName = request.displayName {
            object["displayName"] = .string(displayName)
        }
        if let model = request.model {
            object["model"] = .string(model)
        }
        if let systemInstruction = request.systemInstruction {
            object["systemInstruction"] = try JSONValue.encode(systemInstruction)
        }
        if request.contents.isEmpty == false {
            object["contents"] = .array(try request.contents.map { try JSONValue.encode($0) })
        }
        if request.tools.isEmpty == false {
            object["tools"] = .array(request.tools.map(\.payload))
        }
        if let toolConfig = request.toolConfig {
            object["toolConfig"] = toolConfig
        }
        if let ttl = request.ttl {
            object["ttl"] = .string(ttl)
        }
        if let expireTime = request.expireTime {
            object["expireTime"] = .string(GoogleEncoding.iso8601(expireTime))
        }
        return .object(object)
    }

    private static func decode(_ value: JSONValue) throws -> GoogleCachedContent {
        guard let object = value.objectValue else {
            throw KaizoshaError.invalidResponse("Google returned an invalid cached-content payload.")
        }

        let contents = try (object["contents"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleContent.self, from: $0.data())
        }
        let tools = (object["tools"]?.arrayValue ?? []).map { GoogleToolDefinition(payload: $0) }

        return GoogleCachedContent(
            name: object["name"]?.stringValue,
            displayName: object["displayName"]?.stringValue,
            model: object["model"]?.stringValue,
            systemInstruction: object["systemInstruction"].flatMap {
                try? JSONDecoder().decode(GoogleContent.self, from: $0.data())
            },
            contents: contents,
            tools: tools,
            toolConfig: object["toolConfig"],
            ttl: object["ttl"]?.stringValue,
            expireTime: ModelCatalogDecoding.iso8601Date(object["expireTime"]),
            createTime: ModelCatalogDecoding.iso8601Date(object["createTime"]),
            updateTime: ModelCatalogDecoding.iso8601Date(object["updateTime"])
        )
    }
}

/// Access to Google file-search-store resources.
public struct GoogleFileSearchStoresService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Creates a file-search store.
    public func create(_ request: GoogleFileSearchStore) async throws -> GoogleFileSearchStore {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("fileSearchStores"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try JSONValue.object([
                    "displayName": request.displayName.map(JSONValue.string) ?? .null,
                ]).data()
            )
        )
        return try JSONDecoder().decode(GoogleFileSearchStore.self, from: payload.data())
    }

    /// Retrieves a file-search store.
    public func get(_ name: String) async throws -> GoogleFileSearchStore {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try JSONDecoder().decode(GoogleFileSearchStore.self, from: payload.data())
    }

    /// Lists file-search stores.
    public func list(pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleFileSearchStoresPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("fileSearchStores", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let stores = try (payload.objectValue?["fileSearchStores"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleFileSearchStore.self, from: $0.data())
        }
        return GoogleFileSearchStoresPage(stores: stores, nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue)
    }

    /// Deletes a file-search store.
    public func delete(_ name: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .delete,
                headers: configuration.apiKeyHeaders
            )
        )
    }

    /// Imports an existing uploaded file into a file-search store.
    public func importFile(
        fileSearchStoreName: String,
        fileName: String,
        customMetadata: [GoogleCustomMetadata] = [],
        chunkingConfig: GoogleChunkingConfiguration? = nil
    ) async throws -> GoogleOperation {
        var object: [String: JSONValue] = [
            "fileName": .string(fileName),
        ]
        if customMetadata.isEmpty == false {
            object["customMetadata"] = .array(customMetadata.map(\.jsonValue))
        }
        if let chunkingConfig {
            object["chunkingConfig"] = chunkingConfig.jsonValue
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("\(fileSearchStoreName):importFile"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try JSONValue.object(object).data()
            )
        )
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }

    /// Uploads a file directly into a file-search store.
    public func upload(
        fileSearchStoreName: String,
        data: Data,
        fileName: String,
        mimeType: String,
        displayName: String? = nil,
        customMetadata: [GoogleCustomMetadata] = [],
        chunkingConfig: GoogleChunkingConfiguration? = nil
    ) async throws -> GoogleOperation {
        var metadata: [String: JSONValue] = [
            "displayName": .string(displayName ?? fileName),
            "mimeType": .string(mimeType),
        ]
        if customMetadata.isEmpty == false {
            metadata["customMetadata"] = .array(customMetadata.map(\.jsonValue))
        }
        if let chunkingConfig {
            metadata["chunkingConfig"] = chunkingConfig.jsonValue
        }

        let start = try await configuration.client.send(
            HTTPRequest(
                url: configuration.stableUploadURL("upload/v1beta/\(fileSearchStoreName):uploadToFileSearchStore"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging([
                    "Content-Type": "application/json",
                    "X-Goog-Upload-Protocol": "resumable",
                    "X-Goog-Upload-Command": "start",
                    "X-Goog-Upload-Header-Content-Length": String(data.count),
                    "X-Goog-Upload-Header-Content-Type": mimeType,
                ]) { $1 },
                body: try JSONValue.object(metadata).data()
            )
        )

        guard (200..<300).contains(start.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: start.statusCode,
                body: String(data: start.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        guard let uploadURL = start.headers["X-Goog-Upload-URL"].flatMap(URL.init(string:)) else {
            throw KaizoshaError.invalidResponse("Google did not return an upload URL for the file-search-store upload.")
        }

        let finalize = try await configuration.client.send(
            HTTPRequest(
                url: uploadURL,
                method: .post,
                headers: [
                    "X-Goog-Upload-Offset": "0",
                    "X-Goog-Upload-Command": "upload, finalize",
                    "Content-Length": String(data.count),
                ],
                body: data
            )
        )

        guard (200..<300).contains(finalize.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: finalize.statusCode,
                body: String(data: finalize.body, encoding: .utf8) ?? "<non-utf8 body>"
            )
        }

        let payload = try JSONValue.decode(finalize.body)
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }

    /// Lists documents in a file-search store.
    public func listDocuments(parent: String, pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleFileSearchDocumentsPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("\(parent)/documents", queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let documents = try (payload.objectValue?["documents"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleFileSearchDocument.self, from: $0.data())
        }
        return GoogleFileSearchDocumentsPage(
            documents: documents,
            nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue
        )
    }

    /// Retrieves a file-search-store document.
    public func getDocument(_ name: String) async throws -> GoogleFileSearchDocument {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try JSONDecoder().decode(GoogleFileSearchDocument.self, from: payload.data())
    }

    /// Deletes a file-search-store document.
    public func deleteDocument(_ name: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .delete,
                headers: configuration.apiKeyHeaders
            )
        )
    }

    /// Retrieves a file-search-store operation.
    public func getOperation(_ name: String) async throws -> GoogleOperation {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }
}

/// Access to Google batch-generation and batch-embedding methods.
public struct GoogleBatchesService: Sendable {
    private let configuration: GoogleServiceConfiguration

    init(configuration: GoogleServiceConfiguration) {
        self.configuration = configuration
    }

    /// Performs a synchronous batch embedding request.
    public func batchEmbedContents(modelID: String, requests: [GoogleBatchEmbeddingRequest]) async throws -> EmbeddingResponse {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("models/\(modelID):batchEmbedContents"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try JSONValue.object([
                    "requests": .array(
                        requests.map { request in
                            .object([
                                "model": .string("models/\(modelID)"),
                                "content": .object([
                                    "parts": .array([
                                        .object(["text": .string(request.text)]),
                                    ]),
                                ]),
                            ])
                        }
                    ),
                ]).data()
            )
        )

        let embeddings = payload.objectValue?["embeddings"]?.arrayValue?.compactMap { value -> [Double]? in
            value.objectValue?["values"]?.arrayValue?.compactMap(\.numberValue)
        } ?? []

        return EmbeddingResponse(modelID: modelID, embeddings: embeddings, usage: nil)
    }

    /// Creates a long-running content-generation batch.
    public func createGenerateContentBatch(modelID: String, batch: GoogleGenerateContentBatch) async throws -> GoogleOperation {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("models/\(modelID):batchGenerateContent"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try JSONValue.object(["batch": batch.payload]).data()
            )
        )
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }

    /// Creates a long-running embedding batch.
    public func createEmbedContentBatch(modelID: String, batch: GoogleEmbedContentBatch) async throws -> GoogleOperation {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("models/\(modelID):asyncBatchEmbedContent"),
                method: .post,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try JSONValue.object(["batch": batch.payload]).data()
            )
        )
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }

    /// Retrieves a batch operation or batch resource.
    public func get(_ name: String) async throws -> GoogleOperation {
        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )
        return try JSONDecoder().decode(GoogleOperation.self, from: payload.data())
    }

    /// Lists batch operations under a parent resource name.
    public func list(parent: String, pageSize: Int? = nil, pageToken: String? = nil) async throws -> GoogleOperationsPage {
        var queryItems: [URLQueryItem] = []
        if let pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let payload = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(parent, queryItems: queryItems),
                method: .get,
                headers: configuration.apiKeyHeaders
            )
        )

        let operations = try (payload.objectValue?["operations"]?.arrayValue ?? []).map {
            try JSONDecoder().decode(GoogleOperation.self, from: $0.data())
        }
        return GoogleOperationsPage(operations: operations, nextPageToken: payload.objectValue?["nextPageToken"]?.stringValue)
    }

    /// Cancels a batch operation.
    public func cancel(_ name: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("\(name):cancel"),
                method: .post,
                headers: configuration.apiKeyHeaders
            )
        )
    }

    /// Deletes a batch operation.
    public func delete(_ name: String) async throws {
        _ = try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL(name),
                method: .delete,
                headers: configuration.apiKeyHeaders
            )
        )
    }

    /// Updates a content-generation batch resource.
    public func updateGenerateContentBatch(name: String, batch: GoogleGenerateContentBatch) async throws -> JSONValue {
        try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("\(name):updateGenerateContentBatch"),
                method: .patch,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try batch.payload.data()
            )
        )
    }

    /// Updates an embedding batch resource.
    public func updateEmbedContentBatch(name: String, batch: GoogleEmbedContentBatch) async throws -> JSONValue {
        try await configuration.client.sendJSON(
            HTTPRequest(
                url: configuration.stableURL("\(name):updateEmbedContentBatch"),
                method: .patch,
                headers: configuration.apiKeyHeaders.merging(["Content-Type": "application/json"]) { $1 },
                body: try batch.payload.data()
            )
        )
    }
}
