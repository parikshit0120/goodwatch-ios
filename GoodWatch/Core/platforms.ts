/**
 * Canonical Platform Definitions
 */

export enum PlatformId {
    NETFLIX = 'netflix',
    PRIME_VIDEO = 'prime',
    DISNEY_PLUS = 'disney_plus',
    HBO_MAX = 'hbo_max',
    HULU = 'hulu',
    APPLE_TV = 'apple_tv',
    UNKNOWN = 'unknown' // Fallback
}

export const PLATFORM_NAMES: Record<PlatformId, string> = {
    [PlatformId.NETFLIX]: 'Netflix',
    [PlatformId.PRIME_VIDEO]: 'Prime Video',
    [PlatformId.DISNEY_PLUS]: 'Disney+',
    [PlatformId.HBO_MAX]: 'HBO Max',
    [PlatformId.HULU]: 'Hulu',
    [PlatformId.APPLE_TV]: 'Apple TV+',
    [PlatformId.UNKNOWN]: 'Unknown Platform'
};

/**
 * Normalizes input string to PlatformId
 */
export function normalizePlatform(input: string): PlatformId {
    const normalized = input.toLowerCase().trim().replace(/[\s\-_]+/g, '_');

    // Exact matches logic (can be expanded)
    if (normalized.includes('netflix')) return PlatformId.NETFLIX;
    if (normalized.includes('prime')) return PlatformId.PRIME_VIDEO;
    if (normalized.includes('disney')) return PlatformId.DISNEY_PLUS;
    if (normalized.includes('hbo')) return PlatformId.HBO_MAX;
    if (normalized.includes('hulu')) return PlatformId.HULU;
    if (normalized.includes('apple')) return PlatformId.APPLE_TV;

    return PlatformId.UNKNOWN;
}
