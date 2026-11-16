import SwiftUI
import AVFoundation

/// Minimal settings page: language, speech rate, volume, about
struct SettingsView: View {
    @StateObject private var speech = SpeechManager.shared
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var volume = VolumeKeyHandler.shared

    /// Available language list (display name -> language code)
    private let languages: [(String, String)] = [
        ("English", "en-US"),
        ("Chinese (Simplified)", "zh-CN"),
        ("Japanese", "ja-JP"),
        ("Korean", "ko-KR"),
        ("Auto-detect", "auto")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Speech Synthesis")) {
                    Picker("Default Language", selection: $bookStore.preferredLanguage) {
                        ForEach(languages, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                    .onChange(of: bookStore.preferredLanguage) { newValue in
                        speech.preferredLanguage = newValue
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
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
                            Text("Fixed Volume")
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

                Section(header: Text("How to Use")) {
                    Text("Foreground: press volume up for next sentence, volume down for previous sentence. Volume resets to fixed value automatically.")
                    Text("Lock screen: use the lock screen “Previous / Next / Play / Pause” media buttons to control listening.")
                    Text("EPUB format only. Place books in the app’s Documents/Books folder, or import from the library screen.")
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("License")
                        Spacer()
                        Text("MIT").foregroundColor(.secondary)
                    }
                    Link("GitHub Open Source Project", destination: URL(string: "https://github.com/LightYagami1990/Flowver")!)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            // Sync current values to SpeechManager
            speech.speechRate = bookStore.speechRate
            speech.preferredLanguage = bookStore.preferredLanguage
            volume.fixedVolume = bookStore.fixedVolume
        }
    }
}
