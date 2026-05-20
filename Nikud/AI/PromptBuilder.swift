import Foundation

/// Builds the prompt string for a model, tuned per task, language, and chat format.
///
/// When the text is Hebrew, the instructions themselves are written in Hebrew —
/// Hebrew-native models follow Hebrew instructions far more reliably and never
/// drift into English.
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
        switch language {
        case .hebrew:
            return hebrewInstruction(task: task, tone: tone)
        case .english:
            return englishInstruction(task: task, tone: tone)
                + " The text is in English; respond in English."
        case .mixed:
            return englishInstruction(task: task, tone: tone)
                + " The text mixes Hebrew and English. Keep every word in its"
                + " original language and never translate."
        }
    }

    private static func hebrewInstruction(task: TextTask, tone: Tone) -> String {
        switch task {
        case .proofread:
            return "אתה מגיה מקצועי ודקדקן. תקן שגיאות כתיב, דקדוק ופיסוק בטקסט. "
                + "שמור ככל האפשר על המשמעות, הסגנון והניסוח המקוריים. "
                + "החזר אך ורק את הטקסט המתוקן בעברית — בלי הסברים, בלי מירכאות ובלי הקדמה."
        case .punctuate:
            return "תקן אך ורק פיסוק ורווחים בטקסט. אל תשנה מילים, אל תתרגם ואל תנסח מחדש. "
                + "החזר אך ורק את הטקסט המתוקן בעברית."
        case .polish:
            return "אתה עורך לשון מקצועי. נסח מחדש את הטקסט \(tone.styleHE). "
                + "שמור על המשמעות ועל השפה העברית. "
                + "החזר אך ורק את הטקסט המנוסח — בלי הסברים, בלי מירכאות ובלי הקדמה."
        case .complete:
            return "השלם את הטקסט באופן טבעי. כתוב אך ורק את ההמשך בעברית — "
                + "אל תחזור על מה שכבר נכתב. שמור על אותה נימה וסגנון, "
                + "והוסף משפט אחד או שניים לכל היותר."
        }
    }

    private static func englishInstruction(task: TextTask, tone: Tone) -> String {
        switch task {
        case .proofread:
            return "You are a meticulous proofreader. Correct spelling, grammar, and"
                + " punctuation. Preserve the original meaning, tone, and wording as"
                + " much as possible. Output only the corrected text — no explanations,"
                + " quotation marks, or preamble."
        case .punctuate:
            return "You fix only punctuation, spacing, and capitalization. Do not"
                + " rephrase, translate, or change any words. Output only the corrected"
                + " text — nothing else."
        case .polish:
            return "You are an expert editor. Rewrite the text \(tone.styleEN)."
                + " Keep the original meaning. Output only the rewritten text —"
                + " no explanations, quotation marks, or preamble."
        case .complete:
            return "You continue the user's text naturally. Write only the text that"
                + " should come next — do not repeat what the user already wrote. Keep"
                + " the same tone and style, and add at most one or two sentences."
        }
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
