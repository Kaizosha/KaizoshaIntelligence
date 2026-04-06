import Foundation
import KaizoshaProvider

/// Provider-specific code-execution artifacts surfaced from an Anthropic response.
public struct AnthropicExecutionArtifacts: Sendable, Hashable {
    /// The reusable code-execution container identifier, when Anthropic returns one.
    public var containerID: String?

    /// Provider-managed file identifiers created during code execution.
    public var generatedFileIDs: [String]

    /// Creates an execution-artifacts value.
    public init(containerID: String? = nil, generatedFileIDs: [String] = []) {
        self.containerID = containerID
        self.generatedFileIDs = generatedFileIDs
    }
}

public extension AnthropicFile {
    /// Converts the uploaded file into a reusable `container_upload` prompt part for Anthropic code execution.
    func asCodeExecutionFileContent() -> FileContent {
        FileContent(
            providerFileID: id,
            providerNamespace: AnthropicProvider.namespace,
            providerFileURI: anthropicContainerUploadReferenceURI,
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream"
        )
    }
}

public extension TextGenerationResponse {
    /// Extracts Anthropic code-execution artifacts from the raw provider payload when available.
    func anthropicExecutionArtifacts() -> AnthropicExecutionArtifacts? {
        AnthropicExecutionArtifactsParser.parse(from: rawPayload)
    }
}

package enum AnthropicExecutionArtifactsParser {
    package static func parse(from rawPayload: JSONValue?) -> AnthropicExecutionArtifacts? {
        guard let rawPayload else { return nil }

        let containerID = rawPayload.objectValue?["container"]?.objectValue?["id"]?.stringValue
            ?? rawPayload.objectValue?["container"]?.stringValue
        let generatedFileIDs = generatedFileIDs(from: rawPayload)

        guard containerID != nil || generatedFileIDs.isEmpty == false else {
            return nil
        }

        return AnthropicExecutionArtifacts(containerID: containerID, generatedFileIDs: generatedFileIDs)
    }

    private static func generatedFileIDs(from payload: JSONValue) -> [String] {
        guard let blocks = payload.objectValue?["content"]?.arrayValue else { return [] }

        var fileIDs: [String] = []
        for block in blocks {
            guard let object = block.objectValue, let type = object["type"]?.stringValue else { continue }
            guard type == "bash_code_execution_tool_result"
                || type == "text_editor_code_execution_tool_result"
                || type == "code_execution_tool_result"
            else {
                continue
            }
            collectFileIDs(from: object["content"], into: &fileIDs)
        }

        return Array(Set(fileIDs)).sorted()
    }

    private static func collectFileIDs(from value: JSONValue?, into fileIDs: inout [String]) {
        guard let value else { return }

        if let object = value.objectValue {
            if let fileID = object["file_id"]?.stringValue {
                fileIDs.append(fileID)
            }
            for nestedValue in object.values {
                collectFileIDs(from: nestedValue, into: &fileIDs)
            }
            return
        }

        if let array = value.arrayValue {
            for nestedValue in array {
                collectFileIDs(from: nestedValue, into: &fileIDs)
            }
        }
    }
}
