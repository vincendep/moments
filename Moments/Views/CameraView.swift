import CoreLocation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// System camera for photos and videos; saves to Photos and returns the asset ID, with the
/// current location when location access was given (also written to the asset). `onFailed` reports a
/// capture that couldn't be saved (Photos access taken away meanwhile), rather than losing it silently.
struct CameraView: UIViewControllerRepresentable {
    let timeline: Timeline
    var onFailed: () -> Void = {}
    var onSaved: (MediaKind, String, CLLocation?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        /// Started when the camera opens, so it is usually ready by the time a photo is taken.
        let location = Task { await LocationService.currentLocation() }
        init(_ p: CameraView) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            let video = info[.mediaURL] as? URL
            Task { @MainActor in
                let album = try? await PhotoService.album(for: parent.timeline)
                let location = await location.value
                if let video, let id = try? await PhotoService.save(videoURL: video, into: album, location: location) {
                    parent.onSaved(.video, id, location)
                } else if let image, let id = try? await PhotoService.save(image: image, into: album, location: location) {
                    parent.onSaved(.photo, id, location)
                } else {
                    parent.onFailed()
                }
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
