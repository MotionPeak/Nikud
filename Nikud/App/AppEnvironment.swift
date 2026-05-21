import SwiftUI
import Combine

/// Root application state, shared across every scene.
@MainActor
final class AppEnvironment: ObservableObject {

    enum EngineStatus: Equatable {
        case builtin
        case loadingModel(String)
        case modelReady(String)
        case modelFailed(String)
    }

    let preferences: Preferences
    let models: ModelManager
    let catalog = ModelCatalog.all
    private(set) lazy var quickAssist = QuickAssist(environment: self)
    private(set) lazy var systemAutocomplete = SystemAutocomplete(environment: self)

    /// The engine currently used for all requests.
    @Published private(set) var engine: any TextEngine
    @Published private(set) var engineStatus: EngineStatus = .builtin

    /// The settings tab to show when the settings window opens.
    @Published var settingsTab: SettingsTab = .general

    private var cancellables = Set<AnyCancellable>()

    init() {
        preferences = Preferences()
        models = ModelManager()
        engine = HeuristicEngine()
        quickAssist.start()
        systemAutocomplete.sync()

        // Bubble nested changes up so views observing AppEnvironment refresh.
        preferences.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        models.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if let model = activeModel, models.installedURL(for: model) != nil {
            loadActiveModel()
        }
    }

    /// The catalog entry the user has chosen as active, if any.
    var activeModel: CatalogModel? {
        ModelCatalog.model(withID: preferences.activeModelID)
    }

    var isModelReady: Bool {
        if case .modelReady = engineStatus { return true }
        return false
    }

    /// Builds a request, resolving language and applying the user's preferences.
    func makeRequest(task: TextTask, text: String) -> EngineRequest {
        EngineRequest(
            task: task,
            text: text,
            language: LanguageDetector.resolve(mode: preferences.languageMode, text: text),
            tone: preferences.proofreadTone,
            creativity: preferences.creativity
        )
    }

    func run(_ request: EngineRequest) -> AsyncThrowingStream<String, Error> {
        engine.run(request)
    }

    // MARK: - Engine swapping (model loading is wired in a later stage)

    func useBuiltInEngine() {
        engine = HeuristicEngine()
        engineStatus = .builtin
    }

    /// Re-applies the global hotkey after shortcut settings change.
    func applyHotkeySettings() {
        quickAssist.applyHotkeyPreference()
    }

    /// Starts or stops system-wide autocomplete after the setting changes.
    func syncSystemAutocomplete() {
        systemAutocomplete.sync()
    }

    /// Selects a model and loads it into a llama.cpp engine.
    func activate(_ model: CatalogModel) {
        preferences.activeModelID = model.id
        loadActiveModel()
    }

    /// Loads the active model on a background task, swapping the engine when ready.
    func loadActiveModel() {
        guard let model = activeModel,
              let url = models.installedURL(for: model) else {
            useBuiltInEngine()
            return
        }
        engineStatus = .loadingModel(model.name)
        let path = url.path
        let format = model.chatFormat
        let name = model.name
        Task.detached(priority: .userInitiated) {
            do {
                let engine = try LlamaEngine(modelPath: path, chatFormat: format, displayName: name)
                await MainActor.run {
                    self.setEngine(engine, status: .modelReady(name))
                }
            } catch {
                await MainActor.run {
                    self.setEngine(HeuristicEngine(), status: .modelFailed(error.localizedDescription))
                }
            }
        }
    }

    func setEngine(_ newEngine: any TextEngine, status: EngineStatus) {
        engine = newEngine
        engineStatus = status
    }
}
