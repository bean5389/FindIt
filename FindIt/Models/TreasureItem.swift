import Foundation
import SwiftData

@Model
final class TreasureItem {
    var id: UUID
    var name: String
    var hint: String
    var difficulty: Int
    var createdAt: Date
    
    // 사진 (JPEG)
    @Attribute(.externalStorage)
    var photoData: Data?
    
    // Vision Feature Print
    @Attribute(.externalStorage)
    var featurePrintData: Data?

    init(name: String, hint: String, difficulty: Int) {
        self.id = UUID()
        self.name = name
        self.hint = hint
        self.difficulty = difficulty
        self.createdAt = Date()
        self.photoData = nil
        self.featurePrintData = nil
    }
}
