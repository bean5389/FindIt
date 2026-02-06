import Foundation
import SwiftData

@Model
final class TargetPhoto {
    var id: UUID
    @Attribute(.externalStorage)
    var imageData: Data
    @Attribute(.externalStorage)
    var featurePrintData: Data
    var angle: String
    var createdAt: Date

    var item: TargetItem?

    init(imageData: Data, featurePrintData: Data, angle: String) {
        self.id = UUID()
        self.imageData = imageData
        self.featurePrintData = featurePrintData
        self.angle = angle
        self.createdAt = Date()
    }
}
