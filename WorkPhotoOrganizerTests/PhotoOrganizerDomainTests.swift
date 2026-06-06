import XCTest
@testable import WorkPhotoOrganizer

final class PhotoOrganizerDomainTests: XCTestCase {
    func testNormalizeAcceptsOnlySupportedImagesUnderLimit() {
        let records = PhotoOrganizerDomain.normalize(
            files: [
                PhotoImportCandidate(name: "site.jpg", contentType: "image/jpeg", size: 1_200, assetLocalIdentifier: "asset-1"),
                PhotoImportCandidate(name: "bad.svg", contentType: "image/svg+xml", size: 1_200, assetLocalIdentifier: "asset-2"),
                PhotoImportCandidate(name: "huge.png", contentType: "image/png", size: 21 * 1024 * 1024, assetLocalIdentifier: "asset-3")
            ],
            now: Date(timeIntervalSince1970: 1_780_740_000)
        )

        XCTAssertEqual(records.map(\.fileName), ["site.jpg"])
        XCTAssertEqual(records.first?.assetLocalIdentifier, "asset-1")
        XCTAssertEqual(records.first?.category, .unclassified)
        XCTAssertEqual(records.first?.status, .unclassified)
        XCTAssertEqual(records.first?.captureKind, .photo)
    }

    func testNormalizeDeduplicatesAssetIdentifiersAcrossBatch() {
        let records = PhotoOrganizerDomain.normalize(
            files: [
                PhotoImportCandidate(name: "one.jpg", contentType: "image/jpeg", size: 1_000, assetLocalIdentifier: "dup"),
                PhotoImportCandidate(name: "two.jpg", contentType: "image/jpeg", size: 1_000, assetLocalIdentifier: "dup"),
                PhotoImportCandidate(name: "three.jpg", contentType: "image/jpeg", size: 1_000, assetLocalIdentifier: "unique")
            ]
        )

        XCTAssertEqual(records.map(\.assetLocalIdentifier), ["dup", "unique"])
    }

    func testScreenshotSubtypeBecomesReviewScreenshotCandidate() {
        let records = PhotoOrganizerDomain.normalize(
            files: [
                PhotoImportCandidate(
                    name: "screen.png",
                    contentType: "image/png",
                    size: 1_000,
                    assetLocalIdentifier: "screen-1",
                    isScreenshot: true,
                    capturedAt: Date(timeIntervalSince1970: 1_780_740_000)
                )
            ]
        )

        XCTAssertEqual(records.first?.captureKind, .screenshot)
        XCTAssertEqual(records.first?.status, .review)
        XCTAssertEqual(records.first?.classificationSource, .screenshotMetadata)
    }

    func testWorkLocationAndScheduleClassifyOnlyAsCandidate() {
        let settings = WorkClassificationSettings(
            companyName: "본사",
            companyLatitude: 37.4979,
            companyLongitude: 127.0276,
            companyRadiusMeters: 200,
            workWeekdays: Set([2, 3, 4, 5, 6]),
            workStartHour: 8,
            workEndHour: 18,
            locationClassificationEnabled: true,
            scheduleClassificationEnabled: true
        )
        let insideLocation = PhotoImportCandidate(
            name: "inside.jpg",
            contentType: "image/jpeg",
            size: 1_000,
            assetLocalIdentifier: "inside",
            capturedAt: Date(timeIntervalSince1970: 1_780_740_000),
            latitude: 37.49791,
            longitude: 127.02761
        )
        let outsideWorkTime = PhotoImportCandidate(
            name: "worktime.jpg",
            contentType: "image/jpeg",
            size: 1_000,
            assetLocalIdentifier: "worktime",
            capturedAt: DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 6, day: 5, hour: 9).date
        )
        let outside = PhotoImportCandidate(
            name: "outside.jpg",
            contentType: "image/jpeg",
            size: 1_000,
            assetLocalIdentifier: "outside",
            capturedAt: DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 6, day: 6, hour: 23).date,
            latitude: 37.0,
            longitude: 127.0
        )

        let records = PhotoOrganizerDomain.normalize(files: [insideLocation, outsideWorkTime, outside], settings: settings)

        XCTAssertEqual(records[0].isWorkCandidate, true)
        XCTAssertEqual(records[0].isConfirmedWork, false)
        XCTAssertEqual(records[0].classificationSource, .photoMetadataLocation)
        XCTAssertEqual(records[1].isWorkCandidate, true)
        XCTAssertEqual(records[1].classificationSource, .workSchedule)
        XCTAssertEqual(records[2].isWorkCandidate, false)
    }

    func testFilterCombinesSearchStatusAndCategory() {
        let records = [
            WorkPhotoRecord(
                id: "1",
                fileName: "receipt.jpg",
                siteName: "강남 현장",
                category: .receipt,
                status: .review,
                assignee: "민지",
                memo: "자재 구매",
                tags: ["비용", "자재"],
                size: 100,
                createdAt: Date(),
                isWorkCandidate: true
            ),
            WorkPhotoRecord(
                id: "2",
                fileName: "board.png",
                siteName: "판교 회의",
                category: .meeting,
                status: .done,
                assignee: "준호",
                memo: "일정",
                tags: ["회의"],
                size: 100,
                createdAt: Date()
            )
        ]

        let filtered = PhotoOrganizerDomain.filter(
            records,
            query: "자재",
            status: .review,
            category: .receipt
        )

        XCTAssertEqual(filtered.map(\.id), ["1"])
    }

    func testExportPayloadExcludesPreviewAndRawPhotoData() throws {
        let payload = PhotoOrganizerDomain.exportPayload(records: [
            WorkPhotoRecord(
                id: "1",
                fileName: "현장 사진.jpg",
                siteName: "강남/역삼 3층",
                category: .site,
                status: .done,
                assignee: "민지",
                memo: "고객 확인용",
                tags: ["전기"],
                size: 100,
                createdAt: Date(timeIntervalSince1970: 1_780_740_000),
                assetLocalIdentifier: "local-secret",
                latitude: 37.1,
                longitude: 127.2
            )
        ])

        let data = try JSONEncoder().encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("blob:"))
        XCTAssertFalse(json.contains("base64"))
        XCTAssertFalse(json.contains("preview"))
        XCTAssertFalse(json.contains("assetLocalIdentifier"))
        XCTAssertFalse(json.contains("local-secret"))
        XCTAssertEqual(payload.items.first?.suggestedName, "강남_역삼_3층__현장사진__현장_사진.jpg")
    }

    func testV1ExportItemsMigrateToV2RecordsSafely() {
        let items = [
            WorkPhotoExportItem(
                id: "old-1",
                fileName: "old.jpg",
                siteName: "기존 현장",
                category: "현장사진",
                status: "검토",
                assignee: "담당",
                memo: "기존 메모",
                tags: ["기존"],
                size: 100,
                createdAt: Date(timeIntervalSince1970: 1_780_740_000),
                suggestedName: "ignored.jpg"
            )
        ]

        let records = PhotoOrganizerDomain.migrateV1ExportItems(items)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.captureKind, .unknown)
        XCTAssertEqual(records.first?.classificationSource, .manual)
        XCTAssertEqual(records.first?.isWorkCandidate, false)
    }

    func testRestoredTextRemovesMarkupMetacharacters() {
        let sanitized = PhotoOrganizerDomain.sanitizedText("\"><script>alert(1)</script>")
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
        XCTAssertFalse(sanitized.contains("\""))
    }
}
