import UIKit

/// 햅틱 피드백을 관리하는 서비스
final class HapticManager {
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    // 디바운싱을 위한 마지막 피드백 시간
    private var lastFeedbackTime: Date?
    private let cooldownDuration: TimeInterval = 0.3
    
    private init() {}
    
    /// matchLevel 변경 시 햅틱 피드백
    func triggerMatchLevelChange(to level: MatchLevel) {
        // 디바운싱: cooldown 기간 내에는 피드백 무시
        if let lastTime = lastFeedbackTime,
           Date().timeIntervalSince(lastTime) < cooldownDuration {
            return
        }
        
        switch level {
        case .warm:
            impactLight.impactOccurred()
        case .hot:
            impactMedium.impactOccurred()
        case .match:
            impactHeavy.impactOccurred()
        default:
            return
        }
        
        lastFeedbackTime = Date()
    }
    
    /// 성공 시 2단계 햅틱 피드백
    func triggerSuccess() {
        notificationGenerator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactHeavy.impactOccurred()
        }
    }
    
    /// 힌트 버튼 클릭 시 가벼운 햅틱 피드백
    func triggerLightImpact() {
        impactLight.impactOccurred()
    }
}
