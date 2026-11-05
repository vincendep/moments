import AVFoundation
import SwiftUI
import UIKit

/// The access an action needs before it opens: checked (and asked for the first time) up front,
/// so a denied permission shows `accessAlert` with a way to Settings instead of a dead end.
/// Location isn't here: without it new entries simply get no place.
enum Access: Identifiable {
    case camera, photos, microphone
    /// Limited Photos access: picked items that weren't shared with the app couldn't be added.
    case unsharedPhotos

    var id: Self { self }

    /// Asks for each in order (the system prompt shows only the first time) and returns the first
    /// one that's off, or nil when everything needed is granted.
    @MainActor
    static func request(_ needed: [Access]) async -> Access? {
        for access in needed where !(await access.request()) { return access }
        return nil
    }

    @MainActor
    private func request() async -> Bool {
        switch self {
        case .camera:
            // Without a camera (the simulator) CameraView falls back to the library.
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return true }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return true
            case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
            default: return false
            }
        case .photos, .unsharedPhotos:
            return await PhotoService.requestAccess()
        case .microphone:
            return await AVAudioApplication.requestRecordPermission()
        }
    }

    var title: String {
        switch self {
        case .camera: String(localized: "Camera Access Is Off")
        case .photos: String(localized: "Photos Access Is Off")
        case .microphone: String(localized: "Microphone Access Is Off")
        case .unsharedPhotos: String(localized: "Some Items Weren’t Added")
        }
    }

    var message: String {
        switch self {
        case .camera:
            String(localized: "To take photos and videos, allow Moments to use the camera in Settings.")
        case .photos:
            String(localized: "Moments keeps your photos and videos in Photos. To add them, allow access to Photos in Settings.")
        case .microphone:
            String(localized: "To record voice memos, allow Moments to use the microphone in Settings.")
        case .unsharedPhotos:
            String(localized: "Moments can only see the photos and videos you’ve shared with it. To add any of them, allow full access to Photos in Settings.")
        }
    }
}

extension View {
    /// Explains the missing access, with a button to the app's page in Settings.
    func accessAlert(_ missing: Binding<Access?>) -> some View {
        alert(missing.wrappedValue?.title ?? "", isPresented: Binding(get: { missing.wrappedValue != nil },
                                                                      set: { if !$0 { missing.wrappedValue = nil } }),
              presenting: missing.wrappedValue) { _ in
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { access in
            Text(access.message)
        }
    }
}
