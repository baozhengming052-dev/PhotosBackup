import SwiftUI

/// The original feasibility-probe interface, preserved for engineering and support.
struct DiagnosticsView: View {
    @EnvironmentObject private var log: ProbeLog
    @EnvironmentObject private var probe: AccountConnector
    @EnvironmentObject private var queue: UploadQueue
#if DEBUG
    @EnvironmentObject private var automaticBackup: AutomaticBackupCoordinator
#endif
    @State private var manualToken = ""
    @State private var showAdvanced = false
    @State private var showingConnect = false
    @State private var runs: [AutomaticBackupRunRecord] = []

    var body: some View {
        List {
            Section("Environment") {
                LabeledRow("iOS", value: UIDevice.current.systemVersion)
            }

            Section {
                if runs.isEmpty {
                    Text("尚无备份任务记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runs.prefix(12)) { run in AutomaticRunRow(run: run) }
                }
                NavigationLink("事件时间线") { DiagnosticEventsView() }
            } header: {
                Text("最近的运行记录")
            } footer: {
                Text("按时间从近到远显示每次运行：打开应用、立即备份、快捷指令和 iOS 允许的后台运行。后台记录会显示 iOS 实际启动时间。")
            }

#if DEBUG
            Section {
                // Say up front why a run would refuse, rather than making the
                // user press the button to find out.
                if let blocker = automaticBackup.scheduleBlocker {
                    Label(blocker, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label("可以运行", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                Button {
                    automaticBackup.simulateRun()
                } label: {
                    Label("模拟后台运行", systemImage: "play.circle")
                }
                Text(automaticBackup.debugSimulationStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("复制 LLDB 启动命令") {
                    UIPasteboard.general.string = AutomaticBackupCoordinator.lldbSimulationCommand
                }
                Button("复制日志流命令") {
                    UIPasteboard.general.string = AutomaticBackupCoordinator.logStreamCommand
                }
            } header: {
                Text("后台调试")
            } footer: {
                Text(AutomaticBackupCoordinator.lldbSimulationCommand)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }
#endif

            if !queue.recentFailures.isEmpty {
                Section {
                    ForEach(queue.recentFailures) { failure in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(failure.name).font(.caption.weight(.medium)).lineLimit(1)
                                Spacer()
                                if let code = failure.statusCode {
                                    Text("代码 \(code)").font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                            Text(failure.reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                    Button("复制所有失败详情") {
                        UIPasteboard.general.string = queue.recentFailures
                            .map(\.summary)
                            .joined(separator: "\n")
                    }
                } header: {
                    Text("上传失败记录")
                } footer: {
                    // The count is the part a bug report never has: one 400 and
                    // four hundred of them read identically on a cleared queue.
                    Text(queue.failureCount > queue.recentFailures.count
                         ? "本次运行失败 \(queue.failureCount) 次，显示最近 \(queue.recentFailures.count) 次。"
                         : "本次运行失败 \(queue.failureCount) 次。")
                }
            }

            Section("连接流程") {
                Button { showingConnect = true } label: {
                    Label("连接 Google 账号", systemImage: "person.badge.key")
                }
                if probe.running { HStack { ProgressView(); Text("正在交换凭据…").foregroundStyle(.secondary) } }
            }

            Section("可行性检查清单") {
                ForEach(log.steps) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: item.state.symbol).foregroundStyle(item.state.tint)
                            Text(item.title)
                            Spacer()
                        }
                        if !item.detail.isEmpty {
                            Text(item.detail).font(.caption).foregroundStyle(.secondary).padding(.leading, 26)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if probe.lastResult != nil {
                Section {
                    Button("重新运行只读检查") { Task { await probe.rerunReadAccess() } }.disabled(probe.running)
                }
            }

            Section {
                DisclosureGroup("高级：粘贴 oauth_token", isExpanded: $showAdvanced) {
                    TextField("oauth_token 值", text: $manualToken)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().font(.footnote.monospaced()).lineLimit(4)
                    Button("执行凭据交换") {
                        let token = manualToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !token.isEmpty else { return }
                        log.set(ProbeLog.cookieRead, .skipped, "手动粘贴")
                        log.set(ProbeLog.nativeHandoff, .skipped, "手动粘贴")
                        log.set(ProbeLog.appIngest, .skipped, "手动粘贴")
                        Task { await probe.runExchange(oauthToken: token) }
                    }
                    .disabled(manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || probe.running)
                }
            }
        }
        .navigationTitle("诊断")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { runs = AutomaticBackupRunHistory.recent() }
        .fullScreenCover(isPresented: $showingConnect) {
            AccountConnectView(
                onCaptured: { token in
                    showingConnect = false
                    Task { await probe.ingestWebToken(token) }
                },
                onCancel: { showingConnect = false }
            )
        }
    }
}
