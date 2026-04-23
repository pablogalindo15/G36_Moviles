import Foundation

final class PlanSnapshotMemoryCache {
    private let storage = NSCache<NSString, SnapshotBox>()

    init(maxEntries: Int = 3) {
        storage.totalCostLimit = max(1, maxEntries)
    }

    func snapshot(for userId: String) -> PlanSnapshot? {
        storage.object(forKey: cacheKey(for: userId))?.value
    }

    func store(_ snapshot: PlanSnapshot, for userId: String) {
        storage.setObject(
            SnapshotBox(snapshot),
            forKey: cacheKey(for: userId),
            cost: 1
        )
    }

    func invalidate(userId: String) {
        storage.removeObject(forKey: cacheKey(for: userId))
    }

    func clear() {
        storage.removeAllObjects()
    }

    private func cacheKey(for userId: String) -> NSString {
        userId.lowercased() as NSString
    }
}

private final class SnapshotBox {
    let value: PlanSnapshot

    init(_ value: PlanSnapshot) {
        self.value = value
    }
}
