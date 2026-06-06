import Foundation

struct PhotoImportCandidate: Equatable {
    var name: String
    var contentType: String
    var size: Int
}

enum WorkPhotoCategory: String, CaseIterable, Codable, Identifiable {
    case all = "전체"
    case unclassified = "미분류"
    case site = "현장사진"
    case receipt = "영수증"
    case meeting = "회의"
    case document = "문서"
    case equipment = "장비"
    case safety = "안전 점검"

    var id: String { rawValue }
}

enum WorkPhotoStatus: String, CaseIterable, Codable, Identifiable {
    case all = "전체"
    case unclassified = "미분류"
    case review = "검토"
    case done = "제출완료"

    var id: String { rawValue }
}

struct WorkPhotoRecord: Identifiable, Codable, Equatable {
    var id: String
    var fileName: String
    var siteName: String
    var category: WorkPhotoCategory
    var status: WorkPhotoStatus
    var assignee: String
    var memo: String
    var tags: [String]
    var size: Int
    var createdAt: Date
}

struct WorkPhotoExportPayload: Codable, Equatable {
    var exportedAt: Date
    var total: Int
    var items: [WorkPhotoExportItem]
}

struct WorkPhotoExportItem: Codable, Equatable {
    var id: String
    var fileName: String
    var siteName: String
    var category: String
    var status: String
    var assignee: String
    var memo: String
    var tags: [String]
    var size: Int
    var createdAt: Date
    var suggestedName: String
}

enum PhotoOrganizerDomain {
    static let allowedContentTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]
    static let maxImageBytes = 20 * 1024 * 1024

    static func normalize(files: [PhotoImportCandidate], now: Date = Date()) -> [WorkPhotoRecord] {
        files.enumerated().compactMap { index, file in
            guard allowedContentTypes.contains(file.contentType), file.size > 0, file.size <= maxImageBytes else {
                return nil
            }
            return WorkPhotoRecord(
                id: stableID(name: file.name, size: file.size, index: index),
                fileName: sanitizedText(file.name),
                siteName: "신규 업무",
                category: .unclassified,
                status: .unclassified,
                assignee: "",
                memo: "",
                tags: [],
                size: file.size,
                createdAt: now
            )
        }
    }

    static func filter(
        _ records: [WorkPhotoRecord],
        query: String,
        status: WorkPhotoStatus,
        category: WorkPhotoCategory
    ) -> [WorkPhotoRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return records.filter { record in
            let statusMatches = status == .all || record.status == status
            let categoryMatches = category == .all || record.category == category
            let queryMatches = normalizedQuery.isEmpty || [
                record.fileName,
                record.siteName,
                record.category.rawValue,
                record.status.rawValue,
                record.assignee,
                record.memo,
                record.tags.joined(separator: " ")
            ].contains { $0.lowercased().contains(normalizedQuery) }
            return statusMatches && categoryMatches && queryMatches
        }
    }

    static func exportPayload(records: [WorkPhotoRecord], exportedAt: Date = Date()) -> WorkPhotoExportPayload {
        let items = records.map { record in
            WorkPhotoExportItem(
                id: record.id,
                fileName: record.fileName,
                siteName: record.siteName,
                category: record.category.rawValue,
                status: record.status.rawValue,
                assignee: record.assignee,
                memo: record.memo,
                tags: record.tags,
                size: record.size,
                createdAt: record.createdAt,
                suggestedName: [
                    safeFileSegment(record.siteName.isEmpty ? "현장미지정" : record.siteName),
                    safeFileSegment(record.category.rawValue),
                    safeFileSegment(record.fileName)
                ].joined(separator: "__")
            )
        }
        return WorkPhotoExportPayload(exportedAt: exportedAt, total: items.count, items: items)
    }

    static func sanitizedText(_ value: String) -> String {
        value
            .filter { character in
                !character.isNewline &&
                    character.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } &&
                    !"<>&\"'`".contains(character)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseTags(_ value: String) -> [String] {
        value
            .split { $0 == "," || $0 == "#" }
            .map { sanitizedText(String($0)) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, tag in
                if !result.contains(tag) {
                    result.append(tag)
                }
            }
    }

    private static func stableID(name: String, size: Int, index: Int) -> String {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(size)
        hasher.combine(index)
        return "photo-\(abs(hasher.finalize()))"
    }

    private static func safeFileSegment(_ value: String) -> String {
        let replaced = value.map { character in
            "\\/:*?\"<>| ".contains(character) ? "_" : character
        }
        let collapsed = String(replaced).replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "미지정" : trimmed
    }
}
