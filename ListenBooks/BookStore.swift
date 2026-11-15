import Foundation
import SwiftUI

/// 全局书籍与阅读状态共享，支持启动时恢复上次进度
final class BookStore: ObservableObject {
    static let shared = BookStore()

    /// 当前加载的书
    @Published var currentBook: Book?

    /// 上次阅读的 EPUB 文件路径（持久化）
    @Published var lastBookURL: String? {
        didSet { save() }
    }
    /// 上次阅读的章节索引（持久化）
    @Published var lastChapterIndex: Int = 0 {
        didSet { save() }
    }
    /// 上次阅读的句子索引（持久化）
    @Published var lastSentenceIndex: Int = 0 {
        didSet { save() }
    }
    /// 用户偏好语言（持久化）
    @Published var preferredLanguage: String = "zh-CN" {
        didSet { save() }
    }
    /// 语速（0.1 ~ 1.0，持久化）
    @Published var speechRate: Float = 0.45 {
        didSet { save() }
    }
    /// 固定音量（持久化）
    @Published var fixedVolume: Float = 0.5 {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let lastBookURL = "Flowver.lastBookURL"
        static let lastChapterIndex = "Flowver.lastChapterIndex"
        static let lastSentenceIndex = "Flowver.lastSentenceIndex"
        static let preferredLanguage = "Flowver.preferredLanguage"
        static let speechRate = "Flowver.speechRate"
        static let fixedVolume = "Flowver.fixedVolume"
    }

    private init() {
        load()
    }

    private func load() {
        lastBookURL = defaults.string(forKey: Keys.lastBookURL)
        lastChapterIndex = defaults.integer(forKey: Keys.lastChapterIndex)
        lastSentenceIndex = defaults.integer(forKey: Keys.lastSentenceIndex)
        preferredLanguage = defaults.string(forKey: Keys.preferredLanguage) ?? "zh-CN"
        speechRate = defaults.float(forKey: Keys.speechRate)
        if speechRate == 0 { speechRate = 0.45 }
        fixedVolume = defaults.float(forKey: Keys.fixedVolume)
        if fixedVolume == 0 { fixedVolume = 0.5 }
    }

    private func save() {
        defaults.set(lastBookURL, forKey: Keys.lastBookURL)
        defaults.set(lastChapterIndex, forKey: Keys.lastChapterIndex)
        defaults.set(lastSentenceIndex, forKey: Keys.lastSentenceIndex)
        defaults.set(preferredLanguage, forKey: Keys.preferredLanguage)
        defaults.set(speechRate, forKey: Keys.speechRate)
        defaults.set(fixedVolume, forKey: Keys.fixedVolume)
    }

    /// 清除阅读进度（切换书籍时调用）
    func resetProgress() {
        lastChapterIndex = 0
        lastSentenceIndex = 0
    }
}
