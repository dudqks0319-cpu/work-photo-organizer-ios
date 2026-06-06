import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore
    @EnvironmentObject private var intentRouter: AppIntentRouter
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var exportPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProjectSummaryView()
                    UploadView(selectedPickerItem: $selectedPickerItem)
                    FilterBarView()
                    PhotoGridView()
                    InspectorView()
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("업무 사진 정리함")
            .toolbar {
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
            .onChange(of: selectedPickerItem) { _, newItem in
                Task {
                    await handlePickedItem(newItem)
                }
            }
            .onChange(of: intentRouter.destination) { _, destination in
                guard let destination else { return }
                applyIntentDestination(destination)
            }
        }
    }

    private func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let supportedContentType = item.supportedContentTypes.first
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let contentType = supportedContentType?.preferredMIMEType,
            let image = UIImage(data: data)
        else {
            store.alertMessage = "사진을 읽을 수 없습니다."
            return
        }
        let fileExtension = supportedContentType?.preferredFilenameExtension ?? "jpg"
        store.addPickedPhoto(
            name: "선택한사진.\(fileExtension)",
            contentType: contentType,
            size: data.count,
            image: image
        )
    }

    private func applyIntentDestination(_ destination: OrganizerDestination) {
        switch destination {
        case .all:
            store.statusFilter = .all
            store.categoryFilter = .all
        case .review:
            store.statusFilter = .review
            store.categoryFilter = .all
        case .done:
            store.statusFilter = .done
            store.categoryFilter = .all
        case .upload:
            store.statusFilter = .all
            store.categoryFilter = .all
        }
        intentRouter.destination = nil
    }
}

private struct ProjectSummaryView: View {
    @EnvironmentObject private var store: PhotoOrganizerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("신축 빌딩 전기공사")
                .font(.headline)
            Text("서울 강남구 역삼동 123-45")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(store.doneCount), total: Double(max(store.records.count, 1)))
                .tint(.teal)
            HStack {
                StatView(title: "전체 사진", value: store.records.count)
                StatView(title: "검토 필요", value: store.reviewCount)
                StatView(title: "제출 완료", value: store.doneCount)
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
    @Binding var selectedPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                Label("사진 선택", systemImage: "photo.badge.plus")
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

    var isSelected: Bool {
        store.selectedID == record.id
    }

    var body: some View {
        Button {
            store.select(record)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                PreviewBlockView(record: record)
                    .frame(height: 118)
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
                Text(record.status.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.teal : Color(.separator), lineWidth: isSelected ? 2 : 1)
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
                    Text("업무 사진 샘플")
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
    @State private var assignee = ""
    @State private var status: WorkPhotoStatus = .unclassified
    @State private var memo = ""
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("사진 정보")
                .font(.headline)
            if let record = store.selectedRecord {
                PreviewBlockView(record: record)
                    .frame(height: 180)
                Group {
                    TextField("현장명", text: $siteName)
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
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("태그", text: $tagsText)
                }
                .textFieldStyle(.roundedBorder)
                Button("저장") {
                    store.updateSelected(
                        siteName: siteName,
                        category: category,
                        assignee: assignee,
                        status: status,
                        memo: memo,
                        tagsText: tagsText
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("savePhotoButton")
                Text("\(record.fileName) · \(byteText(record.size))")
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
        assignee = record.assignee
        status = record.status
        memo = record.memo
        tagsText = record.tags.joined(separator: ", ")
    }

    private func byteText(_ size: Int) -> String {
        if size < 1024 * 1024 {
            return "\(max(size / 1024, 0)) KB"
        }
        return String(format: "%.1f MB", Double(size) / 1024 / 1024)
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
