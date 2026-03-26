package struct ServerSentEvent: Sendable, Hashable {
    package var event: String?
    package var data: String
    package var id: String?
}

package enum ServerSentEventParser {
    package static func parse(
        lines: AsyncThrowingStream<String, Error>
    ) -> AsyncThrowingStream<ServerSentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var eventName: String?
                    var eventID: String?
                    var dataLines: [String] = []

                    for try await line in lines {
                        if line.isEmpty {
                            if dataLines.isEmpty == false {
                                continuation.yield(
                                    ServerSentEvent(
                                        event: eventName,
                                        data: dataLines.joined(separator: "\n"),
                                        id: eventID
                                    )
                                )
                            }

                            eventName = nil
                            eventID = nil
                            dataLines = []
                            continue
                        }

                        if line.hasPrefix(":") {
                            continue
                        } else if line.hasPrefix("event:") {
                            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("id:") {
                            eventID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        }
                    }

                    if dataLines.isEmpty == false {
                        continuation.yield(
                            ServerSentEvent(
                                event: eventName,
                                data: dataLines.joined(separator: "\n"),
                                id: eventID
                            )
                        )
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
}
