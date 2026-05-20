import Foundation

/// Builds the prompt string for a model, tuned per task, language, and chat format.
enum PromptBuilder {

    static func build(for request: EngineRequest, format: ChatFormat) -> String {
        let system = systemInstruction(
            task: request.task,
            tone: request.tone,
            language: request.language
        )
        let content = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return wrap(system: system, content: content, format: format)
    }

    // MARK: - System instruction

    private static func systemInstruction(task: TextTask, tone: Tone, language: DetectedLanguage) -> String {
        let languageNote: String
        switch language {
        case .hebrew:
            languageNote = " The text is in Hebrew. Respond in Hebrew and keep the grammar natural."
        case .english:
            languageNote = " The text is in English. Respond in English."
        case .mixed:
            languageNote = " Keep every part of the text in its original language."
        }

        let base: String
        switch task {
        case .proofread:
            base = "You are a meticulous proofreader. Correct spelling, grammar, and punctuation. "
                + "Preserve the original meaning, tone, and wording as much as possible. "
                + "Output only the corrected text — no explanations, quotation marks, or preamble."
        case .punctuate:
            base = "You fix only punctuation, spacing, and capitalization. "
                + "Do not rephrase, translate, or change any words. "
                + "Output only the corrected text — nothing else."
        case .polish:
            base = "You are an expert editor. Rewrite the text so it reads clearly, fluently, and \(tone.rawValue). "
                + "Keep the original meaning and language. "
                + "Output only the rewritten text — no explanations, quotation marks, or preamble."
        case .complete:
            base = "You continue the user's text naturally. "
                + "Write only the text that should come next — do not repeat what the user already wrote. "
                + "Keep the same language, tone, and style, and add at most one or two sentences."
        }
        return base + languageNote
    }

    // MARK: - Chat format

    private static func wrap(system: String, content: String, format: ChatFormat) -> String {
        switch format {
        case .mistral:
            return "[INST] \(system)\n\n\(content) [/INST]"
        case .gemma:
            return "<start_of_turn>user\n\(system)\n\n\(content)<end_of_turn>\n<start_of_turn>model\n"
        case .chatml:
            return "<|im_start|>system\n\(system)<|im_end|>\n"
                + "<|im_start|>user\n\(content)<|im_end|>\n"
                + "<|im_start|>assistant\n"
        case .llama3:
            return "<|start_header_id|>system<|end_header_id|>\n\n\(system)<|eot_id|>"
                + "<|start_header_id|>user<|end_header_id|>\n\n\(content)<|eot_id|>"
                + "<|start_header_id|>assistant<|end_header_id|>\n\n"
        }
    }
}
