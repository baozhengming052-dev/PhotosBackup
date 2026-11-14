import SwiftUI

struct UploadsView: View {
    @EnvironmentObject private var account: PhotosAccount
    @EnvironmentObject private var queue: UploadQueue
    @EnvironmentObject private var preferences: BackupPreferences
    @State private var showPicker = false
    @State private var showingStopBackupConfirmation = false
    @State private var inspectedFailure: FailureDetail?

    /// A failed row's full text, snapshotted when it is tapped. The row itself
    /// can be retried or cleared while the sheet is open.
    private struct FailureDetail: Identifiable {
        let id: UUID
        let name: String
        let reason: String
    }

    var body: some View {
        NavigationView {
            List {
                manualBackupSection
                if let reason = queue.pauseReason { pausedSection(reason) }
                if let warning = queue.persistenceWarning { persistenceWarningSection(warning) }
                if queue.items.isEmpty { emptySection }
                else {
                    queueManagementSection
                    activitySection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("备份记录")
            .sheet(isPresented: $showPicker) {
                PhotoPicker { sources in enqueue(sources) }.ignoresSafeArea()
            }
            .sheet(item: $inspectedFailure) { failure in failureSheet(failure) }
            .confirmationDialog(
                "停止所有备份吗？",
                isPresented: $showingStopBackupConfirmation,
                titleVisibility: .visible
            ) {
                Button("停止备份", role: .destructive) { stopBackup() }
                Button("继续备份", role: .cancel) {}
            } message: {
                Text(stopBackupMessage)
            }
        }
        .navigationViewStyle(.stack)
    }

    /// Photos picked by hand are checked against Google even when the app
    /// remembers them as backed up: picking one is how someone asks "is this
    /// really backed up?", and the hash lookup settles it without re-uploading
    /// anything Google already has.
    private func enqueue(_ sources: [MediaSource]) {
        guard !sources.isEmpty else { return }
        queue.reverify(sources)
    }

    private var manualBackupSection: some View {
        Section {
            Button { showPicker = true } label: {
                HStack(spacing: 12) {
                    FeatureIcon(symbol: "photo.badge.plus", size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("选择照片或视频").font(.headline).foregroundStyle(.primary)
                        Text("每次最多备份 50 项").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(!account.status.isUsable)
        } footer: {
            if !account.status.isUsable { Text("开始备份前，请先连接 Google 相册账号。") }
        }
    }

    private func pausedSection(_ reason: String) -> some View {
        Section {
            Label("Backup Paused", systemImage: "pause.circle.fill").foregroundStyle(.orange)
            Text(reason).font(.footnote).foregroundStyle(.secondary)
            if queue.haltReason != nil {
                Button("继续备份") { queue.resume() }.disabled(!account.status.isUsable)
            } else if queue.isUserPaused {
                Button("继续备份") { queue.resumeUserPausedUploads() }
                    .disabled(!account.status.isUsable)
            }
        }
    }

    private var queueManagementSection: some View {
        Section("任务队列管理") {
            if queue.activeCount > 0 || queue.isUserPaused {
                if queue.isUserPaused {
                    Button {
                        queue.resumeUserPausedUploads()
                    } label: {
                        Label("继续备份", systemImage: "play.circle")
                    }
                    .disabled(!account.status.isUsable)
                } else if queue.pauseReason == nil {
                    Button {
                        queue.pauseAfterCurrentUploads()
                    } label: {
                        Label("当前上传完成后暂停", systemImage: "pause.circle")
                    }
                }

                if queue.activeCount > 0 {
                    Button(role: .destructive) {
                        showingStopBackupConfirmation = true
                    } label: {
                        Label("停止备份", systemImage: "stop.circle")
                    }
                }
            }

            if queue.failedCount > 0 {
                Button {
                    queue.retryAllFailed()
                } label: {
                    Label("重试失败的上传", systemImage: "arrow.clockwise.circle")
                }
            }

            if queue.hasFinishedItems {
                Button {
                    queue.clearFinished()
                } label: {
                    Label("清除已完成记录", systemImage: "checkmark.circle")
                }
            }
        }
    }

    private func persistenceWarningSection(_ warning: String) -> some View {
        Section {
            Label("上传进度未能保存", systemImage: "externaldrive.badge.exclamationmark")
                .foregroundStyle(.orange)
            Text(warning).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var emptySection: some View {
        Section {
            EmptyState(symbol: "tray", title: "暂无备份记录", message: "手动备份或所选相簿的备份记录将显示在这里。")
                .listRowBackground(Color.clear)
        }
    }

    private var activitySection: some View {
        Section {
            if !queue.isIdle {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("总体进度").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(queue.overallFraction, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    ProgressView(value: queue.overallFraction).tint(BackupTheme.blue)
                }
                .padding(.vertical, 6)
            }
            ForEach(listed.items) { item in activityRow(item) }
        } header: {
            HStack {
                Text("上传任务")
                Spacer()
                if !queue.isIdle { Text("剩余 \(queue.activeCount) 项") }
            }
        } footer: {
            let notes = [
                listed.hiddenQueued > 0 ? "还有 \(listed.hiddenQueued.formatted()) 项正在排队。" : nil,
                listed.hiddenFinished > 0 ? "另有 \(listed.hiddenFinished.formatted()) 项较早完成的记录未显示。" : nil,
                queue.deferredForICloudCount > 0
                    ? "有 \(queue.deferredForICloudCount) 项需先从 iCloud 下载。请保持应用打开。"
                    : nil,
            ].compactMap { $0 }
            if !notes.isEmpty { Text(notes.joined(separator: " ")) }
        }
    }

    private var listed: ActivityListing { ActivityListing(queue.items) }

    private var stopBackupMessage: String {
        if preferences.automaticBackup {
            return "将取消正在进行的上传、清空队列并关闭自动备份；已备份的照片不受影响。"
        }
        return "将取消正在进行的上传并清空队列；已备份的照片不受影响。"
    }

    private func stopBackup() {
        preferences.automaticBackup = false
        queue.cancelAll()
    }

    private func activityRow(_ item: UploadItem) -> some View {
        HStack(spacing: 12) {
            FeatureIcon(symbol: symbol(item.state), color: tint(item.state), size: 42)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.name).font(.subheadline.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if item.byteCount > 0 {
                        Text(item.byteCount.formatted(.byteCount(style: .file)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(item.state.label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if case .failed = item.state {
                    // The reason above is clamped to two lines, and Google's
                    // own explanation is usually past the clamp.
                    Text("点击查看详情").font(.caption2).foregroundStyle(BackupTheme.blue)
                }
                if let fraction = item.state.fraction, item.state.isWorking {
                    ProgressView(value: fraction).tint(BackupTheme.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard case .failed(let reason, _) = item.state else { return }
            inspectedFailure = FailureDetail(id: item.id, name: item.name, reason: reason)
        }
        .swipeActions {
            if item.state.isFinished {
                if item.state != .done && item.state != .alreadyBackedUp {
                    Button("重试") { queue.retry(item.id) }.tint(BackupTheme.blue)
                }
            } else {
                Button("取消", role: .destructive) { queue.cancel(item.id) }
            }
        }
    }

    /// The whole reason, selectable and copyable. A support report is only as
    /// good as the text the reporter can actually get out of the app.
    private func failureSheet(_ failure: FailureDetail) -> some View {
        NavigationView {
            List {
                Section("项目") { Text(failure.name).font(.subheadline) }
                Section("Google 返回的信息") {
                    Text(failure.reason)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    Button {
                        UIPasteboard.general.string = "\(failure.name)\n\(failure.reason)"
                    } label: {
                        Label("复制详情", systemImage: "doc.on.doc")
                    }
                    Button {
                        queue.retry(failure.id)
                        inspectedFailure = nil
                    } label: {
                        Label("重试此项目", systemImage: "arrow.clockwise")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("上传失败")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { inspectedFailure = nil }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func symbol(_ state: UploadItem.State) -> String {
        switch state {
        case .done, .alreadyBackedUp: return "checkmark"
        case .failed: return "exclamationmark"
        case .cancelled: return "xmark"
        case .queued, .waitingToRetry, .waitingForICloud: return "clock"
        default: return "arrow.up"
        }
    }

    private func tint(_ state: UploadItem.State) -> Color {
        switch state {
        case .done, .alreadyBackedUp: return .green
        case .failed: return .red
        case .cancelled, .waitingToRetry, .waitingForICloud: return .orange
        default: return BackupTheme.blue
        }
    }
}

/// The rows the Activity list shows. A whole-library backup queues tens of
/// thousands of rows, and a list that long is drawn and diffed again on every
/// change anywhere in the queue, which is what made the tab slow (#8). Rows
/// in progress or needing a decision always show; of the rest, only the next
/// few waiting and the latest finished, with the footer counting the others.
struct ActivityListing {
    static let queuedShown = 20
    static let finishedShown = 50

    let items: [UploadItem]
    let hiddenQueued: Int
    let hiddenFinished: Int

    init(_ all: [UploadItem]) {
        var queued: [Int] = []
        var finished: [Int] = []
        var shown = IndexSet()
        for (index, item) in all.enumerated() {
            switch item.state {
            case .queued: queued.append(index)
            case .done, .alreadyBackedUp: finished.append(index)
            default: shown.insert(index)
            }
        }
        queued.prefix(Self.queuedShown).forEach { shown.insert($0) }
        finished.suffix(Self.finishedShown).forEach { shown.insert($0) }
        items = shown.map { all[$0] }
        hiddenQueued = max(0, queued.count - Self.queuedShown)
        hiddenFinished = max(0, finished.count - Self.finishedShown)
    }
}
