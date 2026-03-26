import Foundation
import KaizoshaProvider

/// Retry behavior shared across provider transports.
public struct RetryPolicy: Sendable, Hashable {
    /// The maximum number of attempts.
    public var maxAttempts: Int

    /// The fixed backoff delay between attempts.
    public var backoff: Duration

    /// The HTTP status codes that should be retried.
    public var retryStatusCodes: Set<Int>

    /// Creates a retry policy.
    public init(
        maxAttempts: Int = 2,
        backoff: Duration = .seconds(1),
        retryStatusCodes: Set<Int> = [408, 409, 425, 429, 500, 502, 503, 504]
    ) {
        self.maxAttempts = maxAttempts
        self.backoff = backoff
        self.retryStatusCodes = retryStatusCodes
    }

    /// The default retry policy.
    public static let `default` = RetryPolicy()
}

package struct HTTPLogEntry: Sendable {
    package var request: HTTPRequest
    package var statusCode: Int?
    package var errorDescription: String?
}

package typealias HTTPLogger = @Sendable (HTTPLogEntry) -> Void

package actor HTTPClient {
    private let transport: any HTTPTransport
    private let retryPolicy: RetryPolicy
    private let logger: HTTPLogger?

    package init(
        transport: (any HTTPTransport)? = nil,
        retryPolicy: RetryPolicy = .default,
        logger: HTTPLogger? = nil
    ) {
        self.transport = transport ?? URLSessionHTTPTransport()
        self.retryPolicy = retryPolicy
        self.logger = logger
    }

    package func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var attempt = 0
        var lastError: Error?

        while attempt < max(1, retryPolicy.maxAttempts) {
            attempt += 1

            do {
                let response = try await transport.execute(request)

                if retryPolicy.retryStatusCodes.contains(response.statusCode),
                   attempt < retryPolicy.maxAttempts {
                    logger?(HTTPLogEntry(request: request, statusCode: response.statusCode, errorDescription: nil))
                    try await Task.sleep(for: retryPolicy.backoff)
                    continue
                }

                logger?(HTTPLogEntry(request: request, statusCode: response.statusCode, errorDescription: nil))
                return response
            } catch {
                lastError = error
                logger?(HTTPLogEntry(request: request, statusCode: nil, errorDescription: error.localizedDescription))

                if attempt < retryPolicy.maxAttempts {
                    try await Task.sleep(for: retryPolicy.backoff)
                }
            }
        }

        throw lastError ?? KaizoshaError.invalidResponse("The transport did not return a response.")
    }

    package func sendJSON(_ request: HTTPRequest) async throws -> JSONValue {
        let response = try await send(request)
        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: response.body, encoding: .utf8) ?? "<non-utf8 body>"
            throw KaizoshaError.httpFailure(statusCode: response.statusCode, body: body)
        }
        return try JSONValue.decode(response.body)
    }

    package func streamEvents(_ request: HTTPRequest) -> AsyncThrowingStream<ServerSentEvent, Error> {
        ServerSentEventParser.parse(lines: transport.streamLines(request))
    }
}

package final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Result<HTTPResponse, Error>] = []
    private var streams: [Result<[String], Error>] = []

    package init() {}

    package func enqueue(response: HTTPResponse) {
        lock.lock()
        responses.append(.success(response))
        lock.unlock()
    }

    package func enqueue(error: Error) {
        lock.lock()
        responses.append(.failure(error))
        lock.unlock()
    }

    package func enqueue(stream: [String]) {
        lock.lock()
        streams.append(.success(stream))
        lock.unlock()
    }

    package func enqueue(streamError: Error) {
        lock.lock()
        streams.append(.failure(streamError))
        lock.unlock()
    }

    package func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        try dequeueResponse(for: request).get()
    }

    package func streamLines(_ request: HTTPRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard self.hasQueuedStream else {
                        throw KaizoshaError.invalidResponse("No queued HTTP stream exists for \(request.url.absoluteString).")
                    }

                    let result = self.dequeueStream()
                    for line in try result.get() {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private var hasQueuedStream: Bool {
        lock.lock()
        defer { lock.unlock() }
        return streams.isEmpty == false
    }

    private func dequeueResponse(for request: HTTPRequest) throws -> Result<HTTPResponse, Error> {
        lock.lock()
        defer { lock.unlock() }

        guard responses.isEmpty == false else {
            throw KaizoshaError.invalidResponse("No queued HTTP response exists for \(request.url.absoluteString).")
        }
        return responses.removeFirst()
    }

    private func dequeueStream() -> Result<[String], Error> {
        lock.lock()
        defer { lock.unlock() }
        return streams.removeFirst()
    }
}
