import Foundation
import Photos
import SwiftUI
import UIKit

@MainActor
final class PhotoOrganizerStore: ObservableObject {
    @Published var records: [WorkPhotoRecord]
    @Published var selectedID: WorkPhotoRecord.ID?
    @Published var query = ""
    @Published var statusFilter: WorkPhotoStatus = .all
    @Published var categoryFilter: WorkPhotoCategory = .all
    @Published var captureKindFilter: CaptureKind = .all
    @Published var workScopeFilter: WorkScopeFilter = .all
    @Published var classificationSettings: WorkClassificationSettings
    @Published var faceIDLockEnabled: Bool
    @Published var alertMessage = ""
    @Published var previewImages: [WorkPhotoRecord.ID: UIImage] = [:]

    private let storageKey = "work-photo-organizer-ios:v2"
    private let settingsKey = "work-photo-organizer-ios:classification-settings"
    private let faceIDKey = "work-photo-organizer-ios:face-id-lock-enabled"

    init() {
        let restored = PhotoOrganizerStore.restoreRecords()
        records = restored.isEmpty ? PhotoOrganizerStore.sampleRecords : restored
        classificationSettings = PhotoOrganizerStore.restoreSettings()
        faceIDLockEnabled = UserDefaults.standard.bool(forKey: faceIDKey)
        selectedID = records.first?.id
        if UserDefaults.standard.object(forKey: "work-photo-organizer-ios:workModeEnabled") != nil {
            classificationSettings.workModeEnabled = UserDefaults.standard.bool(forKey: "work-photo-organizer-ios:workModeEnabled")
        }
    }

    var filteredRecords: [WorkPhotoRecord] {
        PhotoOrganizerDomain
            .filter(records, query: query, status: statusFilter, category: categoryFilter)
            .filter { record in
                captureKindFilter == .all || record.captureKind == captureKindFilter
            }
            .filter { record in
                switch workScopeFilter {
                case .all:
                    return true
                case .candidates:
                    return record.isWorkCandidate
                case .confirmed:
                    return record.isConfirmedWork
                case .unclassified:
                    return record.captureKind == .unknown || record.classificationSource == .unknown
                }
            }
    }

    var selectedRecord: WorkPhotoRecord? {
        records.first { $0.id == selectedID } ?? filteredRecords.first
    }

    var reviewCount: Int {
        records.filter { $0.status == .review }.count
    }

    var doneCount: Int {
        records.filter { $0.status == .done }.count
    }

    var workCandidateCount: Int {
        records.filter { $0.isWorkCandidate }.count
    }

    var confirmedWorkCount: Int {
        records.filter { $0.isConfirmedWork }.count
    }

    var screenshotCount: Int {
        records.filter { $0.captureKind == .screenshot }.count
    }

    var unclassifiedCount: Int {
        records.filter { $0.captureKind == .unknown || $0.classificationSource == .unknown }.count
    }

    var collectionCounts: [(WorkPhotoCategory, Int)] {
        WorkPhotoCategory.allCases
            .filter { $0 != .all }
            .map { category in (category, records.filter { $0.category == category }.count) }
            .filter { $0.1 > 0 }
    }

    func select(_ record: WorkPhotoRecord) {
        selectedID = record.id
    }

    func updateSelected(
        siteName: String,
        category: WorkPhotoCategory,
        assignee: String,
        status: WorkPhotoStatus,
        memo: String,
        tagsText: String,
        captureKind: CaptureKind,
        isWorkCandidate: Bool,
        isConfirmedWork: Bool
    ) {
        guard let selectedID else { return }
        records = records.map { record in
            guard record.id == selectedID else { return record }
            var updated = record
            updated.siteName = PhotoOrganizerDomain.sanitizedText(siteName)
            updated.category = category == .all ? .unclassified : category
            updated.assignee = PhotoOrganizerDomain.sanitizedText(assignee)
            updated.status = status == .all ? .unclassified : status
            updated.memo = PhotoOrganizerDomain.sanitizedText(memo)
            updated.tags = PhotoOrganizerDomain.parseTags(tagsText)
            updated.captureKind = captureKind == .all ? .unknown : captureKind
            updated.isWorkCandidate = isWorkCandidate
            updated.isConfirmedWork = isConfirmedWork
            updated.classificationSource = .manual
            updated.classifiedAt = Date()
            return updated
        }
        save()
    }

    func addPickedPhotos(_ photos: [PickedPhoto]) {
        var seenAssetIdentifiers = Set(records.compactMap(\.assetLocalIdentifier))
        var accepted: [(record: WorkPhotoRecord, image: UIImage?)] = []

        for photo in photos {
            let normalized = PhotoOrganizerDomain.normalize(
                files: [
                    PhotoImportCandidate(
                        name: photo.name,
                        contentType: photo.contentType,
                        size: photo.size,
                        assetLocalIdentifier: photo.assetLocalIdentifier,
                        isScreenshot: photo.isScreenshot,
                        capturedAt: photo.capturedAt,
                        latitude: photo.latitude,
                        longitude: photo.longitude
                    )
                ],
                settings: classificationSettings,
                existingAssetIdentifiers: seenAssetIdentifiers
            )
            guard let record = normalized.first else { continue }
            if let assetLocalIdentifier = record.assetLocalIdentifier {
                seenAssetIdentifiers.insert(assetLocalIdentifier)
            }
            accepted.append((record, photo.image))
        }

        let newRecords = accepted.map(\.record)
        guard !newRecords.isEmpty else {
            alertMessage = "JPG, PNG, WebP 중 20MB 이하 사진만 추가할 수 있습니다."
            return
        }
        records.insert(contentsOf: newRecords, at: 0)
        selectedID = newRecords.first?.id
        for item in accepted {
            if let image = item.image {
                previewImages[item.record.id] = image
            }
        }
        let failedCount = photos.count - newRecords.count
        alertMessage = failedCount > 0 ? "\(newRecords.count)장 추가, \(failedCount)장은 중복이거나 지원하지 않는 파일입니다." : ""
        save()
    }

    func addPickedPhoto(
        name: String,
        contentType: String,
        size: Int,
        image: UIImage?,
        assetLocalIdentifier: String? = nil,
        isScreenshot: Bool = false,
        capturedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        addPickedPhotos([
            PickedPhoto(
                name: name,
                contentType: contentType,
                size: size,
                image: image,
                assetLocalIdentifier: assetLocalIdentifier,
                isScreenshot: isScreenshot,
                capturedAt: capturedAt,
                latitude: latitude,
                longitude: longitude
            )
        ])
    }

    func confirmSelectedWork() {
        guard let selectedID else { return }
        records = records.map { record in
            guard record.id == selectedID else { return record }
            var updated = record
            updated.isWorkCandidate = true
            updated.isConfirmedWork = true
            updated.status = .done
            updated.classificationSource = .manual
            updated.classifiedAt = Date()
            return updated
        }
        save()
    }

    func excludeSelectedWork() {
        guard let selectedID else { return }
        records = records.map { record in
            guard record.id == selectedID else { return record }
            var updated = record
            updated.isWorkCandidate = false
            updated.isConfirmedWork = false
            updated.status = record.status == .done ? .review : record.status
            updated.classificationSource = .manual
            updated.classifiedAt = Date()
            return updated
        }
        save()
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(classificationSettings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
        UserDefaults.standard.set(classificationSettings.workModeEnabled, forKey: "work-photo-organizer-ios:workModeEnabled")
    }

    func saveFaceIDLockEnabled() {
        UserDefaults.standard.set(faceIDLockEnabled, forKey: faceIDKey)
    }

    func restoreThumbnailsFromPhotoLibrary() {
        let identifiersByID = Dictionary(uniqueKeysWithValues: records.compactMap { record in
            record.assetLocalIdentifier.map { ($0, record.id) }
        })
        guard !identifiersByID.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: Array(identifiersByID.keys), options: nil)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        assets.enumerateObjects { asset, _, _ in
            guard let recordID = identifiersByID[asset.localIdentifier] else { return }
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 320, height: 320),
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                guard let image else { return }
                Task { @MainActor in
                    self?.previewImages[recordID] = image
                }
            }
        }
    }

    func resetSamples() {
        records = PhotoOrganizerStore.sampleRecords
        selectedID = records.first?.id
        previewImages.removeAll()
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func exportText() -> String {
        let payload = PhotoOrganizerDomain.exportPayload(records: filteredRecords)
        guard let data = try? JSONEncoder().encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func restoreRecords() -> [WorkPhotoRecord] {
        if
            let data = UserDefaults.standard.data(forKey: "work-photo-organizer-ios:v2"),
            let records = try? JSONDecoder().decode([WorkPhotoRecord].self, from: data)
        {
            return records
        }
        guard
            let data = UserDefaults.standard.data(forKey: "work-photo-organizer-ios:v1"),
            let items = try? JSONDecoder().decode([WorkPhotoExportItem].self, from: data)
        else {
            return []
        }
        return PhotoOrganizerDomain.migrateV1ExportItems(items)
    }

    private static func restoreSettings() -> WorkClassificationSettings {
        guard
            let data = UserDefaults.standard.data(forKey: "work-photo-organizer-ios:classification-settings"),
            let settings = try? JSONDecoder().decode(WorkClassificationSettings.self, from: data)
        else {
            return WorkClassificationSettings()
        }
        return settings
    }

    private static let sampleRecords: [WorkPhotoRecord] = [
        WorkPhotoRecord(id: "sample-1", fileName: "site-before-001.jpg", siteName: "역삼동 신축 현장", category: .site, status: .review, assignee: "김대리", memo: "전기 배선 전 천장 상태 확인 필요", tags: ["전기", "시공전"], size: 2_480_000, createdAt: Date(timeIntervalSince1970: 1_780_691_100), assetLocalIdentifier: nil, captureKind: .photo, classificationSource: .photoMetadataLocation, classifiedAt: Date(timeIntervalSince1970: 1_780_691_100), capturedAt: Date(timeIntervalSince1970: 1_780_691_100), latitude: nil, longitude: nil, isWorkCandidate: true, isConfirmedWork: false),
        WorkPhotoRecord(id: "sample-2", fileName: "receipt-material-014.jpg", siteName: "역삼동 신축 현장", category: .receipt, status: .unclassified, assignee: "", memo: "자재 구매 영수증", tags: ["비용", "자재"], size: 860_000, createdAt: Date(timeIntervalSince1970: 1_780_688_100), assetLocalIdentifier: nil, captureKind: .photo, classificationSource: .unknown, classifiedAt: nil, capturedAt: Date(timeIntervalSince1970: 1_780_688_100), latitude: nil, longitude: nil, isWorkCandidate: false, isConfirmedWork: false),
        WorkPhotoRecord(id: "sample-3", fileName: "whiteboard-schedule.png", siteName: "판교 회의실", category: .meeting, status: .done, assignee: "이PM", memo: "주간 일정 확정본", tags: ["회의", "일정"], size: 1_160_000, createdAt: Date(timeIntervalSince1970: 1_780_679_100), assetLocalIdentifier: nil, captureKind: .screenshot, classificationSource: .screenshotMetadata, classifiedAt: Date(timeIntervalSince1970: 1_780_679_100), capturedAt: Date(timeIntervalSince1970: 1_780_679_100), latitude: nil, longitude: nil, isWorkCandidate: true, isConfirmedWork: true),
        WorkPhotoRecord(id: "sample-4", fileName: "meter-check-002.jpg", siteName: "분당 설비실", category: .equipment, status: .review, assignee: "최기사", memo: "계측값 재확인", tags: ["장비", "점검"], size: 1_340_000, createdAt: Date(timeIntervalSince1970: 1_780_668_300), assetLocalIdentifier: nil, captureKind: .photo, classificationSource: .workSchedule, classifiedAt: Date(timeIntervalSince1970: 1_780_668_300), capturedAt: Date(timeIntervalSince1970: 1_780_668_300), latitude: nil, longitude: nil, isWorkCandidate: true, isConfirmedWork: false)
    ]
}

enum WorkScopeFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case candidates = "후보"
    case confirmed = "확정"
    case unclassified = "미분류"

    var id: String { rawValue }
}

struct PickedPhoto {
    var name: String
    var contentType: String
    var size: Int
    var image: UIImage?
    var assetLocalIdentifier: String?
    var isScreenshot: Bool
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?
}
