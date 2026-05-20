import SwiftUI
import AppKit

struct AboutTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                identity
                description
                creditsGroup
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }

    private var identity: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Text("Nikud")
                .font(.system(size: 22, weight: .bold))

            Text(versionString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text("A quiet writing assistant for Hebrew and English.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var description: some View {
        Text("Nikud finishes your sentences, proofreads, and polishes text using AI models that run entirely on your Mac. Nothing you write is ever sent to a server.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.lg)
    }

    private var creditsGroup: some View {
        SettingsGroup(title: "Built with") {
            creditRow(name: "llama.cpp", detail: "On-device model inference")
            RowDivider()
            creditRow(name: "DictaLM", detail: "Hebrew language models by Dicta")
            RowDivider()
            creditRow(name: "Gemma", detail: "Open models by Google")
            RowDivider()
            creditRow(name: "Qwen", detail: "Open models by Alibaba")
        }
    }

    private func creditRow(name: String, detail: String) -> some View {
        HStack {
            Text(name).font(.system(size: 13, weight: .medium))
            Spacer()
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 1)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
