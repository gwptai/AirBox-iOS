import Foundation

// MARK: - Message role

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Chat message model

struct ChatMessage: Identifiable, Codable {
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

// MARK: - Protocol

protocol AIService {
    /// Название движка, отображаемое в UI
    var displayName: String { get }

    /// Принимает историю сообщений, возвращает ответ ассистента
    func send(messages: [ChatMessage]) async throws -> String
}