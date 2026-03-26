import Foundation

/// Errors thrown by Kaizosha Intelligence components.
public enum KaizoshaError: Error, Sendable {
    case missingAPIKey(namespace: String)
    case invalidRequest(String)
    case invalidResponse(String)
    case unsupportedCapability(modelID: String, capability: String)
    case httpFailure(statusCode: Int, body: String)
    case decodingFailure(String)
    case toolExecutionFailure(name: String, message: String)
}

extension KaizoshaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let namespace):
            return "Missing API key for \(namespace)."
        case .invalidRequest(let message):
            return message
        case .invalidResponse(let message):
            return message
        case .unsupportedCapability(let modelID, let capability):
            return "The model \(modelID) does not support \(capability)."
        case .httpFailure(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .decodingFailure(let message):
            return message
        case .toolExecutionFailure(let name, let message):
            return "Tool \(name) failed: \(message)"
        }
    }
}
