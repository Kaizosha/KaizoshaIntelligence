import Foundation
import KaizoshaGoogle

@main
struct KaizoshaGoogleFileSearchExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()
            let store = try await provider.fileSearchStores.create(
                GoogleFileSearchStore(displayName: "swift-search-store")
            )

            let uploaded = try await provider.files.upload(
                data: Data("Swift packages can vend multiple library products.".utf8),
                fileName: "swift-sdk.txt",
                mimeType: "text/plain"
            )

            let operation = try await provider.fileSearchStores.importFile(
                fileSearchStoreName: store.name ?? "fileSearchStores/swift-search-store",
                fileName: uploaded.name,
                chunkingConfig: GoogleChunkingConfiguration(maxTokensPerChunk: 256, maxOverlapTokens: 32)
            )

            print(operation.name)
        } catch {
            writeToStandardError("Google file search example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
