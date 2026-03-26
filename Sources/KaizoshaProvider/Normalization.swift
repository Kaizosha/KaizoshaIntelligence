import Foundation

package struct ModelMessage: Sendable, Hashable {
    package var role: MessageRole
    package var parts: [ModelPart]
}

package enum ModelPart: Sendable, Hashable {
    case text(String)
    case image(ImageContent)
    case audio(AudioContent)
    case file(FileContent)
    case toolCall(ToolInvocation)
    case toolResult(ToolResult)
}

package enum MessagePipeline {
    package static func normalize(_ messages: [Message]) -> [ModelMessage] {
        messages.map { message in
            ModelMessage(
                role: message.role,
                parts: message.parts.map { part in
                    switch part {
                    case .text(let text):
                        return .text(text)
                    case .image(let image):
                        return .image(image)
                    case .audio(let audio):
                        return .audio(audio)
                    case .file(let file):
                        return .file(file)
                    case .toolCall(let invocation):
                        return .toolCall(invocation)
                    case .toolResult(let result):
                        return .toolResult(result)
                    }
                }
            )
        }
    }

    package static func text(from message: ModelMessage) -> String {
        message.parts.compactMap {
            guard case .text(let text) = $0 else { return nil }
            return text
        }
        .joined(separator: "\n")
    }

    package static func systemPrompt(from messages: [ModelMessage]) -> String? {
        let system = messages.filter { $0.role == .system }.map(text(from:))
        guard system.isEmpty == false else { return nil }
        return system.joined(separator: "\n\n")
    }
}
