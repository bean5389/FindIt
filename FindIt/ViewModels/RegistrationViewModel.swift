import SwiftUI
import SwiftData

@Observable
final class RegistrationViewModel {
    // Form fields
    var name = ""
    var hint = ""
    var difficulty = 3

    // Captured photos
    var capturedPhotos: [(image: UIImage, angle: String)] = []

    // State
    var isProcessing = false
    var errorMessage: String?
    var currentStep: RegistrationStep = .capture

    enum RegistrationStep {
        case capture
        case info
    }

    static let angleGuides = ["정면", "뒷면", "왼쪽", "오른쪽", "위"]

    var currentAngleGuide: String {
        let index = capturedPhotos.count
        if index < Self.angleGuides.count {
            return Self.angleGuides[index]
        }
        return "자유 각도"
    }

    var canProceedToInfo: Bool {
        capturedPhotos.count >= 3
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !capturedPhotos.isEmpty
    }

    func addPhoto(_ image: UIImage) {
        let angle = currentAngleGuide
        capturedPhotos.append((image: image, angle: angle))
    }

    func removePhoto(at index: Int) {
        guard capturedPhotos.indices.contains(index) else { return }
        capturedPhotos.remove(at: index)
    }

    func proceedToInfo() {
        currentStep = .info
    }

    func backToCapture() {
        currentStep = .capture
    }

    func save(context: ModelContext) async -> Bool {
        isProcessing = true
        errorMessage = nil

        do {
            // Create thumbnail from first photo
            guard let thumbnailData = ImageHelper.thumbnailData(from: capturedPhotos[0].image) else {
                throw RegistrationError.thumbnailFailed
            }

            let item = TargetItem(
                name: name.trimmingCharacters(in: .whitespaces),
                hint: hint.trimmingCharacters(in: .whitespaces),
                thumbnailData: thumbnailData,
                difficulty: difficulty
            )

            context.insert(item)

            // Process each photo: extract feature print and save
            let fpService = FeaturePrintService.shared
            for (image, angle) in capturedPhotos {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
                guard let cgImage = image.cgImage else { continue }

                let observation = try await fpService.extractFeaturePrint(from: cgImage)
                let fpData = try await fpService.serializeFeaturePrint(observation)

                let photo = TargetPhoto(
                    imageData: imageData,
                    featurePrintData: fpData,
                    angle: angle
                )
                photo.item = item
                context.insert(photo)
            }

            try context.save()
            isProcessing = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
            return false
        }
    }
}

enum RegistrationError: Error, LocalizedError {
    case thumbnailFailed

    var errorDescription: String? {
        switch self {
        case .thumbnailFailed: "썸네일 생성에 실패했습니다."
        }
    }
}
