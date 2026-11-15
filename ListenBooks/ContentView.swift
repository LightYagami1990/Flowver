import SwiftUI

/// 主入口：底部分栏，书库 + 当前听书
struct ContentView: View {
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
        }
        .tint(.black)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
