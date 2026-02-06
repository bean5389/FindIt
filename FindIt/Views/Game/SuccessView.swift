import SwiftUI

struct SuccessView: View {
    let item: TargetItem
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("🎉")
                .font(.system(size: 80))

            Text("찾았다!")
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundStyle(.green)

            if let uiImage = UIImage(data: item.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.green, lineWidth: 4)
                    }
                    .shadow(radius: 10)
            }

            Text(item.name)
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Text("홈으로 돌아가기")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
        .background(.white)
    }
}
