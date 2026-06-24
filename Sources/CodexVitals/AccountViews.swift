import SwiftUI
import AppKit

private enum AccountAliasPrompt {
    static func edit(account: Account, save: (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = account.hasDisplayAlias ? "Edit Account Alias" : "Set Account Alias"
        alert.informativeText = account.email
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = account.displayAlias ?? ""
        textField.placeholderString = "Display alias"
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            save(Account.normalizedAlias(textField.stringValue))
        }
    }
}

private enum WorkspaceAliasPrompt {
    static func edit(workspace: String, displayName: String, hasAlias: Bool, save: (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = hasAlias ? "Edit Workspace Name" : "Set Workspace Name"
        alert.informativeText = hasAlias ? "Original: \(workspace)" : workspace
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = hasAlias ? displayName : ""
        textField.placeholderString = "Display name"
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            save(Account.normalizedAlias(textField.stringValue))
        }
    }
}

struct AccountListView: View {
    @ObservedObject var vm: UsageViewModel

    var body: some View {
        listBody
    }

    @ViewBuilder
    private var listBody: some View {
        VStack(spacing: 0) {
            if vm.groupByWorkspace {
                if !vm.priorityAccounts.isEmpty {
                    PrioritySeparatorHeader(count: vm.priorityAccounts.count)
                    ForEach(vm.groupedPriorityAccounts, id: \.0) { ws, accs in
                        SectionHeader(
                            originalName: ws,
                            displayName: vm.workspaceDisplayName(for: ws),
                            count: accs.count,
                            hasAlias: vm.workspaceHasDisplayAlias(ws),
                            setAlias: { vm.setWorkspaceAlias($0, for: ws) }
                        )
                        rows(accs)
                    }
                }
                if !vm.normalActiveAccounts.isEmpty {
                    ForEach(vm.groupedNormalActiveAccounts, id: \.0) { ws, accs in
                        SectionHeader(
                            originalName: ws,
                            displayName: vm.workspaceDisplayName(for: ws),
                            count: accs.count,
                            hasAlias: vm.workspaceHasDisplayAlias(ws),
                            setAlias: { vm.setWorkspaceAlias($0, for: ws) }
                        )
                        rows(accs)
                    }
                }
                if !vm.exhaustedAccounts.isEmpty {
                    waitingForResetGroup {
                        ForEach(vm.groupedExhaustedAccounts, id: \.0) { ws, accs in
                            SectionHeader(
                                originalName: ws,
                                displayName: vm.workspaceDisplayName(for: ws),
                                count: accs.count,
                                hasAlias: vm.workspaceHasDisplayAlias(ws),
                                setAlias: { vm.setWorkspaceAlias($0, for: ws) }
                            )
                            rows(accs)
                        }
                        freeWaitingGroup
                    }
                }
            } else {
                if !vm.priorityAccounts.isEmpty {
                    PrioritySeparatorHeader(count: vm.priorityAccounts.count)
                    rows(vm.priorityAccounts)
                }
                if !vm.normalActiveAccounts.isEmpty {
                    rows(vm.normalActiveAccounts)
                }
                if !vm.exhaustedAccounts.isEmpty {
                    waitingForResetGroup {
                        rows(vm.nonFreeExhaustedAccounts)
                        freeWaitingGroup
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func waitingForResetGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isCollapsed = vm.waitingForResetCollapsed && vm.searchText.isEmpty
        ExhaustedSeparatorHeader(
            count: vm.exhaustedAccounts.count,
            isCollapsed: isCollapsed,
            toggle: { vm.toggleWaitingForResetCollapsed() }
        )
        if !isCollapsed {
            content()
        }
    }

    @ViewBuilder
    private var freeWaitingGroup: some View {
        if !vm.freeWaitingAccounts.isEmpty {
            let isCollapsed = vm.freeWaitingCollapsed && vm.searchText.isEmpty
            FreeWaitingGroupHeader(
                count: vm.freeWaitingAccounts.count,
                isCollapsed: isCollapsed,
                toggle: { vm.toggleFreeWaitingCollapsed() }
            )
            if !isCollapsed {
                rows(vm.freeWaitingAccounts)
            }
        }
    }

    @ViewBuilder
    private func rows(_ accs: [Account]) -> some View {
        ForEach(Array(accs.enumerated()), id: \.element.id) { i, acc in
            accountRow(for: acc)
            if i < accs.count - 1 {
                Divider().padding(.horizontal, 12).opacity(0.08)
            }
        }
    }

    @ViewBuilder
    private func accountRow(for acc: Account) -> some View {
        AccountCompactRow(
            account: acc,
            needsRelogin: vm.needsRelogin(acc),
            isRelogging: vm.isRelogging(acc),
            isReloginBlocked: vm.hasPendingAccountAction && !vm.isRelogging(acc),
            isSwitchingToCodex: vm.isSwitchingToCodex(acc),
            isActiveInCodex: vm.isActiveInCodex(acc),
            showsCodexControls: vm.isCodexInstalled,
            isSwitchBlocked: vm.hasPendingAccountAction && !vm.isSwitchingToCodex(acc),
            isRemoving: vm.isRemoving(acc),
            isRemoveBlocked: vm.hasPendingAccountAction && !vm.isRemoving(acc),
            canMoveUp: vm.canMoveAccount(acc, direction: .up),
            canMoveDown: vm.canMoveAccount(acc, direction: .down),
            relogin: { vm.relogin(acc) },
            cancelRelogin: { vm.cancelRelogin() },
            switchToCodex: { vm.switchCodex(to: acc) },
            removeAccount: { vm.removeAccount(acc) },
            setAlias: { vm.setAlias($0, for: acc) },
            moveUp: { vm.moveAccount(acc, direction: .up) },
            moveDown: { vm.moveAccount(acc, direction: .down) }
        )
    }
}

// MARK: - Section Headers

struct SectionHeader: View {
    let originalName: String
    let displayName: String
    let count: Int
    let hasAlias: Bool
    let setAlias: (String?) -> Void

    var body: some View {
        HStack {
            Text("\(displayName.uppercased()) (\(count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12).frame(height: 28)
        .background(Color.primary.opacity(0.03))
        .contentShape(Rectangle())
        .contextMenu {
            Button(hasAlias ? "Edit Workspace Name..." : "Set Workspace Name...") {
                WorkspaceAliasPrompt.edit(
                    workspace: originalName,
                    displayName: displayName,
                    hasAlias: hasAlias,
                    save: setAlias
                )
            }
            if hasAlias {
                Button("Clear Workspace Name") {
                    setAlias(nil)
                }
            }
        }
        .help(hasAlias ? "Original workspace: \(originalName)" : "Set workspace display name")
    }
}

struct PrioritySeparatorHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "FF9F0A"))
            Text("PRIORITY (\(count))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
    }
}

struct ExhaustedSeparatorHeader: View {
    let count: Int
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 10)
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("WAITING FOR RESET (\(count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.primary.opacity(0.03))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? "Show waiting accounts" : "Hide waiting accounts")
    }
}

struct FreeWaitingGroupHeader: View {
    let count: Int
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 10)
                Text("FREE (\(count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.primary.opacity(0.025))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? "Show free accounts" : "Hide free accounts")
    }
}

// MARK: - Expanded Row

struct AccountRow: View {
    let account: Account
    var setAlias: (String?) -> Void = { _ in }
    var canMoveUp = false
    var canMoveDown = false
    var moveUp: () -> Void = {}
    var moveDown: () -> Void = {}
    @State private var hovered = false

    private var exhausted: Bool { account.isWeeklyExhausted }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                accountIdentity
                Spacer()
                WorkspaceChip(ws: account.displayWorkspaceName, colorKey: account.workspace, compact: false)
            }
            .opacity(exhausted ? 0.5 : 1)

            if !exhausted {
                BarRow(
                    label: "5h",
                    pct: account.sessionFree,
                    resetSeconds: account.sessionResetSeconds,
                    style: .normal,
                    urgentReset: false
                )
            }

            BarRow(
                label: "1w",
                pct: account.weeklyFree,
                resetSeconds: account.weeklyResetSeconds,
                style: exhausted ? .weeklyExhausted : .normal,
                urgentReset: account.isWeeklyResetUrgent
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, exhausted ? 6 : 8)
        .frame(maxWidth: .infinity, minHeight: exhausted ? 38 : 56, alignment: .leading)
        .background(hovered ? Color.primary.opacity(0.06) : .clear)
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Move Up") {
                moveUp()
            }
            .disabled(!canMoveUp)
            Button("Move Down") {
                moveDown()
            }
            .disabled(!canMoveDown)
            Divider()
            Button(account.hasDisplayAlias ? "Edit Alias..." : "Set Alias...") {
                AccountAliasPrompt.edit(account: account, save: setAlias)
            }
            if account.hasDisplayAlias {
                Button("Clear Alias") {
                    setAlias(nil)
                }
            }
            Divider()
            Button("Copy email") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(account.email, forType: .string)
            }
        }
    }

    @ViewBuilder
    private var accountIdentity: some View {
        if account.hasDisplayAlias {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    PlanBadge(text: account.displayPlanName, compact: false)
                    Text(account.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(account.email)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            HStack(spacing: 5) {
                Text(account.email)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                PlanBadge(text: account.displayPlanName, compact: false)
            }
        }
    }
}

// MARK: - Compact Row

private enum CompactRowLayout {
    static let horizontalPadding: CGFloat = 12
    static let emailMinWidth: CGFloat = 176
    static let actionWidth: CGFloat = 24

    struct Metrics {
        let spacing: CGFloat
        let emailWidth: CGFloat
        let workspaceWidth: CGFloat
        let metricWidth: CGFloat
        let sessionResetWidth: CGFloat
        let weeklyResetWidth: CGFloat
        let planCycleWidth: CGFloat
        let actionWidth: CGFloat
    }

    static func metrics(totalWidth: CGFloat) -> Metrics {
        let spacing: CGFloat = 3
        let contentWidth = max(0, totalWidth - horizontalPadding * 2)
        let workspaceWidth: CGFloat = 58
        let metricWidth: CGFloat = 76
        let sessionResetWidth: CGFloat = 42
        let weeklyResetWidth: CGFloat = 56
        let planCycleWidth: CGFloat = 34
        let fixedWidth = 16
            + workspaceWidth
            + actionWidth
            + metricWidth * 2
            + sessionResetWidth
            + weeklyResetWidth
            + planCycleWidth
            + spacing * 6

        return Metrics(
            spacing: spacing,
            emailWidth: max(emailMinWidth, contentWidth - fixedWidth),
            workspaceWidth: workspaceWidth,
            metricWidth: metricWidth,
            sessionResetWidth: sessionResetWidth,
            weeklyResetWidth: weeklyResetWidth,
            planCycleWidth: planCycleWidth,
            actionWidth: actionWidth
        )
    }
}

struct AccountCompactRow: View {
    let account: Account
    let needsRelogin: Bool
    let isRelogging: Bool
    let isReloginBlocked: Bool
    let isSwitchingToCodex: Bool
    let isActiveInCodex: Bool
    let showsCodexControls: Bool
    let isSwitchBlocked: Bool
    let isRemoving: Bool
    let isRemoveBlocked: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let relogin: () -> Void
    let cancelRelogin: () -> Void
    let switchToCodex: () -> Void
    let removeAccount: () -> Void
    let setAlias: (String?) -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    @State private var hovered = false

    private var exhausted: Bool { account.isWeeklyExhausted }
    private var rowHeight: CGFloat {
        account.hasDisplayAlias ? 40 : 34
    }
    private var canShowSwapControl: Bool {
        showsCodexControls
            && !isActiveInCodex
            && !needsRelogin
            && !isRelogging
            && account.isUsableForCodex
    }

    private var rowBackgroundColor: Color {
        if isActiveInCodex {
            return Color(hex: "30D158").opacity(hovered ? 0.08 : 0.045)
        }
        return hovered ? Color.primary.opacity(0.06) : .clear
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = CompactRowLayout.metrics(totalWidth: proxy.size.width)
            let freeResetWidth = layout.metricWidth * 2
                + layout.sessionResetWidth
                + layout.weeklyResetWidth
                + layout.planCycleWidth
                + layout.spacing * 2
                + 4
            HStack(alignment: .center, spacing: layout.spacing) {
                leadingAccountControl

                accountIdentityView
                    .frame(width: layout.emailWidth, alignment: .leading)

                WorkspaceChip(ws: account.displayWorkspaceName, colorKey: account.workspace, compact: true)
                    .frame(width: layout.workspaceWidth, alignment: .leading)

                if needsRelogin || isRelogging {
                    accountActionControl(width: layout.actionWidth)
                    reconnectStatus(width: freeResetWidth, alignment: .leading)
                } else if account.isFreeWaitingForReset {
                    accountActionControl(width: layout.actionWidth)
                    freeResetStatus(width: freeResetWidth, alignment: .leading)
                } else {
                    accountActionControl(width: layout.actionWidth)

                    sessionMetricGroup(layout: layout)
                    weeklyMetricGroup(layout: layout)
                    planCycleText(width: layout.planCycleWidth)
                }
            }
            .padding(.horizontal, CompactRowLayout.horizontalPadding)
            .padding(.vertical, 7)
            .frame(width: proxy.size.width, height: rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(height: rowHeight)
        .background(rowBackgroundColor)
        .overlay(alignment: .leading) {
            if isActiveInCodex {
                Capsule()
                    .fill(Color(hex: "30D158"))
                    .frame(width: 2, height: max(14, rowHeight - 8))
                    .padding(.leading, 4)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Move Up") {
                moveUp()
            }
            .disabled(!canMoveUp)
            Button("Move Down") {
                moveDown()
            }
            .disabled(!canMoveDown)
            Divider()
            Button(account.hasDisplayAlias ? "Edit Alias..." : "Set Alias...") {
                AccountAliasPrompt.edit(account: account, save: setAlias)
            }
            if account.hasDisplayAlias {
                Button("Clear Alias") {
                    setAlias(nil)
                }
            }
            Divider()
            Button("Copy email") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(account.email, forType: .string)
            }
        }
    }

    @ViewBuilder
    private var accountIdentityView: some View {
        if account.hasDisplayAlias {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    PlanBadge(text: account.displayPlanName, compact: true)
                    Text(account.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(account.email)
                    .font(.system(size: 8.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .help(account.email)
        } else {
            HStack(spacing: 5) {
                Text(account.email)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                PlanBadge(text: account.displayPlanName, compact: true)
            }
            .help(account.email)
        }
    }

    @ViewBuilder
    private var leadingAccountControl: some View {
        Group {
            if showsCodexControls && isActiveInCodex {
                CodexIconView()
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(hex: "30D158"))
                            .background(Circle().fill(.black.opacity(0.72)))
                    }
                    .help("Active in Codex")
            } else if isRemoving {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
            } else if hovered {
                Button(action: removeAccount) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .disabled(isRemoveBlocked)
                .help("Remove from list")
            } else {
                Color.clear.frame(width: 5, height: 5)
            }
        }
        .frame(width: 16, height: 18)
    }

    @ViewBuilder
    private func sessionMetricGroup(layout: CompactRowLayout.Metrics) -> some View {
        HStack(spacing: 2) {
            Group {
                if !exhausted {
                    compactQuota(label: "5h", pct: account.sessionFree, gray: false, width: layout.metricWidth)
                } else {
                    Color.clear.frame(width: layout.metricWidth, height: 1)
                }
            }
            .opacity(exhausted ? 0.5 : 1)

            sessionResetText(width: layout.sessionResetWidth)
        }
    }

    @ViewBuilder
    private func weeklyMetricGroup(layout: CompactRowLayout.Metrics) -> some View {
        HStack(spacing: 2) {
            compactQuota(label: "1w", pct: account.weeklyFree, gray: exhausted, width: layout.metricWidth)
                .opacity(exhausted ? 0.5 : 1)

            weeklyResetText(width: layout.weeklyResetWidth)
        }
    }

    @ViewBuilder
    private func sessionResetText(width: CGFloat) -> some View {
        Group {
            if exhausted {
                Color.clear.frame(width: width, height: 1)
            } else {
                ResetTimeBadge(
                    text: ResetFormatter.timeOnly(seconds: account.sessionResetSeconds),
                    color: .secondary,
                    width: width,
                    help: ResetFormatter.fullTooltip(seconds: account.sessionResetSeconds)
                )
            }
        }
    }

    @ViewBuilder
    private func planCycleText(width: CGFloat) -> some View {
        Group {
            if let text = PlanCycleFormatter.daysText(for: account),
               let date = account.planRenewalDate {
                PlanCycleBadge(text: text, width: width, help: PlanCycleFormatter.tooltip(for: date))
            } else {
                Color.clear.frame(width: width, height: 1)
            }
        }
    }

    private func weeklyResetText(width: CGFloat) -> some View {
        ResetTimeBadge(
            text: weeklyStatusText,
            color: weeklyStatusColor,
            width: width,
            help: account.hasError ? (account.errorMessage ?? "Invalid account") : ResetFormatter.fullTooltip(seconds: account.weeklyResetSeconds),
            systemImage: weeklyStatusImage
        )
    }

    private var weeklyStatusText: String {
        if account.hasError {
            return "err"
        }
        return ResetFormatter.compact(seconds: account.weeklyResetSeconds)
    }

    private var weeklyStatusColor: Color {
        if account.hasError { return Color(hex: "FF453A") }
        if exhausted { return Theme.weeklyExhaustedBar }
        return account.isWeeklyResetUrgent ? Color(hex: "FF9F0A") : .secondary
    }

    private var weeklyStatusImage: String? {
        if account.hasError { return "exclamationmark.triangle.fill" }
        if account.isWeeklyResetUrgent && !exhausted { return "clock" }
        return nil
    }

    @ViewBuilder
    private func accountActionControl(width: CGFloat) -> some View {
        Group {
            if isRelogging {
                Button(action: cancelRelogin) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            } else if isSwitchingToCodex {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.65)
            } else if canShowSwapControl {
                SwitchAccountButton(action: switchToCodex)
                    .disabled(isSwitchBlocked)
                    .opacity(hovered ? 1 : 0)
                    .allowsHitTesting(hovered)
            } else {
                Color.clear.frame(width: width, height: 1)
            }
        }
        .frame(width: width, height: 18)
    }
}

struct ResetTimeBadge: View {
    let text: String
    let color: Color
    let width: CGFloat
    let help: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 7.5, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 4)
        .frame(width: width, height: 18, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(0.09))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(color.opacity(0.16), lineWidth: 0.5)
        }
        .help(help)
    }
}

struct PlanCycleBadge: View {
    let text: String
    let width: CGFloat
    let help: String

    var body: some View {
        Text(text.lowercased())
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color(hex: "FF9F0A"))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: width, height: 18, alignment: .center)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: "FF9F0A").opacity(0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(hex: "FF9F0A").opacity(0.18), lineWidth: 0.5)
            }
            .help(help)
    }
}

struct PlanBadge: View {
    let text: String?
    var compact = false

    var body: some View {
        if let text {
            Text(text)
                .font(.system(size: compact ? 7.4 : 9, weight: .bold))
                .foregroundStyle(Theme.workspaceTextColor(for: text))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, compact ? 4 : 5)
                .padding(.vertical, compact ? 1 : 1.5)
                .background(Theme.workspaceColor(for: text))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
                .help("Plan: \(text)")
        }
    }
}

struct ReloginAccountButton: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "FF9F0A").opacity(hovered ? 1 : 0.88))
                .frame(width: 20, height: 18)
            .background(hovered ? .thinMaterial : .ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color(hex: "FF9F0A").opacity(hovered ? 0.36 : 0.22), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Re-login")
    }
}

struct SwitchAccountButton: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(hovered ? 0.92 : 0.78))
                .frame(width: 20, height: 18)
                .background(hovered ? .thinMaterial : .ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(hovered ? 0.26 : 0.14), lineWidth: 0.6)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Use in Codex")
    }
}

struct CodexIconView: View {
    private static let image: NSImage = {
        let codexPNG = Bundle.main.url(forResource: "codex", withExtension: "png")
        let image = codexPNG.flatMap { NSImage(contentsOf: $0) }
            ?? NSWorkspace.shared.icon(forFile: "/Applications/Codex.app")
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }()

    var body: some View {
        Image(nsImage: Self.image)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.primary.opacity(0.82))
            .frame(width: 16, height: 16)
    }
}

private extension AccountCompactRow {
    func reconnectStatus(width: CGFloat, alignment: Alignment) -> some View {
        Group {
            if isRelogging {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.62)
                    Text("Reconnecting...")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.13), lineWidth: 0.6)
                }
            } else {
                Button(action: relogin) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Reconnect")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "FF9F0A"))
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Color(hex: "FF9F0A").opacity(0.11))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color(hex: "FF9F0A").opacity(0.24), lineWidth: 0.6)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isReloginBlocked)
            }
        }
        .frame(width: width, alignment: alignment)
        .help(isRelogging ? "Reconnecting account" : "Reconnect this account")
    }

    func freeResetStatus(width: CGFloat, alignment: Alignment) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Free resets \(ResetFormatter.formatFreeReturn(seconds: account.freePlanResetSeconds))")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: width, alignment: alignment)
        .help("Free quota resets \(ResetFormatter.fullTooltip(seconds: account.freePlanResetSeconds))")
    }

    func compactQuota(label: String, pct: Double, gray: Bool, width: CGFloat) -> some View {
        QuotaMeter(
            label: label,
            pct: pct,
            fill: gray ? Theme.weeklyExhaustedBar : Theme.barColor(for: pct),
            dimmed: gray,
            width: width
        )
    }
}

struct QuotaMeter: View {
    let label: String
    let pct: Double
    let fill: Color
    let dimmed: Bool
    let width: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 14, alignment: .leading)

            MeterTrack(pct: pct, fill: fill, height: 4, minimumFill: 2)
                .frame(width: 26)

            Text(String(format: "%.0f%%", pct))
                .font(.system(size: 9.5, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(fill)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .frame(width: width, height: 18, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(dimmed ? 0.035 : 0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(fill.opacity(dimmed ? 0.12 : 0.22), lineWidth: 0.6)
        }
        .opacity(dimmed ? 0.76 : 1)
    }
}

struct MeterTrack: View {
    let pct: Double
    let fill: Color
    var height: CGFloat = 4
    var minimumFill: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let fillWidth = max(minimumFill, geo.size.width * max(0, min(100, pct)) / 100)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.11))
                    .frame(height: height)
                if pct > 0.001 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [fill.opacity(0.68), fill],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: height)
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

// MARK: - Workspace Chip

struct WorkspaceChip: View {
    let ws: String
    let colorKey: String
    var compact: Bool = false

    init(ws: String, colorKey: String? = nil, compact: Bool = false) {
        self.ws = ws
        self.colorKey = colorKey ?? ws
        self.compact = compact
    }

    var body: some View {
        Text(ws)
            .font(.system(size: compact ? 9 : 11, weight: .medium))
            .foregroundColor(Theme.workspaceTextColor(for: colorKey))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, compact ? 1 : 2)
            .background(Theme.workspaceColor(for: colorKey))
            .cornerRadius(4)
    }
}

// MARK: - Horizontal Bar Row

enum BarRowStyle {
    case normal
    case weeklyExhausted
}

struct BarRow: View {
    let label: String
    let pct: Double
    let resetSeconds: Double
    let style: BarRowStyle
    let urgentReset: Bool

    var body: some View {
        let dimmed = style == .weeklyExhausted
        let fillColor: Color = dimmed ? Theme.weeklyExhaustedBar : Theme.barColor(for: pct)

        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(dimmed ? .secondary : fillColor)
                .frame(width: 28, alignment: .leading)
                .opacity(dimmed ? 0.5 : 1)

            MeterTrack(pct: pct, fill: fillColor, height: 5, minimumFill: 4)
                .frame(height: 5)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(dimmed ? 0.025 : 0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(fillColor.opacity(dimmed ? 0.1 : 0.16), lineWidth: 0.5)
                }
            .opacity(dimmed ? 0.5 : 1)

            Text(String(format: "%.0f%%", pct))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(dimmed ? .secondary : fillColor)
                .frame(width: 38, alignment: .trailing)
                .opacity(dimmed ? 0.5 : 1)

            Text("·")
                .foregroundColor(.secondary.opacity(0.5))
                .opacity(dimmed ? 0.5 : 1)

            HStack(spacing: 4) {
                if urgentReset && !dimmed {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "FF9F0A"))
                }
                Text(dimmed ? ResetFormatter.formatReset(seconds: resetSeconds) : ResetFormatter.format(seconds: resetSeconds))
                    .font(.system(size: 11))
                    .foregroundColor(urgentReset && !dimmed ? Color(hex: "FF9F0A") : .secondary)
                    .help(ResetFormatter.fullTooltip(seconds: resetSeconds))
            }
        }
        .frame(height: 14)
    }
}
