import Foundation

struct PhotoImportCandidate: Equatable {
    var name: String
    var contentType: String
    var size: Int
    var assetLocalIdentifier: String?
    var isScreenshot: Bool
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?

    init(
        name: String,
        contentType: String,
        size: Int,
        assetLocalIdentifier: String? = nil,
        isScreenshot: Bool = false,
        capturedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.name = name
        self.contentType = contentType
        self.size = size
        self.assetLocalIdentifier = assetLocalIdentifier
        self.isScreenshot = isScreenshot
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
    }
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

enum CaptureKind: String, CaseIterable, Codable, Identifiable {
    case all = "전체"
    case unknown = "미확인"
    case photo = "사진"
    case screenshot = "스크린샷"

    var id: String { rawValue }
}

enum ClassificationSource: String, CaseIterable, Codable, Identifiable {
    case unknown = "미분류"
    case manual = "수동"
    case screenshotMetadata = "스크린샷 메타데이터"
    case photoMetadataLocation = "위치 메타데이터"
    case workSchedule = "업무 시간"
    case shortcutWorkMode = "업무 모드"

    var id: String { rawValue }
}

struct WorkClassificationSettings: Codable, Equatable {
    var companyName: String
    var companyLatitude: Double?
    var companyLongitude: Double?
    var companyRadiusMeters: Double
    var workWeekdays: Set<Int>
    var workStartHour: Int
    var workEndHour: Int
    var locationClassificationEnabled: Bool
    var scheduleClassificationEnabled: Bool
    var workModeEnabled: Bool
    var timeZoneIdentifier: String

    init(
        companyName: String = "",
        companyLatitude: Double? = nil,
        companyLongitude: Double? = nil,
        companyRadiusMeters: Double = 300,
        workWeekdays: Set<Int> = Set(2...6),
        workStartHour: Int = 9,
        workEndHour: Int = 18,
        locationClassificationEnabled: Bool = false,
        scheduleClassificationEnabled: Bool = false,
        workModeEnabled: Bool = false,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.companyName = companyName
        self.companyLatitude = companyLatitude
        self.companyLongitude = companyLongitude
        self.companyRadiusMeters = companyRadiusMeters
        self.workWeekdays = workWeekdays
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.locationClassificationEnabled = locationClassificationEnabled
        self.scheduleClassificationEnabled = scheduleClassificationEnabled
        self.workModeEnabled = workModeEnabled
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName) ?? ""
        companyLatitude = try container.decodeIfPresent(Double.self, forKey: .companyLatitude)
        companyLongitude = try container.decodeIfPresent(Double.self, forKey: .companyLongitude)
        companyRadiusMeters = try container.decodeIfPresent(Double.self, forKey: .companyRadiusMeters) ?? 300
        workWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .workWeekdays) ?? Set(2...6)
        workStartHour = try container.decodeIfPresent(Int.self, forKey: .workStartHour) ?? 9
        workEndHour = try container.decodeIfPresent(Int.self, forKey: .workEndHour) ?? 18
        locationClassificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .locationClassificationEnabled) ?? false
        scheduleClassificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduleClassificationEnabled) ?? false
        workModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .workModeEnabled) ?? false
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) ?? TimeZone.current.identifier
    }
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
    var assetLocalIdentifier: String?
    var captureKind: CaptureKind
    var classificationSource: ClassificationSource
    var classifiedAt: Date?
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var isWorkCandidate: Bool
    var isConfirmedWork: Bool

    init(
        id: String,
        fileName: String,
        siteName: String,
        category: WorkPhotoCategory,
        status: WorkPhotoStatus,
        assignee: String,
        memo: String,
        tags: [String],
        size: Int,
        createdAt: Date,
        assetLocalIdentifier: String? = nil,
        captureKind: CaptureKind = .unknown,
        classificationSource: ClassificationSource = .manual,
        classifiedAt: Date? = nil,
        capturedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isWorkCandidate: Bool = false,
        isConfirmedWork: Bool = false
    ) {
        self.id = id
        self.fileName = fileName
        self.siteName = siteName
        self.category = category
        self.status = status
        self.assignee = assignee
        self.memo = memo
        self.tags = tags
        self.size = size
        self.createdAt = createdAt
        self.assetLocalIdentifier = assetLocalIdentifier
        self.captureKind = captureKind
        self.classificationSource = classificationSource
        self.classifiedAt = classifiedAt
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.isWorkCandidate = isWorkCandidate
        self.isConfirmedWork = isConfirmedWork
    }
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
    var captureKind: String?
    var classificationSource: String?
    var isWorkCandidate: Bool?
    var isConfirmedWork: Bool?

    init(
        id: String,
        fileName: String,
        siteName: String,
        category: String,
        status: String,
        assignee: String,
        memo: String,
        tags: [String],
        size: Int,
        createdAt: Date,
        suggestedName: String,
        captureKind: String? = nil,
        classificationSource: String? = nil,
        isWorkCandidate: Bool? = nil,
        isConfirmedWork: Bool? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.siteName = siteName
        self.category = category
        self.status = status
        self.assignee = assignee
        self.memo = memo
        self.tags = tags
        self.size = size
        self.createdAt = createdAt
        self.suggestedName = suggestedName
        self.captureKind = captureKind
        self.classificationSource = classificationSource
        self.isWorkCandidate = isWorkCandidate
        self.isConfirmedWork = isConfirmedWork
    }
}

enum PhotoOrganizerDomain {
    static let allowedContentTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]
    static let maxImageBytes = 20 * 1024 * 1024

    static func normalize(
        files: [PhotoImportCandidate],
        settings: WorkClassificationSettings = WorkClassificationSettings(),
        existingAssetIdentifiers: Set<String> = [],
        now: Date = Date()
    ) -> [WorkPhotoRecord] {
        var seenAssetIdentifiers = existingAssetIdentifiers
        return files.enumerated().compactMap { index, file in
            guard allowedContentTypes.contains(file.contentType), file.size > 0, file.size <= maxImageBytes else {
                return nil
            }
            if let assetLocalIdentifier = file.assetLocalIdentifier {
                guard !seenAssetIdentifiers.contains(assetLocalIdentifier) else {
                    return nil
                }
                seenAssetIdentifiers.insert(assetLocalIdentifier)
            }
            let classification = classify(file: file, settings: settings, now: now)
            let status: WorkPhotoStatus = file.isScreenshot || classification.isWorkCandidate ? .review : .unclassified
            return WorkPhotoRecord(
                id: stableID(name: file.name, size: file.size, index: index),
                fileName: sanitizedText(file.name),
                siteName: "신규 업무",
                category: .unclassified,
                status: status,
                assignee: "",
                memo: "",
                tags: [],
                size: file.size,
                createdAt: now,
                assetLocalIdentifier: file.assetLocalIdentifier,
                captureKind: file.isScreenshot ? .screenshot : .photo,
                classificationSource: classification.source,
                classifiedAt: classification.source == .unknown ? nil : now,
                capturedAt: file.capturedAt,
                latitude: file.latitude,
                longitude: file.longitude,
                isWorkCandidate: classification.isWorkCandidate,
                isConfirmedWork: false
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
                record.captureKind.rawValue,
                record.classificationSource.rawValue,
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
                ].joined(separator: "__"),
                captureKind: record.captureKind.rawValue,
                classificationSource: record.classificationSource.rawValue,
                isWorkCandidate: record.isWorkCandidate,
                isConfirmedWork: record.isConfirmedWork
            )
        }
        return WorkPhotoExportPayload(exportedAt: exportedAt, total: items.count, items: items)
    }

    static func migrateV1ExportItems(_ items: [WorkPhotoExportItem]) -> [WorkPhotoRecord] {
        items.map {
            WorkPhotoRecord(
                id: sanitizedText($0.id),
                fileName: sanitizedText($0.fileName),
                siteName: sanitizedText($0.siteName),
                category: WorkPhotoCategory(rawValue: sanitizedText($0.category)) ?? .unclassified,
                status: WorkPhotoStatus(rawValue: sanitizedText($0.status)) ?? .unclassified,
                assignee: sanitizedText($0.assignee),
                memo: sanitizedText($0.memo),
                tags: $0.tags.map(sanitizedText).filter { !$0.isEmpty },
                size: $0.size,
                createdAt: $0.createdAt,
                assetLocalIdentifier: nil,
                captureKind: CaptureKind(rawValue: $0.captureKind ?? "") ?? .unknown,
                classificationSource: ClassificationSource(rawValue: $0.classificationSource ?? "") ?? .manual,
                classifiedAt: nil,
                capturedAt: nil,
                latitude: nil,
                longitude: nil,
                isWorkCandidate: $0.isWorkCandidate ?? false,
                isConfirmedWork: $0.isConfirmedWork ?? false
            )
        }
    }

    static func reclassifyRecentRecords(
        _ records: [WorkPhotoRecord],
        settings: WorkClassificationSettings,
        recentDays: Int = 7,
        now: Date = Date()
    ) -> [WorkPhotoRecord] {
        let cutoff = now.addingTimeInterval(-Double(recentDays) * 24 * 60 * 60)
        return records.map { record in
            guard !record.isConfirmedWork else { return record }
            let referenceDate = record.capturedAt ?? record.createdAt
            guard referenceDate >= cutoff else { return record }

            let candidate = PhotoImportCandidate(
                name: record.fileName,
                contentType: contentType(for: record.fileName),
                size: record.size,
                assetLocalIdentifier: record.assetLocalIdentifier,
                isScreenshot: record.captureKind == .screenshot,
                capturedAt: record.capturedAt,
                latitude: record.latitude,
                longitude: record.longitude
            )
            let classification = classify(file: candidate, settings: settings, now: now)
            var updated = record
            updated.isWorkCandidate = classification.isWorkCandidate
            updated.classificationSource = classification.source
            updated.classifiedAt = classification.source == .unknown ? nil : now
            if classification.isWorkCandidate || updated.captureKind == .screenshot {
                updated.status = updated.status == .done ? .done : .review
            } else if updated.status == .review {
                updated.status = .unclassified
            }
            return updated
        }
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

    private static func classify(
        file: PhotoImportCandidate,
        settings: WorkClassificationSettings,
        now: Date
    ) -> (isWorkCandidate: Bool, source: ClassificationSource) {
        if settings.workModeEnabled {
            return (true, .shortcutWorkMode)
        }
        if settings.locationClassificationEnabled,
           let latitude = file.latitude,
           let longitude = file.longitude,
           let companyLatitude = settings.companyLatitude,
           let companyLongitude = settings.companyLongitude,
           distanceMeters(
               fromLatitude: latitude,
               longitude: longitude,
               toLatitude: companyLatitude,
               longitude: companyLongitude
           ) <= settings.companyRadiusMeters {
            return (true, .photoMetadataLocation)
        }
        if settings.scheduleClassificationEnabled,
           let capturedAt = file.capturedAt,
           isWithinWorkSchedule(capturedAt, settings: settings) {
            return (true, .workSchedule)
        }
        if file.isScreenshot {
            return (false, .screenshotMetadata)
        }
        return (false, .unknown)
    }

    private static func isWithinWorkSchedule(_ date: Date, settings: WorkClassificationSettings) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: settings.timeZoneIdentifier) ?? Calendar.current.timeZone
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        return settings.workWeekdays.contains(weekday) &&
            hour >= settings.workStartHour &&
            hour < settings.workEndHour
    }

    private static func distanceMeters(
        fromLatitude latitude1: Double,
        longitude longitude1: Double,
        toLatitude latitude2: Double,
        longitude longitude2: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let deltaLatitude = (latitude2 - latitude1) * .pi / 180
        let deltaLongitude = (longitude2 - longitude1) * .pi / 180
        let startLatitude = latitude1 * .pi / 180
        let endLatitude = latitude2 * .pi / 180
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2) +
            cos(startLatitude) * cos(endLatitude) *
            sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    private static func safeFileSegment(_ value: String) -> String {
        let replaced = value.map { character in
            "\\/:*?\"<>| ".contains(character) ? "_" : character
        }
        let collapsed = String(replaced).replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "미지정" : trimmed
    }

    private static func contentType(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".png") {
            return "image/png"
        }
        if lowercased.hasSuffix(".webp") {
            return "image/webp"
        }
        return "image/jpeg"
    }
}
