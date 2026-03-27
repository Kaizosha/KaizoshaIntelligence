import Foundation
import KaizoshaGoogle
import KaizoshaProvider

@main
struct KaizoshaGoogleBatchExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()

            let embeddings = try await provider.batches.batchEmbedContents(
                modelID: "text-embedding-004",
                requests: [
                    GoogleBatchEmbeddingRequest(text: "Swift"),
                    GoogleBatchEmbeddingRequest(text: "Concurrency"),
                ]
            )
            print("Embedding batch size: \(embeddings.embeddings.count)")

            let batch = GoogleGenerateContentBatch(
                payload: .object([
                    "model": .string("models/gemini-2.5-flash"),
                    "displayName": .string("swift-batch"),
                    "inputConfig": .object([
                        "requests": .object([
                            "requests": .array([
                                .object([
                                    "request": .object([
                                        "contents": .array([
                                            .object([
                                                "parts": .array([
                                                    .object(["text": .string("Explain Swift actors in one sentence.")]),
                                                ]),
                                            ]),
                                        ]),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ])
            )

            let operation = try await provider.batches.createGenerateContentBatch(
                modelID: "gemini-2.5-flash",
                batch: batch
            )

            print("Batch operation: \(operation.name)")
        } catch {
            writeToStandardError("Google batch example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
