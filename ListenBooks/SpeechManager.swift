import Foundation
import AVFoundation

/// 系统语音管理器，基于 AVSpeechSynthesizer
/// 支持中文（zh-CN）、英文（en-US）、日语（ja-JP）、韩语（ko-KR）
final class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentSentence = ""
    @Published var currentUtterance: AVSpeechUtterance?

    /// 当前播放进度（章节索引，句子索引）
    @Published var currentChapterIndex: Int = 0
    @Published var currentSentenceIndex: Int = 0

    /// 播放队列：(章节索引, 句子索引, 文本)
    private var queue: [(Int, Int, String)] = []
    private var queueIndex = 0

    /// 默认语言，可根据文本自动切换
    var preferredLanguage: String = "zh-CN" {
        didSet { updateAudioSessionCategory() }
    }

    /// 语速（0.1 ~ 1.0）
    var speechRate: Float = 0.45

    private override init() {
        super.init()
        synthesizer.delegate = self
        updateAudioSessionCategory()
    }

    private func updateAudioSessionCategory() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SpeechManager: 设置音频会话失败 \(error)")
        }
    }

    /// 自动检测文本所属语言，返回语言代码
    static func detectLanguage(for text: String) -> String {
        guard let first = text.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "zh-CN" }
        let scalar = String(first).unicodeScalars.first!
        let value = scalar.value

        // 中文统一表意文字
        if (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value) {
            return "zh-CN"
        }
        // 日文假名
        if (0x3040...0x309F).contains(value) || (0x30A0...0x30FF).contains(value) {
            return "ja-JP"
        }
        // 韩文
        if (0xAC00...0xD7AF).contains(value) || (0x1100...0x11FF).contains(value) {
            return "ko-KR"
        }
        // Default to English
        return "en-US"
    }

    /// 播发一本书的某一章，从指定句子开始
    func speak(book: Book, chapterIndex: Int, sentenceIndex: Int = 0) {
        stop()

        guard chapterIndex >= 0, chapterIndex < book.chapters.count else { return }
        let chapter = book.chapters[chapterIndex]
        guard sentenceIndex >= 0, sentenceIndex < chapter.sentences.count else { return }

        currentChapterIndex = chapterIndex
        currentSentenceIndex = sentenceIndex

        buildQueue(book: book, startChapter: chapterIndex, startSentence: sentenceIndex)
        queueIndex = 0
        speakNextInQueue()
    }

    /// 播发下一句（当前章节下一句，或下一章第一句）
    func nextSentence(book: Book) {
        var nextChapter = currentChapterIndex
        var nextSentence = currentSentenceIndex + 1

        if nextSentence >= book.chapters[nextChapter].sentences.count {
            nextChapter += 1
            nextSentence = 0
            if nextChapter >= book.chapters.count {
                // 已读完，停止
                stop()
                return
            }
        }

        speak(book: book, chapterIndex: nextChapter, sentenceIndex: nextSentence)
    }

    /// 播发上一句
    func previousSentence(book: Book) {
        var prevChapter = currentChapterIndex
        var prevSentence = currentSentenceIndex - 1

        if prevSentence < 0 {
            prevChapter -= 1
            if prevChapter < 0 {
                prevChapter = 0
                prevSentence = 0
            } else {
                prevSentence = book.chapters[prevChapter].sentences.count - 1
            }
        }

        speak(book: book, chapterIndex: prevChapter, sentenceIndex: prevSentence)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        queue.removeAll()
        queueIndex = 0
        isSpeaking = false
        currentSentence = ""
        currentUtterance = nil
    }

    // MARK: - 私有

    private func buildQueue(book: Book, startChapter: Int, startSentence: Int) {
        queue.removeAll()
        for c in startChapter..<book.chapters.count {
            let start = (c == startChapter) ? startSentence : 0
            for s in start..<book.chapters[c].sentences.count {
                queue.append((c, s, book.chapters[c].sentences[s]))
            }
        }
    }

    private func speakNextInQueue() {
        guard queueIndex < queue.count else {
            isSpeaking = false
            currentSentence = ""
            return
        }

        let (chapter, sentence, text) = queue[queueIndex]
        currentChapterIndex = chapter
        currentSentenceIndex = sentence
        currentSentence = text

        let lang = SpeechManager.detectLanguage(for: text)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if speechRate > 0 {
            utterance.rate = speechRate
        }
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        currentUtterance = utterance

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        queueIndex += 1
        if queueIndex < queue.count {
            speakNextInQueue()
        } else {
            isSpeaking = false
            currentSentence = ""
            currentUtterance = nil
        }
        saveProgress()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        currentUtterance = utterance
        isSpeaking = true
        saveProgress()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if utterance === currentUtterance {
            isSpeaking = false
            currentSentence = ""
            currentUtterance = nil
        }
        saveProgress()
    }

    /// 将当前章节/句子进度写入 BookStore 持久化
    private func saveProgress() {
        guard let bookURL = BookStore.shared.lastBookURL,
              BookStore.shared.currentBook != nil else { return }
        BookStore.shared.lastChapterIndex = currentChapterIndex
        BookStore.shared.lastSentenceIndex = currentSentenceIndex
    }
}
