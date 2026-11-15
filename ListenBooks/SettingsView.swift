import SwiftUI
import AVFoundation

/// 最小设置页：语言、语速、音量、关于
struct SettingsView: View {
    @StateObject private var speech = SpeechManager.shared
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var volume = VolumeKeyHandler.shared

    /// 可选语言列表（显示名 -> 语言代码）
    private let languages: [(String, String)] = [
        ("中文（简体）", "zh-CN"),
        ("英文", "en-US"),
        ("日文", "ja-JP"),
        ("韩文", "ko-KR"),
        ("自动检测", "auto")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("语音合成")) {
                    Picker("默认语言", selection: $bookStore.preferredLanguage) {
                        ForEach(languages, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                    .onChange(of: bookStore.preferredLanguage) { newValue in
                        speech.preferredLanguage = newValue
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("语速")
                            Spacer()
                            Text(String(format: "%.2f", speech.speechRate))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $speech.speechRate, in: 0.1...1.0, step: 0.05)
                            .onChange(of: speech.speechRate) { newValue in
                                bookStore.speechRate = newValue
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("固定音量")
                            Spacer()
                            Text(String(format: "%.0f%%", volume.fixedVolume * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $volume.fixedVolume, in: 0.1...1.0, step: 0.05)
                            .onChange(of: volume.fixedVolume) { newValue in
                                bookStore.fixedVolume = newValue
                            }
                    }
                }

                Section(header: Text("操作说明")) {
                    Text("前台：设备侧边音量 + 下一句，音量 - 上一句。音量会自动重置为固定值。")
                    Text("锁屏后：使用锁屏界面的“上一首 / 下一首 / 播放 / 暂停”按钮控制听书。")
                    Text("仅支持 EPUB 格式，请将书籍放入 App 的 Documents/Books 目录，或在书库页导入。")
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("许可证")
                        Spacer()
                        Text("MIT").foregroundColor(.secondary)
                    }
                    Link("GitHub 开源项目", destination: URL(string: "https://github.com/LightYagami1990/Flowver")!)
                }
            }
            .navigationTitle("设置")
        }
        .onAppear {
            // 同步当前值到 SpeechManager
            speech.speechRate = bookStore.speechRate
            speech.preferredLanguage = bookStore.preferredLanguage
            volume.fixedVolume = bookStore.fixedVolume
        }
    }
}
