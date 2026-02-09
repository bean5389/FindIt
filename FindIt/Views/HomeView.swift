import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TreasureItem.createdAt, order: .reverse) private var items: [TreasureItem]
    @State private var showingCapture = false
    @State private var formData: CapturedData?
    @State private var selectedItemForGame: TreasureItem?
    
    struct CapturedData: Identifiable {
        let id = UUID()
        let image: UIImage
        let featurePrint: Data
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyStateView
                } else {
                    treasureGridView
                }
            }
            .navigationTitle("보물 도감")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCapture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCapture) {
                CapturePhotoView { image, featurePrint in
                    formData = CapturedData(image: image, featurePrint: featurePrint)
                }
            }
            .sheet(item: $formData) { data in
                ItemFormView(capturedImage: data.image, featurePrintData: data.featurePrint)
            }
            .fullScreenCover(item: $selectedItemForGame) { item in
                GameView(treasure: item)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "cube.transparent")
                .font(.system(size: Constants.UI.emptyStateIconSize))
                .foregroundStyle(.blue)

            Text("등록된 보물이 없어요")
                .font(.title2)
                .fontWeight(.semibold)

            Text("+ 버튼을 눌러 첫 보물을 등록해보세요!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var treasureGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Constants.UI.gridSpacing) {
                ForEach(items) { item in
                    TreasureCard(item: item)
                        .onTapGesture {
                            selectedItemForGame = item
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(Constants.UI.defaultPadding)
        }
    }
    
    private func deleteItem(_ item: TreasureItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

struct TreasureCard: View {
    let item: TreasureItem

    var body: some View {
        VStack(spacing: 8) {
            // 사진 미리보기
            if let photoData = item.photoData,
               let uiImage = UIImage(data: photoData) {
                Color.clear
                    .frame(height: Constants.UI.cardImageHeight)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Constants.UI.imageCornerRadius))
            } else {
                RoundedRectangle(cornerRadius: Constants.UI.imageCornerRadius)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: Constants.UI.cardImageHeight)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: Constants.UI.cardIconSize))
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    ForEach(Constants.UI.minDifficulty...Constants.UI.maxDifficulty, id: \.self) { star in
                        Image(systemName: star <= item.difficulty ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Constants.UI.cardInnerPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: TreasureItem.self, inMemory: true)
}
