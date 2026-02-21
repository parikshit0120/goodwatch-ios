import Foundation

// ============================================
// CONFIGURED URL SESSION
// ============================================
// Single shared URLSession with proper timeouts.
// Replaces URLSession.shared throughout the app to prevent
// 60-second hangs on poor networks.
// ============================================

enum GWNetworkSession {
    /// Configured URLSession with 15s request timeout and 30s resource timeout.
    /// Uses HTTP/2 multiplexing and waitsForConnectivity for better UX.
    /// Includes a 50 MB memory / 100 MB disk URL cache for HTTP-level caching.
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 6
        // 50 MB memory + 100 MB disk for HTTP responses (API JSON + misc)
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024,
                                   diskCapacity: 100 * 1024 * 1024)
        return URLSession(configuration: config)
    }()
}
