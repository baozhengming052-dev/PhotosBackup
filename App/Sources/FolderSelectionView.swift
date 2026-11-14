import Photos
import SwiftUI
import UIKit

struct FolderSelectionView: View {
    @EnvironmentObject private var albums: PhotoAlbumStore
    @EnvironmentObject private var preferences: BackupPreferences
    @EnvironmentObject private var queue: UploadQueue
    @Environment(\.openURL) private var openURL
    @State private var searchText = ""

    private func refreshBackedUpCounts() {
        albums.refreshBackedUpCounts(for: preferences.selectedAlbumIDs,
                                     isBackedUp: queue.backedUpAssetLookup())
    }

    private var filteredAlbums: [PhotoAlbum] {
        guard !searchText.isEmpty else { return albums.albums }
        return albums.albums.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            Group {
                if albums.authorization == .notDetermined {
                    permissionState
                } else if !albums.canRead {
                    deniedState
                } else if albums.isLoading {
                    ProgressView("正在加载相簿…")
                } else if albums.albums.isEmpty {
                    EmptyState(symbol: "rectangle.stack", title: "未找到相簿", message: "这里会显示苹果“照片”中的相簿。")
                } else {
                    albumList
                }
            }
            .background(BackupTheme.background)
            .navigationTitle("相簿")
            .searchable(text: $searchText, prompt: "搜索相簿")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(preferences.selectedAlbumIDs.count) selected")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .onAppear {
                albums.refreshInBackground()
                refreshBackedUpCounts()
            }
            .onChange(of: preferences.selectedAlbumIDs) { _ in refreshBackedUpCounts() }
            .onChange(of: albums.albums) { _ in refreshBackedUpCounts() }
            // The completion ledger, not the rows: `items` changes on every
            // progress tick, and each of those kicked off a fresh enumeration of
            // every asset in every selected album. Only a finished upload can
            // move a "已备份 N / M 项" count.
            .onChange(of: queue.completedSourceKeys) { _ in refreshBackedUpCounts() }
        }
        .navigationViewStyle(.stack)
    }

    private var albumList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if albums.isLimited { limitedAccessBanner }
                HStack(spacing: 10) {
                    Image(systemName: preferences.automaticBackup ? "arrow.triangle.2.circlepath.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(preferences.automaticBackup ? .green : .orange)
                    Text(preferences.automaticBackup ? "所选相簿将自动备份" : "自动备份已暂停")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                .padding(14)
                .background((preferences.automaticBackup ? Color.green : Color.orange).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 4)

                ForEach(filteredAlbums) { album in
                    AlbumSelectionRow(album: album,
                                      isSelected: preferences.selectedAlbumIDs.contains(album.id),
                                      backedUpCount: albums.backedUpCounts[album.id]) {
                        preferences.toggle(albumID: album.id)
                    }
                }
            }
            .padding(16)
        }
    }

    /// Under limited access every PhotoKit fetch is scoped to the assets the
    /// user hand-picked, so "所有照片" can read as a few dozen items with no
    /// explanation. Say so, and offer the way to change it.
    private var limitedAccessBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "photo.badge.checkmark").foregroundStyle(.orange)
                Text("照片访问权限受限").font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("只能查看您授权访问的照片，因此这里的数量不代表整个图库。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("前往设置更改") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 4)
    }

    private var permissionState: some View {
        VStack(spacing: 18) {
            Spacer()
            EmptyState(symbol: "photo.on.rectangle.angled", title: "查看相簿", message: "允许访问照片后，才能选择要备份的相簿。")
            Button("允许访问照片") { Task { await albums.requestAccess() } }
                .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 24)
            Spacer()
        }
    }

    private var deniedState: some View {
        VStack(spacing: 18) {
            Spacer()
            EmptyState(symbol: "photo.badge.exclamationmark", title: "照片访问权限未开启", message: "请前往设置允许访问照片，以选择相簿并进行备份。")
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 24)
            Spacer()
        }
    }
}
