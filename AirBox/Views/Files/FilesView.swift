import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct FilesView: View {
    @State private var files: [MediaFile] = MediaStorage.loadFiles()
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var previewURL: URL?
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    private var filteredFiles: [MediaFile] { searchText.isEmpty ? files : files.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }

    var body: some View {
        ZStack {
            AppBackground()
            if files.isEmpty {
                EmptyStateView(icon: "folder", title: "Нет файлов", subtitle: "Импортируй документы, изображения\nи другие файлы", actionTitle: "Импортировать файл") { showImporter = true }
            } else {
                fileList
            }
        }
        .navigationTitle("Файлы")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск файлов")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CircleIconButton(systemImage: "plus") { showImporter = true } } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { importFiles($0) }
        .sheet(item: $previewURL) { url in
            QuickLookPreview(url: url)
                .ignoresSafeArea()
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
        }
        .alert("Файл недоступен", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "Неизвестная ошибка") }
    }

    private var fileList: some View {
        List {
            ForEach(filteredFiles) { file in
                Button { open(file) } label: {
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
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { open(file) } label: { Label("Открыть", systemImage: "eye") }
                    Button { share(file) } label: { Label("Поделиться", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { delete(file) } label: { Label("Удалить", systemImage: "trash") }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete { offsets in
                for item in offsets.map({ filteredFiles[$0] }) { delete(item) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func open(_ file: MediaFile) {
        guard let url = file.localURL, FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Файл не найден в хранилище AirBox. Импортируй его заново."
            return
        }
        previewURL = url
    }

    private func share(_ file: MediaFile) {
        guard let url = file.localURL, FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Файл не найден в хранилище AirBox."
            return
        }
        shareURL = url
    }

    private func delete(_ item: MediaFile) {
        MediaStorage.deleteFile(named: item.fileName, in: MediaStorage.filesDirectory)
        files.removeAll { $0.id == item.id }
        MediaStorage.saveFiles(files)
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let directory = MediaStorage.filesDirectory else { return }
        for sourceURL in urls {
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            guard let copied = try? MediaStorage.copyFile(from: sourceURL, to: directory) else { continue }
            files.insert(MediaFile(name: sourceURL.deletingPathExtension().lastPathComponent, fileName: copied.fileName, fileExtension: sourceURL.pathExtension, fileSize: copied.fileSize), at: 0)
        }
        MediaStorage.saveFiles(files)
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
