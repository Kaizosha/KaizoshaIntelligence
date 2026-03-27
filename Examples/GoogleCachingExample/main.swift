import Foundation
import KaizoshaGoogle

@main
struct KaizoshaGoogleCachingExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()
            let cachedContent = try await provider.cachedContents.create(
                GoogleCachedContent(
                    displayName: "swift-cache",
                    model: "models/gemini-2.5-flash",
                    contents: [
                        GoogleContent(parts: [
                            GoogleContentPart(text: "Swift uses structured concurrency, actors, and Sendable checking."),
                        ]),
                    ],
                    ttl: "3600s"
                )
            )

            let tokenCount = try await provider.tokens.countTokens(
                modelID: "gemini-2.5-flash",
                request: GoogleCountTokensRequest(
                    generateContentRequest: GoogleContentRequest(
                        contents: [
                            GoogleContent(parts: [
                                GoogleContentPart(text: "Summarize the cached context in one sentence."),
                            ]),
                        ],
                        options: GoogleProviderOptions(cachedContent: cachedContent.name)
                    )
                )
            )

            print("Cached content: \(cachedContent.name ?? "<unknown>")")
            print("Total tokens: \(tokenCount.totalTokens ?? 0)")
        } catch {
            writeToStandardError("Google caching example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
