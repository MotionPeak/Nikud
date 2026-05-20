import Foundation
import Combine

/// Downloads, tracks, and removes local model files.
///
/// `@Published` state is only ever mutated on the main queue; the URLSession
/// delegate callbacks hop back to main before touching it.
final class ModelManager: NSObject, ObservableObject {

    enum DownloadState: Equatable {
        case notInstalled
        case downloading(progress: Double, receivedBytes: Int64, totalBytes: Int64)
        case installed(sizeBytes: Int64)
        case failed(String)
    }

    @Published private(set) var states: [String: DownloadState] = [:]

    private var session: URLSession!
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForResource = 60 * 60 * 6
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        refresh()
    }

    // MARK: - Locations

    var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Nikud/Models", isDirectory: true)
    }

    func localURL(for model: CatalogModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    /// Returns the on-disk URL only if the model is fully installed.
    func installedURL(for model: CatalogModel) -> URL? {
        let url = localURL(for: model)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - State

    func state(for model: CatalogModel) -> DownloadState {
        states[model.id] ?? .notInstalled
    }

    func isInstalled(_ model: CatalogModel) -> Bool {
        if case .installed = state(for: model) { return true }
        return false
    }

    var installedModels: [CatalogModel] {
        ModelCatalog.all.filter { isInstalled($0) }
    }

    /// Re-scans the models directory and updates state for every catalog entry.
    func refresh() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        for model in ModelCatalog.all {
            if case .downloading = states[model.id] { continue }
            if let size = fileSize(localURL(for: model)) {
                states[model.id] = .installed(sizeBytes: size)
            } else {
                states[model.id] = .notInstalled
            }
        }
    }

    // MARK: - Actions

    func download(_ model: CatalogModel) {
        guard activeDownloads[model.id] == nil else { return }
        states[model.id] = .downloading(progress: 0, receivedBytes: 0, totalBytes: model.sizeBytes)

        var request = URLRequest(url: model.downloadURL)
        request.setValue("Nikud/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        task.taskDescription = model.id
        activeDownloads[model.id] = task
        task.resume()
    }

    func cancelDownload(_ model: CatalogModel) {
        activeDownloads[model.id]?.cancel()
        activeDownloads[model.id] = nil
        refreshState(forID: model.id)
    }

    func delete(_ model: CatalogModel) {
        try? FileManager.default.removeItem(at: localURL(for: model))
        states[model.id] = .notInstalled
    }

    // MARK: - Helpers

    private func fileSize(_ url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64, size > 0 else { return nil }
        return size
    }

    private func refreshState(forID id: String) {
        guard let model = ModelCatalog.model(withID: id) else { return }
        if let size = fileSize(localURL(for: model)) {
            states[id] = .installed(sizeBytes: size)
        } else {
            states[id] = .notInstalled
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelManager: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = downloadTask.taskDescription else { return }
        let fallback = ModelCatalog.model(withID: id)?.sizeBytes ?? totalBytesWritten
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : fallback
        let progress = expected > 0 ? Double(totalBytesWritten) / Double(expected) : 0
        DispatchQueue.main.async {
            self.states[id] = .downloading(
                progress: min(progress, 1),
                receivedBytes: totalBytesWritten,
                totalBytes: expected
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = downloadTask.taskDescription,
              let model = ModelCatalog.model(withID: id) else { return }

        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            DispatchQueue.main.async {
                self.activeDownloads[id] = nil
                self.states[id] = .failed("Server returned status \(http.statusCode).")
            }
            return
        }

        let destination = localURL(for: model)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            let size = fileSize(destination) ?? model.sizeBytes
            DispatchQueue.main.async {
                self.activeDownloads[id] = nil
                self.states[id] = .installed(sizeBytes: size)
            }
        } catch {
            DispatchQueue.main.async {
                self.activeDownloads[id] = nil
                self.states[id] = .failed(error.localizedDescription)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let id = task.taskDescription, let error = error else { return }
        let nsError = error as NSError
        DispatchQueue.main.async {
            self.activeDownloads[id] = nil
            if nsError.code == NSURLErrorCancelled {
                self.refreshState(forID: id)
            } else {
                self.states[id] = .failed(error.localizedDescription)
            }
        }
    }
}
