import SwiftUI

/// Main entry: bottom tabs — Library, Reader, Settings
struct ContentView: View {
    @StateObject private var bookStore = BookStore.shared

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Image(systemName: "bookshelf.fill")
                    Text("Library")
                }

            ReaderView()
                .tabItem {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Listen")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .tint(.black)
        .onAppear {
            // On launch, if there is a last book path, try to restore it (ReaderView also handles this)
            restoreLastBookIfNeeded()
        }
    }

    /// If no book currently and a last path exists, try to re-parse and restore
    private func restoreLastBookIfNeeded() {
        guard bookStore.currentBook == nil,
              let lastPath = bookStore.lastBookURL else { return }
        let url = URL(fileURLWithPath: lastPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let book = try EPUBParser.shared.parse(epubURL: url)
                DispatchQueue.main.async {
                    bookStore.currentBook = book
                }
            } catch {
                print("Flowver: Failed to restore last book \(error)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
