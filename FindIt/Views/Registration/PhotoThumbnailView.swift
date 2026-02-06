import SwiftUI

struct PhotoThumbnailView: View {
    let image: UIImage
    let angle: String
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let onDelete {
                    Button {
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
