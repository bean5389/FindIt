import Foundation
import CoreGraphics

/// 앱 전체에서 사용하는 상수 정의
enum Constants {
    
    // MARK: - Camera
    enum Camera {
        /// 카메라 회전 각도 (Portrait)
        static let portraitRotationAngle: CGFloat = 90
        
        /// 세션 정지 후 대기 시간 (초)
        static let sessionStopDelay: TimeInterval = 0.1
        
        /// 목표 화면 비율 (세로 모드: 9:16)
        static let targetAspectRatio: CGFloat = 9.0 / 16.0
        
        /// 화면 비율 비교 허용 오차
        static let aspectRatioTolerance: CGFloat = 0.01
        
        /// 이미지 스케일 기본값
        static let defaultImageScale: CGFloat = 1.0
    }
    
    // MARK: - Vision
    enum Vision {
        /// Feature Print 거리 정규화 계수
        static let distanceNormalizationFactor: Float = 2.0
        
        /// 유사도 임계값 (세그먼테이션 크롭 기준)
        enum SimilarityThreshold {
            /// 매치 임계값 (≥ 0.6) - 개별 사물 크롭 비교 시 정답 수준
            static let match: Float = 0.6

            /// 뜨거워요 임계값 (0.45 ~ 0.6) - 매우 유사한 사물
            static let hot: Float = 0.45

            /// 따뜻해요 임계값 (0.35 ~ 0.45) - 유사한 사물
            static let warm: Float = 0.35
        }
    }
    
    // MARK: - Capture
    enum Capture {
        /// 실시간 감지 주기 (초)
        static let detectionInterval: TimeInterval = 0.5

        /// 바운딩 박스 확장 비율 (15%)
        static let boundingBoxExpandRatio: CGFloat = 0.15

        /// 마스크 이미지 스케일 팩터 (5% 확대)
        static let maskScaleFactor: CGFloat = 1.05

        /// 바운딩 박스 선 두께
        static let boundingBoxLineWidth: CGFloat = 3

        /// 바운딩 박스 모서리 반경
        static let boundingBoxCornerRadius: CGFloat = 12

        /// 터치 영역 확대 비율 (선택을 쉽게 하기 위해)
        static let touchAreaExpandRatio: CGFloat = 0.2

        /// 화면 경계 마진 (화면 밖으로 나간 객체 제외)
        static let screenBoundaryMargin: CGFloat = 0.05

        /// 선택 애니메이션 지속 시간 (초)
        static let selectionAnimationDuration: TimeInterval = 0.2
    }
    
    // MARK: - Item Form
    enum ItemForm {
        /// 기본 난이도 (보통)
        static let defaultDifficulty: Int = 2
        
        /// 힌트 입력 최소 줄 수
        static let hintMinLines: Int = 3
        
        /// 힌트 입력 최대 줄 수
        static let hintMaxLines: Int = 6
        
        /// JPEG 압축 품질 (0.0 ~ 1.0)
        static let jpegCompressionQuality: CGFloat = 0.8
    }
    
    // MARK: - Game
    enum Game {
        /// 매칭 체크 주기 (초)
        static let matchingInterval: TimeInterval = 0.5
        
        /// 매치 유지 시간 (초) - 이 시간 동안 Match 유지 시 성공
        static let matchHoldDuration: TimeInterval = 1.0
        
        /// 피드백 테두리 두께
        static let feedbackBorderWidth: CGFloat = 8
        
        /// 미션 카드 높이
        static let missionCardHeight: CGFloat = 120
        
        /// 미션 이미지 크기
        static let missionImageSize: CGFloat = 80

        /// 감지 바운딩 박스 모서리 반경
        static let detectionBoxCornerRadius: CGFloat = 12

        /// 감지 바운딩 박스 선 두께
        static let detectionBoxLineWidth: CGFloat = 3
        
        // MARK: - Animation
        /// 성공 화면 전환 지속 시간 (초)
        static let successTransitionDuration: TimeInterval = 0.6
        
        /// 성공 화면 전환 댐핑 계수
        static let successTransitionDamping: CGFloat = 0.7
        
        /// 상태 텍스트 펄스 응답 시간 (초)
        static let statusPulseResponse: TimeInterval = 0.3
        
        /// 바운딩 박스 색상 전환 지속 시간 (초)
        static let boxColorTransitionDuration: TimeInterval = 0.3
        
        /// 바운딩 박스 맥동 지속 시간 (초)
        static let boxPulseDuration: TimeInterval = 1.0
        
        /// 힌트 스케일 응답 시간 (초)
        static let hintScaleResponse: TimeInterval = 0.4
    }
    
    // MARK: - UI
    enum UI {
        /// 빈 상태 아이콘 크기
        static let emptyStateIconSize: CGFloat = 80
        
        /// 카드 내 아이콘 크기
        static let cardIconSize: CGFloat = 40
        
        /// 그리드 간격
        static let gridSpacing: CGFloat = 16
        
        /// 기본 패딩
        static let defaultPadding: CGFloat = 16
        
        /// 카드 이미지 높이
        static let cardImageHeight: CGFloat = 150
        
        /// 난이도 최소값
        static let minDifficulty: Int = 1
        
        /// 난이도 최대값
        static let maxDifficulty: Int = 3
        
        /// 카드 내부 패딩
        static let cardInnerPadding: CGFloat = 8
        
        /// 카드 모서리 반경
        static let cardCornerRadius: CGFloat = 16
        
        /// 이미지 모서리 반경
        static let imageCornerRadius: CGFloat = 12
    }
}
