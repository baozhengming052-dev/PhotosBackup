import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var account: PhotosAccount
    @EnvironmentObject private var queue: UploadQueue
    @EnvironmentObject private var preferences: BackupPreferences
    @EnvironmentObject private var albums: PhotoAlbumStore
    @EnvironmentObject private var automaticBackup: AutomaticBackupCoordinator

    let showTutorial: () -> Void
    @State private var confirmDisconnect = false
    @State private var connectionCheckResult: PhotosAccount.VerificationOutcome?
    @State private var verifyMessage: String?
    @State private var isVerifying = false
    private let gpmcURL = URL(string: "https://github.com/xob0t/gpmc")!

    var body: some View {
        NavigationView {
            Form {
                accountSection
                backupSection
                keepAliveSection
                automationSection
                verifySection
                supportSection
                aboutSection
            }
            .navigationTitle("设置")
            .confirmationDialog("断开 Google 相册连接吗？", isPresented: $confirmDisconnect, titleVisibility: .visible) {
                Button("断开连接", role: .destructive) { Task { await account.disconnect() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("断开连接后将无法继续备份，直到重新连接；已备份的照片不受影响。")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var accountSection: some View {
        Section("Google 相册账号") {
            HStack(alignment: .top, spacing: 12) {
                FeatureIcon(symbol: "person.crop.circle.fill", size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(accountTitle)
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(accountSubtitle)
                        .font(.caption)
                        .foregroundStyle(account.status.isUsable ? Color.green : Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer()
                Image(systemName: account.status.isUsable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(account.status.isUsable ? Color.green : Color.orange)
                    .accessibilityLabel(account.status.isUsable ? "已连接" : "需要处理")
            }
            .padding(.vertical, 4)

            if account.status.isUsable {
                Button {
                    connectionCheckResult = nil
                    Task {
                        let result = await account.verify()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            connectionCheckResult = result
                        }
                    }
                } label: {
                    HStack {
                        Text(account.verifying ? "正在检查连接…" : "检查连接")
                        Spacer()
                        if account.verifying {
                            ProgressView()
                        } else if connectionCheckResult == .succeeded {
                            Label("已验证", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                    .disabled(account.verifying)
                Button("断开账号", role: .destructive) { confirmDisconnect = true }
            } else {
                Button("连接账号") { showTutorial() }
            }

            if case .failed(let reason) = connectionCheckResult, account.status.isUsable {
                Label(reason, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if account.status.isUsable, let warning = account.persistenceWarning {
                VStack(alignment: .leading, spacing: 8) {
                    Label("未保存到钥匙串", systemImage: "key.slash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(warning + " 此次使用期间账号有效，但重新打开应用后可能需要再次连接。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: account.status) { status in
            if !status.isUsable { connectionCheckResult = nil }
        }
    }

    private var backupSection: some View {
        Section {
            Toggle("自动备份", isOn: $preferences.automaticBackup)
            Picker("使用的网络", selection: $preferences.connection) {
                ForEach(BackupConnection.allCases) { option in Text(option.title).tag(option) }
            }
            if let reason = queue.networkPauseReason {
                Label(reason, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Picker("同时上传数量", selection: $preferences.concurrentUploads) {
                ForEach(Array(UploadQueue.concurrencyRange), id: \.self) { count in
                    Text(count.formatted()).tag(count)
                }
            }
            Toggle("节省存储空间画质", isOn: $preferences.storageSaver)
            Toggle("计入 Google 存储配额", isOn: $preferences.useQuota)
            Toggle("备份实况照片动态部分", isOn: $preferences.backUpLivePhotoMotion)
        } header: {
            Text("备份")
        } footer: {
            Text("More simultaneous uploads finish a large backup sooner. Each one stages a full-size copy on the device while it runs, so high values use more storage, battery and data at once — 2 suits most phones. Lowering it lets uploads already running finish first.\n\nStorage Saver asks Google Photos to reduce file size. With Count Against Storage Quota off, uploads identify as an older Pixel phone so they don't use your Google storage; the Google Photos app may then label them “Storage saver” even though the original file was kept. The file size, or Google Photos on the web, shows the real quality.\n\nBack Up Live Photo Motion attaches each Live Photo's motion to its photo, so it plays as a Live Photo in Google Photos and the Google Photos app's Free up space can remove it from this iPhone. It uploads the short video too, a few MB per Live Photo, and uses storage the same way the photo does. Live Photos backed up earlier get their motion added in the background.")
        }
    }

    private var verifySection: some View {
        Section {
            Button {
                runVerification()
            } label: {
                HStack {
                    Text(isVerifying ? "正在重新检查…" : "重新检查备份")
                    Spacer()
                    if isVerifying { ProgressView() }
                }
            }
            .disabled(!canVerify)
            if let verifyMessage {
                Text(verifyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("重新检查")
        } footer: {
            Text("重新将所选相簿与 Google 相册对比。云端仍存在的项目会很快完成检查；已从云端删除的内容将重新加入上传队列。")
        }
    }

    private var keepAliveSection: some View {
        Section {
            Toggle("保持后台运行", isOn: $preferences.keepAliveEnabled)
            if preferences.keepAliveEnabled {
                Picker("方式", selection: $preferences.keepAliveMode) {
                    ForEach(KeepAliveMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                Text(preferences.keepAliveMode.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("后台")
        } footer: {
            Text("正常情况下，离开应用几秒后 iOS 就可能暂停它，只在系统允许的后台时段执行备份。开启此功能后，切换应用或锁屏时可尝试继续备份，每次最多同时上传 2 项，全部完成后再次休眠。此功能更耗电，建议连接充电器；需先打开应用启动备份，在多任务界面上滑关闭应用仍会停止。每次运行最长 12 小时。\n\n关闭此选项时，应用内正在备份期间屏幕会保持亮起，因为锁屏会使备份暂停。")
        }
    }

    private var automationSection: some View {
        Section {
            ShortcutsSettingsRows()
        } header: {
            Text("快捷指令")
        } footer: {
            Text("在“快捷指令”中建立个人自动化，例如连接充电器、指定时间或连接家中 Wi-Fi 时立即运行，并添加“备份照片”。每次约有 30 秒来发现选中相簿中的新照片，并将上传任务交给 iOS 后台处理。即使关闭自动备份，此操作仍可运行，但会遵守网络与暂停设置。仅存在于 iCloud 的照片需打开本应用后才能处理。")
        }
    }

    private var canVerify: Bool {
        account.status.isUsable && !isVerifying && !preferences.selectedAlbumIDs.isEmpty
    }

    private func runVerification() {
        guard canVerify else { return }
        isVerifying = true
        verifyMessage = nil
        Task {
            let outcome = await automaticBackup.reverifySelectedAlbums()
            isVerifying = false
            verifyMessage = DashboardView.message(for: outcome)
        }
    }

    private var supportSection: some View {
        Section("支持") {
            NavigationLink("生成诊断报告") { DiagnosticReportView() }
            NavigationLink("存储空间") { StorageUsageView() }
            NavigationLink("诊断") { DiagnosticsView() }
            Button("重新查看新手引导") {
                preferences.resetOnboarding()
            }
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            LabeledRow("应用", value: "照片备份")
            LabeledRow("版本", value: appVersion)
            LabeledRow("iOS", value: UIDevice.current.systemVersion)
            LabeledRow("核心技术") {
                Link("GPMC（作者 xob0t）", destination: gpmcURL)
            }
        }
    }

    private var accountTitle: String {
        switch account.status {
        case .loading: return "正在检查账号…"
        case .disconnected: return "未连接"
        case .connected(let email, _): return email
        case .rejected(let email, _): return email.isEmpty ? "重新登录" : email
        }
    }

    private var accountSubtitle: String {
        switch account.status {
        case .loading: return "正在查找已保存的登录凭据"
        case .disconnected: return "连接后即可开始备份"
        case .connected(_, let since): return "已连接 · \(since.formatted(date: .abbreviated, time: .omitted))"
        case .rejected(_, let reason): return reason
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}

/// The Shortcuts rows: a way into the Shortcuts app, and the last run, so an
/// automation can be checked without waiting for a problem.
private struct ShortcutsSettingsRows: View {
    @State private var lastRun: AutomaticBackupRunRecord?

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                Label("“备份照片”快捷指令", systemImage: "square.stack.3d.up.fill")
                Link("打开快捷指令", destination: URL(string: "shortcuts://")!)
                if let lastRun {
                    AutomaticRunRow(run: lastRun)
                } else {
                    Text("该快捷指令尚未运行。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("需要 iOS 16 或更新版本", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { lastRun = AutomaticBackupRunHistory.latest(.shortcut) }
    }
}

/// Presents the in-app Google account connection flow (see AccountConnectView)
/// and runs the token exchange on capture. Shown as a sheet from the dashboard
/// and Settings.
struct ConnectionTutorialView: View {
    @EnvironmentObject private var probe: AccountConnector
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AccountConnectView(
            onCaptured: { token in
                dismiss()
                Task { await probe.ingestWebToken(token) }
            },
            onCancel: { dismiss() }
        )
    }
}
