# 업무 사진 정리함 iOS

업무 사진을 로컬에서 분류하고 메타데이터를 정리하는 SwiftUI iOS 앱입니다.
v0.2는 수동 메타데이터 정리함에서 자동 업무 사진 후보 분류함으로 확장했습니다.

## 기능

- 업무 사진 샘플 목록
- 상태/업무분류/촬영 유형/업무 후보 필터
- 검색
- 사진 상세 정보 편집
- PhotosPicker 기반 다중 사진 선택
- `PHAsset` 메타데이터 기반 스크린샷 감지
- 회사 위치 반경과 업무 시간 규칙 기반 업무 후보 표시
- 업무 후보/업무 확정/제외 플로우
- Face ID 또는 기기 암호 잠금 옵션
- JSON 내보내기 화면
- Shortcuts/Siri용 App Intents

## App Intents

- `OpenPhotoOrganizerIntent`: 전체/검토/제출완료/업로드 보기로 앱 열기
- `ShowReviewPhotosIntent`: 검토 필요 사진 보기
- `OpenWorkCandidatesIntent`: 업무 후보 사진 보기
- `SetWorkModeIntent`: 업무 모드 켜기/끄기
- `ReclassifyRecentPhotosIntent`: 최근 사진 재분류 화면 열기
- `WorkPhotoOrganizerShortcuts`: 시스템 Shortcuts 노출

## 개인정보 처리

- 서버, 계정, 네트워크 전송이 없습니다.
- 원본 사진, base64, blob, 로컬 파일 경로는 저장하거나 내보내지 않습니다.
- `assetLocalIdentifier`는 앱 내부 썸네일 복구용으로만 저장하고 JSON 내보내기에서는 제외합니다.
- 위치 좌표는 후보 판단에만 쓰며 JSON 내보내기에는 포함하지 않습니다.
- 저장/내보내기는 파일명, 현장명, 분류, 상태, 담당자, 메모, 태그, 후보/확정 상태 등 최소 메타데이터만 사용합니다.

## 개발

프로젝트 생성:

```bash
xcodegen generate
```

테스트/실행은 Xcode 또는 XcodeBuildMCP에서 `WorkPhotoOrganizer` scheme으로 수행합니다.

검증 기록은 [qa/verification.md](qa/verification.md)를 참고하세요.
