import Foundation

// MARK: - Protocol

protocol CacheScanning {
    func scan() -> UInt64
    func clean() -> UInt64
}

// MARK: - Mock

struct MockCacheCleaner: CacheScanning {
    let scanResult: UInt64
    let cleanResult: UInt64
    func scan() -> UInt64 { scanResult }
    func clean() -> UInt64 { cleanResult }
}

// MARK: - Real

struct CacheCleaner: CacheScanning {
    let cacheURL: URL

    init(cacheURL: URL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]) {
        self.cacheURL = cacheURL
    }

    /// Returns the total byte size of ~/Library/Caches contents.
    func scan() -> UInt64 {
        directorySize(at: cacheURL)
    }

    /// Deletes each top-level item in cacheURL. Returns bytes actually freed.
    /// Items that fail to delete (locked, SIP-protected) are silently skipped.
    func clean() -> UInt64 {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var freed: UInt64 = 0
        for item in items {
            let size = directorySize(at: item)
            if (try? fm.removeItem(at: item)) != nil {
                freed += size
            }
        }
        return freed
    }

    // MARK: - Private

    private func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                values.isRegularFile == true,
                let size = values.fileSize
            else { continue }
            total += UInt64(size)
        }
        return total
    }
}
