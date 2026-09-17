import Foundation
import LlamaSwift

private func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

// MARK: - Errors

enum LocalAIError: LocalizedError {
    case modelNotInstalled(URL)
    case modelLoadFailed
    case contextLoadFailed
    case promptTooLarge
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled(let url):
            return "Локальная модель не установлена: \(url.lastPathComponent)"
        case .modelLoadFailed:
            return "Не удалось загрузить локальную GGUF-модель."
        case .contextLoadFailed:
            return "Не удалось создать контекст локальной модели."
        case .promptTooLarge:
            return "История чата слишком большая для текущего контекста."
        case .generationFailed:
            return "Локальная модель не смогла сгенерировать ответ."
        }
    }
}

// MARK: - Model storage

struct LocalModelStore: Sendable {
    let configuration: LocalAIConfiguration

    init(configuration: LocalAIConfiguration = .default) {
        self.configuration = configuration
    }

    var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Models", isDirectory: true)
    }

    var modelURL: URL {
        modelsDirectory.appendingPathComponent(configuration.modelFileName)
    }

    func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: modelURL.path)
    }
}

// MARK: - llama.cpp engine

actor LocalLlamaEngine {
    private let configuration: LocalAIConfiguration
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private var backendInitialized = false

    init(configuration: LocalAIConfiguration) {
        self.configuration = configuration
    }

    deinit {
        if let sampler { llama_sampler_free(sampler) }
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
        if backendInitialized { llama_backend_free() }
    }

    func generate(prompt: String) throws -> String {
        try loadIfNeeded()

        guard let model, let context, let vocab, let sampler else {
            throw LocalAIError.modelLoadFailed
        }

        _ = model
        let promptTokens = tokenize(prompt, vocab: vocab, addBOS: true)
        guard !promptTokens.isEmpty else {
            throw LocalAIError.promptTooLarge
        }

        let contextSize = Int(llama_n_ctx(context))
        let maxNewTokens = min(configuration.maxOutputTokens, max(1, contextSize - promptTokens.count - 1))
        guard maxNewTokens > 0 else {
            throw LocalAIError.promptTooLarge
        }

        var batch = llama_batch_init(UInt32(max(promptTokens.count, 1)), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(promptTokens.count)
        for (index, token) in promptTokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]?[0] = 0
            batch.logits[index] = 0
        }
        batch.logits[promptTokens.count - 1] = 1

        guard llama_decode(context, batch) == 0 else {
            throw LocalAIError.generationFailed
        }

        var output = ""
        var nCurrent = Int32(promptTokens.count)
        var utf8Buffer: [CChar] = []

        for _ in 0..<maxNewTokens {
            let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)

            if llama_vocab_is_eog(vocab, token) {
                break
            }

            if let piece = tokenToString(token, vocab: vocab, buffer: &utf8Buffer) {
                output += piece
            }

            llama_batch_clear(&batch)
            batch.token[0] = token
            batch.pos[0] = nCurrent
            batch.n_seq_id[0] = 1
            batch.seq_id[0]?[0] = 0
            batch.logits[0] = 1
            batch.n_tokens = 1

            guard llama_decode(context, batch) == 0 else {
                throw LocalAIError.generationFailed
            }

            nCurrent += 1
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadIfNeeded() throws {
        guard model == nil else { return }

        let store = LocalModelStore(configuration: configuration)
        guard store.isInstalled() else {
            throw LocalAIError.modelNotInstalled(store.modelURL)
        }

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

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = configuration.contextSize
        contextParams.n_batch = min(configuration.contextSize, 512)

        let cpuCount = ProcessInfo.processInfo.processorCount
        let threads = max(2, min(6, cpuCount - 2))
        contextParams.n_threads = Int32(threads)
        contextParams.n_threads_batch = Int32(threads)

        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            model = nil
            llama_backend_free()
            backendInitialized = false
            throw LocalAIError.contextLoadFailed
        }

        context = loadedContext

        var samplerParams = llama_sampler_chain_default_params()
        samplerParams.no_perf = true
        guard let chain = llama_sampler_chain_init(samplerParams) else {
            throw LocalAIError.generationFailed
        }
        sampler = chain

        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(configuration.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(configuration.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
    }

    private func tokenize(_ text: String, vocab: OpaquePointer, addBOS: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let capacity = utf8Count + (addBOS ? 1 : 0) + 8
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: capacity)
        defer { tokens.deallocate() }

        let count = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            tokens,
            Int32(capacity),
            addBOS,
            false
        )

        guard count > 0 else { return [] }
        return (0..<Int(count)).map { tokens[$0] }
    }

    private func tokenToString(
        _ token: llama_token,
        vocab: OpaquePointer,
        buffer: inout [CChar]
    ) -> String? {
        var result = [CChar](repeating: 0, count: 8)
        let count = llama_token_to_piece(vocab, token, &result, Int32(result.count), 0, false)

        if count < 0 {
            result = [CChar](repeating: 0, count: Int(-count))
            let actual = llama_token_to_piece(vocab, token, &result, Int32(result.count), 0, false)
            result = Array(result.prefix(Int(actual)))
        } else {
            result = Array(result.prefix(Int(count)))
        }

        buffer.append(contentsOf: result)
        guard let text = String(data: Data(buffer.map { UInt8(bitPattern: $0) }), encoding: .utf8) else {
            return nil
        }
        buffer.removeAll(keepingCapacity: true)
        return text
    }
}

// MARK: - Local AI service

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
            case .system:
                prompt += "\n<|system|>\n\(message.content)\n<|end|>"
            case .user:
                prompt += "\n<|user|>\n\(message.content)\n<|end|>"
            case .assistant:
                prompt += "\n<|assistant|>\n\(message.content)\n<|end|>"
            }
        }

        prompt += "\n<|assistant|>\n"
        return prompt
    }
}
