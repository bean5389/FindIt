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
| Step 1: PoC | Feature Print 유사도 검증 | Done |
| Step 2: 카메라 | 실시간 프레임 처리 | Done |
| Step 3: 데이터 & UI | 전체 화면 구현 | Done |
| Step 4: LiDAR & 객체 선택 | ARKit LiDAR 프리뷰 + 탭 기반 사물 세그먼트 | Pending |
| Step 5: ML 파이프라인 | CreateML On-device 학습 | Pending |
| Step 6: 폴리싱 | 애니메이션, 햅틱, 이펙트 | Pending |

## 빌드 요구사항

- Xcode 26.2+
- iOS 18+ 디바이스. **LiDAR** 기기 권장, 없어도 카메라만으로 동일 플로우 지원 (Vision 전경 분리)
