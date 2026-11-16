import Foundation
import Fuzi
import Zip

/// EPUB parsing error types
enum EPUBError: Error, LocalizedError {
    case fileNotFound
    case unzipFailed(Error)
    case invalidStructure(String)
    case noChaptersFound
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "EPUB file not found"
        case .unzipFailed(let error):
            return "Failed to unzip EPUB: \(error.localizedDescription)"
        case .invalidStructure(let detail):
            return "Invalid EPUB structure: \(detail)"
        case .noChaptersFound:
            return "No chapters found"
        case .encodingFailed:
            return "Failed to read file encoding"
        }
    }
}

/// EPUB parser
/// Function: unzip EPUB, read container.xml / OPF, extract chapter plain text in spine order and split into sentences
enum EPUBParser {
    static let shared = EPUBParser()

    /// Parse a local EPUB file into a Book model
    /// - Parameter epubURL: EPUB file path
    /// - Returns: Book
    func parse(epubURL: URL) throws -> Book {
        guard FileManager.default.fileExists(atPath: epubURL.path) else {
            throw EPUBError.fileNotFound
        }

        // 1. Unzip to cache directory
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

        // 2. Read META-INF/container.xml to find OPF path
        let containerURL = bookFolder.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBError.invalidStructure("META-INF/container.xml not found")
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
            throw EPUBError.invalidStructure("Failed to parse container.xml")
        }

        guard let rootfile = containerDoc.css("rootfile").first?.attr("full-path") else {
            throw EPUBError.invalidStructure("rootfile not found")
        }

        let opfURL = bookFolder.appendingPathComponent(rootfile)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBError.invalidStructure("OPF file not found: \(rootfile)")
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
            throw EPUBError.invalidStructure("Failed to parse OPF")
        }

        // Base directory (directory containing the OPF, used to resolve relative paths)
        let baseURL = opfURL.deletingLastPathComponent()

        // 3. Parse metadata (title / creator)
        let metadata = opfDoc.root.firstChild(tag: "metadata")
        let title = metadata?.children.first(where: { $0.tag == "dc:title" })?.stringValue
            ?? epubURL.deletingPathExtension().lastPathComponent
        let author = metadata?.children.first(where: { $0.tag == "dc:creator" })?.stringValue ?? "Unknown Author"

        // 4. Parse manifest, build id -> path mapping
        var manifest: [String: String] = [:]
        for item in opfDoc.css("manifest item") {
            if let id = item.attr("id"), let href = item.attr("href") {
                manifest[id] = href
            }
        }

        // 5. Parse spine, take chapter ids in order
        var spineIDs: [String] = []
        for itemref in opfDoc.css("spine itemref") {
            if let idref = itemref.attr("idref") {
                spineIDs.append(idref)
            }
        }

        // 6. Parse each chapter XHTML, extract plain text and split into sentences
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

            // Remove script / style
            for node in htmlDoc.css("script, style") {
                node.removeFromParent()
            }
            let rawText = htmlDoc.root?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawText.isEmpty else { continue }

            let sentences = splitIntoSentences(rawText)
            guard !sentences.isEmpty else { continue }

            let chapterTitle = "Chapter \(index + 1)"
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

    /// Simple sentence splitting by punctuation, supports common Chinese/English/Japanese/Korean punctuation
    private func splitIntoSentences(_ text: String) -> [String] {
        // Compress consecutive whitespace first
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        // Splitting regex: Chinese/English period, question mark, exclamation mark, semicolon, newline etc.
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

        // Filter out too-short sentences (less than 2 characters usually noise), but keep at least one
        let filtered = sentences.filter { $0.count >= 2 }
        return filtered.isEmpty ? sentences : filtered
    }
}
