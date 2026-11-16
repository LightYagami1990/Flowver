import SwiftUI
import AVFoundation

/// Reader: eye-care background + black text, listening-first, volume keys control previous/next sentence
struct ReaderView: View {
    @StateObject private var speech = SpeechManager.shared
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var volume = VolumeKeyHandler.shared

    @State private var showingChapterPicker = false
    @State private var showingSettings = false
    @State private var isRestoring = false

    // Eye-care background color (cream), black text
    private let bgColor = Color(red: 0.97, green: 0.95, blue: 0.88)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if let book = bookStore.currentBook {
                content(for: book)
            } else if isRestoring {
                VStack {
                    ProgressView("Restoring last progress…")
                        .foregroundColor(.black)
                }
            } else {
                ContentUnavailableView(
                    "No Book Selected",
                    systemImage: "book",
                    description: Text("Please select an EPUB novel from the library")
                )
            }
        }
        .onAppear {
            setupVolumeKeys()
            restoreProgressIfNeeded()
        }
        .onDisappear {
            teardownVolumeKeys()
        }
        .sheet(isPresented: $showingChapterPicker) {
            ChapterPickerView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    @ViewBuilder
    private func content(for book: Book) -> some View {
        VStack(spacing: 0) {
            // Top info bar + settings entry
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.title2.bold())
                        .foregroundColor(.black)
                        .accessibilityLabel("Title: \(book.title)")
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Author: \(book.author)")
                    let progress = "Chapter \(speech.currentChapterIndex + 1) · Sentence \(speech.currentSentenceIndex + 1)"
                    Text(progress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Progress: \(progress)")
                }
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Adjust language, speech rate, and volume")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 10)

            // Main text: current sentence
            if speech.currentSentence.isEmpty {
                Text("Ready. Tap play to start listening")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Ready. Tap the play button to start listening")
            } else {
                ScrollView {
                    Text(speech.currentSentence)
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.black)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                        .accessibilityLabel("Current sentence: \(speech.currentSentence)")
                }
            }

            Spacer(minLength: 10)

            // Control bar
            VStack(spacing: 14) {
                HStack(spacing: 20) {
                    Button {
                        speech.previousSentence(book: bookStore.currentBook!)
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous sentence")
                    .accessibilityHint("Volume down key also goes to previous sentence")

                    Button {
                        togglePlay(book: book)
                    } label: {
                        Image(systemName: speech.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(speech.isSpeaking ? "Pause" : "Play")
                    .accessibilityHint("Tap to pause or continue reading the current sentence")

                    Button {
                        speech.nextSentence(book: bookStore.currentBook!)
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next sentence")
                    .accessibilityHint("Volume up key also goes to next sentence")
                }

                Text("Volume keys: Previous / Next sentence  ·  Lock screen media controls also work")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Volume keys control previous and next sentence; lock screen media controls also work")
            }
            .padding(.bottom, 30)
        }
    }

    private func togglePlay(book: Book) {
        if speech.isSpeaking {
            speech.pause()
        } else {
            let chapter = speech.currentChapterIndex
            let sentence = speech.currentSentenceIndex
            speech.speak(book: book, chapterIndex: chapter, sentenceIndex: sentence)
        }
    }

    /// On launch, try to restore last reading progress
    private func restoreProgressIfNeeded() {
        guard let book = bookStore.currentBook,
              let lastURL = bookStore.lastBookURL,
              lastURL == book.epubURL.path else { return }

        isRestoring = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let chapter = min(max(bookStore.lastChapterIndex, 0), book.chapters.count - 1)
            let sentence = min(max(bookStore.lastSentenceIndex, 0), book.chapters[chapter].sentences.count - 1)
            speech.speak(book: book, chapterIndex: chapter, sentenceIndex: sentence)
            isRestoring = false
        }
    }

    private func setupVolumeKeys() {
        volume.fixedVolume = bookStore.fixedVolume
        volume.onVolumeUp = {
            guard let book = bookStore.currentBook else { return }
            speech.nextSentence(book: book)
        }
        volume.onVolumeDown = {
            guard let book = bookStore.currentBook else { return }
            speech.previousSentence(book: book)
        }
        volume.startListening()
    }

    private func teardownVolumeKeys() {
        volume.onVolumeUp = nil
        volume.onVolumeDown = nil
    }
}

/// Chapter picker (minimal, for chapter jumping only)
struct ChapterPickerView: View {
    @StateObject private var bookStore = BookStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let book = bookStore.currentBook {
                    List(book.chapters.indices, id: \.self) { index in
                        Button {
                            SpeechManager.shared.speak(book: book, chapterIndex: index, sentenceIndex: 0)
                            BookStore.shared.lastChapterIndex = index
                            BookStore.shared.lastSentenceIndex = 0
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.chapters[index].title)
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .accessibilityLabel("\(book.chapters[index].title), \(book.chapters[index].sentences.count) sentences")
                                Text("\(book.chapters[index].sentences.count) sentences")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ContentUnavailableView("No Books", systemImage: "book")
                }
            }
            .navigationTitle("Select Chapter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
