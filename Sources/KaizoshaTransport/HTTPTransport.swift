import Foundation
import KaizoshaProvider
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The HTTP method used for transport requests.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A transport request shared by provider adapters.
public struct HTTPRequest: Sendable {
    /// The target URL.
    public var url: URL

    /// The HTTP method.
    public var method: HTTPMethod

    /// HTTP headers.
    public var headers: [String: String]

    /// Optional request body.
    public var body: Data?

    /// Optional timeout in seconds.
    public var timeoutInterval: TimeInterval?

    /// Creates a transport request.
    public init(
        url: URL,
        method: HTTPMethod = .post,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval? = 60
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
}

/// A transport response shared by provider adapters.
public struct HTTPResponse: Sendable {
    /// The response status code.
    public var statusCode: Int

    /// Response headers.
    public var headers: [String: String]

    /// Raw response body bytes.
    public var body: Data

    /// Creates a transport response.
    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

/// A low-level HTTP transport contract.
public protocol HTTPTransport: Sendable {
    /// Executes a request and returns the full response.
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse

    /// Streams the response as newline-delimited strings.
    func streamLines(_ request: HTTPRequest) -> AsyncThrowingStream<String, Error>
}

/// A URLSession-backed HTTP transport.
public final class URLSessionHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    /// Creates a transport backed by URLSession.
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.session = URLSession(configuration: configuration)
    }

    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = buildURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KaizoshaError.invalidResponse("The server response was not an HTTPURLResponse.")
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: httpResponse.headers,
            body: data
        )
    }

    public func streamLines(_ request: HTTPRequest) -> AsyncThrowingStream<String, Error> {
        let urlRequest = buildURLRequest(from: request)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw KaizoshaError.invalidResponse("The server response was not an HTTPURLResponse.")
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                        }
                        throw KaizoshaError.httpFailure(statusCode: httpResponse.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        continuation.yield(line)
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

    private func buildURLRequest(from request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeoutInterval ?? 60

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return urlRequest
    }
}

extension HTTPURLResponse {
    fileprivate var headers: [String: String] {
        var mapped: [String: String] = [:]
        for (key, value) in allHeaderFields {
            mapped[String(describing: key)] = String(describing: value)
        }
        return mapped
    }
}
