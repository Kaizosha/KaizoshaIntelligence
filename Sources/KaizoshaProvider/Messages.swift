import Foundation

/// A conversation role used by provider-neutral messages.
public enum MessageRole: String, Sendable, Hashable {
    case system
    case user
    case assistant
    case tool
}

/// Binary or remote image content used in multimodal prompts.
public struct ImageContent: Sendable, Hashable {
    /// The inline image data.
    public var data: Data?

    /// The remote URL for the image.
    public var url: URL?

    /// The image MIME type.
    public var mimeType: String

    /// Creates image content from raw bytes.
    public init(data: Data, mimeType: String = "image/png") {
        self.data = data
        self.url = nil
        self.mimeType = mimeType
    }

    /// Creates image content from a remote URL.
    public init(url: URL, mimeType: String = "image/png") {
        self.data = nil
        self.url = url
        self.mimeType = mimeType
    }
}

/// Audio content included in prompts or transcripts.
public struct AudioContent: Sendable, Hashable {
    /// The inline audio data.
    public var data: Data

    /// The audio MIME type.
    public var mimeType: String

    /// Creates audio content from raw bytes.
    public init(data: Data, mimeType: String = "audio/wav") {
        self.data = data
        self.mimeType = mimeType
    }
}

/// File content included in prompts.
public struct FileContent: Sendable, Hashable {
    /// The inline file data when the file is carried in the message payload.
    public var data: Data?

    /// The file name when inline bytes are supplied.
    public var fileName: String?

    /// The file MIME type.
    public var mimeType: String

    /// The provider-managed file identifier when the file is already uploaded.
    public var providerFileID: String?

    /// The provider-managed file URI when the provider requires a reusable URI instead of an ID.
    public var providerFileURI: String?

    /// The provider namespace that owns the uploaded file identifier.
    public var providerNamespace: String?

    /// Creates file content from raw bytes.
    public init(data: Data, fileName: String, mimeType: String = "application/octet-stream") {
        self.init(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            providerFileID: nil,
            providerFileURI: nil,
            providerNamespace: nil
        )
    }

    /// Creates file content from an existing provider-managed file identifier.
    public init(
        providerFileID: String,
        providerNamespace: String,
        providerFileURI: String? = nil,
        fileName: String? = nil,
        mimeType: String = "application/octet-stream"
    ) {
        self.init(
            data: nil,
            fileName: fileName,
            mimeType: mimeType,
            providerFileID: providerFileID,
            providerFileURI: providerFileURI,
            providerNamespace: providerNamespace
        )
    }

    private init(
        data: Data?,
        fileName: String?,
        mimeType: String,
        providerFileID: String?,
        providerFileURI: String?,
        providerNamespace: String?
    ) {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.providerFileID = providerFileID
        self.providerFileURI = providerFileURI
        self.providerNamespace = providerNamespace
    }
}

/// A provider-neutral tool invocation produced by a model.
public struct ToolInvocation: Sendable, Hashable {
    /// The provider-generated invocation identifier.
    public var id: String

    /// The tool name.
    public var name: String

    /// The JSON input passed to the tool.
    public var input: JSONValue

    /// Creates a tool invocation.
    public init(id: String = UUID().uuidString, name: String, input: JSONValue) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// A provider-neutral tool result message.
public struct ToolResult: Sendable, Hashable {
    /// The matching tool invocation identifier.
    public var invocationID: String

    /// The tool name.
    public var name: String

    /// The tool output.
    public var output: JSONValue

    /// Indicates whether the tool result represents an error.
    public var isError: Bool

    /// Creates a tool result.
    public init(invocationID: String, name: String, output: JSONValue, isError: Bool = false) {
        self.invocationID = invocationID
        self.name = name
        self.output = output
        self.isError = isError
    }
}

/// A multimodal message part.
public enum MessagePart: Sendable, Hashable {
    case text(String)
    case image(ImageContent)
    case audio(AudioContent)
    case file(FileContent)
    case toolCall(ToolInvocation)
    case toolResult(ToolResult)
}

/// A provider-neutral conversation message.
public struct Message: Sendable, Hashable {
    /// The message role.
    public var role: MessageRole

    /// The message parts.
    public var parts: [MessagePart]

    /// Creates a message.
    public init(role: MessageRole, parts: [MessagePart]) {
        self.role = role
        self.parts = parts
    }

    /// Creates a text-only system message.
    public static func system(_ text: String) -> Message {
        Message(role: .system, parts: [.text(text)])
    }

    /// Creates a text-only user message.
    public static func user(_ text: String) -> Message {
        Message(role: .user, parts: [.text(text)])
    }

    /// Creates a multimodal user message.
    public static func user(parts: [MessagePart]) -> Message {
        Message(role: .user, parts: parts)
    }

    /// Creates a text-only assistant message.
    public static func assistant(_ text: String) -> Message {
        Message(role: .assistant, parts: [.text(text)])
    }

    /// Creates an assistant message with tool calls.
    public static func assistant(parts: [MessagePart]) -> Message {
        Message(role: .assistant, parts: parts)
    }

    /// Creates a tool result message.
    public static func tool(_ results: [ToolResult]) -> Message {
        Message(role: .tool, parts: results.map(MessagePart.toolResult))
    }

    /// Returns the concatenated text parts for the message.
    public var text: String {
        parts.compactMap {
            guard case .text(let text) = $0 else { return nil }
            return text
        }
        .joined()
    }
}
