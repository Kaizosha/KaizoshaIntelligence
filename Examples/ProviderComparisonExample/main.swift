import Foundation
import KaizoshaAnthropic
import KaizoshaGateway
import KaizoshaGoogle
import KaizoshaIntelligence
import KaizoshaOpenAI

@main
struct KaizoshaProviderComparisonExample {
    static func main() {
        let available = [
            "OpenAI via \(OpenAIProvider.namespace)",
            "Anthropic via \(AnthropicProvider.namespace)",
            "Google via \(GoogleProvider.namespace)",
            "Gateway via \(GatewayProvider.namespace)",
        ]
        print(available.joined(separator: "\n"))
    }
}
