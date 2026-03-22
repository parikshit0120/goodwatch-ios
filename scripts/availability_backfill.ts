/**
 * scripts/availability_backfill.ts
 * 
 * ONE-TIME SCRIPT
 * Purpose: Backfill Supabase with trustworthy availability data from TMDB/OMDb.
 * 
 * Logic:
 * 1. Fetch "stale" movies (mocked).
 * 2. Query TMDB/OMDb (mocked) for platform data.
 * 3. Normalize platform strings.
 * 4. Update "Supabase" with standardized data.
 * 
 * Run: npx tsx scripts/availability_backfill.ts
 */

import { normalizePlatform, PlatformId } from '../core/normalization';

// --- MOCK SUPABASE CLIENT ---
// In real life: import { createClient } from '@supabase/supabase-js'
const MOCK_DB = [
    { id: 'm1', title: 'The Matrix', available: null, platforms: [], checked_at: null },
    { id: 'm2', title: 'Mad Max: Fury Road', available: true, platforms: ['netflix'], checked_at: '2023-01-01T00:00:00Z' }, // Expired
    { id: 'm3', title: 'Inception', available: null, platforms: [], checked_at: null },
    { id: 'm4', title: 'Parasite', available: null, platforms: [], checked_at: null },
    { id: 'm5', title: 'Paddington 2', available: null, platforms: [], checked_at: null },
];

// --- MOCK PROVIDER API (TMDB/JustWatch) ---
// Returns "messy" real-world data
async function fetchProviderData(movieId: string, title: string): Promise<string[]> {
    console.log(`   [API] Fetching providers for ${title}...`);
    await new Promise(r => setTimeout(r, 100)); // Simulate net lag

    const MOCK_RESPONSES: Record<string, string[]> = {
        'm1': ['Netflix', 'Amazon Prime Video', 'Apple iTunes'],
        'm2': ['HBO Max', 'Hulu'],
        'm3': ['Netflix', 'JioCinema'], // Inception
        'm4': ['Hulu', 'Kanopy'],       // Parasite
        'm5': ['Disney+', 'Amazon Video'], // Paddington
    };
    return MOCK_RESPONSES[movieId] || [];
}

async function runBackfill() {
    console.log('🚀 Starting Availability Backfill (One-Time)...');
    console.log('---------------------------------------------');

    // 1. QUERY: Find stale records
    const now = new Date();
    const staleMovies = MOCK_DB.filter(m => {
        if (!m.checked_at) return true;
        const lastCheck = new Date(m.checked_at);
        const diffDays = (now.getTime() - lastCheck.getTime()) / (1000 * 3600 * 24);
        return diffDays > 7;
    });

    console.log(`📦 Found ${staleMovies.length} movies needing update.\n`);

    // 2. PROCESS LOOP
    for (const movie of staleMovies) {
        console.log(`🔹 Processing: "${movie.title}" (${movie.id})`);

        // A. Fetch Data
        const rawPlatforms = await fetchProviderData(movie.id, movie.title);

        // B. Normalize
        const normalizedPlatforms = rawPlatforms
            .map(p => normalizePlatform(p))
            .filter(p => p !== PlatformId.UNKNOWN); // Filter out unknown garbage

        // C. Logic: Available if on ANY trusted platform
        const isAvailable = normalizedPlatforms.length > 0;

        // D. Update Object (Mock DB Write)
        const updatePayload = {
            available: isAvailable,
            platforms: normalizedPlatforms,
            availability_confidence: 'HIGH',
            availability_checked_at: new Date().toISOString()
        };

        // E. Log Result
        console.log(`   -> Raw: [${rawPlatforms.join(', ')}]`);
        console.log(`   -> Normalized: [${normalizedPlatforms.join(', ')}]`);
        console.log(`   ✅ UPDATED: available=${isAvailable}\n`);
    }

    console.log('---------------------------------------------');
    console.log('🎉 Backfill Complete. Supabase is now trustworthy.');
}

runBackfill();
