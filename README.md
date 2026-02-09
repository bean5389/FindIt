# FindIt - 우리집 보물찾기 도감

아이(6세)와 함께 집안 물건으로 보물찾기 놀이를 하는 iOS 앱.
부모가 물건을 다각도로 촬영해 등록하면, 아이가 카메라로 해당 물건을 찾는 게임입니다.

## 주요 기능

### 도감 등록 (Admin)
- **LiDAR 카메라 프리뷰**에서 사물을 **탭으로 선택**
- 탭 지점의 깊이로 사물 영역만 세그먼트 (배경 자동 제거)
- 물건을 다각도로 촬영 (정면/뒷면/좌/우/위 가이드)
- 촬영 즉시 Vision Feature Print 벡터 추출 및 저장
- 이름, 힌트, 난이도 설정

### 탐색 게임 (Play)
- 미션 카드로 찾을 물건 제시
- 실시간 카메라 유사도 피드백 (Hot & Cold)
  - **Cold** (< 0.25): 반응 없음
  - **Warm** (0.25 ~ 0.5): 화면 테두리 색상 변경
  - **Hot** (0.5 ~ 0.65): 강한 시각적 강조
  - **Match** (>= 0.65): 1초 유지 시 성공 판정 (개선된 임계값)

## 기술 스택

| 항목 | 기술 |
|------|------|
| Platform | iOS 18+ |
| Hardware | **LiDAR 우선** (iPhone 12 Pro+, iPad Pro 2020+). LiDAR 없음 → Vision 전경 분리 폴백 |
| Language | Swift 6 |
| UI | SwiftUI |
| Persistence | SwiftData |
| 캡처·깊이 | **ARKit (LiDAR)** + AVFoundation — 프리뷰, 객체 선택·세그먼트 |
| 이미지 인식 | Vision Framework (`VNFeaturePrintObservation`) — 세그먼트 영역 기준 |
| ML 분류 | k-NN Classifier (k=3) — On-device 학습, 역거리 가중치 투표 |
| 외부 의존성 | 없음 (Apple 네이티브만 사용) |

## 인식 파이프라인

```
카메라 + LiDAR 프리뷰
├── [객체 선택] 사용자 탭 → 깊이 기반 세그먼트 → 관심 사물 영역 추출
├── [1차] Vision Feature Print (세그먼트 영역) → 유사도 계산 (가중치 0.6)
├── [2차] k-NN Classifier (k=3) → 아이템 분류 (가중치 0.4)
└── 가중치 조합 → 최종 Confidence Score

학습 파이프라인:
아이템 등록/삭제 → 자동 재학습 (백그라운드) → k-NN 분류기 업데이트
```

## 프로젝트 구조

```
FindIt/
├── FindItApp.swift
├── ContentView.swift
├── Constants.swift               # 앱 전체 상수 정의 (리팩토링됨)
├── Models/
│   └── TreasureItem.swift        # 보물 아이템 모델 (SwiftData)
├── Services/
│   ├── CameraService.swift       # AVCaptureSession 관리
│   ├── SegmentationService.swift # Vision 기반 사물 감지 (VNGenerateForegroundInstanceMaskRequest)
│   └── VisionService.swift       # Feature Print 추출 및 유사도 계산
└── Views/
    ├── HomeView.swift            # 보물 도감 Grid
    ├── Capture/
    │   ├── CapturePhotoView.swift   # 실시간 사물 감지 및 선택
    │   └── ItemFormView.swift       # 보물 정보 입력 폼
    └── Game/
        └── GameView.swift           # 보물찾기 게임 화면 (Hot & Cold 피드백)
```

## 개발 진행 상황

| Phase | 설명 | 상태 |
|-------|------|------|
| Step 1: PoC | Feature Print 유사도 검증 | ✅ Done |
| Step 2: 카메라 | 실시간 프레임 처리 | ✅ Done |
| Step 3: 데이터 & UI | 전체 화면 구현 | ✅ Done |
| Step 4: LiDAR & 객체 선택 | ARKit LiDAR 프리뷰 + 탭 기반 사물 세그먼트 | ✅ Done |
| Step 5: ML 파이프라인 | k-NN On-device 학습 + UI 피드백 | ✅ Done |
| Step 6: 폴리싱 | 애니메이션, 햅틱, 이펙트, 접근성 | ✅ Done |

### v0.5 보물찾기 게임 화면 (2026-02-08)

**✅ 완료**
- GameView 구현: 카메라 프리뷰 + 실시간 Feature Print 매칭
- Hot & Cold 피드백: 유사도에 따라 테두리 색상 변경 (Cold/Warm/Hot/Match)
- Match 1초 유지 시 성공 판정 → 성공 화면 표시
- 미션 카드 UI: 보물 사진 + 이름 + 힌트 + 난이도 표시
- HomeView 연동: 보물 카드 탭 → GameView fullScreenCover 표시

## 코드 품질 개선 (2026-02-08)

### 리팩토링 완료
- ✅ **Constants.swift 생성**: 모든 매직 넘버를 의미 있는 상수로 추출
  - `Constants.Camera`: 카메라 관련 상수 (회전 각도, 화면 비율 등)
  - `Constants.Vision`: Vision 관련 상수 (유사도 임계값 등)
  - `Constants.Capture`: 캡처 UI 관련 상수 (애니메이션, 투명도 등)
  - `Constants.ItemForm`: 폼 관련 상수 (기본값, 압축 품질 등)
  - `Constants.Orientation`: 화면 회전 관련 상수 (그리드 컬럼 수)
  - `Constants.UI`: UI 레이아웃 상수 (크기, 간격, 모서리 반경 등)

- ✅ **화면 방향 최적화**: 전체 앱 Portrait 전용
  - AppDelegate를 통한 전역 방향 제어
  - 사물 촬영 및 텍스트 입력에 최적화된 세로 모드
  - 일관된 사용자 경험 제공

### 개선 효과
- **유지보수성 향상**: 상수 변경 시 한 곳에서만 수정
- **가독성 개선**: 숫자 대신 의미 있는 이름 사용
- **일관성 확보**: 전체 앱에서 동일한 값 사용 보장
- **사용자 경험 향상**: Portrait 모드로 최적화된 일관된 UX

## 빌드 요구사항

- Xcode 16.2+
- iOS 18+ 디바이스
- Vision Framework 지원 기기 (실시간 사물 감지)
