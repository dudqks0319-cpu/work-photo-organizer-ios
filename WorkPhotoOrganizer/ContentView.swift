import LocalAuthentication
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    @EnvironmentObject private var intentRouter: AppIntentRouter
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var exportPresented = false
    @State private var settingsPresented = false
    @State private var isUnlocked = true
    @State private var unlockMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if isUnlocked {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ProjectSummaryView()
                            UploadView(selectedPickerItems: $selectedPickerItems)
                            FilterBarView()
                            PhotoGridView()
                            InspectorView()
                        }
                        .padding(16)
                    }
                } else {
                    LockedView(message: unlockMessage) {
                        authenticateIfNeeded(force: true)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("업무 사진 정리함")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        settingsPresented = true
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportPresented = true
                    } label: {
                        Label("내보내기", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("exportButton")
                }
            }
            .searchable(text: $store.query, prompt: "사진 검색")
            .sheet(isPresented: $exportPresented) {
                ExportSheetView(exportText: store.exportText())
            }
            .sheet(isPresented: $settingsPresented) {
                SettingsSheetView()
            }
            .onAppear {
                store.restoreThumbnailsFromPhotoLibrary()
                authenticateIfNeeded(force: false)
            }
            .onChange(of: selectedPickerItems) { _, newItems in
                Task {
                    await handlePickedItems(newItems)
                }
            }
            .onChange(of: intentRouter.destination) { _, destination in
                guard let destination else { return }
                applyIntentDestination(destination)
            }
            .onChange(of: intentRouter.workModeOverride) { _, enabled in
                guard let enabled else { return }
                store.setWorkMode(enabled)
                intentRouter.workModeOverride = nil
            }
            .onChange(of: intentRouter.reclassifyRequestID) { _, requestID in
                guard requestID != nil else { return }
                store.reclassifyRecentPhotos()
                intentRouter.reclassifyRequestID = nil
            }
        }
    }

    private func handlePickedItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var pickedPhotos: [PickedPhoto] = []
        var failedCount = 0

        for item in items {
            let metadata = photoMetadata(for: item.itemIdentifier)
            let supportedContentType = item.supportedContentTypes.first
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let contentType = supportedContentType?.preferredMIMEType,
                let image = UIImage(data: data)
            else {
                failedCount += 1
                continue
            }
            let fileExtension = supportedContentType?.preferredFilenameExtension ?? "jpg"
            pickedPhotos.append(
                PickedPhoto(
                    name: metadata.fileName ?? "선택한사진.\(fileExtension)",
                    contentType: contentType,
                    size: data.count,
                    image: image,
                    assetLocalIdentifier: item.itemIdentifier,
                    isScreenshot: metadata.isScreenshot,
                    capturedAt: metadata.capturedAt,
                    latitude: metadata.latitude,
                    longitude: metadata.longitude
                )
            )
        }
        store.addPickedPhotos(pickedPhotos)
        if failedCount > 0 {
            store.alertMessage = store.alertMessage.isEmpty
                ? "\(failedCount)장은 사진 데이터를 읽을 수 없습니다."
                : "\(store.alertMessage) 읽기 실패 \(failedCount)장."
        }
        selectedPickerItems = []
    }

    private func photoMetadata(for identifier: String?) -> PhotoMetadata {
        guard let identifier else { return PhotoMetadata() }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return PhotoMetadata() }
        let resources = PHAssetResource.assetResources(for: asset)
        return PhotoMetadata(
            fileName: resources.first?.originalFilename,
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
            capturedAt: asset.creationDate,
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude
        )
    }

    private func applyIntentDestination(_ destination: OrganizerDestination) {
        switch destination {
        case .all:
            store.statusFilter = .all
            store.categoryFilter = .all
            store.captureKindFilter = .all
            store.workScopeFilter = .all
        case .review:
            store.statusFilter = .review
            store.categoryFilter = .all
            store.workScopeFilter = .all
        case .done:
            store.statusFilter = .done
            store.categoryFilter = .all
            store.workScopeFilter = .all
        case .upload:
            store.statusFilter = .all
            store.categoryFilter = .all
            store.workScopeFilter = .all
        case .candidates:
            store.statusFilter = .all
            store.categoryFilter = .all
            store.workScopeFilter = .candidates
        case .screenshots:
            store.statusFilter = .all
            store.categoryFilter = .all
            store.captureKindFilter = .screenshot
            store.workScopeFilter = .all
        }
        intentRouter.destination = nil
    }

    private func authenticateIfNeeded(force: Bool) {
        guard store.faceIDLockEnabled else {
            isUnlocked = true
            return
        }
        if isUnlocked && !force { return }
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "업무 사진 정리함을 열기 위해 인증이 필요합니다.") { success, error in
            Task { @MainActor in
                isUnlocked = success
                unlockMessage = success ? "" : (error?.localizedDescription ?? "인증에 실패했습니다.")
            }
        }
    }
}

private struct PhotoMetadata {
    var fileName: String?
    var isScreenshot = false
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?
}

private struct ProjectSummaryView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.classificationSettings.companyName.isEmpty ? "업무 사진 후보함" : store.classificationSettings.companyName)
                .font(.headline)
            Text("스크린샷, 위치, 업무 시간으로 후보만 자동 표시합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(store.confirmedWorkCount), total: Double(max(store.records.count, 1)))
                .tint(.teal)
            HStack {
                StatView(title: "전체", value: store.records.count)
                StatView(title: "후보", value: store.workCandidateCount)
                StatView(title: "확정", value: store.confirmedWorkCount)
                StatView(title: "스크린샷", value: store.screenshotCount)
                StatView(title: "미분류", value: store.unclassifiedCount)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("projectSummary")
    }
}

private struct StatView: View {
    var title: String
    var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UploadView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    @Binding var selectedPickerItems: [PhotosPickerItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $selectedPickerItems, maxSelectionCount: 50, matching: .images) {
                Label("사진 여러 장 선택", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.teal.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityIdentifier("photoPickerButton")

            if !store.alertMessage.isEmpty {
                Text(store.alertMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct FilterBarView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("상태", selection: $store.statusFilter) {
                ForEach(WorkPhotoStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)

            Picker("후보", selection: $store.workScopeFilter) {
                ForEach(WorkScopeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("workScopeFilter")

            Picker("촬영 유형", selection: $store.captureKindFilter) {
                ForEach(CaptureKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .accessibilityIdentifier("captureKindFilter")

            Picker("업무분류", selection: $store.categoryFilter) {
                ForEach(WorkPhotoCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .accessibilityIdentifier("categoryFilter")
        }
    }
}

private struct PhotoGridView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("사진 목록")
                .font(.headline)
            if store.filteredRecords.isEmpty {
                ContentUnavailableView("조건에 맞는 사진이 없습니다", systemImage: "photo.on.rectangle", description: Text("검색어 또는 필터를 바꿔보세요."))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.filteredRecords) { record in
                        PhotoCardView(record: record)
                    }
                }
            }
        }
        .accessibilityIdentifier("photoGrid")
    }
}

private struct PhotoCardView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    var record: WorkPhotoRecord

    var body: some View {
        Button {
            store.select(record)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                PreviewBlockView(record: record)
                    .frame(height: 118)
                HStack(spacing: 6) {
                    BadgeView(title: record.captureKind.rawValue, color: record.captureKind == .screenshot ? .purple : .teal)
                    if record.isWorkCandidate {
                        BadgeView(title: record.isConfirmedWork ? "업무 확정" : "업무 후보", color: record.isConfirmedWork ? .green : .orange)
                    }
                }
                Text(record.category.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.teal)
                Text(record.siteName.isEmpty ? "현장 미지정" : record.siteName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(record.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                BadgeView(title: record.status.rawValue, color: statusColor)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(store.selectedID == record.id ? Color.teal : Color(.separator), lineWidth: store.selectedID == record.id ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("photoCard-\(record.id)")
    }

    private var statusColor: Color {
        switch record.status {
        case .done:
            return .green
        case .review:
            return .orange
        case .all, .unclassified:
            return .secondary
        }
    }
}

private struct BadgeView: View {
    var title: String
    var color: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct PreviewBlockView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    var record: WorkPhotoRecord

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(previewColor.opacity(0.22))
            if let image = store.previewImages[record.id] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewTitle)
                        .font(.title2.weight(.bold))
                    Text(record.captureKind.rawValue)
                        .font(.caption)
                    Capsule().fill(previewColor.opacity(0.45)).frame(height: 6)
                    Capsule().fill(previewColor.opacity(0.35)).frame(width: 110, height: 6)
                    Capsule().fill(previewColor.opacity(0.30)).frame(width: 82, height: 6)
                }
                .foregroundStyle(previewColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .clipped()
    }

    private var previewTitle: String {
        if record.captureKind == .screenshot { return "캡처" }
        switch record.category {
        case .receipt:
            return "영수증"
        case .meeting:
            return "회의"
        case .equipment:
            return "계측"
        case .safety:
            return "점검"
        default:
            return "현장"
        }
    }

    private var previewColor: Color {
        if record.captureKind == .screenshot { return .purple }
        switch record.category {
        case .receipt:
            return .orange
        case .meeting:
            return .slate
        case .equipment:
            return .blue
        case .safety:
            return .red
        default:
            return .teal
        }
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    @State private var siteName = ""
    @State private var category: WorkPhotoCategory = .unclassified
    @State private var captureKind: CaptureKind = .photo
    @State private var assignee = ""
    @State private var status: WorkPhotoStatus = .unclassified
    @State private var memo = ""
    @State private var tagsText = ""
    @State private var isWorkCandidate = false
    @State private var isConfirmedWork = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("사진 정보")
                .font(.headline)
            if let record = store.selectedRecord {
                PreviewBlockView(record: record)
                    .frame(height: 180)
                Group {
                    TextField("현장명", text: $siteName)
                    Picker("촬영 유형", selection: $captureKind) {
                        ForEach(CaptureKind.allCases.filter { $0 != .all }) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    Picker("업무분류", selection: $category) {
                        ForEach(WorkPhotoCategory.allCases.filter { $0 != .all }) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    TextField("담당자", text: $assignee)
                    Picker("상태", selection: $status) {
                        ForEach(WorkPhotoStatus.allCases.filter { $0 != .all }) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    Toggle("업무 후보", isOn: $isWorkCandidate)
                    Toggle("업무 확정", isOn: $isConfirmedWork)
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("태그", text: $tagsText)
                }
                .textFieldStyle(.roundedBorder)
                HStack {
                    Button("제외") {
                        store.excludeSelectedWork()
                    }
                    .buttonStyle(.bordered)
                    Button("업무 확정") {
                        store.confirmSelectedWork()
                    }
                    .buttonStyle(.bordered)
                    Button("저장") {
                        store.updateSelected(
                            siteName: siteName,
                            category: category,
                            assignee: assignee,
                            status: status,
                            memo: memo,
                            tagsText: tagsText,
                            captureKind: captureKind,
                            isWorkCandidate: isWorkCandidate,
                            isConfirmedWork: isConfirmedWork
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .accessibilityIdentifier("savePhotoButton")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                Text("\(record.fileName) · \(byteText(record.size)) · \(record.classificationSource.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("inspector")
        .onAppear(perform: syncFields)
        .onChange(of: store.selectedID) { _, _ in syncFields() }
        .onChange(of: store.records) { _, _ in syncFields() }
    }

    private func syncFields() {
        guard let record = store.selectedRecord else { return }
        siteName = record.siteName
        category = record.category
        captureKind = record.captureKind == .all ? .unknown : record.captureKind
        assignee = record.assignee
        status = record.status
        memo = record.memo
        tagsText = record.tags.joined(separator: ", ")
        isWorkCandidate = record.isWorkCandidate
        isConfirmedWork = record.isConfirmedWork
    }

    private func byteText(_ size: Int) -> String {
        if size < 1024 * 1024 {
            return "\(max(size / 1024, 0)) KB"
        }
        return String(format: "%.1f MB", Double(size) / 1024 / 1024)
    }
}

private struct SettingsSheetView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    @Environment(\.dismiss) private var dismiss
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var radiusText = ""
    @State private var timeZoneText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("업무 장소") {
                    TextField("회사명", text: $store.classificationSettings.companyName)
                    TextField("위도", text: $latitudeText)
                        .keyboardType(.decimalPad)
                    TextField("경도", text: $longitudeText)
                        .keyboardType(.decimalPad)
                    TextField("반경 m", text: $radiusText)
                        .keyboardType(.numberPad)
                    Toggle("위치 후보 분류", isOn: $store.classificationSettings.locationClassificationEnabled)
                }
                Section("업무 시간") {
                    Stepper("시작 \(store.classificationSettings.workStartHour)시", value: $store.classificationSettings.workStartHour, in: 0...23)
                    Stepper("종료 \(store.classificationSettings.workEndHour)시", value: $store.classificationSettings.workEndHour, in: 1...24)
                    WeekdaySelector(selectedWeekdays: $store.classificationSettings.workWeekdays)
                    TextField("타임존", text: $timeZoneText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("업무 시간 후보 분류", isOn: $store.classificationSettings.scheduleClassificationEnabled)
                    Toggle("업무 모드", isOn: $store.classificationSettings.workModeEnabled)
                }
                Section("보안") {
                    Toggle("Face ID 또는 암호 잠금", isOn: $store.faceIDLockEnabled)
                }
            }
            .navigationTitle("분류 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        persistFields()
                        dismiss()
                    }
                }
            }
            .onAppear {
                latitudeText = store.classificationSettings.companyLatitude.map { String($0) } ?? ""
                longitudeText = store.classificationSettings.companyLongitude.map { String($0) } ?? ""
                radiusText = String(format: "%.0f", store.classificationSettings.companyRadiusMeters)
                timeZoneText = store.classificationSettings.timeZoneIdentifier
            }
        }
    }

    private func persistFields() {
        store.classificationSettings.companyLatitude = Double(latitudeText)
        store.classificationSettings.companyLongitude = Double(longitudeText)
        if let radius = Double(radiusText), radius > 0 {
            store.classificationSettings.companyRadiusMeters = radius
        }
        if TimeZone(identifier: timeZoneText) != nil {
            store.classificationSettings.timeZoneIdentifier = timeZoneText
        } else {
            store.classificationSettings.timeZoneIdentifier = TimeZone.current.identifier
        }
        store.saveSettings()
        store.saveFaceIDLockEnabled()
    }
}

private struct WeekdaySelector: View {
    @Binding var selectedWeekdays: Set<Int>

    private let weekdays: [(label: String, value: Int)] = [
        ("일", 1),
        ("월", 2),
        ("화", 3),
        ("수", 4),
        ("목", 5),
        ("금", 6),
        ("토", 7)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("근무요일")
                .font(.subheadline)
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.value) { weekday in
                    Button {
                        toggle(weekday.value)
                    } label: {
                        Text(weekday.label)
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(selectedWeekdays.contains(weekday.value) ? Color.teal.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedWeekdays.contains(weekday.value) ? Color.teal : Color.secondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("weekday-\(weekday.value)")
                }
            }
            Text("Calendar 기준: 1=일요일, 2=월요일, ... 7=토요일")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }
}

private struct LockedView: View {
    var message: String
    var unlock: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
            Text("잠금 상태")
                .font(.headline)
            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("인증") {
                unlock()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ExportSheetView: View {
    var exportText: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(exportText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("내보내기 JSON")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension Color {
    static let slate = Color(red: 0.24, green: 0.30, blue: 0.38)
}
