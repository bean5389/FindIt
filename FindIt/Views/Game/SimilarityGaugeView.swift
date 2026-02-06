import SwiftUI

struct SimilarityGaugeView: View {
    let similarity: Float
    
    @State private var pulse = 1.0

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 14)

                    Capsule()
                        .fill(gaugeColor)
                        .frame(width: geometry.size.width * CGFloat(similarity), height: 14)
                        .shadow(color: gaugeColor.opacity(similarity > 0.6 ? 0.6 : 0), radius: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: similarity)
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(similarity * 100))")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .scaleEffect(similarity >= 0.8 ? pulse : 1.0)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("유사도 \(Int(similarity * 100))퍼센트")
        .accessibilityValue(accessibilityFeedback)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulse = 1.1
            }
        }
    }

    private var accessibilityFeedback: String {
        switch similarity {
        case 0.8...: return "매우 가까워요! 거의 다 찾았어요!"
        case 0.6..<0.8: return "뜨거워요! 가까워지고 있어요"
        case 0.3..<0.6: return "따뜻해요. 방향이 맞아요"
        default: return "차가워요. 다른 곳을 찾아보세요"
        }
    }

    private var gaugeColor: Color {
        switch similarity {
        case 0.8...: .green
        case 0.6..<0.8: .orange
        case 0.3..<0.6: .yellow
        default: .gray
        }
    }
}
