import SwiftUI
import AVFoundation

/// 阅读器：护眼背景 + 黑色文字，以听为主，音量键控制上一句/下一句
struct ReaderView: View {
    @StateObject private var speech = SpeechManager.shared
    @StateObject private var bookStore = BookStore.shared
    @StateObject private var volume = VolumeKeyHandler.shared

    @State private var showingChapterPicker = false
    @State private var showingSettings = false
    @State private var isRestoring = false

    // 护眼背景色（米黄），黑色文字
    private let bgColor = Color(red: 0.97, green: 0.95, blue: 0.88)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if let book = bookStore.currentBook {
                content(for: book)
            } else if isRestoring {
                VStack {
                    ProgressView("恢复上次阅读进度…")
                        .foregroundColor(.black)
                }
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
            // 顶部信息栏 + 设置入口
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.title2.bold())
                        .foregroundColor(.black)
                        .accessibilityLabel("书名：\(book.title)")
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("作者：\(book.author)")
                    let progress = "第 \(speech.currentChapterIndex + 1) 章 · 第 \(speech.currentSentenceIndex + 1) 句"
                    Text(progress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("当前进度：\(progress)")
                }
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                .accessibilityLabel("设置")
                .accessibilityHint("调整语言、语速和音量")
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
                    .accessibilityLabel("准备就绪，点击播放按钮开始听书")
            } else {
                ScrollView {
                    Text(speech.currentSentence)
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.black)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                        .accessibilityLabel("当前句子：\(speech.currentSentence)")
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
                    .accessibilityLabel("上一句")
                    .accessibilityHint("音量减键同样可以上一句")

                    Button {
                        togglePlay(book: book)
                    } label: {
                        Image(systemName: speech.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(speech.isSpeaking ? "暂停" : "播放")
                    .accessibilityHint("点击暂停或继续朗读当前句子")

                    Button {
                        speech.nextSentence(book: bookStore.currentBook!)
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("下一句")
                    .accessibilityHint("音量加键同样可以下一句")
                }

                Text("音量键：上一句 / 下一句  ·  锁屏后可用锁屏媒体控制")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("音量键控制上一句下一句，锁屏后使用系统媒体控制")
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

    /// 启动时尝试恢复上次阅读进度
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

    /// 进度持久化：每当章节或句子切换时保存
    private func observeProgress() {
        // 通过 onReceive 监听 speech 的章节/句子变化，写入 BookStore
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
                            SpeechManager.shared.speak(book: book, chapterIndex: index, sentenceIndex: 0)
                            BookStore.shared.lastChapterIndex = index
                            BookStore.shared.lastSentenceIndex = 0
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.chapters[index].title)
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .accessibilityLabel("\(book.chapters[index].title)，共 \(book.chapters[index].sentences.count) 句")
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
}
