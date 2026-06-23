import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginModel()
    private let contentWidth: CGFloat = 360

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.name)
                        .font(.system(size: 17, weight: .semibold))
                    Text("Menu bar usage vitals for Codex")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: contentWidth, alignment: .leading)

            VStack(spacing: 0) {
                settingsRow {
                    Toggle(isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )) {
                        Label("Launch at Login", systemImage: "poweron")
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(width: contentWidth)

            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(launchAtLogin.errorMessage == nil ? .secondary : .orange)
                .lineLimit(2)
                .frame(width: contentWidth, alignment: .leading)

            VStack(spacing: 0) {
                Button {
                    open(AppInfo.studioURL)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Made by")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            RamterStudioLogoView()
                                .frame(width: 150, height: 24, alignment: .leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open RamterStudio website")

                Divider()
                    .opacity(0.12)
                    .padding(.leading, 14)

                Button {
                    open(AppInfo.feedbackURL)
                } label: {
                    HStack(spacing: 10) {
                        Label("Feedback", systemImage: "envelope.fill")
                            .font(.system(size: 13, weight: .medium))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Send feedback to RamterStudio")
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(width: contentWidth)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var statusText: String {
        if let errorMessage = launchAtLogin.errorMessage {
            return errorMessage
        }
        return launchAtLogin.statusText
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .contentShape(Rectangle())
    }
}

private struct RamterStudioLogoView: View {
    private static let logo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "RamterStudioLogo", withExtension: "png") else {
            return nil
        }
        let image = NSImage(contentsOf: url)
        image?.isTemplate = true
        return image
    }()

    var body: some View {
        Group {
            if let logo = Self.logo {
                Image(nsImage: logo)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Text("RamterStudio")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published var isEnabled = false
    @Published var statusText = ""
    @Published var errorMessage: String?

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        statusText = status.displayText
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}

private extension SMAppService.Status {
    var displayText: String {
        switch self {
        case .enabled:
            return "Launch at Login is enabled"
        case .requiresApproval:
            return "Launch at Login needs approval in System Settings"
        case .notFound:
            return "Launch at Login is unavailable for this build"
        case .notRegistered:
            return "Launch at Login is off"
        @unknown default:
            return "Launch at Login status is unknown"
        }
    }
}
