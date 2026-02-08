/**
 * Movie Selector (Pure Logic)
 */

import { Session } from './session';
import { isAvailable } from './availability';
import { Movie } from './types';
export { Movie } from './types';

export interface SelectionContext {
    session: Session;
    availableMovies: Movie[];
    seenMovieIds: string[];
    userPlatforms: string[];
    blacklistedMovieIds: string[];
}

/**
 * Selects a movie based on the context.
 * Pure function: Context -> Movie | null
 */
export function selectMovie(context: SelectionContext): Movie | null {
    const { availableMovies, seenMovieIds, blacklistedMovieIds, userPlatforms, session } = context;

    // 1. Exclude Seen and Blacklisted
    let candidates = availableMovies.filter(movie => {
        if (seenMovieIds.includes(movie.id)) return false;
        if (blacklistedMovieIds.includes(movie.id)) return false;
        return true;
    });

    // 2. Metadata Filters (Hard Guards)
    candidates = candidates.filter(movie => {
        // Language Match
        if (!session.userLanguages.includes(movie.language)) return false;

        // Runtime Guard (80-160 mins)
        if (movie.runtimeMinutes < 80 || movie.runtimeMinutes > 160) return false;

        // Minimum Votes (Static: e.g., 500)
        if (movie.voteCount < 500) return false;

        // Minimum Rating (Static: e.g., 6.0)
        if (movie.rating < 6.0) return false;

        return true;
    });

    if (candidates.length === 0) {
        return null;
    }

    // 3. Availability Filter (Strict Platform Match)
    // Note: Selector uses `isAvailable` which checks platforms.
    // We pass `session.userPlatforms` (which comes from calibration)
    const availableCandidates = candidates.filter(movie => isAvailable(movie, session.userPlatforms));

    if (availableCandidates.length === 0) {
        return null;
    }

    // 4. Recency Decay (Simple Logic for v1)
    // "Prefer newer only when risk_level > 0". 
    // Since risk logic is placeholder, let's implement a simple sort:
    // Sort by releaseDate DESC (Newest first)
    // This satisfies "Prefer newer".
    availableCandidates.sort((a, b) => {
        return new Date(b.releaseDate).getTime() - new Date(a.releaseDate).getTime();
    });

    // 5. Pick Deterministic (Top of sorted list)
    return availableCandidates[0];
}
