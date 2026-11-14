import AppIntents

/// The app owns the coordinator. App Intents may be created independently of
/// SwiftUI's view tree, so this tiny bridge gives the action the same backup
/// engine instead of constructing a second queue over the same files.
@available(iOS 16.0, *)
@MainActor
enum BackupShortcutBridge {
    static var coordinator: AutomaticBackupCoordinator?

    static func run() async -> String {
        guard let coordinator else {
            DiagnosticEventLog.shared.record(
                "shortcut",
                "Back Up Photos ran before the app finished starting, so nothing was done",
                level: .warning
            )
            return "请先打开一次照片备份应用，再重新运行该快捷指令。"
        }
        let summary = await coordinator.performShortcutBackup().summary
        return summary.prefix(1).uppercased() + summary.dropFirst()
    }
}

/// Runs in the background (`openAppWhenRun` is false) with the roughly 30
/// seconds iOS gives an App Intent; `AutomaticBackupCoordinator.shortcutBudget`
/// keeps the work inside that. `.alwaysAllowed` lets a personal automation run
/// while the iPhone is locked — the credential, the queue and the staged files
/// are all readable after the first unlock since restart.
@available(iOS 16.0, *)
struct BackUpPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "备份照片"
    static let description = IntentDescription(
        "查找照片备份中所选相簿的新照片和视频，并将其上传至 Google 相册。快捷指令结束后，上传仍可在后台继续。"
    )
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await BackupShortcutBridge.run()
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

@available(iOS 16.0, *)
struct PhotosBackupAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BackUpPhotosIntent(),
            phrases: [
                "Back up my photos with \(.applicationName)",
                "Start \(.applicationName) backup"
            ],
            shortTitle: "备份照片",
            systemImageName: "photo.badge.arrow.down"
        )
    }
}
