import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TargetItem.createdAt, order: .reverse) private var items: [TargetItem]
    @State private var viewModel = HomeViewModel()

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if items.isEmpty {
                    emptyState
                } else {
                    itemGrid
                }

                if !items.isEmpty {
                    gameStartButton
                }
            }
            .navigationTitle("보물찾기 도감")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showRegistration = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showRegistration) {
                RegistrationView()
            }
            .fullScreenCover(isPresented: $viewModel.showGame) {
                if let item = viewModel.selectedItem {
                    GameView(targetItem: item)
                }
            }
        }
        .task(id: items) {
            // Train/Retrain classifier whenever items change (add/delete)
            await ClassifierService.shared.train(items: items)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("등록된 물건이 없어요")
                .font(.title2)
                .fontWeight(.medium)
            Text("+ 버튼을 눌러 찾을 물건을 등록해 보세요!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var itemGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    itemCard(item)
                }
            }
            .padding()
        }
    }

    private func itemCard(_ item: TargetItem) -> some View {
        VStack(spacing: 8) {
            if let uiImage = UIImage(data: item.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= item.difficulty ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text("\(item.photos.count)장")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                viewModel.startGame(with: item)
            } label: {
                Label("게임 시작", systemImage: "play.fill")
            }

            Button(role: .destructive) {
                viewModel.deleteItem(item, context: modelContext)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .onTapGesture {
            viewModel.startGame(with: item)
        }
    }

    private var gameStartButton: some View {
        Button {
            viewModel.startRandomGame(items: items)
        } label: {
            Label("랜덤 보물찾기 시작!", systemImage: "sparkles")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .padding()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: TargetItem.self, inMemory: true)
}
