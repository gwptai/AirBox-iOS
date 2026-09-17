import Foundation
import LlamaSwift

enum LocalAIError: LocalizedError {
    case modelNotInstalled(URL)
    case modelLoadFailed
    case contextLoadFailed
    case promptTooLarge
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled(let url): return "Локальная модель не установлена: \(url.lastPathComponent)"
        case .modelLoadFailed: return "Не удалось загрузить локальную GGUF-модель."
        case .contextLoadFailed: return "Не удалось создать контекст локальной модели."
        case .promptTooLarge: return "История чата слишком большая для текущего контекста."
        case .generationFailed: return "Локальная модель не смогла сгенерировать ответ."
        }
    }
}

struct LocalModelStore: Sendable {
    let configuration: LocalAIConfiguration

    init(configuration: LocalAIConfiguration = .default) { self.configuration = configuration }

    var modelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)
    }

    var modelURL: URL { modelsDirectory.appendingPathComponent(configuration.modelFileName) }

    func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func isInstalled() -> Bool { FileManager.default.fileExists(atPath: modelURL.path) }
}

actor LocalLlamaEngine {
    private let configuration: LocalAIConfiguration
    private var model: OpaquePointer?
    private var vocab: OpaquePointer?
    private var backendInitialized = false

    init(configuration: LocalAIConfiguration) { self.configuration = configuration }

    deinit {
        if let model { llama_model_free(model) }
        if backendInitialized { llama_backend_free() }
    }

    func generate(prompt: String) throws -> String {
        try loadModelIfNeeded()
        guard let model, let vocab else { throw LocalAIError.modelLoadFailed }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = configuration.contextSize
        contextParams.n_batch = min(configuration.contextSize, 512)

        let cpuCount = ProcessInfo.processInfo.processorCount
        let threads = max(2, min(6, cpuCount - 2))
        contextParams.n_threads = UInt32(threads)
        contextParams.n_threads_batch = UInt32(threads)

        guard let context = llama_init_from_model(model, contextParams) else {
            throw LocalAIError.contextLoadFailed
        }
        defer { llama_free(context) }

        let promptTokens = tokenize(prompt, vocab: vocab)
        guard !promptTokens.isEmpty else { throw LocalAIError.promptTooLarge }

        let contextSize = Int(llama_n_ctx(context))
        let maxNewTokens = min(configuration.maxOutputTokens, max(0, contextSize - promptTokens.count - 1))
        guard maxNewTokens > 0 else { throw LocalAIError.promptTooLarge }

        var batch = llama_batch_init(UInt32(max(promptTokens.count, 1)), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(promptTokens.count)
        for index in promptTokens.indices {
            batch.token[index] = promptTokens[index]
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            if let seqIDs = batch.seq_id, let seqID = seqIDs[index] { seqID[0] = 0 }
            batch.logits[index] = 0
        }
        batch.logits[promptTokens.count - 1] = 1

        guard llama_decode(context, batch) == 0 else { throw LocalAIError.generationFailed }

        var output = ""
        var currentPosition = Int32(promptTokens.count)

        for _ in 0..<maxNewTokens {
            guard let logits = llama_get_logits_ith(context, batch.n_tokens - 1) else {
                throw LocalAIError.generationFailed
            }

            let vocabularySize = Int(llama_vocab_n_tokens(vocab))
            guard vocabularySize > 0 else { throw LocalAIError.generationFailed }

            var bestLogit = logits[0]
            var nextToken: llama_token = 0
            if vocabularySize > 1 {
                for tokenID in 1..<vocabularySize where logits[tokenID] > bestLogit {
                    bestLogit = logits[tokenID]
                    nextToken = llama_token(tokenID)
                }
            }

            if nextToken == llama_vocab_eos(vocab) { break }

            var pieceBuffer = [CChar](repeating: 0, count: 256)
            let pieceLength = llama_token_to_piece(vocab, nextToken, &pieceBuffer, Int32(pieceBuffer.count), 0, false)
            if pieceLength > 0 {
                let bytes = pieceBuffer.prefix(Int(pieceLength)).map { UInt8(bitPattern: $0) }
                if let piece = String(bytes: bytes, encoding: .utf8) { output += piece }
            }

            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = currentPosition
            batch.n_seq_id[0] = 1
            if let seqIDs = batch.seq_id, let seqID = seqIDs[0] { seqID[0] = 0 }
            batch.logits[0] = 1

            guard llama_decode(context, batch) == 0 else { throw LocalAIError.generationFailed }
            currentPosition += 1
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadModelIfNeeded() throws {
        guard model == nil else { return }

        let store = LocalModelStore(configuration: configuration)
        try store.ensureDirectory()
        guard store.isInstalled() else { throw LocalAIError.modelNotInstalled(store.modelURL) }

        llama_backend_init()
        backendInitialized = true

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99

        guard let loadedModel = llama_model_load_from_file(store.modelURL.path, modelParams) else {
            llama_backend_free()
            backendInitialized = false
            throw LocalAIError.modelLoadFailed
        }

        model = loadedModel
        vocab = llama_model_get_vocab(loadedModel)
    }

    private func tokenize(_ text: String, vocab: OpaquePointer) -> [llama_token] {
        let utf8Count = text.utf8.count
        let capacity = max(8, utf8Count + 1)
        var tokens = [llama_token](repeating: 0, count: capacity)
        let count = llama_tokenize(vocab, text, Int32(utf8Count), &tokens, Int32(capacity), true, true)
        guard count > 0 else { return [] }
        return Array(tokens.prefix(Int(count)))
    }
}

final class LocalAIService: AIService, @unchecked Sendable {
    let displayName = "AirBox Local AI"
    private let engine: LocalLlamaEngine

    init(configuration: LocalAIConfiguration = .default) {
        self.engine = LocalLlamaEngine(configuration: configuration)
    }

    func send(messages: [ChatMessage]) async throws -> String {
        try await engine.generate(prompt: makePrompt(messages))
    }

    private func makePrompt(_ messages: [ChatMessage]) -> String {
        var prompt = """
        <|system|>
        Ты AirBox AI — локальный ассистент внутри iPhone-приложения AirBox. Отвечай кратко, полезно и на языке пользователя. Интернет недоступен и не требуется.
        <|end|>
        """

        for message in messages {
            switch message.role {
            case .system: prompt += "\n<|system|>\n\(message.content)\n<|end|>"
            case .user: prompt += "\n<|user|>\n\(message.content)\n<|end|>"
            case .assistant: prompt += "\n<|assistant|>\n\(message.content)\n<|end|>"
            }
        }
        prompt += "\n<|assistant|>\n"
        return prompt
    }
}
