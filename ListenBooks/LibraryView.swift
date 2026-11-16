import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Library: lists EPUB files under Documents/Books, supports tap to open and import
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
                        "No Books",
                        systemImage: "book.closed",
                        description: Text("Copy EPUB files to “\(booksDirectory.path)” or tap “+” below to import.")
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
                            .accessibilityLabel("\(url.deletingPathExtension().lastPathComponent), tap to open")
                            .accessibilityHint("Load this EPUB novel and start listening")
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import book")
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
            .alert("Import Failed", isPresented: .constant(loadError != nil)) {
                Button("OK") { loadError = nil }
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
                    self.selectedBookURL = nil // reset to avoid re-trigger
                    BookStore.shared.currentBook = book
                    BookStore.shared.lastBookURL = url.path
                    BookStore.shared.resetProgress()
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
