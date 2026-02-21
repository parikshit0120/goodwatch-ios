import Foundation

// ============================================
// REMOTE MOOD CONFIG SERVICE
// ============================================
// Fetches mood_mappings from Supabase on session start.
// Caches in memory. Falls back to hardcoded defaults matching
// current behavior if Supabase is unreachable.
// ============================================

// MARK: - GWMoodMapping Model

struct GWMoodMapping: Codable {
    let moodKey: String
    let displayName: String

    // Target ranges (nil = no constraint)
    let targetComfortMin: Int?
    let targetComfortMax: Int?
    let targetDarknessMin: Int?
    let targetDarknessMax: Int?
    let targetEmotionalIntensityMin: Int?
    let targetEmotionalIntensityMax: Int?
    let targetEnergyMin: Int?
    let targetEnergyMax: Int?
    let targetComplexityMin: Int?
    let targetComplexityMax: Int?
    let targetRewatchabilityMin: Int?
    let targetRewatchabilityMax: Int?
    let targetHumourMin: Int?
    let targetHumourMax: Int?
    let targetMentalstimulationMin: Int?
    let targetMentalstimulationMax: Int?

    // Ideal center for scoring (0-10 per dimension)
    let idealComfort: Double?
    let idealDarkness: Double?
    let idealEmotionalIntensity: Double?
    let idealEnergy: Double?
    let idealComplexity: Double?
    let idealRewatchability: Double?
    let idealHumour: Double?
    let idealMentalstimulation: Double?

    // Tags
    let compatibleTags: [String]
    let antiTags: [String]

    // Dimension weights (how much each dimension matters for this mood, 0.0-1.0)
    let weightComfort: Double
    let weightDarkness: Double
    let weightEmotionalIntensity: Double
    let weightEnergy: Double
    let weightComplexity: Double
    let weightRewatchability: Double
    let weightHumour: Double
    let weightMentalstimulation: Double

    let archetypeMovieIds: [Int]
    let version: Int

    enum CodingKeys: String, CodingKey {
        case moodKey = "mood_key"
        case displayName = "display_name"
        case targetComfortMin = "target_comfort_min"
        case targetComfortMax = "target_comfort_max"
        case targetDarknessMin = "target_darkness_min"
        case targetDarknessMax = "target_darkness_max"
        case targetEmotionalIntensityMin = "target_emotional_intensity_min"
        case targetEmotionalIntensityMax = "target_emotional_intensity_max"
        case targetEnergyMin = "target_energy_min"
        case targetEnergyMax = "target_energy_max"
        case targetComplexityMin = "target_complexity_min"
        case targetComplexityMax = "target_complexity_max"
        case targetRewatchabilityMin = "target_rewatchability_min"
        case targetRewatchabilityMax = "target_rewatchability_max"
        case targetHumourMin = "target_humour_min"
        case targetHumourMax = "target_humour_max"
        case targetMentalstimulationMin = "target_mentalstimulation_min"
        case targetMentalstimulationMax = "target_mentalstimulation_max"
        case idealComfort = "ideal_comfort"
        case idealDarkness = "ideal_darkness"
        case idealEmotionalIntensity = "ideal_emotional_intensity"
        case idealEnergy = "ideal_energy"
        case idealComplexity = "ideal_complexity"
        case idealRewatchability = "ideal_rewatchability"
        case idealHumour = "ideal_humour"
        case idealMentalstimulation = "ideal_mentalstimulation"
        case compatibleTags = "compatible_tags"
        case antiTags = "anti_tags"
        case weightComfort = "weight_comfort"
        case weightDarkness = "weight_darkness"
        case weightEmotionalIntensity = "weight_emotional_intensity"
        case weightEnergy = "weight_energy"
        case weightComplexity = "weight_complexity"
        case weightRewatchability = "weight_rewatchability"
        case weightHumour = "weight_humour"
        case weightMentalstimulation = "weight_mentalstimulation"
        case archetypeMovieIds = "archetype_movie_ids"
        case version
    }
}

// MARK: - GWMoodConfigService

final class GWMoodConfigService {
    static let shared = GWMoodConfigService()

    private var mappings: [String: GWMoodMapping] = [:]
    private var _isLoaded = false
    private var _configSource: String = "fallback"
    private let queue = DispatchQueue(label: "com.goodwatch.moodconfig")

    /// Whether remote config has been loaded
    var isLoaded: Bool {
        queue.sync { _isLoaded }
    }

    /// Source of current config: "remote" or "fallback"
    var configSource: String {
        queue.sync { _configSource }
    }

    /// All active mood mappings (ordered: feel_good, easy_watch, surprise_me, gripping, dark_heavy)
    var allMappings: [GWMoodMapping] {
        queue.sync {
            let order = ["feel_good", "easy_watch", "surprise_me", "gripping", "dark_heavy"]
            return order.compactMap { mappings[$0] }
        }
    }

    private init() {
        // Load hardcoded fallbacks immediately
        loadFallbackDefaults()
    }

    // MARK: - Lookup

    /// Get mood mapping for a given mood key
    func getMoodMapping(for moodKey: String) -> GWMoodMapping? {
        queue.sync { mappings[moodKey] }
    }

    // MARK: - Remote Fetch

    /// Fetch mood mappings from Supabase. Called once per session.
    /// Has a 3-second timeout. Falls back to hardcoded defaults on failure.
    func fetchRemoteConfig() async {
        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("[MoodConfig] Supabase not configured, using fallback")
            #endif
            return
        }

        // Skip remote fetch if feature flag is disabled
        guard GWFeatureFlags.shared.isEnabled("remote_mood_mapping") else {
            #if DEBUG
            print("[MoodConfig] remote_mood_mapping flag disabled, using fallback")
            #endif
            return
        }

        let urlString = "\(SupabaseConfig.url)/rest/v1/mood_mappings?is_active=eq.true&select=*"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                #if DEBUG
                print("[MoodConfig] HTTP error, using fallback")
                #endif
                return
            }

            let decoder = JSONDecoder()
            let remoteMappings = try decoder.decode([GWMoodMapping].self, from: data)

            guard !remoteMappings.isEmpty else {
                #if DEBUG
                print("[MoodConfig] Empty response, using fallback")
                #endif
                return
            }

            queue.sync {
                for mapping in remoteMappings {
                    self.mappings[mapping.moodKey] = mapping
                }
                self._isLoaded = true
                self._configSource = "remote"
            }

            #if DEBUG
            print("[MoodConfig] Loaded \(remoteMappings.count) mood mappings from remote")
            #endif
        } catch {
            #if DEBUG
            print("[MoodConfig] Fetch failed: \(error.localizedDescription), using fallback")
            #endif
            // Fallback defaults already loaded in init
        }
    }

    /// Wait for remote config with timeout. Returns immediately if already loaded.
    func waitForLoad(timeout: TimeInterval = 3.0) async {
        if isLoaded { return }

        let start = Date()
        while !isLoaded && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    // MARK: - Hardcoded Fallback Defaults

    /// Matches EXACTLY the current hardcoded behavior in MoodSelectorView.swift
    private func loadFallbackDefaults() {
        let defaults: [GWMoodMapping] = [
            // Feel-good: ["feel_good", "uplifting", "safe_bet", "light", "calm"]
            GWMoodMapping(
                moodKey: "feel_good", displayName: "Feel-good",
                targetComfortMin: nil, targetComfortMax: nil,
                targetDarknessMin: nil, targetDarknessMax: nil,
                targetEmotionalIntensityMin: nil, targetEmotionalIntensityMax: nil,
                targetEnergyMin: nil, targetEnergyMax: nil,
                targetComplexityMin: nil, targetComplexityMax: nil,
                targetRewatchabilityMin: nil, targetRewatchabilityMax: nil,
                targetHumourMin: nil, targetHumourMax: nil,
                targetMentalstimulationMin: nil, targetMentalstimulationMax: nil,
                idealComfort: 5.0, idealDarkness: 5.0,
                idealEmotionalIntensity: 5.0, idealEnergy: 5.0,
                idealComplexity: 5.0, idealRewatchability: 5.0,
                idealHumour: 5.0, idealMentalstimulation: 5.0,
                compatibleTags: ["feel_good", "uplifting", "safe_bet", "light", "calm"],
                antiTags: [],
                weightComfort: 0.5, weightDarkness: 0.5,
                weightEmotionalIntensity: 0.5, weightEnergy: 0.5,
                weightComplexity: 0.5, weightRewatchability: 0.5,
                weightHumour: 0.5, weightMentalstimulation: 0.5,
                archetypeMovieIds: [], version: 0
            ),
            // Easy watch: ["light", "background_friendly", "safe_bet", "calm"]
            GWMoodMapping(
                moodKey: "easy_watch", displayName: "Easy watch",
                targetComfortMin: nil, targetComfortMax: nil,
                targetDarknessMin: nil, targetDarknessMax: nil,
                targetEmotionalIntensityMin: nil, targetEmotionalIntensityMax: nil,
                targetEnergyMin: nil, targetEnergyMax: nil,
                targetComplexityMin: nil, targetComplexityMax: nil,
                targetRewatchabilityMin: nil, targetRewatchabilityMax: nil,
                targetHumourMin: nil, targetHumourMax: nil,
                targetMentalstimulationMin: nil, targetMentalstimulationMax: nil,
                idealComfort: 5.0, idealDarkness: 5.0,
                idealEmotionalIntensity: 5.0, idealEnergy: 5.0,
                idealComplexity: 5.0, idealRewatchability: 5.0,
                idealHumour: 5.0, idealMentalstimulation: 5.0,
                compatibleTags: ["light", "background_friendly", "safe_bet", "calm"],
                antiTags: [],
                weightComfort: 0.5, weightDarkness: 0.5,
                weightEmotionalIntensity: 0.5, weightEnergy: 0.5,
                weightComplexity: 0.5, weightRewatchability: 0.5,
                weightHumour: 0.5, weightMentalstimulation: 0.5,
                archetypeMovieIds: [], version: 0
            ),
            // Surprise me: [] (empty, any movie passes)
            GWMoodMapping(
                moodKey: "surprise_me", displayName: "Surprise me",
                targetComfortMin: nil, targetComfortMax: nil,
                targetDarknessMin: nil, targetDarknessMax: nil,
                targetEmotionalIntensityMin: nil, targetEmotionalIntensityMax: nil,
                targetEnergyMin: nil, targetEnergyMax: nil,
                targetComplexityMin: nil, targetComplexityMax: nil,
                targetRewatchabilityMin: nil, targetRewatchabilityMax: nil,
                targetHumourMin: nil, targetHumourMax: nil,
                targetMentalstimulationMin: nil, targetMentalstimulationMax: nil,
                idealComfort: 5.0, idealDarkness: 5.0,
                idealEmotionalIntensity: 5.0, idealEnergy: 5.0,
                idealComplexity: 5.0, idealRewatchability: 5.0,
                idealHumour: 5.0, idealMentalstimulation: 5.0,
                compatibleTags: [],
                antiTags: [],
                weightComfort: 0.5, weightDarkness: 0.5,
                weightEmotionalIntensity: 0.5, weightEnergy: 0.5,
                weightComplexity: 0.5, weightRewatchability: 0.5,
                weightHumour: 0.5, weightMentalstimulation: 0.5,
                archetypeMovieIds: [], version: 0
            ),
            // Gripping: ["tense", "high_energy", "full_attention", "medium"]
            GWMoodMapping(
                moodKey: "gripping", displayName: "Gripping",
                targetComfortMin: nil, targetComfortMax: nil,
                targetDarknessMin: nil, targetDarknessMax: nil,
                targetEmotionalIntensityMin: nil, targetEmotionalIntensityMax: nil,
                targetEnergyMin: nil, targetEnergyMax: nil,
                targetComplexityMin: nil, targetComplexityMax: nil,
                targetRewatchabilityMin: nil, targetRewatchabilityMax: nil,
                targetHumourMin: nil, targetHumourMax: nil,
                targetMentalstimulationMin: nil, targetMentalstimulationMax: nil,
                idealComfort: 5.0, idealDarkness: 5.0,
                idealEmotionalIntensity: 5.0, idealEnergy: 5.0,
                idealComplexity: 5.0, idealRewatchability: 5.0,
                idealHumour: 5.0, idealMentalstimulation: 5.0,
                compatibleTags: ["tense", "high_energy", "full_attention", "medium"],
                antiTags: [],
                weightComfort: 0.5, weightDarkness: 0.5,
                weightEmotionalIntensity: 0.5, weightEnergy: 0.5,
                weightComplexity: 0.5, weightRewatchability: 0.5,
                weightHumour: 0.5, weightMentalstimulation: 0.5,
                archetypeMovieIds: [], version: 0
            ),
            // Dark & Heavy: ["dark", "bittersweet", "heavy", "full_attention", "acquired_taste"]
            GWMoodMapping(
                moodKey: "dark_heavy", displayName: "Dark & Heavy",
                targetComfortMin: nil, targetComfortMax: nil,
                targetDarknessMin: nil, targetDarknessMax: nil,
                targetEmotionalIntensityMin: nil, targetEmotionalIntensityMax: nil,
                targetEnergyMin: nil, targetEnergyMax: nil,
                targetComplexityMin: nil, targetComplexityMax: nil,
                targetRewatchabilityMin: nil, targetRewatchabilityMax: nil,
                targetHumourMin: nil, targetHumourMax: nil,
                targetMentalstimulationMin: nil, targetMentalstimulationMax: nil,
                idealComfort: 5.0, idealDarkness: 5.0,
                idealEmotionalIntensity: 5.0, idealEnergy: 5.0,
                idealComplexity: 5.0, idealRewatchability: 5.0,
                idealHumour: 5.0, idealMentalstimulation: 5.0,
                compatibleTags: ["dark", "bittersweet", "heavy", "full_attention", "acquired_taste"],
                antiTags: [],
                weightComfort: 0.5, weightDarkness: 0.5,
                weightEmotionalIntensity: 0.5, weightEnergy: 0.5,
                weightComplexity: 0.5, weightRewatchability: 0.5,
                weightHumour: 0.5, weightMentalstimulation: 0.5,
                archetypeMovieIds: [], version: 0
            ),
        ]

        queue.sync {
            for mapping in defaults {
                self.mappings[mapping.moodKey] = mapping
            }
            // Fallback is always "loaded" — it just has version 0
            self._isLoaded = true
            self._configSource = "fallback"
        }
    }
}
