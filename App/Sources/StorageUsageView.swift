import SwiftUI

struct StorageUsageView: View {
    @EnvironmentObject private var queue: UploadQueue
    @State private var snapshot: AppStorageSnapshot?
    @State private var isCleaning = false

    var body: some View {
        List {
            Section("照片备份占用的空间") {
                storageRow("等待上传的文件副本", bytes: snapshot?.stagedUploads)
                storageRow("备份历史与任务队列", bytes: snapshot?.backupRecords)
                storageRow("已完成的传输回执", bytes: snapshot?.transferResults)
            }

            Section("由系统管理") {
                storageRow("网络和网页缓存", bytes: snapshot?.caches)
            }

            Section {
                Button {
                    cleanUp()
                } label: {
                    HStack {
                        Label("清理无用数据", systemImage: "sparkles")
                        Spacer()
                        if isCleaning { ProgressView() }
                    }
                }
                .disabled(isCleaning)
            } footer: {
                Text("清理操作会删除缓存、失效的传输回执和不属于当前队列的上传副本；不会删除待上传内容、Google 账号或用于避免重复备份的记录。")
            }

            Section("保留的数据") {
                Text("待上传的内容会保留一份完整本地副本，直到 Google 确认备份。因此大型视频通常是临时空间占用的主要来源。")
                Text("备份历史会保存与账号关联的照片标识，体积远小于媒体文件，可避免每次扫描都重复上传。")
            }
        }
        .navigationTitle("存储空间")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    @ViewBuilder
    private func storageRow(_ title: String, bytes: Int64?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let bytes {
                Text(bytes.formatted(.byteCount(style: .file)))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }

    private func cleanUp() {
        guard !isCleaning else { return }
        isCleaning = true
        let files = queue.retainedStagingURLs
        let transferIDs = queue.retainedTransferIDs
        let before = snapshot?.total
        Task {
            await AppStorageUsage.cleanUp(retaining: files, transferIDs: transferIDs)
            await refresh()
            if let before, let after = snapshot?.total {
                DiagnosticEventLog.shared.record(
                    "storage",
                    "已清理无用数据，释放 \(DiagnosticProcessInfo.bytes(max(0, before - after)))"
                )
            }
            isCleaning = false
        }
    }

    private func refresh() async {
        snapshot = await AppStorageUsage.measure()
    }
}
