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
            let coordinator = URLSessionLineStreamCoordinator(continuation: continuation)
            coordinator.start(with: urlRequest)
            continuation.onTermination = { _ in
                coordinator.cancel()
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

#if os(Linux)
private final class URLSessionLineStreamCoordinator: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()

    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var lineBuffer = StreamingLineBuffer()
    private var errorBody = Data()
    private var statusCode: Int?
    private var isCancelled = false
    private var isFinished = false

    init(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.continuation = continuation
    }

    func start(with request: URLRequest) {
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)

        lock.lock()
        self.session = session
        self.task = task
        lock.unlock()

        task.resume()
    }

    func cancel() {
        let task: URLSessionDataTask?
        let session: URLSession?

        lock.lock()
        isCancelled = true
        task = self.task
        session = self.session
        lock.unlock()

        task?.cancel()
        session?.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        do {
            guard let httpResponse = response as? HTTPURLResponse else {
                throw KaizoshaError.invalidResponse("The server response was not an HTTPURLResponse.")
            }

            lock.lock()
            statusCode = httpResponse.statusCode
            lock.unlock()
            completionHandler(.allow)
        } catch {
            finish(throwing: error)
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let linesToYield: [String]
        let continuation: AsyncThrowingStream<String, Error>.Continuation?

        lock.lock()
        if let statusCode, (200..<300).contains(statusCode) {
            linesToYield = lineBuffer.append(data)
        } else {
            errorBody.append(data)
            linesToYield = []
        }
        continuation = self.continuation
        lock.unlock()

        for line in linesToYield {
            continuation?.yield(line)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if isCancellation(error) {
                finish()
            } else {
                finish(throwing: error)
            }
            return
        }

        let linesToYield: [String]
        let completionError: Error?
        let continuation: AsyncThrowingStream<String, Error>.Continuation?

        lock.lock()
        if let statusCode, (200..<300).contains(statusCode) {
            linesToYield = lineBuffer.finish()
            completionError = nil
        } else if let statusCode {
            linesToYield = []
            completionError = KaizoshaError.httpFailure(
                statusCode: statusCode,
                body: String(decoding: errorBody, as: UTF8.self)
            )
        } else {
            linesToYield = []
            completionError = KaizoshaError.invalidResponse("The transport did not return an HTTP response.")
        }
        continuation = self.continuation
        lock.unlock()

        for line in linesToYield {
            continuation?.yield(line)
        }

        if let completionError {
            finish(throwing: completionError)
        } else {
            finish()
        }
    }

    private func finish(throwing error: Error? = nil) {
        let continuation: AsyncThrowingStream<String, Error>.Continuation?
        let session: URLSession?

        lock.lock()
        guard isFinished == false else {
            lock.unlock()
            return
        }
        isFinished = true
        continuation = self.continuation
        self.continuation = nil
        session = self.session
        self.session = nil
        task = nil
        lock.unlock()

        if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
        session?.finishTasksAndInvalidate()
    }

    private func isCancellation(_ error: Error) -> Bool {
        lock.lock()
        let isCancelled = self.isCancelled
        lock.unlock()

        if isCancelled {
            return true
        }

        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }

        return false
    }
}
#endif

extension HTTPURLResponse {
    fileprivate var headers: [String: String] {
        var mapped: [String: String] = [:]
        for (key, value) in allHeaderFields {
            mapped[String(describing: key)] = String(describing: value)
        }
        return mapped
    }
}
