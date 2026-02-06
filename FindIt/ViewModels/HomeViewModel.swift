import SwiftUI
import SwiftData

@Observable
final class HomeViewModel {
    var showRegistration = false
    var selectedItem: TargetItem?
    var showGame = false

    func deleteItem(_ item: TargetItem, context: ModelContext) {
        context.delete(item)
    }

    func startGame(with item: TargetItem) {
        selectedItem = item
        showGame = true
    }

    func startRandomGame(items: [TargetItem]) {
        guard let item = items.randomElement() else { return }
        startGame(with: item)
    }
}
