import SwiftUI

/// Prompt-formatting style a model expects.
enum ChatFormat: String, Hashable {
    case mistral
    case gemma
    case chatml
    case llama3
}

/// How well a model handles Hebrew, for display in the catalog.
enum HebrewTier: Hashable {
    case excellent
    case good
    case basic

    var label: String {
        switch self {
        case .excellent: return "Excellent Hebrew"
        case .good:      return "Good Hebrew"
        case .basic:     return "Basic Hebrew"
        }
    }

    var tint: Color {
        switch self {
        case .excellent: return .green
        case .good:      return Theme.accent
        case .basic:     return .secondary
        }
    }
}

/// Rough speed/footprint class of a model.
enum SpeedTier: Hashable {
    case fast
    case balanced
    case heavy

    var label: String {
        switch self {
        case .fast:     return "Fast"
        case .balanced: return "Balanced"
        case .heavy:    return "Heavy"
        }
    }

    var systemImage: String {
        switch self {
        case .fast:     return "bolt.fill"
        case .balanced: return "speedometer"
        case .heavy:    return "cpu"
        }
    }
}

/// A downloadable model and everything Nikud needs to fetch and run it.
struct CatalogModel: Identifiable, Hashable {
    let id: String
    let name: String
    let developer: String
    let summary: String
    let detail: String
    let parameters: String
    let sizeBytes: Int64
    let minRAMGB: Int
    let fileName: String
    let downloadURL: URL
    let chatFormat: ChatFormat
    let hebrewTier: HebrewTier
    let speedTier: SpeedTier
    let isRecommended: Bool
    let tags: [String]

    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// The curated set of models offered for download, Hebrew-first.
enum ModelCatalog {
    static let all: [CatalogModel] = [
        CatalogModel(
            id: "dictalm2.0-instruct",
            name: "DictaLM 2.0",
            developer: "Dicta",
            summary: "Hebrew-first 7B model, tuned for natural Hebrew and English.",
            detail: "Built by Dicta on Mistral 7B and trained heavily on Hebrew. The best balance of Hebrew quality and speed for everyday proofreading and writing.",
            parameters: "7B",
            sizeBytes: 4_374_991_808,
            minRAMGB: 8,
            fileName: "dictalm2.0-instruct.Q4_K_M.gguf",
            downloadURL: URL(string: "https://huggingface.co/dicta-il/dictalm2.0-instruct-GGUF/resolve/main/dictalm2.0-instruct.Q4_K_M.gguf")!,
            chatFormat: .mistral,
            hebrewTier: .excellent,
            speedTier: .balanced,
            isRecommended: true,
            tags: ["Hebrew", "English"]
        ),
        CatalogModel(
            id: "dictalm3.0-nemotron-12b",
            name: "DictaLM 3.0",
            developer: "Dicta",
            summary: "Dicta's latest and strongest Hebrew model.",
            detail: "A 12B model with the best Hebrew understanding in the catalog. It needs more memory and runs slower than DictaLM 2.0, but produces the most fluent Hebrew.",
            parameters: "12B",
            sizeBytes: 7_494_495_200,
            minRAMGB: 16,
            fileName: "DictaLM-3.0-Nemotron-12B-Instruct.Q4_K_M.gguf",
            downloadURL: URL(string: "https://huggingface.co/dicta-il/DictaLM-3.0-Nemotron-12B-Instruct-GGUF/resolve/main/DictaLM-3.0-Nemotron-12B-Instruct-Q4_K_M.gguf")!,
            chatFormat: .chatml,
            hebrewTier: .excellent,
            speedTier: .heavy,
            isRecommended: false,
            tags: ["Hebrew", "English", "Best quality"]
        ),
        CatalogModel(
            id: "gemma-2-9b-it",
            name: "Gemma 2 9B",
            developer: "Google",
            summary: "Google's capable multilingual model.",
            detail: "Strong general writing across many languages, including Hebrew. A good all-rounder if you also write in languages beyond Hebrew and English.",
            parameters: "9B",
            sizeBytes: 5_761_057_728,
            minRAMGB: 12,
            fileName: "gemma-2-9b-it.Q4_K_M.gguf",
            downloadURL: URL(string: "https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf")!,
            chatFormat: .gemma,
            hebrewTier: .good,
            speedTier: .balanced,
            isRecommended: false,
            tags: ["Multilingual"]
        ),
        CatalogModel(
            id: "qwen2.5-7b-instruct",
            name: "Qwen 2.5 7B",
            developer: "Alibaba",
            summary: "Fast, well-rounded multilingual model.",
            detail: "A 7B model with solid multilingual writing. A lighter alternative to Gemma 2 9B when you want quicker results.",
            parameters: "7B",
            sizeBytes: 4_683_074_240,
            minRAMGB: 8,
            fileName: "Qwen2.5-7B-Instruct.Q4_K_M.gguf",
            downloadURL: URL(string: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf")!,
            chatFormat: .chatml,
            hebrewTier: .good,
            speedTier: .balanced,
            isRecommended: false,
            tags: ["Multilingual"]
        ),
        CatalogModel(
            id: "gemma-2-2b-it",
            name: "Gemma 2 2B",
            developer: "Google",
            summary: "Small and fast — runs comfortably on any Mac.",
            detail: "A 2B model for quick sentence completion and light proofreading. Hebrew is basic; use a DictaLM model for serious Hebrew work.",
            parameters: "2B",
            sizeBytes: 1_708_582_752,
            minRAMGB: 4,
            fileName: "gemma-2-2b-it.Q4_K_M.gguf",
            downloadURL: URL(string: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")!,
            chatFormat: .gemma,
            hebrewTier: .basic,
            speedTier: .fast,
            isRecommended: false,
            tags: ["Fast", "Lightweight"]
        )
    ]

    static func model(withID id: String) -> CatalogModel? {
        all.first { $0.id == id }
    }

    static var recommended: CatalogModel {
        all.first { $0.isRecommended } ?? all[0]
    }
}
