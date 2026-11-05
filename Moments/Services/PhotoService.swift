import AVFoundation
import CoreLocation
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Saves media to Photos (optionally into an album) and returns only the asset ID.
enum PhotoService {
    static let sharedAlbumName = "Moments"

    /// True with full or limited access; limited still saves new captures (they join the selection).
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// `location` is written to the asset: the system camera picker leaves captures without one.
    static func save(image: UIImage, into album: PHAssetCollection?, location: CLLocation?) async throws -> String {
        try await save(into: album, location: location) { PHAssetChangeRequest.creationRequestForAsset(from: image) }
    }

    static func save(videoURL: URL, into album: PHAssetCollection?, location: CLLocation?) async throws -> String {
        try await save(into: album, location: location) {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }

    private static func save(into album: PHAssetCollection?, location: CLLocation?,
                             _ make: @escaping () -> PHAssetChangeRequest?) async throws -> String {
        var id: String?
        try await PHPhotoLibrary.shared().performChanges {
            guard let req = make(), let ph = req.placeholderForCreatedAsset else { return }
            req.location = location
            id = ph.localIdentifier
            if let album { PHAssetCollectionChangeRequest(for: album)?.addAssets([ph] as NSArray) }
        }
        guard let id else { throw CocoaError(.fileWriteUnknown) }
        return id
    }

    /// The album new media for `timeline` should go into, creating it if needed. Nil when its mode is `.none`.
    @MainActor
    static func album(for timeline: Timeline) async throws -> PHAssetCollection? {
        switch timeline.albumMode {
        case .none:
            return nil
        case .shared:
            let opts = PHFetchOptions()
            opts.predicate = NSPredicate(format: "title = %@", sharedAlbumName)
            if let a = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: opts).firstObject {
                return a
            }
            return try await createAlbum(title: sharedAlbumName)
        case .perTimeline:
            // By ID first: timelines can share a name and can be renamed.
            if let id = albumID(for: timeline), let a = collection(id) { return a }
            // On another device the album arrives through iCloud Photos under the timeline's name.
            let opts = PHFetchOptions()
            opts.predicate = NSPredicate(format: "title = %@", timeline.name)
            let a: PHAssetCollection
            if let synced = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: opts).firstObject {
                a = synced
            } else {
                a = try await createAlbum(title: timeline.name)
            }
            setAlbumID(a.localIdentifier, for: timeline)
            return a
        }
    }

    // Album local IDs differ per device, so they are kept on the device rather than synced.
    private static let albumIDsKey = "albumIDs"

    static func albumID(for timeline: Timeline) -> String? {
        (UserDefaults.standard.dictionary(forKey: albumIDsKey) as? [String: String])?[timeline.uuid.uuidString]
    }

    static func setAlbumID(_ id: String, for timeline: Timeline) {
        var ids = UserDefaults.standard.dictionary(forKey: albumIDsKey) as? [String: String] ?? [:]
        ids[timeline.uuid.uuidString] = id
        UserDefaults.standard.set(ids, forKey: albumIDsKey)
    }

    /// iCloud Photos identifier for an asset, the same on every device. Nil until the asset is in iCloud.
    static func cloudID(forLocalID id: String) -> String? {
        guard case .success(let cloud)? = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: [id])[id]
        else { return nil }
        return cloud.stringValue
    }

    /// Records the iCloud ID of assets added on this device whose ID wasn't known yet
    /// (a fresh capture only gets one once it reaches iCloud), so other devices can find them.
    @MainActor static func backfillCloudIDs(in ctx: ModelContext) {
        let pending = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.assetLocalID != nil && $0.assetCloudID == nil })
        guard let items = try? ctx.fetch(pending), !items.isEmpty else { return }
        for item in items {
            if let id = item.assetLocalID { item.assetCloudID = cloudID(forLocalID: id) }
        }
        try? ctx.save()
    }

    @MainActor private static var resolvedCloudIDs: [String: String] = [:]

    /// This device's ID for the item's asset: the stored one when it was added here, otherwise
    /// looked up by its iCloud ID. Never written back, since each device has its own.
    @MainActor static func localID(for item: MediaItem) -> String? {
        if let id = item.assetLocalID, asset(id) != nil { return id }
        guard let cloud = item.assetCloudID else { return nil }
        if let id = resolvedCloudIDs[cloud] { return id }
        let key = PHCloudIdentifier(stringValue: cloud)
        guard case .success(let id)? = PHPhotoLibrary.shared().localIdentifierMappings(for: [key])[key] else { return nil }
        resolvedCloudIDs[cloud] = id
        return id
    }

    /// The assets picked in a `PhotosPicker`, oldest first.
    static func assets(for items: [PhotosPickerItem]) -> [PHAsset] {
        items.compactMap { $0.itemIdentifier.flatMap(asset) }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// A picked asset as an entry's photo or video, linked by reference (no copy).
    static func item(for asset: PHAsset) -> MediaItem {
        MediaItem(asset.mediaType == .video ? .video : .photo, assetLocalID: asset.localIdentifier)
    }

    /// Adds picked assets to the timeline's album, when its settings ask for it.
    @MainActor static func addImports(_ assets: [PHAsset], for timeline: Timeline) {
        guard timeline.addImportsToAlbum, !assets.isEmpty else { return }
        let ids = assets.map(\.localIdentifier)
        Task {
            if let album = try? await album(for: timeline) { try? await add(assetIDs: ids, to: album) }
        }
    }

    static func add(assetIDs: [String], to album: PHAssetCollection) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        guard assets.count > 0 else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: album)?.addAssets(assets)
        }
    }

    static func renameAlbum(_ id: String, to title: String) async throws {
        guard let album = collection(id) else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: album)?.title = title
        }
    }

    private static func createAlbum(title: String) async throws -> PHAssetCollection {
        var id = ""
        try await PHPhotoLibrary.shared().performChanges {
            id = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                .placeholderForCreatedAssetCollection.localIdentifier
        }
        guard let a = collection(id) else { throw CocoaError(.fileWriteUnknown) }
        return a
    }

    private static func collection(_ id: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    static func asset(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// The asset's image at roughly `size` (a thumbnail for small sizes, full screen for large ones).
    static func image(_ id: String, size: CGSize) async -> UIImage? {
        guard let asset = asset(id) else { return nil }
        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(for: asset, targetSize: size,
                                                  contentMode: .aspectFill, options: opts) { img, _ in
                cont.resume(returning: img)
            }
        }
    }

    static func playerItem(_ id: String) async -> AVPlayerItem? {
        guard let asset = asset(id) else { return nil }
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: opts) { item, _ in
                cont.resume(returning: item)
            }
        }
    }
}
