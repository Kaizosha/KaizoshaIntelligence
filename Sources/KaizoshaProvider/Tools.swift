import Foundation

/// Context passed to tool execution closures.
public struct ToolExecutionContext: Sendable {
    /// The model identifier responsible for the tool call.
    public var modelID: String

    /// Arbitrary request metadata carried through the generation call.
    public var metadata: [String: String]

    /// Creates a tool execution context.
    public init(modelID: String, metadata: [String: String] = [:]) {
        self.modelID = modelID
        self.metadata = metadata
    }
}

/// A strongly typed tool declaration.
public struct Tool<Input: Decodable & Sendable, Output: Encodable & Sendable>: Sendable {
    /// The public tool name.
    public var name: String

    /// The tool description shown to the model.
    public var description: String

    /// The input schema used for validation and provider mapping.
    public var inputSchema: Schema<Input>

    private let executor: @Sendable (Input, ToolExecutionContext) async throws -> Output

    /// Creates a tool.
    public init(
        name: String,
        description: String,
        inputSchema: Schema<Input>,
        execute: @escaping @Sendable (Input, ToolExecutionContext) async throws -> Output
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.executor = execute
    }

    /// Converts the tool into a type-erased tool.
    public func eraseToAnyTool() -> AnyTool {
        AnyTool(
            name: name,
            description: description,
            inputSchema: inputSchema.jsonSchema,
            execute: { input, context in
                let data = try input.data()
                let decoded = try JSONDecoder().decode(Input.self, from: data)
                let output = try await executor(decoded, context)
                return try JSONValue.encode(output)
            }
        )
    }
}

/// A type-erased tool declaration.
public struct AnyTool: Sendable {
    /// The public tool name.
    public var name: String

    /// The tool description.
    public var description: String

    /// The input schema in JSON schema form.
    public var inputSchema: JSONValue

    package let executor: @Sendable (JSONValue, ToolExecutionContext) async throws -> JSONValue

    /// Creates a type-erased tool.
    public init(
        name: String,
        description: String,
        inputSchema: JSONValue,
        execute: @escaping @Sendable (JSONValue, ToolExecutionContext) async throws -> JSONValue
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.executor = execute
    }
}

/// A registry of tools available to a generation request.
public struct ToolRegistry: Sendable {
    /// The type-erased tools.
    public var tools: [AnyTool]

    /// Creates a registry from existing type-erased tools.
    public init(_ tools: [AnyTool] = []) {
        self.tools = tools
    }

    /// Creates a registry from strongly typed tools.
    public init<Input, Output>(_ tools: [Tool<Input, Output>]) where Input: Decodable & Sendable, Output: Encodable & Sendable {
        self.tools = tools.map { $0.eraseToAnyTool() }
    }

    /// Returns whether the registry contains any tools.
    public var isEmpty: Bool {
        tools.isEmpty
    }
}

extension ToolRegistry {
    package var byName: [String: AnyTool] {
        Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    package func execute(
        invocations: [ToolInvocation],
        context: ToolExecutionContext
    ) async throws -> [ToolResult] {
        var results: [ToolResult] = []

        for invocation in invocations {
            guard let tool = byName[invocation.name] else {
                throw KaizoshaError.toolExecutionFailure(
                    name: invocation.name,
                    message: "No tool named \(invocation.name) exists in the registry."
                )
            }

            do {
                let output = try await tool.executor(invocation.input, context)
                results.append(
                    ToolResult(
                        invocationID: invocation.id,
                        name: invocation.name,
                        output: output
                    )
                )
            } catch {
                results.append(
                    ToolResult(
                        invocationID: invocation.id,
                        name: invocation.name,
                        output: .object(["error": .string(error.localizedDescription)]),
                        isError: true
                    )
                )
            }
        }

        return results
    }
}
