# 업무 사진 정리함 iOS

업무 사진을 로컬에서 분류하고 메타데이터를 정리하는 SwiftUI iOS 앱입니다.

## 기능

- 업무 사진 샘플 목록
- 상태/업무분류 필터
- 검색
- 사진 상세 정보 편집
- PhotosPicker 기반 사진 선택 진입점
- JSON 내보내기 화면
- Shortcuts/Siri용 App Intents

## App Intents

- `OpenPhotoOrganizerIntent`: 전체/검토/제출완료/업로드 보기로 앱 열기
- `ShowReviewPhotosIntent`: 검토 필요 사진 보기
- `WorkPhotoOrganizerShortcuts`: 시스템 Shortcuts 노출

## 개인정보 처리

- 서버, 계정, 네트워크 전송이 없습니다.
- 원본 사진은 미리보기용 메모리에만 둡니다.
- 저장/내보내기는 파일명, 현장명, 분류, 상태, 담당자, 메모, 태그 등 메타데이터만 사용합니다.

## 개발

프로젝트 생성:

```bash
xcodegen generate
```

테스트/실행은 Xcode 또는 XcodeBuildMCP에서 `WorkPhotoOrganizer` scheme으로 수행합니다.

검증 기록은 [qa/verification.md](qa/verification.md)를 참고하세요.
