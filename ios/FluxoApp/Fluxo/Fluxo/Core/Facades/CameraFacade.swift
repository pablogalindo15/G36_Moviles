import SwiftUI
import UIKit

final class CameraFacade {
    func preferredSourceType() -> UIImagePickerController.SourceType {
        UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    }

    var fallbackHint: String? {
        UIImagePickerController.isSourceTypeAvailable(.camera)
            ? nil
            : "Camera unavailable on this device. Photo Library will be used."
    }

    func jpegData(from image: UIImage?) -> Data? {
        image?.jpegData(compressionQuality: 0.85)
    }
}

struct SystemImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: SystemImagePicker

        init(_ parent: SystemImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked(nil)
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let edited = info[.editedImage] as? UIImage
            let original = info[.originalImage] as? UIImage
            parent.onImagePicked(edited ?? original)
            parent.dismiss()
        }
    }
}
