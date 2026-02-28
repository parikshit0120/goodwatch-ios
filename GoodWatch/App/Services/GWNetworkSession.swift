import Foundation

// ============================================
// CONFIGURED URL SESSION
// ============================================
// Single shared URLSession with aggressive timeouts.
// Replaces URLSession.shared throughout the app to prevent
// long hangs on poor/unavailable networks.
// ============================================

enum GWNetworkSession {
    /// Configured URLSession with 10s request timeout and 15s resource timeout.
    /// Fails fast on unreachable hosts instead of waiting for connectivity.
    /// Includes a 50 MB memory / 100 MB disk URL cache for HTTP-level caching.
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 6
        // 50 MB memory + 100 MB disk for HTTP responses (API JSON + misc)
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024,
                                   diskCapacity: 100 * 1024 * 1024)
        return URLSession(configuration: config)
    }()
}
