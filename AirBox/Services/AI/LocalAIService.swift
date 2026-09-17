import Foundation

final class LocalAIService: AIService {

    let displayName = "Local AI"

    func send(messages: [ChatMessage]) async throws -> String {
        // Имитация задержки модели
        try await Task.sleep(nanoseconds: 700_000_000)

        guard let last = messages.last(where: { $0.role == .user }) else {
            return "Привет! Напиши что-нибудь."
        }

        return makeResponse(for: last.content)
    }

    // MARK: - Private

    private func makeResponse(for input: String) -> String {
        let text = input.lowercased()

        if text.contains("привет") || text.contains("hello") || text.contains("hi") {
            return "Привет! Я AirBox AI. Пока работаю в режиме заглушки — локальная модель будет подключена позже."
        }

        if text.contains("что ты умеешь") || text.contains("помощь") || text.contains("help") {
            return "В будущем я смогу помогать с медиафайлами: описывать видео, добавлять теги к музыке, анализировать документы — всё локально, без интернета."
        }

        if text.contains("версия") || text.contains("version") {
            return "AirBox AI · Этап 1 · Заглушка (stub). Реальная локальная LLM будет добавлена позже."
        }

        return "[\(displayName)] Получил твоё сообщение: «\(input)». Реальный AI-движок появится на следующем этапе разработки."
    }
}