import Foundation

// MARK: - Trailer Service (FIX 10)
// Fetches YouTube trailer keys from TMDB /videos endpoint.

struct TrailerService {
    private static let tmdbAPIKey = "204363c10c39f75a0320ad4258565f71"

    static func fetchTrailerKey(tmdbId: Int) async -> String? {
        let urlString = "https://api.themoviedb.org/3/movie/\(tmdbId)/videos?api_key=\(tmdbAPIKey)&language=en-US"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBVideoResponse.self, from: data)

            let videos = response.results.filter { $0.site == "YouTube" }
            let officialTrailer = videos.first { $0.type == "Trailer" && $0.official }
            let anyTrailer = videos.first { $0.type == "Trailer" }
            let teaser = videos.first { $0.type == "Teaser" }

            return officialTrailer?.key ?? anyTrailer?.key ?? teaser?.key
        } catch {
            #if DEBUG
            print("[GW] Trailer fetch failed for tmdb \(tmdbId): \(error)")
            #endif
            return nil
        }
    }
}

private struct TMDBVideoResponse: Codable {
    let results: [TMDBVideo]
}

private struct TMDBVideo: Codable {
    let key: String
    let site: String
    let type: String
    let official: Bool
    let name: String

    enum CodingKeys: String, CodingKey {
        case key, site, type, official, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        site = try container.decode(String.self, forKey: .site)
        type = try container.decode(String.self, forKey: .type)
        official = try container.decodeIfPresent(Bool.self, forKey: .official) ?? false
        name = try container.decode(String.self, forKey: .name)
    }
}
