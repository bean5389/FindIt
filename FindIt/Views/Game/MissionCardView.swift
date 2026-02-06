import SwiftUI

struct MissionCardView: View {
    let item: TargetItem
    let onStart: () -> Void

    @State private var animateTitle = false
    @State private var animateImage = false
    @State private var animateHint = false
    @State private var animateButton = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("미션!")
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundStyle(.orange)
                .scaleEffect(animateTitle ? 1.0 : 0.5)
                .opacity(animateTitle ? 1.0 : 0.0)
                .accessibilityLabel("미션 시작")

            // Item thumbnail
            if let uiImage = UIImage(data: item.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .scaleEffect(animateImage ? 1.0 : 0.8)
                    .opacity(animateImage ? 1.0 : 0.0)
                    .rotationEffect(.degrees(animateImage ? 0 : -10))
                    .accessibilityLabel("\(item.name) 이미지")
            }

            VStack(spacing: 8) {
                Text(item.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text("을(를) 찾아보세요!")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .offset(y: animateImage ? 0 : 20)
            .opacity(animateImage ? 1.0 : 0.0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.name)을(를) 찾아보세요!")

            if !item.hint.isEmpty {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("힌트: \(item.hint)")
                        .font(.body)
                }
                .padding()
                .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .scaleEffect(animateHint ? 1.0 : 0.9)
                .opacity(animateHint ? 1.0 : 0.0)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("힌트: \(item.hint)")
            }

            Spacer()

            Button {
                HapticHelper.buttonTap()
                onStart()
            } label: {
                Text("시작!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .scaleEffect(animateButton ? 1.0 : 0.8)
            .opacity(animateButton ? 1.0 : 0.0)
            .buttonStyle(PulseButtonStyle())
            .accessibilityLabel("보물찾기 시작")
            .accessibilityHint("\(item.name) 찾기를 시작합니다")
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateTitle = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateImage = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                animateHint = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
                animateButton = true
            }
        }
    }
}
