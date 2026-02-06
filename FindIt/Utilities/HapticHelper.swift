import UIKit

/// Enhanced haptic feedback helper with generator caching for better performance
enum HapticHelper {
    // Reusable generators for better performance
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Standard impact feedback
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = impactLight
        case .medium: generator = impactMedium
        case .heavy: generator = impactHeavy
        case .soft: generator = impactSoft
        case .rigid: generator = impactRigid
        @unknown default: generator = impactMedium
        }
        generator.prepare()
        generator.impactOccurred()
    }

    /// Notification feedback (success, warning, error)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }

    /// Selection feedback (subtle)
    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    // MARK: - Convenience Methods

    /// Button tap feedback
    static func buttonTap() {
        impact(.light)
    }

    /// Item captured/registered
    static func itemCaptured() {
        impact(.medium)
    }

    /// Success action
    static func success() {
        notification(.success)
    }

    /// Warning action
    static func warning() {
        notification(.warning)
    }

    /// Error action
    static func error() {
        notification(.error)
    }

    /// Deletion action
    static func delete() {
        impact(.rigid)
    }

    /// Prepare for haptic (reduces latency)
    static func prepare(for style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = impactLight
        case .medium: generator = impactMedium
        case .heavy: generator = impactHeavy
        case .soft: generator = impactSoft
        case .rigid: generator = impactRigid
        @unknown default: generator = impactMedium
        }
        generator.prepare()
    }
}
