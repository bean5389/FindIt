import SwiftUI

struct MissionCardView: View {
    let item: TargetItem
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("미션!")
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundStyle(.orange)

            // Item thumbnail
            if let uiImage = UIImage(data: item.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
            }

            VStack(spacing: 8) {
                Text(item.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text("을(를) 찾아보세요!")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if !item.hint.isEmpty {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("힌트: \(item.hint)")
                        .font(.body)
                }
                .padding()
                .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            Button {
                onStart()
            } label: {
                Text("시작!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding()
    }
}
