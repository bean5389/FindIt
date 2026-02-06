import SwiftUI

struct SuccessView: View {
    let item: TargetItem
    let onDismiss: () -> Void
    
    @State private var animateIcon = false
    @State private var animateText = false

    var body: some View {
        ZStack {
            // Festive background
            LinearGradient(colors: [.green.opacity(0.1), .white], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Confetti Layer
            ConfettiView()

            VStack(spacing: 32) {
                Spacer()

                Text("🎉")
                    .font(.system(size: 80))
                    .scaleEffect(animateIcon ? 1.2 : 0.8)
                    .rotationEffect(.degrees(animateIcon ? 10 : -10))

                Text("찾았다!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
                    .offset(y: animateText ? 0 : 20)
                    .opacity(animateText ? 1 : 0)

                if let uiImage = UIImage(data: item.thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.green, lineWidth: 6)
                        }
                        .shadow(color: .green.opacity(0.3), radius: 20)
                        .scaleEffect(animateIcon ? 1.0 : 0.5)
                }

                Text(item.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.1), in: Capsule())

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("도감으로 돌아가기")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateText = true
            }
        }
    }
}

struct ConfettiView: View {
    @State private var animate = false
    private let colors: [Color] = [.red, .blue, .yellow, .green, .pink, .purple, .orange]
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { i in
                Rectangle()
                    .fill(colors.randomElement() ?? .blue)
                    .frame(width: CGFloat.random(in: 5...12), height: CGFloat.random(in: 5...12))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: animate ? UIScreen.main.bounds.height + 10 : -10
                    )
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .animation(
                        .linear(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: false)
                        .delay(Double.random(in: 0...2)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}
