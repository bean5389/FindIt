# FindIt - App Specification

## 1. App Overview

- **App Name**: FindIt - 우리집 보물찾기 도감
- **Platform**: iOS 18+
- **Framework**: SwiftUI + SwiftData
- **Language**: Swift 6
- **Minimum iOS Version**: iOS 18
- **Description**: Apple Vision Framework와 CreateML 기반 하이브리드 인식 기술을 활용해, 사용자가 직접 등록한 사물을 카메라로 인식하고 찾는 보물찾기 앱. 아이(6세)와 함께 집안 물건으로 보물찾기 놀이를 할 수 있는 게이미피케이션 앱.
- **Target User**: 개발자 아빠(관리자) & 6세 아들(플레이어)

---

## 2. Core Tech

**하이브리드 인식(Vision + ML)** 방식을 사용한다. Vision Feature Print로 이미지 유사도를 매칭하고, CreateML Image Classifier로 카테고리 분류를 보조하여 두 결과를 조합한다.

### 2.1 하이브리드 인식 파이프라인

```
카메라 프레임
├── [1차] Vision Feature Print → 유사도 거리 계산 (메인)
├── [2차] CreateML Image Classifier → 카테고리 분류 (보조)
└── 두 결과를 가중치 조합 → 최종 Confidence Score
```

### 2.2 기술 상세

- **Vision Framework**: `VNGenerateImageFeaturePrintRequest`
  - 이미지를 고유한 벡터값(Feature Print)으로 변환
  - 두 이미지(등록된 사진 vs 실시간 카메라 화면)의 벡터 거리를 계산하여 동일 물건 여부 판별
  - **역할**: 메인 인식 엔진. 등록된 특정 물건과의 1:1 유사도 측정
- **CreateML / Core ML**: `MLImageClassifier` (On-device Training)
  - 등록된 물건들의 다각도 사진으로 On-device 학습하여 분류 모델 생성
  - 물건 카테고리 분류를 통해 Feature Print 매칭 대상을 사전 필터링
  - **역할**: 보조 인식 엔진. 각도/조명 변화에 대한 Feature Print의 약점 보완
- **가중치 조합**: 최종 Confidence = (Feature Print 유사도 x 0.6) + (ML 분류 확신도 x 0.4) *(가중치는 PoC에서 튜닝)*
- **SwiftData**: 등록된 물건의 메타데이터, 벡터 데이터, 학습 이미지를 로컬에 저장
- **AVFoundation**: 커스텀 카메라 뷰를 구성하고 실시간 프레임 처리를 담당

---

## 3. Core Features

### 3.1 도감 등록 (Admin Mode) - Phase 1 MVP

- **Description**: 찾고 싶은 물건을 다각도로 촬영하여 도감에 등록하고, ML 학습 데이터를 수집하는 기능
- **User Story**: 관리자(아빠)로서 찾을 물건을 여러 각도에서 사진으로 등록하고 이름, 힌트, 난이도를 설정한다.
- **Acceptance Criteria**:
  - [ ] 물건 사진 다각도 촬영 (최소 5장, 권장 10장)
  - [ ] 촬영 즉시 각 사진의 Feature Print(벡터) 추출 및 저장
  - [ ] 촬영 가이드 UI 제공 (앞/뒤/좌/우/위 안내)
  - [ ] 물건 이름 입력
  - [ ] 난이도 설정 (1~5)
  - [ ] 힌트 텍스트 입력
  - [ ] 등록 완료 시 ML 모델 재학습 트리거

### 3.2 탐색 게임 (Play Mode) - Phase 1 MVP

- **Description**: 등록된 물건 중 하나를 선택하여 카메라로 실시간 탐색하는 게임
- **User Story**: 플레이어(아이)로서 미션 카드를 받고 카메라로 물건을 찾는다.
- **Acceptance Criteria**:
  - [ ] 등록된 물건 중 랜덤 또는 선택하여 미션 시작
  - [ ] 실시간 유사도 피드백 (Hot & Cold)
    - Cold: 유사도 낮음 (반응 없음)
    - Warm: 유사도 증가 (화면 테두리 색상 변경 or 햅틱 진동 약하게)
    - Hot: 유사도 높음 (강한 진동, 시각적 강조)
  - [ ] 성공 판정: 일정 시간(1초) 이상 임계값(Threshold 0.8)을 넘으면 성공 이펙트 발동

### 3.3 ML 모델 학습 (Background) - Phase 1 MVP

- **Description**: 등록된 물건들의 사진 데이터로 On-device Image Classifier 모델을 학습하는 기능
- **User Story**: 물건 등록/삭제 시 자동으로 ML 모델이 갱신되어 인식 정확도가 향상된다.
- **Acceptance Criteria**:
  - [ ] CreateML `MLImageClassifier`를 이용한 On-device 학습
  - [ ] 백그라운드에서 비동기 학습 처리
  - [ ] 학습 완료 시 Core ML 모델 자동 교체 (Hot-swap)
  - [ ] 물건 추가/삭제 시 재학습 트리거
  - [ ] 학습 진행률 표시 (선택)

### 3.4 음성 안내 (TTS) - Phase 2

- **Description**: 글자를 모르는 아이를 위해 미션 이름을 읽어주는 기능
- **User Story**: 플레이어(아이)로서 "아빠의 차 키를 찾아보세요!" 같은 음성 안내를 듣는다.

### 3.5 타임어택 - Phase 2

- **Description**: 제한 시간 내에 물건 찾기 모드

---

## 4. UI/UX Design

### 4.1 Screen List

| Screen | Description |
|--------|-------------|
| 홈 화면 | 도감 리스트 (Grid) + 게임 시작 버튼 |
| 등록 화면 (Admin) | 카메라 촬영 + 물건 정보 입력 폼 |
| 미션 카드 화면 | 랜덤/선택된 물건의 미션 카드 표시 |
| 게임 화면 | 실시간 카메라 + 유사도 게이지 Overlay UI |
| 성공 화면 | 폭죽 이펙트 + 결과 표시 |

### 4.2 Navigation Flow

```
홈 화면 (도감 Grid)
├── [+] 등록 → 등록 화면 (카메라 촬영 → 정보 입력 → 저장 → 홈으로)
├── [아이템 탭] → 아이템 상세
└── [게임 시작] → 미션 카드 화면 → 게임 화면 → 성공 화면 → 홈으로
```

### 4.3 Design Guidelines

- **Color Scheme**: 아이 친화적인 밝고 따뜻한 색상
- **Typography**: 큰 글씨, 아이가 읽기 쉬운 폰트
- **Icons**: SF Symbols 활용

---

## 5. Data Model

### 5.1 Entities

| Entity | Property | Type | Description |
|--------|----------|------|-------------|
| TargetItem | id | UUID | 고유 식별자 |
| TargetItem | name | String | 물건 이름 (예: "아빠 키보드") |
| TargetItem | hint | String | 힌트 (예: "책상 위에 있어") |
| TargetItem | thumbnailData | Data | 썸네일 표시용 대표 이미지 데이터 |
| TargetItem | difficulty | Int | 난이도 (1~5) |
| TargetItem | createdAt | Date | 등록 일시 |
| TargetItem | photos | [TargetPhoto] | 다각도 촬영 사진 목록 (관계) |
| TargetPhoto | id | UUID | 고유 식별자 |
| TargetPhoto | imageData | Data | 촬영된 이미지 데이터 |
| TargetPhoto | featurePrint | Data | Vision이 추출한 벡터 데이터 |
| TargetPhoto | angle | String | 촬영 각도 (front, back, left, right, top) |
| TargetPhoto | createdAt | Date | 촬영 일시 |
| TargetPhoto | item | TargetItem | 소속 물건 (역관계) |

### 5.2 Relationships

- **TargetItem** 1 : N **TargetPhoto** (한 물건에 여러 장의 다각도 사진)

### 5.3 Schema

```swift
@Model
class TargetItem {
    var id: UUID
    var name: String
    var hint: String
    var thumbnailData: Data
    var difficulty: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var photos: [TargetPhoto]

    init(name: String, hint: String, thumbnailData: Data, difficulty: Int) {
        self.id = UUID()
        self.name = name
        self.hint = hint
        self.thumbnailData = thumbnailData
        self.difficulty = difficulty
        self.createdAt = Date()
        self.photos = []
    }
}

@Model
class TargetPhoto {
    var id: UUID
    var imageData: Data
    var featurePrint: Data
    var angle: String
    var createdAt: Date

    @Relationship(inverse: \TargetItem.photos)
    var item: TargetItem?

    init(imageData: Data, featurePrint: Data, angle: String) {
        self.id = UUID()
        self.imageData = imageData
        self.featurePrint = featurePrint
        self.angle = angle
        self.createdAt = Date()
    }
}
```

---

## 6. Architecture

- **Pattern**: MVVM
- **Concurrency**: Modern Concurrency (async/await)
- **State Management**: SwiftUI @Observable / @Query
- **Persistence**: SwiftData (On-device)
- **ML Pipeline**: CreateML On-device Training → Core ML Inference

---

## 7. Third-Party Dependencies

| Library | Purpose | Version |
|---------|---------|---------|
| 없음 (Apple 네이티브만 사용) | - | - |

---

## 8. Development Milestones

| Phase | Description | Status |
|-------|-------------|--------|
| Step 1: PoC | 정적 이미지로 Feature Print 유사도 거리 검증 + CreateML Image Classifier PoC + 하이브리드 가중치 튜닝 | Pending |
| Step 2: 카메라 | AVCaptureVideoDataOutput 실시간 프레임 처리 + Vision/ML 이중 추론 비동기 처리 | Pending |
| Step 3: 데이터 & UI | SwiftData CRUD (TargetItem + TargetPhoto) + 다각도 등록 뷰 + 리스트 뷰(Grid) + 게임 뷰(Overlay) | Pending |
| Step 4: ML 파이프라인 | On-device CreateML 학습 + Core ML 모델 Hot-swap + 재학습 트리거 | Pending |
| Step 5: 폴리싱 | 유사도 게이지 애니메이션 + CoreHaptics 진동 + 성공 이펙트(Confetti) | Pending |

---

## 9. Notes

- **조명 이슈**: Vision의 FeaturePrint는 조명에 강한 편이지만, 너무 어두우면 인식 불가. "밝은 곳에서 찍어주세요" 안내 필요.
- **배경 노이즈**: 물건 등록 시 배경이 단순할수록 인식률이 좋음. Focus 영역 처리 검토.
- **발열 관리**: 실시간 영상 처리 시 1초에 60프레임 모두 검사하지 않고, 5~10번만 검사하도록 throttle 처리 필수.
- **ML 학습 데이터**: 물건당 최소 5장, 권장 10장 이상의 다각도 사진이 필요. 등록 UX에서 촬영 가이드를 제공하여 데이터 품질 확보.
- **ML 학습 시간**: On-device 학습은 물건 수와 사진 수에 따라 수초~수십 초 소요. 백그라운드 처리 + 진행률 표시 필요.
- **하이브리드 가중치**: Feature Print(0.6) + ML(0.4) 기본값이며, PoC 단계에서 실측 데이터 기반 튜닝 필요.
