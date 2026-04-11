import Foundation

// MARK: - MCP Protocol Types

/// MCP JSON-RPC request
public struct MCPRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int?
    public let method: String
    public let params: MCPParams?

    public init(id: Int? = nil, method: String, params: MCPParams? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// MCP JSON-RPC response
public struct MCPResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int?
    public let result: MCPResult?
    public let error: MCPError?

    public init(id: Int?, result: MCPResult? = nil, error: MCPError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

/// MCP parameters (flexible key-value)
public struct MCPParams: Codable, Sendable {
    public let name: String?
    public let arguments: [String: AnyCodable]?

    public init(name: String? = nil, arguments: [String: AnyCodable]? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// MCP result wrapper
public struct MCPResult: Codable, Sendable {
    public let content: [MCPContent]?
    public let tools: [MCPToolDefinition]?

    public init(content: [MCPContent]? = nil, tools: [MCPToolDefinition]? = nil) {
        self.content = content
        self.tools = tools
    }
}

/// MCP content block
public struct MCPContent: Codable, Sendable {
    public let type: String
    public let text: String?

    public init(type: String = "text", text: String? = nil) {
        self.type = type
        self.text = text
    }
}

/// MCP error
public struct MCPError: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

/// MCP tool definition
public struct MCPToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: MCPInputSchema

    public init(name: String, description: String, inputSchema: MCPInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

/// MCP input schema (JSON Schema subset)
public struct MCPInputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: MCPPropertySchema]?
    public let required: [String]?

    public init(type: String = "object", properties: [String: MCPPropertySchema]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// MCP property schema
public struct MCPPropertySchema: Codable, Sendable {
    public let type: String
    public let description: String?
    public let defaultValue: String?

    public init(type: String, description: String? = nil, defaultValue: String? = nil) {
        self.type = type
        self.description = description
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case type, description
        case defaultValue = "default"
    }
}

// MARK: - MCP Transport Protocol

/// Protocol for MCP communication transport
public protocol MCPTransport: Sendable {
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func close() async
}
