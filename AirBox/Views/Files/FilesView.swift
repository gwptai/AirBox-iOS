import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @State private var files: [MediaFile] = MediaStorage.loadFiles()
    @State private var showImporter = false
    @State private var searchText = ""

    private var filteredFiles: [MediaFile] {
        guard !searchText.isEmpty else { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if files.isEmpty { emptyView } else { fileList }
        }
        .navigationTitle("Файлы")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск файлов")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showImporter = true } label: {
                    Image(systemName: "plus").foregroundColor(.white)
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill").font(.system(size: 64)).foregroundColor(.gray)
            Text("Нет файлов").font(.title2.weight(.semibold)).foregroundColor(.white)
            Text("Нажми + чтобы импортировать файл").font(.subheadline).foregroundColor(.gray)
        }
    }

    private var fileList: some View {
        List {
            ForEach(filteredFiles) { file in
                HStack(spacing: 14) {
                    Image(systemName: file.sfSymbol)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name).foregroundColor(.white).fontWeight(.medium).lineLimit(1)
                        HStack(spacing: 8) {
                            Text(file.fileExtension.uppercased())
                            if let size = file.formattedSize { Text(size) }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                let items = offsets.map { filteredFiles[$0] }
                for item in items {
                    MediaStorage.deleteFile(named: item.fileName, in: MediaStorage.filesDirectory)
                    files.removeAll { $0.id == item.id }
                }
                MediaStorage.saveFiles(files)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let directory = MediaStorage.filesDirectory else { return }

        for sourceURL in urls {
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            guard let copied = try? MediaStorage.copyFile(from: sourceURL, to: directory) else { continue }

            let ext = sourceURL.pathExtension
            let item = MediaFile(
                name: sourceURL.deletingPathExtension().lastPathComponent,
                fileName: copied.fileName,
                fileExtension: ext,
                fileSize: copied.fileSize
            )
            files.insert(item, at: 0)
        }
        MediaStorage.saveFiles(files)
    }
}
