import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @State private var files: [MediaFile] = MediaStorage.loadFiles()
    @State private var showImporter = false
    @State private var searchText = ""
    private var filteredFiles: [MediaFile] { searchText.isEmpty ? files : files.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }

    var body: some View {
        ZStack {
            AppBackground()
            if files.isEmpty {
                EmptyStateView(icon: "folder", title: "Нет файлов", subtitle: "Импортируй документы, изображения\nи другие файлы", actionTitle: "Импортировать файл") { showImporter = true }
            } else { fileList }
        }
        .navigationTitle("Файлы").navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск файлов")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CircleIconButton(systemImage: "plus") { showImporter = true } } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { importFiles($0) }
    }

    private var fileList: some View {
        List {
            ForEach(filteredFiles) { file in
                HStack(spacing: AppTheme.spacingM) {
                    MediaThumbnail(systemImage: file.sfSymbol)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                        HStack(spacing: 8) {
                            InfoChip(icon: "doc", text: file.fileExtension.uppercased())
                            if let size = file.formattedSize { InfoChip(icon: "internaldrive", text: size) }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.textTertiary)
                }
                .cardStyle()
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete { offsets in
                for item in offsets.map({ filteredFiles[$0] }) { MediaStorage.deleteFile(named: item.fileName, in: MediaStorage.filesDirectory); files.removeAll { $0.id == item.id } }
                MediaStorage.saveFiles(files)
            }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let directory = MediaStorage.filesDirectory else { return }
        for sourceURL in urls {
            let accessing = sourceURL.startAccessingSecurityScopedResource(); defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            guard let copied = try? MediaStorage.copyFile(from: sourceURL, to: directory) else { continue }
            files.insert(MediaFile(name: sourceURL.deletingPathExtension().lastPathComponent, fileName: copied.fileName, fileExtension: sourceURL.pathExtension, fileSize: copied.fileSize), at: 0)
        }
        MediaStorage.saveFiles(files)
    }
}
