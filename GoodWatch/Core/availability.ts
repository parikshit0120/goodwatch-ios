import { Movie } from './types';

/**
 * Availability Gate
 * Pure function to verify if a movie is watchable.
 */

export function isAvailable(movie: Movie, userPlatforms: string[]): boolean {
    // 1. Check global availability flag
    if (!movie.available) {
        return false;
    }

    // 2. Check platform intersection
    // If user has no platforms, they can't watch anything (strict mode)
    if (!userPlatforms || userPlatforms.length === 0) {
        return false;
    }

    return movie.platforms.some(platform => userPlatforms.includes(platform));
}
