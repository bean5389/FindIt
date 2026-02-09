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
- 미션 카드로 찾을 물건 제시 (보물 사진 + 이름 + 힌트 + 난이도)
- 실시간 카메라 유사도 피드백 (Hot & Cold)
  - **Cold** (< 0.35): 상태 텍스트만 반투명 표시
  - **Warm** (0.35 ~ 0.45): 노란 바운딩 박스 + 가벼운 진동
  - **Hot** (0.45 ~ 0.6): 주황 바운딩 박스 + 중간 진동 + 맥동 효과
  - **Match** (≥ 0.6): 초록 바운딩 박스 + 강한 진동 + 맥동 효과, 1초 유지 시 성공!
- 성공 시 순차 등장 애니메이션 + 2단계 햅틱 피드백
- 힌트 버튼으로 보물 사진 오버레이 확인 가능

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
│   ├── VisionService.swift       # Feature Print 추출 및 유사도 계산
│   └── HapticManager.swift       # 햅틱 피드백 관리 (0.3s 디바운싱)
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
| Step 4: 사물 감지 & 선택 | Vision 기반 실시간 사물 감지 + 스마트 선택 | ✅ Done |
| Step 5: 게임 화면 & 매칭 | 실시간 Feature Print 매칭 + Hot & Cold 피드백 | ✅ Done |
| Step 6: 폴리싱 | 햅틱 피드백, 애니메이션, 시각 효과 | ✅ Done |

### v0.6 GameView UI/UX 폴리싱 (2026-02-09)

**✅ 햅틱 피드백 구현**
- **HapticManager 서비스 신규 추가**
  - Singleton 패턴으로 햅틱 피드백 중앙 관리
  - matchLevel 변경 시 차등 햅틱 (warm: light, hot: medium, match: heavy)
  - 성공 시 2단계 햅틱 (notification + heavy, 0.1초 간격)
  - 0.3초 디바운싱으로 과도한 진동 방지
- **힌트 버튼 라이트 햅틱** 추가

**✅ 성공 화면 애니메이션**
- **전환 애니메이션**: 스케일(0.8→1.0) + 투명도 (0.6초 spring)
- **순차 등장 효과** (0.2초 간격):
  1. 이미지 스케일 업
  2. 이모지 페이드 인
  3. "찾았다!" 텍스트
  4. 보물 이름
  5. 홈으로 버튼
- **이미지 펄스**: 1초 주기로 1.0 ↔ 1.05 맥동

**✅ 바운딩 박스 시각 피드백 개선**
- **부드러운 색상 전환**: 0.3초 easeInOut 애니메이션
- **맥동 후광 효과** (hot/match 레벨):
  - 외곽 후광 링 (스케일 1.0 → 1.2)
  - 투명도 페이드 아웃 (0.8 → 0.0)
  - 1초 주기 반복

**✅ 상태 텍스트 개선**
- **cold 상태 가시성**: 반투명(60%)으로 항상 표시
- **matchLevel 펄스**: 레벨 변경 시 1.0 → 1.15 → 1.0 애니메이션

**✅ 힌트 UX 폴리싱**
- **버튼 스케일**: 활성 시 1.1배 확대
- **오버레이 전환**: 스케일 0.8 ↔ 1.0 spring 애니메이션

**✅ Constants 애니메이션 상수 추가**
- `Game.successTransitionDuration/Damping`
- `Game.statusPulseResponse`
- `Game.boxColorTransitionDuration/boxPulseDuration`
- `Game.hintScaleResponse`

**🎯 개선 효과**
- 촉각 피드백으로 게임 몰입도 향상
- 부드러운 애니메이션으로 시각적 연속성 확보
- 성공 순간의 만족감 극대화
- 앱 작동 상태 명확히 전달

### v0.5 보물찾기 게임 화면 (2026-02-09)

**✅ GameView 기본 구현**
- 전체 화면 카메라 프리뷰
- 하단 미션 카드 (보물 사진 + 이름 + 힌트 + 난이도)
- 상단 바 (닫기, 타이틀, 힌트 버튼)
- 성공 화면 (보물 사진 + "찾았다!" + 홈으로 버튼)

**✅ 실시간 매칭 로직**
- 0.5초 간격 Feature Print 매칭
- 세그먼테이션 기반 개별 사물 크롭 비교
- 바운딩 박스 실시간 표시
- 유사도 임계값 최적화 (match: 0.6, hot: 0.45, warm: 0.35)

**✅ Hot & Cold 피드백**
- 4단계 피드백 (cold/warm/hot/match)
- 바운딩 박스 색상 변경 (투명/노랑/주황/초록)
- 상태 텍스트 + 매칭률 실시간 표시
- Match 레벨 1초 유지 시 성공 판정

**✅ HomeView 연동**
- 보물 카드 탭 → GameView fullScreenCover
- 게임 종료 시 홈으로 복귀

**🎯 개선 효과**
- 개별 사물 크롭으로 정확도 향상
- 0.5초 주기로 빠른 반응성
- 색상과 텍스트로 직관적 피드백

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
