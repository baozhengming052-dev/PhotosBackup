import SwiftUI
import UIKit

/// The event timeline, newest first, so a user can see why the app did what
/// it did without generating and reading a whole report.
struct DiagnosticEventsView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case problems = "问题"
        var id: Self { self }
    }

    @State private var events: [DiagnosticEvent] = []
    @State private var filter: Filter = .all
    @State private var confirmingClear = false

    var body: some View {
        List {
            Section {
                Picker("显示", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("最多显示最近两周的 \(DiagnosticEventLog.defaultLimit) 条事件。警告和错误的保留时间比普通记录更长，文件名、照片标识、地址和链接已移除。")
            }

            Section {
                if visible.isEmpty {
                    Text(filter == .all ? "尚无事件记录。" : "没有警告或错误。")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(visible.enumerated()), id: \.offset) { _, event in
                    DiagnosticEventRow(event: event)
                }
            }
        }
        .navigationTitle("事件时间线")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        let formatter = ISO8601DateFormatter()
                        UIPasteboard.general.string = events.map { $0.line(formatter) }.joined(separator: "\n")
                    } label: {
                        Label("全部复制", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        confirmingClear = true
                    } label: {
                        Label("清空时间线", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("清空事件时间线？", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("清空时间线", role: .destructive) {
                DiagnosticEventLog.shared.clear()
                reload()
            }
        } message: {
            Text("清空后，新生成的诊断报告将无法解释之前发生的问题。")
        }
        .onAppear(perform: reload)
        .refreshable { reload() }
    }

    private var visible: [DiagnosticEvent] {
        let newestFirst = events.reversed()
        return filter == .all ? Array(newestFirst) : newestFirst.filter { $0.level != .info }
    }

    private func reload() {
        events = DiagnosticEventLog.shared.snapshot()
    }
}

private struct DiagnosticEventRow: View {
    let event: DiagnosticEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.category.capitalized).font(.caption.weight(.semibold))
                    Spacer()
                    Text(event.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text(event.message)
                    .font(.footnote)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if event.occurrences > 1 {
                    Text("重复 \(event.occurrences) 次"
                         + (event.firstDate.map { "，始于 \($0.formatted(date: .omitted, time: .shortened))" } ?? ""))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var symbol: String {
        switch event.level {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch event.level {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }
}

/// One backup run: what started it, when, under which conditions, and what
/// it achieved.
struct AutomaticRunRow: View {
    let run: AutomaticBackupRunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(run.source.rawValue).font(.subheadline.weight(.medium))
                Spacer()
                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let summary = run.summary {
                Text(summary.prefix(1).uppercased() + summary.dropFirst())
                    .font(.caption)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("仍在运行，或应用在完成前已停止。")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let context = run.context {
                Text(context).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let duration = run.duration {
                Text("耗时 \(AutomaticBackupCoordinator.describeInterval(duration))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var symbol: String {
        switch run.success {
        case .some(true): return "checkmark.circle.fill"
        case .some(false): return "exclamationmark.triangle.fill"
        case .none: return "clock.badge.exclamationmark"
        }
    }

    private var tint: Color {
        switch run.success {
        case .some(true): return .green
        case .some(false), .none: return .orange
        }
    }
}
