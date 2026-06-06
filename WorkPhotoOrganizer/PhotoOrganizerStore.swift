import Foundation
import SwiftUI
import UIKit

@MainActor
final class PhotoOrganizerStore: ObservableObject {
    @Published var records: [WorkPhotoRecord]
    @Published var selectedID: WorkPhotoRecord.ID?
    @Published var query = ""
    @Published var statusFilter: WorkPhotoStatus = .all
    @Published var categoryFilter: WorkPhotoCategory = .all
    @Published var alertMessage = ""
    @Published var previewImages: [WorkPhotoRecord.ID: UIImage] = [:]

    private let storageKey = "work-photo-organizer-ios:v1"

    init() {
        let restored = PhotoOrganizerStore.restoreRecords()
        records = restored.isEmpty ? PhotoOrganizerStore.sampleRecords : restored
        selectedID = records.first?.id
    }

    var filteredRecords: [WorkPhotoRecord] {
        PhotoOrganizerDomain.filter(records, query: query, status: statusFilter, category: categoryFilter)
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
        tagsText: String
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
            return updated
        }
        save()
    }

    func addPickedPhoto(name: String, contentType: String, size: Int, image: UIImage?) {
        let newRecords = PhotoOrganizerDomain.normalize(
            files: [PhotoImportCandidate(name: name, contentType: contentType, size: size)]
        )
        guard let record = newRecords.first else {
            alertMessage = "JPG, PNG, WebP 중 20MB 이하 사진만 추가할 수 있습니다."
            return
        }
        records.insert(record, at: 0)
        selectedID = record.id
        if let image {
            previewImages[record.id] = image
        }
        alertMessage = ""
        save()
    }

    func resetSamples() {
        records = PhotoOrganizerStore.sampleRecords
        selectedID = records.first?.id
        previewImages.removeAll()
        save()
    }

    func save() {
        let payload = PhotoOrganizerDomain.exportPayload(records: records)
        if let data = try? JSONEncoder().encode(payload.items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func exportText() -> String {
        let payload = PhotoOrganizerDomain.exportPayload(records: filteredRecords)
        guard let data = try? JSONEncoder().encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func restoreRecords() -> [WorkPhotoRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: "work-photo-organizer-ios:v1"),
            let items = try? JSONDecoder().decode([WorkPhotoExportItem].self, from: data)
        else {
            return []
        }
        return items.map {
            WorkPhotoRecord(
                id: PhotoOrganizerDomain.sanitizedText($0.id),
                fileName: PhotoOrganizerDomain.sanitizedText($0.fileName),
                siteName: PhotoOrganizerDomain.sanitizedText($0.siteName),
                category: WorkPhotoCategory(rawValue: PhotoOrganizerDomain.sanitizedText($0.category)) ?? .unclassified,
                status: WorkPhotoStatus(rawValue: PhotoOrganizerDomain.sanitizedText($0.status)) ?? .unclassified,
                assignee: PhotoOrganizerDomain.sanitizedText($0.assignee),
                memo: PhotoOrganizerDomain.sanitizedText($0.memo),
                tags: $0.tags.map(PhotoOrganizerDomain.sanitizedText).filter { !$0.isEmpty },
                size: $0.size,
                createdAt: $0.createdAt
            )
        }
    }

    private static let sampleRecords: [WorkPhotoRecord] = [
        WorkPhotoRecord(id: "sample-1", fileName: "site-before-001.jpg", siteName: "역삼동 신축 현장", category: .site, status: .review, assignee: "김대리", memo: "전기 배선 전 천장 상태 확인 필요", tags: ["전기", "시공전"], size: 2_480_000, createdAt: Date(timeIntervalSince1970: 1_780_691_100)),
        WorkPhotoRecord(id: "sample-2", fileName: "receipt-material-014.jpg", siteName: "역삼동 신축 현장", category: .receipt, status: .unclassified, assignee: "", memo: "자재 구매 영수증", tags: ["비용", "자재"], size: 860_000, createdAt: Date(timeIntervalSince1970: 1_780_688_100)),
        WorkPhotoRecord(id: "sample-3", fileName: "whiteboard-schedule.png", siteName: "판교 회의실", category: .meeting, status: .done, assignee: "이PM", memo: "주간 일정 확정본", tags: ["회의", "일정"], size: 1_160_000, createdAt: Date(timeIntervalSince1970: 1_780_679_100)),
        WorkPhotoRecord(id: "sample-4", fileName: "meter-check-002.jpg", siteName: "분당 설비실", category: .equipment, status: .review, assignee: "최기사", memo: "계측값 재확인", tags: ["장비", "점검"], size: 1_340_000, createdAt: Date(timeIntervalSince1970: 1_780_668_300))
    ]
}
