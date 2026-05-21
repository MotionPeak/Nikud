import SwiftUI
import AppKit

/// The text workspace shown inside the menu-bar popover.
struct ComposerView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model = ComposerModel()
    @State private var didApplyDefaults = false
    @State private var tabMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            taskSection
            inputSection
            metaRow
            actionButton
            resultSection
        }
        .padding(Theme.Spacing.md)
        .onAppear {
            if !didApplyDefaults {
                didApplyDefaults = true
                model.task = preferences.defaultTask
            }
            installTabMonitor()
        }
        .onDisappear { removeTabMonitor() }
        .onChange(of: model.input) { _, _ in
            model.inputChanged(using: env)
        }
        .animation(Theme.Motion.spring, value: model.phase)
        .animation(Theme.Motion.spring, value: model.task)
        .animation(Theme.Motion.snappy, value: model.suggestion)
    }

    // MARK: Task

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            TaskPicker(selection: $model.task)
            Text(model.task.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .id(model.task)
                .transition(.opacity)
        }
    }

    // MARK: Input

    private var inputSection: some View {
        let hebrew = LanguageDetector.detect(model.input) == .hebrew
        return ZStack(alignment: hebrew ? .topTrailing : .topLeading) {
            if !model.suggestion.isEmpty {
                ghostText(hebrew: hebrew)
            }

            TextEditor(text: $model.input)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .environment(\.layoutDirection, hebrew ? .rightToLeft : .leftToRight)
                .padding(7)
                .frame(height: 116)

            if model.input.isEmpty {
                Text("Type or paste text…")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 15)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    // MARK: Meta

    private var metaRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Chip(text: languageLabel, systemImage: "globe", tint: .secondary)

            if !model.input.isEmpty {
                Text("\(model.input.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            if !model.suggestion.isEmpty {
                HStack(spacing: 3) {
                    Text(verbatim: "⇥").font(.system(size: 10, weight: .bold))
                    Text("to accept").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
            }

            Spacer()

            if model.task == .polish {
                tonePicker
            }
        }
    }

    private var tonePicker: some View {
        Menu {
            ForEach(Tone.allCases) { tone in
                Button {
                    model.tone = tone
                } label: {
                    Label(tone.title, systemImage: tone.systemImage)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: model.tone.systemImage).font(.system(size: 9))
                Text(model.tone.title).font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 7))
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var languageLabel: String {
        switch preferences.languageMode {
        case .auto:
            return model.input.isEmpty
                ? "Auto-detect"
                : "Auto · \(LanguageDetector.detect(model.input).displayName)"
        case .hebrew:
            return "Hebrew"
        case .english:
            return "English"
        }
    }

    // MARK: Action

    private var actionButton: some View {
        Button {
            if model.isRunning {
                model.cancel()
            } else {
                model.run(using: env)
            }
        } label: {
            HStack(spacing: 6) {
                if model.isRunning {
                    ThinkingDots(tint: .white)
                    Text("Stop")
                } else {
                    Image(systemName: model.task.systemImage)
                    Text(model.task.actionVerb)
                }
            }
        }
        .buttonStyle(.nikudPrimary(fullWidth: true))
        .disabled(!model.canRun && !model.isRunning)
    }

    // MARK: Result

    @ViewBuilder
    private var resultSection: some View {
        switch model.phase {
        case .idle:
            EmptyView()
        case .running, .finished:
            ResultCard(model: model, onCopy: copyOutput)
        case let .failed(message, needsModel):
            ErrorCard(message: message, needsModel: needsModel, onGetModel: openSettings)
        }
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.output, forType: .string)
    }

    private func openSettings() {
        env.settingsTab = .models
        NSApplication.shared.activate()
        openWindow(id: WindowID.settings)
    }

    // MARK: Autocomplete

    /// The suggestion shown inline behind the editor, as muted ghost text.
    private func ghostText(hebrew: Bool) -> some View {
        (Text(verbatim: model.input).foregroundColor(.clear)
            + Text(verbatim: model.suggestion).foregroundColor(Color(nsColor: .placeholderTextColor)))
            .font(.system(size: 13))
            .multilineTextAlignment(hebrew ? .trailing : .leading)
            .environment(\.layoutDirection, hebrew ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hebrew ? .topTrailing : .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 15)
            .allowsHitTesting(false)
    }

    private func installTabMonitor() {
        guard tabMonitor == nil else { return }
        let model = self.model
        tabMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 48, !model.suggestion.isEmpty {
                model.acceptSuggestion()
                return nil
            }
            return event
        }
    }

    private func removeTabMonitor() {
        if let tabMonitor {
            NSEvent.removeMonitor(tabMonitor)
            self.tabMonitor = nil
        }
    }
}

// MARK: - Task picker

private struct TaskPicker: View {
    @Binding var selection: TextTask
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TextTask.allCases) { task in
                button(for: task)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.softFill)
        )
    }

    private func button(for task: TextTask) -> some View {
        let selected = task == selection
        return Button {
            withAnimation(Theme.Motion.spring) { selection = task }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: task.systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(task.title)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.brandGradient)
                        .matchedGeometryEffect(id: "taskPill", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Result card

private struct ResultCard: View {
    @ObservedObject var model: ComposerModel
    let onCopy: () -> Void
    @State private var copied = false

    var body: some View {
        let hebrew = LanguageDetector.detect(model.output) == .hebrew
        let showDiff = model.phase == .finished
            && model.task.showsDiff
            && !model.input.isEmpty
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                SectionLabel(text: "Result")
                if showDiff {
                    let count = TextDiff.changeCount(original: model.input, corrected: model.output)
                    Text(count == 0 ? "no changes" : "\(count) change\(count == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if model.isRunning { ThinkingDots() }
            }

            ScrollView {
                Group {
                    if showDiff {
                        DiffText(original: model.input, corrected: model.output)
                    } else {
                        Text(verbatim: model.output.isEmpty ? "…" : model.output)
                            .foregroundStyle(.primary)
                    }
                }
                .font(.system(size: 13))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: hebrew ? .trailing : .leading)
                .environment(\.layoutDirection, hebrew ? .rightToLeft : .leftToRight)
            }
            .frame(height: 150)

            if model.phase == .finished {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        onCopy()
                        withAnimation(Theme.Motion.snappy) { copied = true }
                    } label: {
                        Label(copied ? "Copied" : "Copy",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.nikudSecondary)

                    Button {
                        withAnimation(Theme.Motion.spring) { model.useResult() }
                    } label: {
                        Label(model.task == .complete ? "Add to input" : "Replace input",
                              systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.nikudSecondary)

                    Spacer()
                }
            }
        }
        .card()
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Error card

private struct ErrorCard: View {
    let message: String
    let needsModel: Bool
    let onGetModel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if needsModel {
                Button(action: onGetModel) {
                    Label("Download a model", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.nikudPrimary)
            }
        }
        .card()
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}
