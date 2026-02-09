# FindIt - 우리집 보물찾기 도감 (Simple Photo 버전)

아이(6세)와 함께 집안 물건으로 보물찾기 놀이를 하는 iOS 앱.  
물건의 **정면 사진 1장**을 찍어 등록하고, Vision Framework로 해당 물건을 찾는 방식입니다.

## 주요 기능

### 1단계: 도감 등록 (부모)

#### 사물 선택 (스마트 선택)
- 카메라 프리뷰 실행
- **자동 모드**: Vision이 실시간으로 모든 사물 윤곽선 표시 (초록색)
  - 원하는 윤곽선을 탭하면 즉시 선택
- **수동 모드**: 윤곽선이 없을 때
  - 사물 중심을 탭하면 Vision이 자동으로 영역 추출
  - "이 사물이 맞나요?" 확인 후 선택

#### 등록 완료
- 선택된 사물의 사진 저장 (배경 제거 가능)
- 이름, 힌트, 난이도 입력
- Vision Feature Print 자동 추출 및 저장

### 2단계: 보물찾기 게임 (아이)
- 랜덤으로 선택된 보물의 미션 카드 표시
- 카메라로 집안을 비추면서 보물 찾기
- Vision Feature Print 실시간 매칭
- Hot & Cold 피드백 (유사도 기반)
  - **Cold** (< 0.35): 반응 없음 (텍스트만 반투명 표시)
  - **Warm** (0.35 ~ 0.45): 노란 테두리 + 가벼운 진동
  - **Hot** (0.45 ~ 0.6): 주황 테두리 + 중간 진동 + 맥동 효과
  - **Match** (≥ 0.6): 초록 테두리 + 강한 진동 + 맥동 효과, 1초 유지 시 성공!

## 기술 스택

| 항목 | 기술 |
|------|------|
| Platform | iOS 17+ |
| Hardware | **카메라만 있으면 OK** (모든 iPhone) |
| Language | Swift 6 |
| UI | SwiftUI |
| Persistence | SwiftData (사진 Data 저장) |
| 사진 촬영 | **AVFoundation** (간단한 카메라) |
| 이미지 인식 | **Vision Framework** (Feature Print) |
| 실시간 매칭 | Vision Feature Print 비교 |
| 외부 의존성 | 없음 (Apple 네이티브만 사용) |

## 인식 파이프라인

```
등록 플로우:
1. 카메라 프리뷰 실행
2. 실시간 사물 감지
   └── VNGenerateForegroundInstanceMaskRequest
   └── 감지된 사물마다 초록 윤곽선 표시
3. 사용자가 원하는 사물 탭
   ├── [자동] 윤곽선 있으면 즉시 선택
   └── [수동] 윤곽선 없으면 해당 지점 주변 자동 추출
4. 선택된 사물 확인 & 사진 저장
5. 이름, 힌트, 난이도 입력
6. Vision Feature Print 추출
   └── VNGenerateImageFeaturePrintRequest
7. SwiftData에 저장
   ├── 사진 (Data)
   └── Feature Print (Data)

게임 플로우:
1. 랜덤 보물 선택 → 미션 카드 표시
2. 카메라 실시간 프레임
3. 각 프레임마다 Feature Print 추출
4. 등록된 Feature Print와 유사도 비교
   └── VNFeaturePrintObservation.computeDistance()
5. 유사도 점수에 따라 피드백
   ├── < 0.3: Cold (반응 없음)
   ├── 0.3~0.5: Warm (노란 테두리)
   ├── 0.5~0.7: Hot (주황 테두리)
   └── >= 0.7: Match! (성공)
```

## 프로젝트 구조

```
FindIt/
├── FindItApp.swift                  # 앱 진입점 (AppDelegate)
├── ContentView.swift
├── Constants.swift                  # 앱 전체 상수 정의 (리팩토링)
├── Models/
│   └── TreasureItem.swift           # 보물 모델 (사진 + Feature Print)
├── Services/
│   ├── CameraService.swift          # AVFoundation 카메라
│   ├── VisionService.swift          # Feature Print 추출 & 매칭
│   ├── SegmentationService.swift    # 사물 감지 & 윤곽선 추출
│   └── HapticManager.swift          # 햅틱 피드백 관리
└── Views/
    ├── HomeView.swift               # 보물 도감 Grid
    └── Capture/
        ├── CapturePhotoView.swift   # 사물 선택 화면 (프리뷰 + 윤곽선)
        └── ItemFormView.swift       # 정보 입력
```

## 개발 진행 상황

| Phase | 설명 | 상태 |
|-------|------|------|
| ✅ Step 0 | 기본 앱 구조 & SwiftData | 완료 (2026-02-07) |
| ✅ Step 1 | 실시간 사물 감지 & 선택 | 완료 (2026-02-07) |
| ✅ Step 2 | 보물 등록 플로우 완성 | 완료 (2026-02-07) |
| ✅ Step 2.5 | 코드 리팩토링 & 회전 지원 | 완료 (2026-02-08) |
| ✅ Step 3 | 보물찾기 게임 화면 | 완료 (2026-02-09) |
| ✅ Step 4 | 실시간 매칭 & 피드백 | 완료 (2026-02-09) |
| ✅ Step 5 | 폴리싱 (애니메이션, 햅틱) | 완료 (2026-02-09) |

### v0.6 GameView UI/UX 대폭 개선 (2026-02-09)

**✅ 완료**
- **HapticManager 서비스 신규 추가**
  - Singleton 패턴으로 햅틱 피드백 중앙 관리
  - 0.3초 디바운싱으로 과도한 진동 방지
  - matchLevel별 차등 햅틱 (light/medium/heavy)
  - 성공 시 2단계 햅틱 (notification + heavy, 0.1초 간격)

- **성공 화면 애니메이션**
  - 전체 화면 스케일 + 투명도 전환 (0.6초 spring)
  - 요소별 순차 등장 (0.2초 간격)
    - 이미지 → 이모지 → "찾았다!" → 보물 이름 → 홈으로 버튼
  - 이미지 펄스 효과 (1.0 ↔ 1.05, 1초 주기)

- **바운딩 박스 시각 피드백 개선**
  - 색상 전환 부드러운 애니메이션 (0.3초 easeInOut)
  - hot/match 레벨에서 맥동 후광 효과
  - 실시간 맥동 애니메이션 (1.0 → 1.2 스케일)

- **상태 텍스트 개선**
  - cold 상태에서도 텍스트 표시 (반투명 60%)
  - matchLevel 변경 시 펄스 애니메이션 (1.0 → 1.15 → 1.0)

- **힌트 버튼 폴리싱**
  - 탭 시 스케일 애니메이션 (1.1배)
  - 라이트 햅틱 피드백
  - 힌트 오버레이 스케일 전환 (0.8 ↔ 1.0)

- **Constants 애니메이션 상수 추가**
  - Game.successTransitionDuration/Damping
  - Game.statusPulseResponse
  - Game.boxColorTransitionDuration/boxPulseDuration
  - Game.hintScaleResponse

**🎯 주요 효과**
- **몰입도 향상**: 햅틱 피드백으로 촉각적 몰입감 제공
- **시각적 연속성**: 부드러운 애니메이션으로 자연스러운 전환
- **성공 만족감**: 순차 등장 애니메이션으로 성취감 극대화
- **피드백 명확성**: cold 상태에서도 앱 작동 여부 명확히 표시

### v0.5 보물찾기 게임 화면 (2026-02-09)

**✅ 완료**
- **GameView 기본 구조**
  - 전체 화면 카메라 프리뷰
  - 하단 미션 카드 (보물 사진 + 이름 + 힌트 + 난이도)
  - 상단 바 (닫기, 타이틀, 힌트 버튼)

- **실시간 매칭 로직**
  - 0.5초 간격 Feature Print 매칭
  - 세그먼테이션 기반 개별 사물 크롭 비교
  - 바운딩 박스 실시간 표시
  - 유사도 임계값 조정 (match: 0.6, hot: 0.45, warm: 0.35)

- **Hot & Cold 피드백**
  - 유사도에 따른 4단계 피드백 (cold/warm/hot/match)
  - 바운딩 박스 색상 변경 (투명/노랑/주황/초록)
  - 상태 텍스트 및 매칭률 표시

- **성공 판정**
  - match 레벨 1초 유지 시 성공
  - 성공 화면 표시 (보물 사진 + "찾았다!" + 홈으로 버튼)

- **HomeView 연동**
  - 보물 카드 탭 → GameView fullScreenCover 표시
  - 게임 종료 시 홈으로 복귀

**🎯 주요 개선**
- **정확도**: 개별 사물 크롭으로 배경 간섭 최소화
- **반응성**: 0.5초 주기로 빠른 피드백
- **직관성**: 색상과 텍스트로 명확한 피드백
- **게임성**: 1초 유지 조건으로 적절한 난이도

### v0.4 코드 리팩토링 & 방향 최적화 (2026-02-08)

**✅ 완료**
- **Constants.swift 생성**: 모든 매직 넘버를 상수로 추출
  - Camera, Vision, Capture, ItemForm, UI 카테고리
  - 25개 이상의 매직 넘버 제거
- **화면 방향 최적화**:
  - AppDelegate로 전체 앱 Portrait 고정
  - 카메라 촬영 및 입력 폼에 최적화
  - 일관된 사용자 경험 제공
- README 및 Spec 문서 업데이트

**🎯 주요 개선**
- **유지보수성**: 상수 변경 시 한 곳에서만 수정
- **가독성**: 숫자 대신 의미 있는 이름 사용
- **사용자 경험**: Portrait 모드로 최적화된 일관된 UX
- **일관성**: 전체 앱에서 동일한 값 사용 보장
- **단순성**: 불필요한 회전 처리 코드 제거

### v0.3 보물 등록 플로우 완성 (2026-02-07)

**✅ 완료**
- 전체 등록 플로우 구현 및 테스트
- 여러 사물 동시 감지 (인스턴스별 세그먼테이션)
- 정확한 터치 좌표 매칭 (TouchableBox)
- 선택 시점 이미지 캡처 및 저장
- 이미지 크롭 (15% 여백 포함)
- HomeView 보물 그리드 표시
- SwiftData 저장 및 로드

**🎯 주요 기능**
- 실시간 여러 사물 감지 (0.5초 간격)
- 마스크 오버레이 표시 (초록색 0.3 opacity)
- 정확한 bounding box 터치 영역
- 탭으로 사물 선택 (노란색 0.5 opacity, 선택한 사물만 표시)
- 선택 시점 이미지 스냅샷 저장
- 15% 여백 포함 이미지 크롭
- Feature Print 추출 및 SwiftData 저장
- 보물 도감 그리드 UI (Portrait 2열 / Landscape 3열)

**🔧 해결한 문제**
- 터치 좌표 정렬: ContourOverlay와 동일한 AspectFill 스케일 적용
- 이미지 타이밍: 선택 시점에 이미지 캡처하여 카메라 움직임 방지
- bounding box 좌표계: top-left origin 일관성 유지
- Sheet 표시: CapturedData 구조체로 안정적인 데이터 전달

**📋 다음 작업**
1. GameView 생성 (미션 카드 + 실시간 매칭)
2. Hot & Cold 피드백 구현
3. 보물 찾기 성공 애니메이션

## 빌드 요구사항

- Xcode 16.2+
- iOS 17+ 디바이스
- **카메라만 있으면 OK** (모든 iPhone)
- Vision Framework 지원 (iOS 13+부터 기본 제공)

## 왜 Simple Photo 방식?

| 이유 | 설명 |
|------|------|
| 🎯 **단순함** | 사진 1장만 찍으면 끝! 6세 아이도 이해하기 쉬움 |
| ⚡ **빠름** | 즉시 등록, 즉시 게임 시작 가능 |
| 💾 **가벼움** | 사진 1장 = ~100KB, 3D 모델 = ~5MB |
| 📱 **범용성** | 모든 iPhone에서 작동 (LiDAR 불필요) |
| 🎮 **충분함** | Vision Feature Print 인식률 충분히 높음 |

## 한계점 & 해결 방안

| 한계 | 해결 방안 |
|------|----------|
| 각도 변화에 약함 | 정면에서 찍은 사진이면 대부분 인식됨 |
| 조명 변화에 민감 | Feature Print가 조명 변화를 어느 정도 보정 |
| 비슷한 물건 구별 어려움 | 난이도를 높여서 게임성 유지 |

## TreasureItem 데이터 모델

```swift
@Model
final class TreasureItem {
    var id: UUID
    var name: String                    // 보물 이름
    var hint: String                    // 힌트
    var difficulty: Int                 // 난이도 (1~5)
    var createdAt: Date
    
    @Attribute(.externalStorage)
    var photoData: Data?                // 사진 (JPEG)
    
    @Attribute(.externalStorage)
    var featurePrintData: Data?         // Vision Feature Print
}
```

## 구현 상세

### ✅ Phase 1 완료: 실시간 사물 감지 & 선택

#### CameraService (FindIt/Services/CameraService.swift)
- AVFoundation 기반 카메라 세션
- 1080x1920 portrait 캡처
- AspectFill crop (9:16 비율)
- Async/await 패턴으로 프레임 캡처
- 비동기 세션 설정 (continuation 패턴)
- **Portrait 고정**: 비디오 방향 90도 고정

#### SegmentationService (FindIt/Services/SegmentationService.swift)
- `VNGenerateForegroundInstanceMaskRequest` 사용
- 인스턴스별 세그먼테이션 (여러 사물 동시 감지)
- 마스크 이미지 생성 (픽셀 단위 정확도)
- Bounding box 자동 계산 (normalized coordinates)
- DetectedObject 모델: id, boundingBox, confidence, maskImage

#### VisionService (FindIt/Services/VisionService.swift)
- `VNGenerateImageFeaturePrintRequest` 사용
- Feature Print 추출 (인식용 벡터)
- Feature Print 비교 (computeDistance)
- **유사도 임계값**: Constants.Vision.SimilarityThreshold (0.35, 0.45, 0.6)
- MatchLevel 변환: Cold, Warm, Hot, Match

#### HapticManager (FindIt/Services/HapticManager.swift)
- Singleton 패턴 햅틱 피드백 관리
- UIImpactFeedbackGenerator (light/medium/heavy)
- UINotificationFeedbackGenerator (success)
- 0.3초 디바운싱으로 과도한 진동 방지
- matchLevel별 차등 햅틱, 성공 시 2단계 햅틱

#### CapturePhotoView (FindIt/Views/Capture/CapturePhotoView.swift)
- 실시간 감지 (Constants.Capture.detectionInterval = 0.5초)
- GeometryReader로 화면 크기 계산
- ContourOverlay: AspectFill 스케일 + Constants.Capture.maskScaleFactor (1.05)
- 선택되지 않은 사물: 초록색 Constants.Capture.unselectedOpacity (0.3)
- 선택된 사물: 노란색 Constants.Capture.selectedOpacity (0.5)
- 선택 확인 UI: 취소/확인 버튼
- 좌표 변환: Vision (normalized) → SwiftUI (points)

#### ItemFormView (FindIt/Views/Capture/ItemFormView.swift)
- 사진 미리보기
- 이름, 힌트, 난이도 입력
- SwiftData 저장

### ⏳ Phase 2: 보물 등록 플로우 완성
1. HomeView에 등록된 아이템 표시
2. 전체 플로우 테스트 및 버그 수정
3. 에러 처리 개선

### 🔨 Phase 3: 게임 화면 (Step 3)
1. GameView 기본 구조 (카메라 프리뷰 + 미션 카드)
2. 실시간 Feature Print 매칭 (0.5초 간격)
3. Hot & Cold 피드백 (테두리 색상 변경)
4. Match 1초 유지 시 성공 판정
5. 성공 화면 (보물 사진 + "찾았다!" + 홈으로)
6. HomeView에서 TreasureCard 탭 → GameView 연결

#### GameView 화면 구성
```
┌─────────────────────────┐
│ [X]     "보물을 찾아라!" │  ← 상단 바
├─────────────────────────┤
│                         │
│    [카메라 프리뷰]        │  ← 전체 화면 배경
│    (실시간 매칭 중)       │
│                         │
├─────────────────────────┤
│ ┌──────────────────┐    │
│ │ 📷  보물이름       │    │  ← 미션 카드 (하단)
│ │     힌트: ...     │    │
│ │     ⭐⭐          │    │
│ └──────────────────┘    │
│   "차가워요" / "뜨거워요!" │  ← 상태 텍스트
└─────────────────────────┘
 ↑ 테두리 색상이 유사도에 따라 변경
```

#### 피드백 레벨
| MatchLevel | 유사도 | 테두리 색 | 햅틱 | 효과 |
|-----------|-------|----------|------|------|
| Cold | < 0.35 | - | - | 상태 텍스트만 (반투명) |
| Warm | 0.35~0.45 | 노란색 | Light | - |
| Hot | 0.45~0.6 | 주황색 | Medium | 맥동 후광 |
| Match | ≥ 0.6 | 초록색 | Heavy | 맥동 후광 + 1초 유지 시 성공 |

### ⏳ Phase 4: 실시간 매칭
1. 실시간 Feature Print 매칭
2. Hot & Cold 피드백
3. 성공 애니메이션

### ⏳ Phase 5: 폴리싱
1. 애니메이션
2. 햅틱 피드백
3. 접근성
4. 에러 처리
## 기술적 해결 과제

### 1. 좌표계 정렬 문제
**문제**: 카메라 프리뷰와 Vision 마스크 오버레이 좌표가 맞지 않음

**해결 과정**:
1. 카메라 버퍼가 1080x1920 portrait임을 확인
2. Vision은 normalized coordinates (0-1) 사용
3. SwiftUI는 points (top-left origin) 사용
4. AspectFill 스케일 계산: `scale = max(widthScale, heightScale)`
5. 마스크가 사물 경계를 완벽히 감지하지 못해 5% 확대 적용

**최종 구현**:
```swift
let widthScale = frameSize.width / maskSize.width
let heightScale = frameSize.height / maskSize.height
let scale = max(widthScale, heightScale) * Constants.Capture.maskScaleFactor
```

### 2. 카메라 세션 설정 오류
**문제**: Fig errors (-12710, -17281), 세션이 시작되지 않음

**해결**: `sessionQueue.sync` 대신 async continuation 패턴 사용
```swift
try await withCheckedThrowingContinuation { continuation in
    sessionQueue.async { [weak self] in
        try self?.configureSession()
        continuation.resume()
    }
}
```

### 3. 실시간 성능 최적화
**문제**: 초기 1.0초 감지 간격이 너무 느림

**해결**: Constants.Capture.detectionInterval (0.5초)로 단축하여 반응성 개선
- Vision Framework 처리 시간: ~200ms
- 0.5초 간격이 적절한 균형점

### 4. 매직 넘버 제거 (2026-02-08)
**문제**: 코드 전체에 하드코딩된 숫자값 (25개 이상)

**해결**: Constants.swift 생성 및 카테고리별 분류
```swift
enum Constants {
    enum Camera { ... }        // 카메라 설정
    enum Vision { ... }        // 유사도 임계값
    enum Capture { ... }       // 캡처 UI
    enum ItemForm { ... }      // 폼 기본값
    enum Orientation { ... }   // 회전 설정
    enum UI { ... }           // 레이아웃
}
```

### 5. 화면 방향 최적화 (2026-02-08)
**문제**: 디바이스 회전 시 레이아웃 깨짐, 카메라 화면에서 가로 모드 부적합

**해결**: AppDelegate로 전체 앱 Portrait 고정
- AppDelegate에서 `.portrait`만 허용
- 카메라 촬영 및 텍스트 입력에 최적화된 세로 모드
- 단순하고 일관된 UX 제공
- 불필요한 회전 처리 코드 제거

## 사물 선택 UI/UX 상세

### 화면 구성 (현재 구현)
```
┌─────────────────────────┐
│   [X]                   │ ← 닫기 버튼
├─────────────────────────┤
│                         │
│    [카메라 프리뷰]         │
│                         │
│    🟢🟢   🟢🟢🟢         │ ← 실시간 마스크 오버레이
│    🟢🟢   🟢🟢🟢         │   (초록 0.3 / 노랑 0.5)
│                         │
├─────────────────────────┤
│  💡 초록색 윤곽선을         │ ← 안내 메시지
│     탭하거나 사물을 탭하세요  │
│                         │
│   [취소]      [확인]      │ ← 선택 시 표시
└─────────────────────────┘
```

### 상호작용 플로우
1. **자동 감지 모드**
   - 0.5초마다 실시간 사물 감지
   - 감지된 사물 마스크 오버레이 (초록색)
   - 마스크 탭 시 즉시 선택 (노란색)

2. **선택 확인**
   - "선택한 사물이 맞나요?" 메시지
   - [취소] 버튼: 선택 해제, 다시 감지 시작
   - [확인] 버튼: Feature Print 추출 후 ItemFormView 이동

3. **등록 완료**
   - ItemFormView에서 정보 입력
   - 사진 + Feature Print → SwiftData 저장

