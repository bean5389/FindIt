import SwiftUI
import SwiftData

/// 보물 정보 입력 폼
struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let capturedImage: UIImage
    let featurePrintData: Data
    
    @State private var name: String = ""
    @State private var hint: String = ""
    @State private var difficulty: Int = Constants.ItemForm.defaultDifficulty
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // 사진 미리보기
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // 기본 정보
                Section("기본 정보") {
                    TextField("보물 이름", text: $name)
                        .textInputAutocapitalization(.never)
                    
                    TextField("힌트 (선택)", text: $hint, axis: .vertical)
                        .lineLimit(Constants.ItemForm.hintMinLines...Constants.ItemForm.hintMaxLines)
                        .textInputAutocapitalization(.sentences)
                }
                
                // 난이도
                Section {
                    Picker("난이도", selection: $difficulty) {
                        Text("쉬움 ⭐️").tag(1)
                        Text("보통 ⭐️⭐️").tag(2)
                        Text("어려움 ⭐️⭐️⭐️").tag(3)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("난이도")
                } footer: {
                    Text("아이가 이 보물을 찾기 어려운 정도를 선택해주세요.")
                }
            }
            .navigationTitle("보물 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }
    
    // MARK: - Methods
    private func saveItem() {
        guard !name.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                // JPEG로 압축
                guard let photoData = capturedImage.jpegData(compressionQuality: Constants.ItemForm.jpegCompressionQuality) else {
                    throw ItemFormError.imageCompressionFailed
                }
                
                // TreasureItem 생성
                let item = TreasureItem(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    hint: hint.trimmingCharacters(in: .whitespacesAndNewlines),
                    difficulty: difficulty
                )
                
                item.photoData = photoData
                item.featurePrintData = featurePrintData
                
                // SwiftData에 저장
                await MainActor.run {
                    modelContext.insert(item)
                    
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        isSaving = false
                        errorMessage = "저장에 실패했습니다: \(error.localizedDescription)"
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Errors
enum ItemFormError: LocalizedError {
    case imageCompressionFailed
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "이미지 압축에 실패했습니다."
        }
    }
}

// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([TreasureItem.self])
    let container = try! ModelContainer(for: schema, configurations: config)
    
    // 샘플 이미지 생성
    let size = CGSize(width: 200, height: 200)
    let renderer = UIGraphicsImageRenderer(size: size)
    let sampleImage = renderer.image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    
    return ItemFormView(
        capturedImage: sampleImage,
        featurePrintData: Data()
    )
    .modelContainer(container)
}
