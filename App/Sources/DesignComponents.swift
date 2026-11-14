import SwiftUI

enum BackupTheme {
    static let blue = Color(uiColor: .systemBlue)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(BackupTheme.blue.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

/// Keeps card content legible when disabled while preserving a clear pressed state.
struct CardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .saturation(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct StatusPill: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct FeatureIcon: View {
    let symbol: String
    var color: Color = BackupTheme.blue
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

struct AppMark: View {
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [BackupTheme.blue, BackupTheme.blue.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "photo.stack.fill")
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: BackupTheme.blue.opacity(0.22), radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}

struct SafariTutorialCard: View {
    enum Scene {
        case signIn
        case enableExtension
        case connect
    }

    let scene: Scene

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "textformat.size")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                    Text(scene == .enableExtension ? "Safari 扩展" : "accounts.google.com")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                Image(systemName: "arrow.clockwise").font(.caption)
            }
            .padding(10)

            Divider()

            Group {
                switch scene {
                case .signIn: signInScene
                case .enableExtension: extensionScene
                case .connect: connectScene
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Image(systemName: "chevron.backward")
                Spacer()
                Image(systemName: "chevron.forward").foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                Spacer()
                Image(systemName: "book")
                Spacer()
                Image(systemName: "square.on.square")
            }
            .font(.body)
            .foregroundStyle(BackupTheme.blue)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(minHeight: 300)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.08)))
        .shadow(color: .black.opacity(0.09), radius: 18, y: 8)
        .padding(.horizontal, 24)
    }

    private var signInScene: some View {
        VStack(spacing: 16) {
            Text("G").font(.system(size: 34, weight: .medium)).foregroundStyle(BackupTheme.blue)
            Text("登录").font(.title3.weight(.semibold))
            Text("使用您的 Google 账号").font(.subheadline).foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.35))
                .frame(height: 44)
                .overlay(Text("邮箱或电话号码").font(.subheadline).foregroundStyle(.secondary), alignment: .leading)
                .padding(.horizontal, 30)
            Text("下一步")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 9)
                .background(BackupTheme.blue, in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(.vertical, 20)
    }

    private var extensionScene: some View {
        VStack(spacing: 10) {
            Text("扩展").font(.headline)
            Text("允许扩展自定义 Safari。").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                FeatureIcon(symbol: "photo.stack.fill", size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("照片备份连接")
                        .font(.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("已允许访问网站")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .layoutPriority(1)
                Spacer()
                Toggle("", isOn: .constant(true)).labelsHidden()
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            Text("开启扩展，然后返回 Safari。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 28)
    }

    private var connectScene: some View {
        VStack(spacing: 14) {
            HStack {
                FeatureIcon(symbol: "photo.stack.fill", size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("照片备份").font(.subheadline.weight(.semibold))
                    Text("Safari 扩展").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            Text("准备连接")
                .font(.title3.weight(.semibold))
            Text("我们会安全地将登录信息发送给照片备份应用。")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Label("连接账号", systemImage: "link")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(BackupTheme.blue, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
    }
}

struct SafariConnectionGuide: View {
    private let steps: [(String, String, String)] = [
        ("1", "登录并点击“我同意”", "完成 Google 登录页面。"),
        ("2", "打开 Safari 扩展菜单", "点击拼图图标或网页菜单图标。"),
        ("3", "选择“照片备份连接”", "在列表中打开照片备份扩展。"),
        ("4", "点击“连接到应用”", "等待出现绿色确认提示，然后返回。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "textformat.size").font(.caption.weight(.semibold))
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                    Text("accounts.google.com").font(.caption2)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.caption).foregroundStyle(BackupTheme.blue)
            }
            .padding(10)
            Divider()
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(item.0)
                            .font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(BackupTheme.blue, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1).font(.subheadline.weight(.semibold))
                            Text(item.2).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if index == steps.count - 1 {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 9)
                    if index < steps.count - 1 { Divider().padding(.leading, 38) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .frame(minHeight: 330)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.08)))
        .shadow(color: .black.opacity(0.09), radius: 18, y: 8)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}
