import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 书库：列出 Documents/Books 下的 EPUB 文件，支持点击打开、导入
struct LibraryView: View {
    @State private var books: [URL] = []
    @State private var showingImporter = false
    @State private var selectedBookURL: URL?
    @State private var isLoading = false
    @State private var loadError: String?

    let booksDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let booksDir = docs.appendingPathComponent("Books", isDirectory: true)
        self.booksDirectory = booksDir
        try? FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "暂无书籍",
                        systemImage: "book.closed",
                        description: Text("请将 EPUB 文件拷贝到 “\(booksDirectory.path)” 目录，或点击下方“导入”按钮添加。")
                    )
                } else {
                    List {
                        ForEach(books, id: \.self) { url in
                            Button {
                                selectedBookURL = url
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.black)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.body)
                                            .foregroundColor(.black)
                                        Text(url.path)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("书库")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType.ePub, UTType.zip],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .onChange(of: selectedBookURL) { newValue in
                if let url = newValue {
                    openBook(url)
                }
            }
            .onAppear {
                reloadBooks()
            }
            .alert("加载失败", isPresented: .constant(loadError != nil)) {
                Button("知道了") { loadError = nil }
            } message: {
                Text(loadError ?? "")
            }
        }
    }

    private func reloadBooks() {
        guard let enumerator = FileManager.default.enumerator(
            at: booksDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }
        var found: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "epub" {
                found.append(fileURL)
            }
        }
        books = found.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func openBook(_ url: URL) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let book = try EPUBParser.shared.parse(epubURL: url)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.selectedBookURL = nil // 重置，避免重复触发
                    // 通过环境对象或通知把 book 传给 ReaderView，这里用简单的全局共享
                    BookStore.shared.currentBook = book
                    // 由父级响应 navigation
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = error.localizedDescription
                }
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let source = urls.first else { return }
        do {
            let fileName = source.lastPathComponent
            let dest = booksDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
            reloadBooks()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// 简单的全局书籍共享，用于 LibraryView 和 ReaderView 之间传递
final class BookStore: ObservableObject {
    static let shared = BookStore()
    @Published var currentBook: Book?
    private init() {}
}
