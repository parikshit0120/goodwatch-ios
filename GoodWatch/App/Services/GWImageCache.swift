import SwiftUI
import UIKit

// ============================================
// GW IMAGE CACHE - Memory + Disk caching for TMDB images
// ============================================
// Replaces AsyncImage throughout the app for instant poster loads.
//
// Architecture:
//   1. Check NSCache (memory) — instant, ~50 MB cap
//   2. Check disk cache (~200 MB cap, 7-day expiry)
//   3. Network fetch → store in both caches
//
// TMDB image sizes used:
//   - w154: list thumbnails (78x112)
//   - w185: grid cards (3-col grid posters)
//   - w342: detail sheet poster
//   - w500: hero/backdrop (full-width)
//   - original: never used (too large)
// ============================================

// MARK: - Image Cache Manager

final class GWImageCache {
    static let shared = GWImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheDir: URL
    private let diskCacheSizeLimit: Int = 200 * 1024 * 1024  // 200 MB
    private let diskCacheMaxAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    private let session: URLSession

    private init() {
        // Memory cache: ~50 MB limit, ~200 images
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        memoryCache.countLimit = 300

        // Disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDir = cacheDir.appendingPathComponent("GWImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)

        // Dedicated session for image downloads — no auth headers needed, higher concurrency
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.httpMaximumConnectionsPerHost = 8
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)

        // Prune expired disk cache on init (background)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.pruneDiskCache()
        }
    }

    // MARK: - Public API

    /// Load image from cache or network. Returns nil if URL is invalid.
    func loadImage(from urlString: String) async -> UIImage? {
        let cacheKey = NSString(string: urlString)

        // 1. Memory cache hit
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        // 2. Disk cache hit
        let diskPath = diskPath(for: urlString)
        if let diskImage = loadFromDisk(path: diskPath) {
            let cost = diskImage.jpegData(compressionQuality: 1.0)?.count ?? 0
            memoryCache.setObject(diskImage, forKey: cacheKey, cost: cost)
            return diskImage
        }

        // 3. Network fetch
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                return nil
            }

            // Store in memory cache
            let cost = data.count
            memoryCache.setObject(image, forKey: cacheKey, cost: cost)

            // Store on disk (background)
            let path = diskPath
            Task.detached(priority: .utility) {
                try? data.write(to: path)
            }

            return image
        } catch {
            return nil
        }
    }

    /// Prefetch images into cache without blocking UI
    func prefetch(urls: [String]) {
        for urlString in urls {
            let cacheKey = NSString(string: urlString)
            if memoryCache.object(forKey: cacheKey) != nil { continue }

            Task.detached(priority: .utility) { [weak self] in
                _ = await self?.loadImage(from: urlString)
            }
        }
    }

    // MARK: - Disk Cache

    private func diskPath(for urlString: String) -> URL {
        // Use SHA-like hash from the URL for filename
        let hash = urlString.utf8.reduce(into: UInt64(5381)) { hash, byte in
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return diskCacheDir.appendingPathComponent("\(hash).jpg")
    }

    private func loadFromDisk(path: URL) -> UIImage? {
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }

        // Check age
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > diskCacheMaxAge {
            try? FileManager.default.removeItem(at: path)
            return nil
        }

        guard let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func pruneDiskCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        var totalSize: Int = 0
        var fileInfos: [(url: URL, date: Date, size: Int)] = []

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = attrs.contentModificationDate,
                  let size = attrs.fileSize else { continue }

            // Remove expired files
            if Date().timeIntervalSince(date) > diskCacheMaxAge {
                try? FileManager.default.removeItem(at: file)
                continue
            }

            totalSize += size
            fileInfos.append((url: file, date: date, size: size))
        }

        // If over size limit, remove oldest files first
        if totalSize > diskCacheSizeLimit {
            let sorted = fileInfos.sorted { $0.date < $1.date }
            for info in sorted {
                try? FileManager.default.removeItem(at: info.url)
                totalSize -= info.size
                if totalSize <= diskCacheSizeLimit / 2 { break }
            }
        }
    }
}

// MARK: - TMDB Image Size Helpers

enum TMDBImageSize: String {
    case w154 = "w154"     // List thumbnails (78px wide)
    case w185 = "w185"     // Grid cards (~110px wide)
    case w342 = "w342"     // Detail poster
    case w500 = "w500"     // Hero/backdrop
    case w780 = "w780"     // Full-width backdrop

    /// Build full TMDB URL from a poster_path
    static func url(path: String, size: TMDBImageSize) -> String {
        if path.hasPrefix("http") { return path }
        return "https://image.tmdb.org/t/p/\(size.rawValue)\(path)"
    }
}

// MARK: - GWCachedImage View

/// Drop-in replacement for AsyncImage that uses GWImageCache.
/// Loads images from memory/disk cache instantly, network only on miss.
struct GWCachedImage: View {
    let url: String?
    let placeholder: AnyView

    @State private var image: UIImage?
    @State private var isLoading = true

    init(url: String?, @ViewBuilder placeholder: () -> some View) {
        self.url = url
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                placeholder
            } else {
                placeholder
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            image = nil
            isLoading = true
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !url.isEmpty else {
            isLoading = false
            return
        }

        // Quick check: already loaded
        if image != nil { return }

        Task {
            if let loaded = await GWImageCache.shared.loadImage(from: url) {
                await MainActor.run {
                    self.image = loaded
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - GWCachedImageDual

/// Variant that passes the loaded SwiftUI Image to a content builder.
/// Used when the same image needs to appear in multiple places (e.g. backdrop + thumbnail).
struct GWCachedImageDual<Content: View>: View {
    let url: String?
    let content: (Image) -> Content

    @State private var loadedImage: UIImage?

    init(url: String?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        Group {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadedImage = nil
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url, !url.isEmpty else { return }
        if loadedImage != nil { return }

        Task {
            if let loaded = await GWImageCache.shared.loadImage(from: url) {
                await MainActor.run {
                    self.loadedImage = loaded
                }
            }
        }
    }
}
