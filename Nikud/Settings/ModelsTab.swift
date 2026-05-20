import SwiftUI
import AppKit

struct ModelsTab: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var models: ModelManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                engineBanner
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(ModelCatalog.all) { model in
                        ModelRow(model: model)
                    }
                }
                storageFooter
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: Engine banner

    private var engineBanner: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(bannerColor.opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: bannerIcon)
                    .font(.system(size: 17))
                    .foregroundStyle(bannerColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle).font(.system(size: 13, weight: .semibold))
                Text(bannerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private var bannerTitle: String {
        switch env.engineStatus {
        case .builtin:               return "Built-in rules active"
        case .loadingModel(let n):   return "Loading \(n)…"
        case .modelReady(let n):     return "\(n) is ready"
        case .modelFailed:           return "Model failed to load"
        }
    }

    private var bannerSubtitle: String {
        switch env.engineStatus {
        case .builtin:      return "Proofreading and punctuation work now. Download a model for Polish and Complete."
        case .loadingModel: return "Preparing the model — this takes a moment."
        case .modelReady:   return "All four tasks run on your local model."
        case .modelFailed:  return "Try another model, or free up memory and retry."
        }
    }

    private var bannerIcon: String {
        switch env.engineStatus {
        case .builtin:      return "function"
        case .loadingModel: return "hourglass"
        case .modelReady:   return "checkmark.seal.fill"
        case .modelFailed:  return "exclamationmark.triangle.fill"
        }
    }

    private var bannerColor: Color {
        switch env.engineStatus {
        case .builtin:      return Theme.accent
        case .loadingModel: return .orange
        case .modelReady:   return .green
        case .modelFailed:  return .red
        }
    }

    // MARK: Storage footer

    private var storageFooter: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "internaldrive")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text(storageSummary)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Show in Finder") {
                NSWorkspace.shared.open(models.modelsDirectory)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 4)
    }

    private var storageSummary: String {
        let total = ModelCatalog.all.reduce(Int64(0)) { sum, model in
            if case .installed(let size) = models.state(for: model) { return sum + size }
            return sum
        }
        let count = models.installedModels.count
        guard count > 0 else { return "No models downloaded yet." }
        let size = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return "\(size) used by \(count) model\(count == 1 ? "" : "s")."
    }
}

// MARK: - Model row

private struct ModelRow: View {
    let model: CatalogModel
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var models: ModelManager

    var body: some View {
        let state = models.state(for: model)
        let isActive = preferences.activeModelID == model.id && isInstalled(state)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(model.name).font(.system(size: 14, weight: .semibold))
                        if model.isRecommended {
                            Chip(text: "Recommended", systemImage: "star.fill", tint: Theme.accent)
                        }
                        if isActive {
                            Chip(text: "Active", systemImage: "checkmark", tint: .green)
                        }
                    }
                    Text("\(model.developer) · \(model.parameters) · \(model.sizeDescription)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                trailingControl(state: state, isActive: isActive)
            }

            Text(model.summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Chip(text: model.hebrewTier.label, tint: model.hebrewTier.tint)
                Chip(text: model.speedTier.label, systemImage: model.speedTier.systemImage, tint: .secondary)
                Chip(text: "\(model.minRAMGB) GB RAM", tint: .secondary)
            }

            progressArea(state: state)
        }
        .card()
    }

    // MARK: Trailing control

    @ViewBuilder
    private func trailingControl(state: ModelManager.DownloadState, isActive: Bool) -> some View {
        switch state {
        case .notInstalled:
            Button("Get") { models.download(model) }
                .buttonStyle(.nikudPrimary)

        case .downloading:
            Button {
                models.cancelDownload(model)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.nikudSecondary)

        case .installed:
            HStack(spacing: 6) {
                if isActive {
                    Label("In use", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    Button("Use") { env.activate(model) }
                        .buttonStyle(.nikudPrimary)
                }
                IconButton(systemName: "trash", help: "Delete model") {
                    deleteModel()
                }
            }

        case .failed:
            Button("Retry") { models.download(model) }
                .buttonStyle(.nikudSecondary)
        }
    }

    // MARK: Progress / error

    @ViewBuilder
    private func progressArea(state: ModelManager.DownloadState) -> some View {
        switch state {
        case let .downloading(progress, received, total):
            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                HStack {
                    Text("\(byteString(received)) of \(byteString(total))")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            }
            .transition(.opacity)

        case let .failed(message):
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

        default:
            EmptyView()
        }
    }

    private func isInstalled(_ state: ModelManager.DownloadState) -> Bool {
        if case .installed = state { return true }
        return false
    }

    private func deleteModel() {
        models.delete(model)
        if preferences.activeModelID == model.id {
            preferences.activeModelID = ""
            env.useBuiltInEngine()
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
