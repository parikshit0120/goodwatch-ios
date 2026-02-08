/**
 * Core Data Models & Enums
 */

// A.1 Canonical Internal ID (UUID)
export type CanonicalID = string;

// A.5 Availability Region
export enum AvailabilityRegion {
    IN = 'IN', // India (Default v1)
    US = 'US',
    UK = 'UK'
}

// A.3 Availability Confidence
export enum AvailabilityConfidence {
    HIGH = 'HIGH',    // Confirmed by multiple sources or trusted source
    MEDIUM = 'MEDIUM', // Single source or older check
    LOW = 'LOW'       // Unverified or conflicting or very old
}

// A.8 Availability Failure Reason
export enum AvailabilityFailureReason {
    MISSING_ID = 'missing_id',
    EXPIRED_TTL = 'expired_ttl',
    PLATFORM_MISMATCH = 'platform_mismatch',
    REGION_MISMATCH = 'region_mismatch',
    LOW_CONFIDENCE = 'low_confidence',
    UNKNOWN = 'unknown'
}

// A.2 Movie Sources
export interface MovieSource {
    movieId: CanonicalID;
    source: 'tmdb' | 'omdb' | 'custom';
    sourceId: string;
}

export interface Movie {
    id: CanonicalID;
    title: string;

    // Availability Core
    available: boolean;
    platforms: string[]; // Normalized Platform IDs
    availability_checked_at: string; // ISO Date
    availability_region: AvailabilityRegion; // A.5
    availability_confidence: AvailabilityConfidence; // A.3
    platform_last_verified_by: 'supabase' | 'tmdb' | 'omdb'; // A.7

    // Metadata Filters
    language: string;
    runtimeMinutes: number;
    voteCount: number;
    rating: number; // 0-10
    releaseDate: string; // ISO Date
}
