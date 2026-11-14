import SwiftUI
import UIKit

struct DiagnosticReportView: View {
    @EnvironmentObject private var log: ProbeLog
    @EnvironmentObject private var account: PhotosAccount
    @EnvironmentObject private var queue: UploadQueue
    @EnvironmentObject private var preferences: BackupPreferences
    @EnvironmentObject private var albums: PhotoAlbumStore
    @EnvironmentObject private var automaticBackup: AutomaticBackupCoordinator
    @State private var report: DiagnosticReport?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingShareSheet = false
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Label("可安全公开分享", systemImage: "hand.raised.fill")
                    .foregroundStyle(.green)
                Text("报告不会包含登录凭据、账号地址、照片标识、文件名、媒体内容及请求网址。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    generate()
                } label: {
                    HStack {
                        Label(report == nil ? "生成报告" : "刷新报告", systemImage: "doc.text.magnifyingglass")
                        Spacer()
                        if isGenerating { ProgressView() }
                    }
                }
                .disabled(isGenerating)

                if let report {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("分享或保存报告", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = report.text
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "复制报告文本", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("出现问题后请尽快生成报告，并将文本文件附到 github.com/g8row/PhotosBackup/issues 的问题反馈中。")
            }

            if let report {
                Section {
                    ForEach(Array(report.findings.enumerated()), id: \.offset) { _, finding in
                        Text(finding)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("主要发现")
                } footer: {
                    Text(report.url.lastPathComponent).font(.caption2.monospaced())
                }
            }

            Section {
                NavigationLink("事件时间线") { DiagnosticEventsView() }
            } footer: {
                Text("显示应用执行了哪些操作及原因，包括 iOS 何时启动后台任务以及任务结果。")
            }
        }
        .navigationTitle("诊断报告")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let report {
                ActivityView(items: [report.url])
            }
        }
    }

    private func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        copied = false
        Task {
            do {
                report = try await DiagnosticReportBuilder.create(
                    log: log,
                    account: account,
                    queue: queue,
                    preferences: preferences,
                    albums: albums,
                    automaticBackup: automaticBackup
                )
            } catch {
                errorMessage = "无法生成报告：\(error.localizedDescription)"
                DiagnosticEventLog.shared.record("support", "无法生成诊断报告：\(error.localizedDescription)", level: .error)
            }
            isGenerating = false
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
