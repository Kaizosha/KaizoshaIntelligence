# Swift App Example

```swift
import KaizoshaIntelligence
import KaizoshaOpenAI
import Observation

@Observable
final class ChatViewModel {
    var transcript = ""

    func send(_ prompt: String) async throws {
        let provider = try OpenAIProvider()
        let response = try await generateText(
            prompt: prompt,
            using: provider.languageModel("gpt-4o-mini")
        )
        transcript = response.text
    }
}
```
