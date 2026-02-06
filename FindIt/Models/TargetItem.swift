import Foundation
import SwiftData

@Model
final class TargetItem {
    var id: UUID
    var name: String
    var hint: String
    @Attribute(.externalStorage)
    var thumbnailData: Data
    var difficulty: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TargetPhoto.item)
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
