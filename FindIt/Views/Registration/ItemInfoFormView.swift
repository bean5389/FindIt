import SwiftUI

struct ItemInfoFormView: View {
    @Bindable var viewModel: RegistrationViewModel

    var body: some View {
        Form {
            Section("사진") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.capturedPhotos.enumerated()), id: \.offset) { index, photo in
                            PhotoThumbnailView(
                                image: photo.image,
                                angle: photo.angle
                            )
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("물건 정보") {
                TextField("이름 (예: 아빠 키보드)", text: $viewModel.name)

                TextField("힌트 (예: 책상 위에 있어)", text: $viewModel.hint)
            }

            Section("난이도") {
                HStack {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            viewModel.difficulty = level
                        } label: {
                            Image(systemName: level <= viewModel.difficulty ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
