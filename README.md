# FindIt - 우리집 보물찾기 도감

아이(6세)와 함께 집안 물건으로 보물찾기 놀이를 하는 iOS 앱.
부모가 물건을 다각도로 촬영해 등록하면, 아이가 카메라로 해당 물건을 찾는 게임입니다.

## 주요 기능

### 도감 등록 (Admin)
- 물건을 다각도로 촬영 (정면/뒷면/좌/우/위 가이드)
- 촬영 즉시 Vision Feature Print 벡터 추출 및 저장
- 이름, 힌트, 난이도 설정

### 탐색 게임 (Play)
- 미션 카드로 찾을 물건 제시
- 실시간 카메라 유사도 피드백 (Hot & Cold)
  - **Cold** (< 0.3): 반응 없음
  - **Warm** (0.3 ~ 0.6): 화면 테두리 색상 변경
  - **Hot** (0.6 ~ 0.8): 강한 시각적 강조
  - **Match** (>= 0.8): 1초 유지 시 성공 판정

## 기술 스택

| 항목 | 기술 |
|------|------|
| Platform | iOS 18+ |
| Language | Swift 6 |
| UI | SwiftUI |
| Persistence | SwiftData |
| 이미지 인식 | Vision Framework (`VNFeaturePrintObservation`) |
| ML 분류 (예정) | CreateML On-device Training |
| 카메라 | AVFoundation (8fps throttle) |
| 외부 의존성 | 없음 (Apple 네이티브만 사용) |

## 인식 파이프라인

```
카메라 프레임 (8fps)
├── [1차] Vision Feature Print → 유사도 거리 계산 (가중치 0.6)
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
│   └── TargetPhoto.swift         # 사진 모델 (Feature Print 포함)
├── Services/
│   ├── FeaturePrintService.swift # Vision 벡터 추출/비교
│   ├── ClassifierService.swift   # CreateML 분류기 (스텁)
│   ├── RecognitionService.swift  # 하이브리드 인식 조합
│   └── CameraService.swift       # AVCaptureSession 관리
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── RegistrationViewModel.swift
│   └── GameViewModel.swift
├── Views/
│   ├── HomeView.swift            # 도감 Grid + 게임 시작
│   ├── Registration/             # 등록 플로우 (촬영 → 정보 입력)
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
| Step 4: ML 파이프라인 | CreateML On-device 학습 | Pending |
| Step 5: 폴리싱 | 애니메이션, 햅틱, 이펙트 | Pending |

## 빌드 요구사항

- Xcode 26.2+
- iOS 18+ 디바이스 (카메라 필요)
