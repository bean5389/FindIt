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
├── Models/
│   ├── TargetItem.swift          # 물건 모델 (SwiftData)
│   └── TargetPhoto.swift         # 사진 모델 (Feature Print 포함)
├── Services/
│   ├── FeaturePrintService.swift # Vision 벡터 추출/비교
│   ├── ClassifierService.swift   # CreateML 분류기 (스텁)
│   ├── RecognitionService.swift  # 하이브리드 인식 조합
│   ├── SegmentationService.swift # 깊이 기반 객체 세그먼트
│   └── CameraService.swift       # AVCaptureSession / ARKit LiDAR 관리
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
| Step 1: PoC | Feature Print 유사도 검증 | ✅ Done |
| Step 2: 카메라 | 실시간 프레임 처리 | ✅ Done |
| Step 3: 데이터 & UI | 전체 화면 구현 | ✅ Done |
| Step 4: LiDAR & 객체 선택 | ARKit LiDAR 프리뷰 + 탭 기반 사물 세그먼트 | ✅ Done |
| Step 5: ML 파이프라인 | k-NN On-device 학습 + UI 피드백 | ✅ Done |
| Step 6: 폴리싱 | 애니메이션, 햅틱, 이펙트, 접근성 | ✅ Done |

---

**🎉 모든 단계 완료!** FindIt 앱이 완성되었습니다.

## 빌드 요구사항

- Xcode 26.2+
- iOS 18+ 디바이스. **LiDAR** 기기 권장, 없어도 카메라만으로 동일 플로우 지원 (Vision 전경 분리)
