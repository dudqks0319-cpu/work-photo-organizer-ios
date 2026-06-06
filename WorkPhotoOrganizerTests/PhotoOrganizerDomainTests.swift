import XCTest
@testable import WorkPhotoOrganizer

final class PhotoOrganizerDomainTests: XCTestCase {
    func testNormalizeAcceptsOnlySupportedImagesUnderLimit() {
        let records = PhotoOrganizerDomain.normalize(
            files: [
                PhotoImportCandidate(name: "site.jpg", contentType: "image/jpeg", size: 1_200),
                PhotoImportCandidate(name: "bad.svg", contentType: "image/svg+xml", size: 1_200),
                PhotoImportCandidate(name: "huge.png", contentType: "image/png", size: 21 * 1024 * 1024)
            ],
            now: Date(timeIntervalSince1970: 1_780_740_000)
        )

        XCTAssertEqual(records.map(\.fileName), ["site.jpg"])
        XCTAssertEqual(records.first?.category, .unclassified)
        XCTAssertEqual(records.first?.status, .unclassified)
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
                createdAt: Date()
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
                createdAt: Date(timeIntervalSince1970: 1_780_740_000)
            )
        ])

        let data = try JSONEncoder().encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("blob:"))
        XCTAssertFalse(json.contains("base64"))
        XCTAssertFalse(json.contains("preview"))
        XCTAssertEqual(payload.items.first?.suggestedName, "강남_역삼_3층__현장사진__현장_사진.jpg")
    }

    func testRestoredTextRemovesMarkupMetacharacters() {
        let sanitized = PhotoOrganizerDomain.sanitizedText("\"><script>alert(1)</script>")
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
        XCTAssertFalse(sanitized.contains("\""))
    }
}
