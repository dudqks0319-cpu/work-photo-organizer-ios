import AppIntents
import Combine
import Foundation

enum OrganizerDestination: String, AppEnum {
    case all
    case review
    case done
    case upload

    static var typeDisplayName: LocalizedStringResource { "사진 보기" }
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "사진 보기")

    static var caseDisplayRepresentations: [OrganizerDestination: DisplayRepresentation] {
        [
            .all: "전체 사진",
            .review: "검토 필요",
            .done: "제출 완료",
            .upload: "사진 추가"
        ]
    }
}

@MainActor
final class AppIntentRouter: ObservableObject {
    static let shared = AppIntentRouter()
    @Published var destination: OrganizerDestination?

    private init() {}
}

struct OpenPhotoOrganizerIntent: AppIntent {
    static let title: LocalizedStringResource = "업무 사진 정리 열기"
    static let description = IntentDescription("업무 사진 정리함을 원하는 보기로 엽니다.")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "보기")
    var destination: OrganizerDestination

    init() {
        destination = .all
    }

    init(destination: OrganizerDestination) {
        self.destination = destination
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.destination = destination
        }
        return .result()
    }
}

struct ShowReviewPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "검토 사진 보기"
    static let description = IntentDescription("검토가 필요한 업무 사진 목록을 엽니다.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.destination = .review
        }
        return .result()
    }
}

struct WorkPhotoOrganizerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPhotoOrganizerIntent(destination: .all),
            phrases: [
                "\(.applicationName)에서 업무 사진 열기",
                "\(.applicationName) 사진 정리 열어"
            ],
            shortTitle: "사진 정리",
            systemImageName: "photo.on.rectangle"
        )
        AppShortcut(
            intent: ShowReviewPhotosIntent(),
            phrases: [
                "\(.applicationName)에서 검토 사진 보여줘",
                "\(.applicationName) 검토 필요 사진"
            ],
            shortTitle: "검토 사진",
            systemImageName: "checklist"
        )
    }
}
