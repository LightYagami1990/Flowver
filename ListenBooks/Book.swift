import Foundation
import UIKit

/// 一本书：EPUB 解析后的轻量模型
struct Book: Identifiable, Equatable {
    let id = UUID()
    /// 原始 EPUB 文件 URL
    let epubURL: URL
    /// 解压后的工作目录（缓存目录下）
    let workDirectory: URL
    let title: String
    let author: String
    let chapters: [Chapter]
}

/// 一个章节，内部已按“句子”切分好，供 TTS 逐句播放
struct Chapter: Identifiable, Equatable {
    let id = UUID()
    let title: String
    /// 原始 XHTML 内容（已提取纯文本）
    let text: String
    /// 按句子切分后的数组，每句作为一个 TTS 播发单元
    let sentences: [String]
}
