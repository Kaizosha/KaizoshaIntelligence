import Foundation
import KaizoshaProvider
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A websocket request shared by provider adapters.
public struct WebSocketRequest: Sendable {
    /// The websocket URL.
    public var url: URL

    /// Connection headers.
    public var headers: [String: String]

    /// Creates a websocket request.
    public init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }
}

/// A low-level websocket connection contract.
public protocol WebSocketConnection: Sendable {
    /// Sends a UTF-8 text frame.
    func send(text: String) async throws

    /// Receives a UTF-8 text frame.
    func receiveText() async throws -> String

    /// Closes the connection.
    func close() async
}

/// A low-level websocket transport contract.
public protocol WebSocketTransport: Sendable {
    /// Opens a websocket connection.
    func connect(_ request: WebSocketRequest) async throws -> any WebSocketConnection
}

/// A URLSession-backed websocket transport.
public final class URLSessionWebSocketTransport: WebSocketTransport, @unchecked Sendable {
    private let session: URLSession

    /// Creates a websocket transport backed by URLSession.
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.session = URLSession(configuration: configuration)
    }

    public func connect(_ request: WebSocketRequest) async throws -> any WebSocketConnection {
        var urlRequest = URLRequest(url: request.url)
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.webSocketTask(with: urlRequest)
        task.resume()
        return URLSessionWebSocketConnection(task: task)
    }
}

private actor URLSessionWebSocketConnection: WebSocketConnection {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func send(text: String) async throws {
        try await task.send(.string(text))
    }

    func receiveText() async throws -> String {
        switch try await task.receive() {
        case .string(let text):
            return text
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw KaizoshaError.invalidResponse("The websocket returned non-UTF8 data.")
            }
            return text
        @unknown default:
            throw KaizoshaError.invalidResponse("The websocket returned an unsupported message type.")
        }
    }

    func close() async {
        task.cancel(with: .goingAway, reason: nil)
    }
}

package actor MockWebSocketConnection: WebSocketConnection {
    package private(set) var sentTexts: [String] = []
    private var queuedTexts: [Result<String, Error>] = []

    package init() {}

    package func enqueue(text: String) {
        queuedTexts.append(.success(text))
    }

    package func enqueue(error: Error) {
        queuedTexts.append(.failure(error))
    }

    package func send(text: String) async throws {
        sentTexts.append(text)
    }

    package func receiveText() async throws -> String {
        guard queuedTexts.isEmpty == false else {
            throw KaizoshaError.invalidResponse("No queued websocket message is available.")
        }
        return try queuedTexts.removeFirst().get()
    }

    package func close() async {}
}

package actor MockWebSocketTransport: WebSocketTransport {
    package let connection: MockWebSocketConnection
    package private(set) var requests: [WebSocketRequest] = []

    package init(connection: MockWebSocketConnection = MockWebSocketConnection()) {
        self.connection = connection
    }

    package func connect(_ request: WebSocketRequest) async throws -> any WebSocketConnection {
        requests.append(request)
        return connection
    }
}
