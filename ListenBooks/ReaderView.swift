import SwiftUI
import AVFoundation

/// 阅读器：护眼背景 + 黑色文字，以听为主，音量键控制上一句/下一句
struct ReaderView: View {
    @StateObject private var speech = SpeechManager.shared
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var volume = VolumeKeyHandler.shared

    @State private var showingChapterPicker = false
    @State private var isLoading = false

    // 护眼背景色（米黄），黑色文字
    private let bgColor = Color(red: 0.97, green: 0.95, blue: 0.88)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if let book = bookStore.currentBook {
                content(for: book)
            } else {
                ContentUnavailableView(
                    "未选择书籍",
                    systemImage: "book",
                    description: Text("请在书库中选择一本 EPUB 小说")
                )
            }
        }
        .onAppear {
            setupVolumeKeys()
        }
        .onDisappear {
            teardownVolumeKeys()
        }
        .sheet(isPresented: $showingChapterPicker) {
            ChapterPickerView()
        }
    }

    @ViewBuilder
    private func content(for book: Book) -> some View {
        VStack(spacing: 0) {
            // 顶部信息栏
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.title2.bold())
                    .foregroundColor(.black)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                let progress = "第 \(speech.currentChapterIndex + 1) 章 · 第 \(speech.currentSentenceIndex + 1) 句"
                Text(progress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 10)

            // 正文：当前句子
            if speech.currentSentence.isEmpty {
                Text("准备就绪，点击播放开始听书")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
            } else {
                ScrollView {
                    Text(speech.currentSentence)
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.black)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                }
            }

            Spacer(minLength: 10)

            // 操作栏
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

                    Button {
                        togglePlay(book: book)
                    } label: {
                        Image(systemName: speech.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        speech.nextSentence(book: bookStore.currentBook!)
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }

                Text("音量键：上一句 / 下一句  ·  长按暂停/继续")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

    private func setupVolumeKeys() {
        volume.fixedVolume = 0.5
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

/// 章节选择器（极简，仅供跳转章节用）
struct ChapterPickerView: View {
    @StateObject private var bookStore = BookStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let book = bookStore.currentBook {
                    List(book.chapters.indices, id: \.self) { index in
                        Button {
                            speechJump(to: index, in: book)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.chapters[index].title)
                                    .font(.body)
                                    .foregroundColor(.black)
                                Text("\(book.chapters[index].sentences.count) 句")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ContentUnavailableView("无书籍", systemImage: "book")
                }
            }
            .navigationTitle("选择章节")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func speechJump(to index: Int, in book: Book) {
        SpeechManager.shared.speak(book: book, chapterIndex: index, sentenceIndex: 0)
    }
}
