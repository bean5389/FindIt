import SwiftUI

struct PhotoThumbnailView: View {
    let image: UIImage
    let angle: String
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Checkerboard background to show transparency
                CheckerboardView()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    }

                if let onDelete {
                    Button {
                        HapticHelper.delete()
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white, .red)
                    }
                    .offset(x: 4, y: -4)
                }
            }

            Text(angle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// Checkerboard pattern to visualize transparency
struct CheckerboardView: View {
    let squareSize: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(geometry.size.width / squareSize)
            let rows = Int(geometry.size.height / squareSize)

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let isEven = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isEven ? .gray.opacity(0.1) : .gray.opacity(0.2))
                        )
                    }
                }
            }
        }
    }
}
