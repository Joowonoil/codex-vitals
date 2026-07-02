import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var isShowingSettings = false

    static let preferredWidth: CGFloat = 652

    static func preferredHeight() -> CGFloat {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
        return min(720, floor(visibleHeight * 0.85))
    }

    static func listMaxHeight() -> CGFloat {
        max(280, preferredHeight() - 84)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(vm: viewModel, isShowingSettings: $isShowingSettings)
            thinDivider

            if isShowingSettings {
                SettingsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: Self.listMaxHeight())
            } else {
                if viewModel.isLoading && viewModel.accounts.isEmpty {
                    SkeletonView()
                } else if !viewModel.hasAnyAccount {
                    emptyState
                } else {
                    ScrollView(.vertical) {
                        AccountListView(vm: viewModel)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: Self.listMaxHeight())
                }
            }

            thinDivider

            if !isShowingSettings && viewModel.errorsCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("\(viewModel.errorsCount) account(s) with errors")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                thinDivider
            }

            if let accountActionError = viewModel.accountActionError {
                FooterView(message: accountActionError)
            }
        }
        .frame(width: Self.preferredWidth)
        .background(.ultraThinMaterial)
        .background(
            Group {
                Button("") { isShowingSettings.toggle() }.keyboardShortcut(",", modifiers: .command)
                Button("") { viewModel.toggleGroupByWorkspace() }.keyboardShortcut("g", modifiers: [.command, .shift])
                Button("") { viewModel.refresh(forceMetadataRefresh: true) }.keyboardShortcut("r", modifiers: .command)
                Button("") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
            }.opacity(0)
        )
    }

    private var thinDivider: some View { Divider().opacity(0.15) }

    @ViewBuilder
    private var emptyState: some View {
        if !viewModel.searchText.isEmpty {
            Text("No account matches '\(viewModel.searchText)'")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 32)).foregroundColor(.secondary)
                Text("No accounts found")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                Button {
                    viewModel.addAccount()
                } label: {
                    Label("Add account", systemImage: "person.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.hasPendingAccountAction)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @ObservedObject var vm: UsageViewModel
    @Binding var isShowingSettings: Bool
    @State private var manualRefreshPending = false
    @State private var showsRefreshSuccess = false
    @State private var refreshSuccessTask: Task<Void, Never>?
    @State private var isSearchVisible = false

    var body: some View {
        HStack(spacing: 8) {
            if isShowingSettings {
                Button {
                    isShowingSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .help("Back")

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            } else if shouldShowSearchField {
                compactSearchField
            } else {
                appBrandLockup
                Spacer(minLength: 0)
            }

            if !isShowingSettings {
                searchButton

                Button {
                    if vm.isAddingAccount {
                        vm.cancelRelogin()
                    } else {
                        vm.addAccount()
                    }
                } label: {
                    Image(systemName: vm.isAddingAccount ? "xmark.circle.fill" : "person.badge.plus")
                        .font(.system(size: 13))
                        .foregroundColor(vm.isAddingAccount ? .secondary : Color(hex: "30D158"))
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(vm.hasPendingAccountAction && !vm.isAddingAccount)
                .help(vm.isAddingAccount ? "Cancel" : "Add account")

                workspaceGroupingButton

                Button {
                    requestRefresh()
                } label: {
                    if vm.isLoading {
                        ProgressView().controlSize(.small)
                    } else if showsRefreshSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "30D158"))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14)).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain).frame(width: 22, height: 22)
                .disabled(vm.isLoading)
                .help(showsRefreshSuccess ? "Updated" : "Refresh")
            }

            Button {
                isShowingSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isShowingSettings ? .primary : .secondary)
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help(isShowingSettings ? "Accounts" : "Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help("Quit Codex Vitals")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(height: 44)
        .animation(.easeInOut(duration: 0.16), value: shouldShowSearchField)
        .onReceive(vm.$isLoading.dropFirst()) { isLoading in
            handleLoadingChange(isLoading)
        }
    }

    private var shouldShowSearchField: Bool {
        isSearchVisible || !vm.searchText.isEmpty
    }

    private var appBrandLockup: some View {
        HStack(spacing: 7) {
            AppBrandIcon()
                .frame(width: 20, height: 20)

            Text("Codex Vitals")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .fixedSize()
        .help("Codex Vitals")
        .transition(.opacity)
    }

    private var compactSearchField: some View {
        HStack(spacing: 6) {
            SearchTextField("Search", text: $vm.searchText)
                .frame(width: searchFieldWidth)
                .frame(minHeight: 16)

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                    isSearchVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.07))
        .cornerRadius(7)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var searchFieldWidth: CGFloat {
        170
    }

    private var searchButton: some View {
        Button {
            if shouldShowSearchField && vm.searchText.isEmpty {
                isSearchVisible = false
            } else {
                isSearchVisible = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(shouldShowSearchField ? .primary : .secondary)
                .frame(width: 24, height: 22)
                .background(shouldShowSearchField ? Color.primary.opacity(0.12) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(shouldShowSearchField ? "Hide search" : "Search")
    }

    private var workspaceGroupingButton: some View {
        Button {
            vm.toggleGroupByWorkspace()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(vm.groupByWorkspace ? .primary : .secondary)
                .frame(width: 28, height: 24)
                .background(vm.groupByWorkspace ? Color.primary.opacity(0.12) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(vm.groupByWorkspace ? "Ungroup workspaces" : "Group by workspace")
    }

    private func requestRefresh() {
        guard !vm.isLoading else { return }
        manualRefreshPending = true
        showsRefreshSuccess = false
        refreshSuccessTask?.cancel()
        vm.refresh(forceMetadataRefresh: true)
    }

    private func handleLoadingChange(_ isLoading: Bool) {
        guard !isLoading, manualRefreshPending else { return }
        manualRefreshPending = false
        showsRefreshSuccess = true
        refreshSuccessTask?.cancel()
        refreshSuccessTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            showsRefreshSuccess = false
        }
    }
}

struct AppBrandIcon: View {
    private static let icon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: 20, height: 20)
        return image
    }()

    var body: some View {
        Group {
            if let icon = Self.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "30D158"))
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
    }
}

struct SearchTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> ShortcutTextField {
        let field = ShortcutTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: 13)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: ShortcutTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

final class ShortcutTextField: NSTextField {
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control),
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            currentEditor()?.selectAll(nil)
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Footer

struct FooterView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(height: 40)
    }
}

// MARK: - Skeleton

struct SkeletonView: View {
    @State private var pulse = false

    private let rowHeight: CGFloat = 28

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(pulse ? 0.08 : 0.04))
                    .frame(height: rowHeight)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
