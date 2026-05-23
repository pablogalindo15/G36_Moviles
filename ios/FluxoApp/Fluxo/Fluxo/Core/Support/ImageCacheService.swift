import Foundation
import UIKit
import CryptoKit

enum ImageCacheSource {
    case memory
    case disk
}

struct CachedImageSnapshot {
    let image: UIImage
    let source: ImageCacheSource
}

actor ImageCacheService {
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager: FileManager
    private let directoryURL: URL
    private let ttl: TimeInterval

    init(
        fileManager: FileManager = .default,
        directoryName: String = "receipt-image-cache",
        ttl: TimeInterval = 30 * 24 * 3_600
    ) {
        self.fileManager = fileManager
        self.ttl = ttl

        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directoryURL = cachesURL.appendingPathComponent(directoryName, isDirectory: true)

        memoryCache.totalCostLimit = 50 * 1024 * 1024
        memoryCache.countLimit = 200

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func cachedImage(forKey key: String) -> CachedImageSnapshot? {
        let cacheKey = key as NSString
        if let image = memoryCache.object(forKey: cacheKey) {
            return CachedImageSnapshot(image: image, source: .memory)
        }

        let url = fileURL(forKey: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            try? fileManager.removeItem(at: url)
            return nil
        }

        if modificationDate < Date().addingTimeInterval(-ttl) {
            try? fileManager.removeItem(at: url)
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            try? fileManager.removeItem(at: url)
            return nil
        }

        memoryCache.setObject(image, forKey: cacheKey, cost: cost(for: image))
        return CachedImageSnapshot(image: image, source: .disk)
    }

    func store(_ image: UIImage, forKey key: String) {
        let cacheKey = key as NSString
        memoryCache.setObject(image, forKey: cacheKey, cost: cost(for: image))

        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let url = fileURL(forKey: key)
        try? data.write(to: url, options: .atomic)
    }

    func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        try? fileManager.removeItem(at: fileURL(forKey: key))
    }

    func purgeExpired() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-ttl)
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modificationDate = values.contentModificationDate else {
                try? fileManager.removeItem(at: url)
                continue
            }
            if modificationDate < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined() + ".jpg"
        return directoryURL.appendingPathComponent(filename)
    }

    private func cost(for image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return max(1, width * height * 4)
    }
}
