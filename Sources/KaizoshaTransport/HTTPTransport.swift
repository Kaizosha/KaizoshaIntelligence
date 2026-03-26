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
#if os(Linux)
        let (data, response) = try await executeDataTask(for: urlRequest)
#else
        let (data, response) = try await session.data(for: urlRequest)
#endif
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
#if os(Linux)
            let dataTask = session.dataTask(with: urlRequest) { data, response, error in
                do {
                    if let error {
                        throw error
                    }

                    guard let data, let response else {
                        throw KaizoshaError.invalidResponse("The transport did not return data.")
                    }

                    let httpResponse = try self.validatedHTTPResponse(from: response)

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        let body = String(decoding: data, as: UTF8.self)
                        throw KaizoshaError.httpFailure(statusCode: httpResponse.statusCode, body: body)
                    }

                    for line in self.bufferedLines(from: data) {
                        continuation.yield(line)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            dataTask.resume()
            continuation.onTermination = { _ in
                dataTask.cancel()
            }
#else
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    let httpResponse = try validatedHTTPResponse(from: response)

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
#endif
        }
    }

    private func executeDataTask(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(
                        throwing: KaizoshaError.invalidResponse("The transport did not return data.")
                    )
                    return
                }

                continuation.resume(returning: (data, response))
            }

            task.resume()
        }
    }

    private func validatedHTTPResponse(from response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KaizoshaError.invalidResponse("The server response was not an HTTPURLResponse.")
        }

        return httpResponse
    }

    private func bufferedLines(from data: Data) -> [String] {
        String(decoding: data, as: UTF8.self)
            .components(separatedBy: .newlines)
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
