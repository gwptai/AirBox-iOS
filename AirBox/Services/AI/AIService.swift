import Foundation

// MARK: - Message role

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Chat message model

struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Local model configuration

struct LocalAIConfiguration: Sendable {
    /// GGUF model file name stored in Application Support/Models.
    var modelFileName: String = "airbox-3b-q4_k_m.gguf"

    /// Initial context. The engine can lower this on memory-constrained devices.
    var contextSize: UInt32 = 4096

    /// Maximum number of generated tokens for one request.
    var maxOutputTokens: Int = 512

    var temperature: Float = 0.7
    var topP: Float = 0.9

    static let `default` = LocalAIConfiguration()
}

// MARK: - Protocol

protocol AIService: Sendable {
    var displayName: String { get }
    func send(messages: [ChatMessage]) async throws -> String
}
