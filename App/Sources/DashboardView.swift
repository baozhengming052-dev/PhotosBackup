import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var account: PhotosAccount
    @EnvironmentObject private var queue: UploadQueue
    @EnvironmentObject private var preferences: BackupPreferences
    @EnvironmentObject private var albums: PhotoAlbumStore
    @EnvironmentObject private var automaticBackup: AutomaticBackupCoordinator

    let onConnect: () -> Void
    let onAccount: () -> Void
    @State private var showPicker = false
    @State private var showingStopBackupConfirmation = false
    @State private var manualRunMessage: String?
    @State private var isStartingManualRun = false

    private var selectedAlbums: [PhotoAlbum] {
        albums.albums.filter { preferences.selectedAlbumIDs.contains($0.id) }
    }

    /// Unique-item estimate for the selection. "所有照片" spans the whole
    /// image/video library, so when it is selected every other album is a
    /// subset of it — summing per-album counts would count most assets twice.
    private var selectedItemCount: Int {
        if let all = selectedAlbums.first(where: { $0.isAllPhotos }) { return all.count }
        return selectedAlbums.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    accountBanner
                    backupHero
                    quickActions
                    folderSummary
                    if !queue.items.isEmpty { recentActivity }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(BackupTheme.background)
            .navigationTitle("照片备份")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    accountToolbarItem
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPicker { sources in enqueue(sources) }.ignoresSafeArea()
            }
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
            .onAppear {
                albums.refreshInBackground()
                refreshBackedUpCounts()
            }
            .onChange(of: preferences.selectedAlbumIDs) { _ in refreshBackedUpCounts() }
            .onChange(of: albums.albums) { _ in refreshBackedUpCounts() }
            .onChange(of: queue.completedSourceKeys) { _ in refreshBackedUpCounts() }
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

    @ViewBuilder private var accountBanner: some View {
        switch account.status {
        case .loading:
            banner(color: .blue, symbol: "hourglass", title: "正在检查账号", message: "请稍候…")
        case .disconnected:
            Button(action: onConnect) {
                banner(color: .orange, symbol: "person.crop.circle.badge.exclamationmark", title: "连接 Google 相册", message: "登录后即可开始备份照片图库", showsChevron: true)
            }
            .buttonStyle(.plain)
        case .connected:
            if let warning = account.persistenceWarning {
                banner(color: .orange, symbol: "key.slash", title: "未保存到钥匙串", message: warning, showsChevron: false)
            } else if let reason = queue.pauseReason {
                banner(color: .orange, symbol: "pause.circle.fill", title: "备份已暂停", message: reason, showsChevron: false)
            }
        case .rejected(_, let reason):
            Button(action: onConnect) {
                banner(color: .red, symbol: "exclamationmark.arrow.circlepath", title: "重新登录", message: reason, showsChevron: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var backupHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(heroTitle).font(.title2.bold())
                    Text(heroSubtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(heroTint.opacity(0.14), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: heroProgress)
                        .stroke(heroTint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: heroSymbol)
                        .font(.title3.bold())
                        .foregroundStyle(heroTint)
                }
                .frame(width: 58, height: 58)
            }

            Divider()

            HStack {
                metric(value: queue.completedSourceCount.formatted(), label: "已备份")
                Divider().frame(height: 38)
                metric(value: selectedAlbums.count.formatted(), label: "相簿")
                Divider().frame(height: 38)
                metric(value: queue.activeCount.formatted(), label: "等待上传")
            }

            if !queue.isIdle || queue.isUserPaused {
                HStack(spacing: 10) {
                    if queue.isUserPaused {
                        Button {
                            queue.resumeUserPausedUploads()
                        } label: {
                            Label("继续", systemImage: "play.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(BackupTheme.blue)
                        .disabled(!account.status.isUsable)
                    } else if queue.pauseReason == nil {
                        Button {
                            queue.pauseAfterCurrentUploads()
                        } label: {
                            Label("暂停", systemImage: "pause.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(BackupTheme.blue)
                        .accessibilityHint("等待正在上传的任务完成，然后暂停剩余队列")
                    }

                    if !queue.isIdle {
                        Button(role: .destructive) {
                            showingStopBackupConfirmation = true
                        } label: {
                            Label("停止", systemImage: "stop.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
        }
        .padding(20)
        .background(BackupTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private var quickActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) { albumBackupAction; photoPickerAction }
                .buttonStyle(CardButtonStyle())
        } else {
            HStack(spacing: 12) { albumBackupAction; photoPickerAction }
                .buttonStyle(CardButtonStyle())
        }
    }

    private var albumBackupAction: some View {
        let enabled = account.status.isUsable && !selectedAlbums.isEmpty
            && !isStartingManualRun && !queue.isUserPaused
        return Button(action: backUpSelectedAlbums) {
            quickActionLabel(symbol: "arrow.up.circle.fill",
                             title: isStartingManualRun ? "正在检查…" : "立即备份",
                             detail: backUpActionDetail,
                             isEnabled: enabled)
        }
        .disabled(!enabled)
    }

    private var backUpActionDetail: String {
        if selectedAlbums.isEmpty { return "请先选择相簿" }
        if queue.isUserPaused { return "备份已暂停" }
        let backedUp = selectedBackedUpCount
        guard selectedItemCount > 0 else { return "\(selectedItemCount.formatted()) 项" }
        return "已备份 \(backedUp.formatted()) / \(selectedItemCount.formatted()) 项"
    }

    /// Backed-up total for the selection, using the same "All Photos contains
    /// everything" rule as `selectedItemCount` so the two agree.
    private var selectedBackedUpCount: Int {
        if let all = selectedAlbums.first(where: { $0.isAllPhotos }) {
            return albums.backedUpCounts[all.id] ?? 0
        }
        return selectedAlbums.reduce(0) { $0 + (albums.backedUpCounts[$1.id] ?? 0) }
    }

    private var photoPickerAction: some View {
        let enabled = account.status.isUsable
        return Button { showPicker = true } label: {
            quickActionLabel(symbol: "photo.badge.plus", title: "选择照片", detail: "手动备份", isEnabled: enabled)
        }
        .disabled(!enabled)
    }

    private var folderSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("已选相簿").font(.headline)
                Spacer()
                if preferences.automaticBackup {
                    StatusPill(text: "自动备份", symbol: "arrow.triangle.2.circlepath", color: .green)
                }
            }
            if let manualRunMessage {
                Text(manualRunMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if selectedAlbums.isEmpty {
                Text("尚未选择相簿，请前往“相簿”页面选择。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(selectedAlbums.prefix(4).enumerated()), id: \.element.id) { index, album in
                    if index > 0 { Divider().padding(.leading, 54) }
                    HStack(spacing: 12) {
                        FeatureIcon(symbol: album.symbol, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title).font(.subheadline.weight(.semibold))
                            Text(progressLabel(for: album)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: albums.backedUpCounts[album.id] == album.count
                              ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(albums.backedUpCounts[album.id] == album.count
                                             ? Color.green : BackupTheme.blue)
                    }
                }
                if selectedAlbums.count > 4 {
                    Text("另有 \(selectedAlbums.count - 4) 个相簿")
                        .font(.footnote.weight(.semibold)).foregroundStyle(BackupTheme.blue)
                }
            }
        }
        .padding(18)
        .background(BackupTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近的备份记录").font(.headline)
            ForEach(Array(queue.items.suffix(3).reversed())) { item in
                HStack(spacing: 12) {
                    FeatureIcon(symbol: symbol(item.state), color: tint(item.state), size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(item.state.label).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(BackupTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var accountToolbarItem: some View {
        Button(action: onAccount) {
            ZStack {
                Circle().fill(account.status.isUsable ? BackupTheme.blue : Color.secondary.opacity(0.18))
                Image(systemName: account.status.isUsable ? "person.fill" : "person.crop.circle.badge.exclamationmark")
                    .font(.caption.weight(.bold)).foregroundStyle(account.status.isUsable ? .white : .secondary)
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(account.status.isUsable ? "账号已连接" : "账号未连接")
        .accessibilityHint("打开账号设置")
    }

    private func banner(color: Color, symbol: String, title: String, message: String, showsChevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary) }
        }
        .padding(14)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickActionLabel(symbol: String, title: String, detail: String, isEnabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(isEnabled ? BackupTheme.blue : Color.secondary)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BackupTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var heroTitle: String {
        if !account.status.isUsable { return "连接账号后开始备份" }
        if queue.pauseReason != nil { return "备份已暂停" }
        if !queue.isIdle { return "正在备份…" }
        if queue.failedCount > 0 { return "备份需要处理" }
        if queue.completedSourceCount == 0 { return "准备就绪" }
        return "备份完成"
    }

    private var heroSubtitle: String {
        if !account.status.isUsable { return "请先连接账号" }
        if let reason = queue.pauseReason { return reason }
        if !queue.isIdle { return "剩余 \(queue.activeCount) 项" }
        if queue.failedCount > 0 { return "\(queue.failedCount) 项失败，请到“备份记录”中重试" }
        if selectedAlbums.isEmpty { return "选择需要备份的相簿" }
        return "所选相簿已全部备份"
    }

    private var heroProgress: Double {
        if !account.status.isUsable || queue.pauseReason != nil { return 0.18 }
        return queue.isIdle ? 1 : max(queue.overallFraction, 0.04)
    }

    private var heroTint: Color {
        if !account.status.isUsable || queue.pauseReason != nil { return .orange }
        if queue.failedCount > 0 { return .red }
        return queue.isIdle ? .green : BackupTheme.blue
    }

    private var heroSymbol: String {
        if !account.status.isUsable { return "link" }
        if queue.pauseReason != nil { return "pause.fill" }
        if queue.failedCount > 0 { return "exclamationmark" }
        return queue.isIdle ? "checkmark" : "arrow.up"
    }

    private func progressLabel(for album: PhotoAlbum) -> String {
        guard let backedUp = albums.backedUpCounts[album.id] else {
            return "\(album.count.formatted()) 项"
        }
        return "已备份 \(backedUp.formatted()) / \(album.count.formatted()) 项"
    }

    private func refreshBackedUpCounts() {
        albums.refreshBackedUpCounts(for: preferences.selectedAlbumIDs,
                                     isBackedUp: queue.backedUpAssetLookup())
    }

    private func backUpSelectedAlbums() {
        guard !isStartingManualRun else { return }
        isStartingManualRun = true
        manualRunMessage = nil
        Task {
            let outcome = await automaticBackup.backUpSelectedAlbumsNow()
            isStartingManualRun = false
            manualRunMessage = Self.message(for: outcome)
        }
    }

    static func message(for outcome: AutomaticBackupCoordinator.ManualRunOutcome) -> String {
        switch outcome {
        case .noLibraryAccess: return "请在设置中允许访问照片，才能备份相簿。"
        case .noAlbumsSelected: return "请先到“相簿”页面选择相簿。"
        case .nothingToDo: return "所选相簿中的内容均已备份。"
        case .started(let count): return "正在备份 \(count.formatted()) 项，可在“备份记录”中查看进度。"
        case .rechecking(let count): return "正在与 Google 相册核对 \(count.formatted()) 项。"
        }
    }

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
