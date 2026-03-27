# Google Built-In Tools

Gemini built-in tools are exposed explicitly in `KaizoshaGoogle` through ``GoogleTools`` for `generateContent`, and through ``GoogleInteractionTool`` for the Interactions API.

## Generate Content Tools

```swift
var providerOptions = ProviderOptions()
providerOptions.setGoogle(
    GoogleProviderOptions(
        builtInTools: [
            GoogleTools.googleSearch(),
            GoogleTools.urlContext(),
            GoogleTools.googleMaps(enableWidget: true)
        ]
    )
)
```

Built-in helpers currently include:

- ``GoogleTools/googleSearch(timeRange:searchTypes:)``
- ``GoogleTools/urlContext()``
- ``GoogleTools/googleMaps(enableWidget:)``
- ``GoogleTools/codeExecution()``
- ``GoogleTools/computerUse(environment:excludedPredefinedFunctions:)``
- ``GoogleTools/fileSearchStore(names:topK:metadataFilter:)``

## Tool Configuration

Use ``GoogleToolConfiguration`` to control function-calling behavior and retrieval hints.

```swift
let toolConfiguration = GoogleToolConfiguration(
    functionCalling: GoogleFunctionCallingConfiguration(
        mode: .auto,
        allowedFunctionNames: ["lookup_weather"]
    )
)
```

## Grounding Metadata

Raw grounding metadata is surfaced on ``GoogleContentCandidate/groundingMetadata`` for callers who need provider-specific provenance or search details.
