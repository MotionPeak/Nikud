import Foundation
import llama

/// A thread-safe flag shared with a running generation so it can be stopped.
final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }
}

/// A `TextEngine` backed by a local GGUF model running on llama.cpp with Metal.
final class LlamaEngine: TextEngine {

    let displayName: String
    var usesModel: Bool { true }

    private let model: OpaquePointer
    private let vocab: OpaquePointer
    private let context: OpaquePointer
    private let chatFormat: ChatFormat
    private let contextLength: Int32 = 4096
    private let queue = DispatchQueue(label: "com.shaharsolomons.Nikud.inference", qos: .userInitiated)

    /// Initializes the llama.cpp backend exactly once per process.
    private static let backend: Void = {
        llama_backend_init()
        llama_log_set({ _, _, _ in }, nil)
    }()

    init(modelPath: String, chatFormat: ChatFormat, displayName: String) throws {
        _ = LlamaEngine.backend
        self.displayName = displayName
        self.chatFormat = chatFormat

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 999

        guard let loadedModel = llama_model_load_from_file(modelPath, modelParams) else {
            throw EngineError.modelLoadFailed("the model file could not be read")
        }
        guard let modelVocab = llama_model_get_vocab(loadedModel) else {
            llama_model_free(loadedModel)
            throw EngineError.modelLoadFailed("the model has no vocabulary")
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(contextLength)
        contextParams.n_batch = 512
        contextParams.n_ubatch = 512

        guard let createdContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            throw EngineError.modelLoadFailed("the inference context could not be created")
        }

        self.model = loadedModel
        self.vocab = modelVocab
        self.context = createdContext
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    func run(_ request: EngineRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let cancellation = CancellationToken()
            continuation.onTermination = { _ in cancellation.cancel() }
            // `self` is captured strongly so the engine outlives the generation.
            queue.async {
                do {
                    let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { throw EngineError.emptyInput }
                    try self.generate(request, cancellation: cancellation) { piece in
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Generation

    private func generate(
        _ request: EngineRequest,
        cancellation: CancellationToken,
        emit: (String) -> Void
    ) throws {
        llama_memory_clear(llama_get_memory(context), true)

        let prompt = PromptBuilder.build(for: request, format: chatFormat)
        var promptTokens = try tokenize(prompt, addSpecial: true)

        let maxPromptTokens = Int(contextLength) - 64
        if promptTokens.count > maxPromptTokens {
            promptTokens = Array(promptTokens.suffix(maxPromptTokens))
        }
        try decode(promptTokens)

        let sampler = makeSampler(creativity: request.creativity)
        defer { llama_sampler_free(sampler) }

        let budget = maxNewTokens(for: request.task)
        var pending: [UInt8] = []
        var produced = 0

        while produced < budget {
            if cancellation.isCancelled { throw CancellationError() }

            let next = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, next) { break }

            pending.append(contentsOf: pieceBytes(for: next))
            let ready = drainUTF8(&pending)
            if !ready.isEmpty { emit(ready) }

            produced += 1
            try decode([next])
        }

        if !pending.isEmpty {
            emit(String(decoding: pending, as: UTF8.self))
        }
    }

    // MARK: - llama.cpp helpers

    private func tokenize(_ text: String, addSpecial: Bool) throws -> [llama_token] {
        let byteCount = Int32(text.utf8.count)
        var capacity = Int(byteCount) + 8
        var tokens = [llama_token](repeating: 0, count: capacity)
        var count = text.withCString { pointer in
            llama_tokenize(vocab, pointer, byteCount, &tokens, Int32(capacity), addSpecial, true)
        }
        if count < 0 {
            capacity = Int(-count)
            tokens = [llama_token](repeating: 0, count: capacity)
            count = text.withCString { pointer in
                llama_tokenize(vocab, pointer, byteCount, &tokens, Int32(capacity), addSpecial, true)
            }
        }
        guard count >= 0 else {
            throw EngineError.generationFailed("the text could not be tokenized")
        }
        return Array(tokens.prefix(Int(count)))
    }

    private func decode(_ tokens: [llama_token]) throws {
        guard !tokens.isEmpty else { return }
        var buffer = tokens
        let chunkSize = 512
        var offset = 0
        while offset < buffer.count {
            let length = min(chunkSize, buffer.count - offset)
            let status = buffer.withUnsafeMutableBufferPointer { pointer -> Int32 in
                llama_decode(context, llama_batch_get_one(pointer.baseAddress! + offset, Int32(length)))
            }
            guard status == 0 else {
                throw EngineError.generationFailed("the model could not process the text (code \(status))")
            }
            offset += length
        }
    }

    private func pieceBytes(for token: llama_token) -> [UInt8] {
        var buffer = [CChar](repeating: 0, count: 256)
        var count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        guard count > 0 else { return [] }
        return buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
    }

    /// Emits the longest valid UTF-8 prefix, keeping incomplete trailing bytes
    /// so multi-byte characters (e.g. Hebrew) are never split mid-stream.
    private func drainUTF8(_ pending: inout [UInt8]) -> String {
        guard !pending.isEmpty else { return "" }
        for trim in 0...min(3, pending.count) {
            let keep = pending.count - trim
            if keep == 0 { break }
            if let text = String(bytes: pending[0..<keep], encoding: .utf8) {
                pending.removeFirst(keep)
                return text
            }
        }
        return ""
    }

    private func makeSampler(creativity: Double) -> UnsafeMutablePointer<llama_sampler> {
        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        llama_sampler_chain_add(chain, llama_sampler_init_penalties(64, 1.1, 0.0, 0.0))
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.95, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_min_p(0.05, 1))
        let temperature = Float(0.1 + max(0, min(creativity, 1)) * 0.7)
        llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.max))
        return chain
    }

    private func maxNewTokens(for task: TextTask) -> Int {
        switch task {
        case .complete:  return 110
        case .punctuate: return 700
        case .proofread: return 700
        case .polish:    return 800
        }
    }
}
