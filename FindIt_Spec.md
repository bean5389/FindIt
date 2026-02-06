# FindIt - 우리집 보물찾기 도감

아이(6세)와 함께 집안 물건으로 보물찾기 놀이를 하는 iOS 앱.  
**LiDAR**를 사용해, **프리뷰에 나오는 사물을 탭해서 선택**해 등록하고, 찾기에서도 같은 프리뷰로 해당 물건을 찾는 방식입니다. (단순 사진 촬영이 아님.)

## 주요 기능

### 도감 등록 (Admin)
- **LiDAR 카메라 프리뷰**에서 찾을 **사물을 탭으로 선택**
- 탭 위치의 깊이로 **사물 영역만 세그먼트** (배경 제외) 후 Feature Print 추출·저장
- 이름, 힌트, 난이도 설정 (선택: 다른 각도에서 다시 탭해 스냅샷 추가)

### 탐색 게임 (Play)
- 미션 카드로 찾을 물건 제시
- **동일 LiDAR 프리뷰**로 실시간 탐색, 등록된 "선택 사물"과 유사도 비교
- Hot & Cold 피드백
  - **Cold** (< 0.3): 반응 없음
  - **Warm** (0.3 ~ 0.6): 화면 테두리 색상 변경
  - **Hot** (0.6 ~ 0.8): 강한 시각적 강조
  - **Match** (>= 0.8): 1초 유지 시 성공 판정

## 기술 스택

| 항목 | 기술 |
|------|------|
| Platform | iOS 18+ |
| Hardware | **LiDAR 우선** (iPhone 12 Pro 이상, iPad Pro 2020 이상). **LiDAR 없음** → 카메라 + Vision 전경 분리 폴백 |
| Language | Swift 6 |
| UI | SwiftUI |
| Persistence | SwiftData |
| 캡처·깊이 | **ARKit (LiDAR)** + AVFoundation — 프리뷰, 객체 선택·세그먼트 |
| 이미지 인식 | Vision Framework (`VNFeaturePrintObservation`) — 세그먼트 영역 기준 |
| ML 분류 (예정) | CreateML On-device Training |
| 외부 의존성 | 없음 (Apple 네이티브만 사용) |

## 인식 파이프라인

```
카메라 + LiDAR 프리뷰
├── [객체 선택] 사용자 탭 → 깊이 기반 세그먼트 → 관심 사물 영역 추출
├── [1차] Vision Feature Print (세그먼트 영역) → 유사도 계산 (가중치 0.6)
├── [2차] CreateML Image Classifier → 카테고리 분류 (가중치 0.4, 예정)
└── 가중치 조합 → 최종 Confidence Score
```

## 프로젝트 구조

```
FindIt/
├── FindItApp.swift
├── ContentView.swift
├── Models/
│   ├── TargetItem.swift          # 물건 모델 (SwiftData)
│   └── TargetPhoto.swift         # 세그먼트된 사물 스냅샷 (Feature Print 포함)
├── Services/
│   ├── FeaturePrintService.swift # Vision 벡터 추출/비교
│   ├── ClassifierService.swift   # CreateML 분류기 (스텁)
│   ├── RecognitionService.swift  # 하이브리드 인식 조합
│   └── CameraService.swift       # AVCaptureSession / ARKit LiDAR 관리
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── RegistrationViewModel.swift
│   └── GameViewModel.swift
├── Views/
│   ├── HomeView.swift            # 도감 Grid + 게임 시작
│   ├── Registration/             # 등록 플로우 (프리뷰 탭 선택 → 세그먼트 확인 → 정보 입력)
│   ├── Game/                     # 게임 플로우 (미션 → 탐색 → 성공)
│   └── Components/               # CameraPreviewView
└── Utilities/
    └── ImageHelper.swift         # 이미지 변환 유틸
```

## 개발 진행 상황

| Phase | 설명 | 상태 |
|-------|------|------|
| Step 1: PoC | Feature Print 유사도 검증 | ✅ Done |
| Step 2: 카메라 | 실시간 프레임 처리 | ✅ Done |
| Step 3: 데이터 & UI | 전체 화면 구현 | ✅ Done |
| Step 4: LiDAR & 객체 선택 | ARKit LiDAR 프리뷰 + 탭 기반 사물 세그먼트 + 깊이 기반 세그먼트 | ✅ Done |
| Step 5: ML 파이프라인 | k-NN On-device 학습 + UI 피드백 | ✅ Done |
| Step 6: 폴리싱 | 애니메이션, 햅틱, 이펙트, 접근성 | ✅ Done |

### Step 4 구현 세부사항 (2026-02-06 완료)

**✅ LiDAR 깊이 기반 세그먼테이션**
- `SegmentationService.segmentObjectWithDepth()`: LiDAR 깊이 맵 활용
- 탭한 지점의 깊이 값 추출 → 유사 깊이 영역만 분리
- Vision 인스턴스 마스크와 깊이 마스크 결합 (AND 연산)
- LiDAR 없는 기기는 자동으로 Vision-only 폴백

**✅ CameraService 개선**
- `capturePhotoWithDepth()`: ARFrame + 깊이 맵 동시 캡처
- `smoothedSceneDepth` 우선, `sceneDepth` 폴백

**✅ 등록 플로우 통합**
- CapturePhotoView: LiDAR 사용 가능 시 깊이 데이터 전달
- RegistrationViewModel: 깊이 맵 있으면 `segmentObjectWithDepth()` 사용

### Step 5 구현 세부사항 (2026-02-06 완료)

**✅ k-NN 기반 분류기 (On-device Learning)**
- ClassifierService: Vision Feature Print 기반 k=3 최근접 이웃
- 역거리 가중치 투표로 정확도 향상
- 완전한 on-device 학습 (서버 불필요)
- O(N) 선형 탐색 (< 1000개 아이템까지 효율적)

**✅ 하이브리드 인식 파이프라인**
- RecognitionService: Feature Print (0.6) + k-NN (0.4) 가중치 조합
- 모델 없으면 자동으로 FP만 사용
- 1:N 식별 & 1:1 검증 지원

**✅ UI 피드백 시스템**
- 학습 진행 상황 실시간 표시
- 진행률 바 & 퍼센트 표시
- 학습 완료 시 성공 애니메이션
- 학습 샘플 수 & 소요 시간 표시

**✅ 성능 최적화**
- 백그라운드 학습 (UI 블로킹 없음)
- 성능 메트릭 로깅 (학습/분류 시간 측정)
- 자동 재학습 (아이템 추가/삭제 시)
- 학습 상태 추적 (idle/training/ready/failed)

### Step 6 구현 세부사항 (2026-02-06 완료)

**✅ HapticHelper 강화**
- 제너레이터 재사용으로 성능 개선 (캐싱)
- prepare() 호출로 햅틱 지연 감소
- 편의 메서드 추가 (buttonTap, itemCaptured, success, error, delete)
- 5가지 impact 스타일 지원 (light, medium, heavy, soft, rigid)

**✅ 햅틱 피드백 추가**
- 버튼 탭 시 light impact
- 사진 캡처 시 medium impact
- 아이템 등록 완료 시 success notification
- 아이템 삭제 시 rigid impact
- 난이도 선택 시 selection feedback
- 오류 발생 시 error notification

**✅ 애니메이션 개선**
- HomeView 카드 등장 애니메이션 (순차 delay)
- MissionCard 단계별 등장 (제목 → 이미지 → 힌트 → 버튼)
- PulseButtonStyle - 버튼 누름 효과 (spring 애니메이션)
- SimilarityGauge pulse 애니메이션 (80% 이상 시)
- SuccessView Confetti 효과 (이미 구현됨)

**✅ 접근성 개선**
- VoiceOver 레이블 추가 (모든 주요 UI 요소)
- accessibilityHint로 상세 설명 제공
- accessibilityValue로 동적 상태 전달
- SimilarityGaugeView 음성 피드백 ("뜨거워요!", "차가워요" 등)
- 난이도 선택 isSelected trait
- 버튼 상태에 따른 hint 변경

**✅ 비주얼 이펙트**
- 버튼 그림자 효과 (green, blue 등)
- Material 배경 (.ultraThinMaterial)
- Scale & opacity 전환 효과
- Rotation 애니메이션 (MissionCard 이미지)

## 빌드 요구사항

- Xcode 26.2+
- iOS 18+ 디바이스. **LiDAR** 기기 권장, 없어도 카메라만으로 동일 플로우 지원 (Vision 전경 분리)
