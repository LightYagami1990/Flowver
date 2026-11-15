import Foundation
import Fuzi
import Zip

/// EPUB 解析错误类型
enum EPUBError: Error, LocalizedError {
    case fileNotFound
    case unzipFailed(Error)
    case invalidStructure(String)
    case noChaptersFound
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "EPUB 文件不存在"
        case .unzipFailed(let error):
            return "解压 EPUB 失败：\(error.localizedDescription)"
        case .invalidStructure(let detail):
            return "EPUB 结构无效：\(detail)"
        case .noChaptersFound:
            return "未解析到任何章节"
        case .encodingFailed:
            return "文件编码读取失败"
        }
    }
}

/// EPUB 解析器
/// 功能：解压 EPUB、读取 container.xml / OPF、按 spine 顺序提取章节纯文本并切分句子
enum EPUBParser {
    static let shared = EPUBParser()

    /// 从本地 EPUB 文件解析出 Book 模型
    /// - Parameter epubURL: EPUB 文件路径
    /// - Returns: Book
    func parse(epubURL: URL) throws -> Book {
        guard FileManager.default.fileExists(atPath: epubURL.path) else {
            throw EPUBError.fileNotFound
        }

        // 1. 解压到缓存目录
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let safeName = epubURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: " ", with: "_")
        let bookFolder = cacheDir.appendingPathComponent(safeName)
        try? FileManager.default.removeItem(at: bookFolder)
        try FileManager.default.createDirectory(at: bookFolder, withIntermediateDirectories: true)

        do {
            try Zip.unzipFile(epubURL, destination: bookFolder, overwrite: true, password: nil)
        } catch {
            throw EPUBError.unzipFailed(error)
        }

        // 2. 读取 META-INF/container.xml，找到 OPF 路径
        let containerURL = bookFolder.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBError.invalidStructure("未找到 META-INF/container.xml")
        }

        let containerData: Data
        do {
            containerData = try Data(contentsOf: containerURL)
        } catch {
            throw EPUBError.encodingFailed
        }

        let containerDoc: XMLDocument
        do {
            containerDoc = try XMLDocument(data: containerData)
        } catch {
            throw EPUBError.invalidStructure("container.xml 解析失败")
        }

        guard let rootfile = containerDoc.css("rootfile").first?.attr("full-path") else {
            throw EPUBError.invalidStructure("未找到 rootfile")
        }

        let opfURL = bookFolder.appendingPathComponent(rootfile)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBError.invalidStructure("OPF 文件不存在：\(rootfile)")
        }

        let opfData: Data
        do {
            opfData = try Data(contentsOf: opfURL)
        } catch {
            throw EPUBError.encodingFailed
        }

        let opfDoc: XMLDocument
        do {
            opfDoc = try XMLDocument(data: opfData)
        } catch {
            throw EPUBError.invalidStructure("OPF 解析失败")
        }

        // 基础目录（OPF 所在目录，用于解析相对路径）
        let baseURL = opfURL.deletingLastPathComponent()

        // 3. 解析 metadata（title / creator）
        let metadata = opfDoc.root.firstChild(tag: "metadata")
        let title = metadata?.children.first(where: { $0.tag == "dc:title" })?.stringValue
            ?? epubURL.deletingPathExtension().lastPathComponent
        let author = metadata?.children.first(where: { $0.tag == "dc:creator" })?.stringValue ?? "未知作者"

        // 4. 解析 manifest，建立 id -> 路径 映射
        var manifest: [String: String] = [:]
        for item in opfDoc.css("manifest item") {
            if let id = item.attr("id"), let href = item.attr("href") {
                manifest[id] = href
            }
        }

        // 5. 解析 spine，按顺序取出章节 id
        var spineIDs: [String] = []
        for itemref in opfDoc.css("spine itemref") {
            if let idref = itemref.attr("idref") {
                spineIDs.append(idref)
            }
        }

        // 6. 依次解析每个章节 XHTML，提取纯文本并切分句子
        var chapters: [Chapter] = []
        for (index, id) in spineIDs.enumerated() {
            guard let relativePath = manifest[id] else { continue }
            let chapterURL = baseURL.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: chapterURL.path) else { continue }

            let htmlData: Data
            do {
                htmlData = try Data(contentsOf: chapterURL)
            } catch {
                continue
            }

            let htmlDoc: HTMLDocument
            do {
                htmlDoc = try HTMLDocument(data: htmlData)
            } catch {
                continue
            }

            // 去掉 script / style
            for node in htmlDoc.css("script, style") {
                node.removeFromParent()
            }
            let rawText = htmlDoc.root?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawText.isEmpty else { continue }

            let sentences = splitIntoSentences(rawText)
            guard !sentences.isEmpty else { continue }

            let chapterTitle = "第 \(index + 1) 章"
            chapters.append(Chapter(title: chapterTitle, text: rawText, sentences: sentences))
        }

        guard !chapters.isEmpty else {
            throw EPUBError.noChaptersFound
        }

        return Book(
            epubURL: epubURL,
            workDirectory: bookFolder,
            title: title,
            author: author,
            chapters: chapters
        )
    }

    /// 简单按标点切分句子，支持中英日韩常见标点
    private func splitIntoSentences(_ text: String) -> [String] {
        // 先把连续空白压缩
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        // 切分正则：中英文句号、问号、感叹号、分号、换行等
        let pattern = #"([。！！？？\.!?;；\n\r]+)"#
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return [cleaned]
        }
        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        let parts = regex.components(separatedBy: cleaned, options: [], range: range)

        var sentences: [String] = []
        var buffer = ""
        for part in parts {
            if part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            let isDelimiter = part.range(of: #"^[。！！？？\.!?;；\n\r]+$"#, options: .regularExpression) != nil
            if isDelimiter {
                if !buffer.isEmpty {
                    buffer += part
                    sentences.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
                    buffer = ""
                }
            } else {
                buffer += part
            }
        }
        if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sentences.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // 过滤过短的句子（少于 2 个字符通常是噪声），但保留至少一句
        let filtered = sentences.filter { $0.count >= 2 }
        return filtered.isEmpty ? sentences : filtered
    }
}
