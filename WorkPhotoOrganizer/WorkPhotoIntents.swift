import AppIntents
import Combine
import Foundation

enum OrganizerDestination: String, AppEnum {
    case all
    case review
    case done
    case upload
    case candidates
    case screenshots

    static var typeDisplayName: LocalizedStringResource { "사진 보기" }
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "사진 보기")

    static var caseDisplayRepresentations: [OrganizerDestination: DisplayRepresentation] {
        [
            .all: "전체 사진",
            .review: "검토 필요",
            .done: "제출 완료",
            .upload: "사진 추가",
            .candidates: "업무 후보",
            .screenshots: "스크린샷"
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

struct OpenWorkCandidatesIntent: AppIntent {
    static let title: LocalizedStringResource = "업무 후보 사진 보기"
    static let description = IntentDescription("자동 분류된 업무 후보 사진 목록을 엽니다.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.destination = .candidates
        }
        return .result()
    }
}

struct SetWorkModeIntent: AppIntent {
    static let title: LocalizedStringResource = "업무 모드 설정"
    static let description = IntentDescription("사진 후보 분류에 사용할 업무 모드를 켜거나 끕니다.")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "업무 모드 켜기")
    var enabled: Bool

    init() {
        enabled = true
    }

    init(enabled: Bool) {
        self.enabled = enabled
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(enabled, forKey: "work-photo-organizer-ios:workModeEnabled")
        await MainActor.run {
            AppIntentRouter.shared.destination = .candidates
        }
        return .result(dialog: enabled ? "업무 모드를 켰습니다." : "업무 모드를 껐습니다.")
    }
}

struct ReclassifyRecentPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "최근 사진 재분류"
    static let description = IntentDescription("앱을 열어 최근 업무 후보 사진을 다시 확인합니다.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.destination = .candidates
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
        AppShortcut(
            intent: OpenWorkCandidatesIntent(),
            phrases: [
                "\(.applicationName)에서 업무 후보 보여줘",
                "\(.applicationName) 업무 사진 후보"
            ],
            shortTitle: "업무 후보",
            systemImageName: "briefcase"
        )
        AppShortcut(
            intent: SetWorkModeIntent(enabled: true),
            phrases: [
                "\(.applicationName)에서 업무 모드 켜",
                "\(.applicationName) 업무 모드 시작"
            ],
            shortTitle: "업무 모드",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: ReclassifyRecentPhotosIntent(),
            phrases: [
                "\(.applicationName)에서 최근 사진 재분류",
                "\(.applicationName) 사진 다시 분류"
            ],
            shortTitle: "재분류",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
