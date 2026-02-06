import SwiftUI

struct SimilarityGaugeView: View {
    let similarity: Float

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.3))
                        .frame(height: 12)

                    Capsule()
                        .fill(gaugeColor)
                        .frame(width: geometry.size.width * CGFloat(similarity), height: 12)
                        .animation(.easeInOut(duration: 0.3), value: similarity)
                }
            }
            .frame(height: 12)

            Text("\(Int(similarity * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .monospacedDigit()
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
