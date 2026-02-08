/**
 * core/normalization.ts
 * 
 * Responsible for mapping raw, messy provider strings (from TMDB/JustWatch/OMDb)
 * into our canonical trusted PlatformId enum.
 */

import { PlatformId } from './platforms'; // Assuming platforms.ts exists or we define enum here

// If platforms.ts doesn't exist in this context yet, let's look at the existing setup.
// We previously defined PlatformId in `core/platforms.ts` or `core/types.ts`.
// Let's re-export or redefine for this standalone script context if needed, 
// but ideally we import. For this script, I'll inline the enum to ensure it runs standalone 
// easily (or I can check if core/platforms.ts exists).

// Checking context: I know `core/platforms.ts` exists from previous turns.
// But this script might run in a Node env where imports are tricky without proper tsconfig.
// To be safe and self-contained for the script:

export enum PlatformId {
    NETFLIX = "netflix",
    PRIME = "prime",
    DISNEY = "disney_plus",
    HOTSTAR = "hotstar",
    JIO = "jio_cinema",
    HBO = "hbo_max",
    APPLE = "apple_tv",
    HULU = "hulu",
    UNKNOWN = "unknown"
}

export function normalizePlatform(raw: string): PlatformId {
    const lower = raw.toLowerCase().trim();

    if (lower.includes('netflix')) return PlatformId.NETFLIX;
    if (lower.includes('amazon') || lower.includes('prime')) return PlatformId.PRIME;
    if (lower.includes('disney')) return PlatformId.DISNEY;
    if (lower.includes('hotstar')) return PlatformId.HOTSTAR;
    if (lower.includes('jio')) return PlatformId.JIO;
    if (lower.includes('hbo')) return PlatformId.HBO;
    if (lower.includes('apple') || lower.includes('itunes')) return PlatformId.APPLE;
    if (lower.includes('hulu')) return PlatformId.HULU;

    return PlatformId.UNKNOWN;
}
