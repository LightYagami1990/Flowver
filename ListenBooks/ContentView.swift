import SwiftUI

/// 主入口：底部分栏，书库 + 当前听书 + 设置
struct ContentView: View {
    @StateObject private var bookStore = BookStore.shared

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Image(systemName: "bookshelf.fill")
                    Text("书库")
                }

            ReaderView()
                .tabItem {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("听书")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
        }
        .tint(.black)
        .onAppear {
            // 启动时若有上次书籍路径，自动尝试恢复（在 ReaderView 内部也会处理）
            restoreLastBookIfNeeded()
        }
    }

    /// 若当前无书且有上次路径，尝试重新解析并恢复
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
                print("Flowver: 恢复上次书籍失败 \(error)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
