import Foundation

/// One action the model decided on: a tool name plus simple string arguments.
struct ToolCall {
    let tool: String
    let args: [String: String]
}

enum ToolError: LocalizedError {
    case missingArgument(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name): return "Missing \(name)."
        }
    }
}

/// A capability the agent can use. The model only picks a tool and fills in a few
/// string arguments; everything else happens in Swift.
@MainActor
protocol AgentTool {
    var name: String { get }
    /// One line shown to the model: what the tool does and its args as JSON.
    var promptLine: String { get }
    /// (user message, exact JSON the model should answer) pairs shown to the model.
    var examples: [(String, String)] { get }
    /// Tools that change something wait for a Confirm tap before running.
    var needsConfirmation: Bool { get }
    /// Short text shown on the action card.
    func summary(for args: [String: String]) -> String
    func run(_ args: [String: String]) async throws -> String
}

/// Reads the model's raw output and extracts the JSON action, if any.
enum AgentParser {
    static func parse(_ raw: String) -> ToolCall? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start < end,
              let data = String(raw[start...end]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = object["tool"] as? String
        else { return nil }
        var args: [String: String] = [:]
        for (key, value) in (object["args"] as? [String: Any]) ?? [:] {
            args[key] = "\(value)"
        }
        return ToolCall(tool: tool, args: args)
    }
}
