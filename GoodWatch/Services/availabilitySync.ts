/**
 * Availability Sync Service
 * Fetches data from external providers (TMDB/OMDb) and updates the database.
 * This runs outside the main user flow.
 */

import { Movie } from '../core/types';

export class AvailabilitySyncService {
    /**
     * Mocks fetching availability from an external provider and updating local/DB state.
     * @param movie The movie to update
     */
    async syncAvailability(movie: Movie): Promise<Movie> {
        console.log(`[SYNC] Checking availability for ${movie.title} (${movie.id})...`);

        // Mock Implementation
        // In reality, this would call TMDB API, normalize platforms, and update Supabase.

        const updatedMovie = { ...movie };
        updatedMovie.availability_checked_at = new Date().toISOString();

        // Simulate 'm3' (Inception) being unavailable or on a platform user doesn't have
        if (movie.id === 'm3') {
            updatedMovie.available = false;
            updatedMovie.platforms = [];
        } else {
            updatedMovie.available = true;
            updatedMovie.platforms = ['netflix', 'prime']; // Default mock platforms
        }

        console.log(`[SYNC] Updated: Available=${updatedMovie.available}, Platforms=[${updatedMovie.platforms.join(', ')}]`);
        return updatedMovie;
    }
}
