/**
 * services/backfill.ts
 * 
 * Simulates a Cloud Function or Cron Job that audits the `movies` table in Supabase.
 * It checks external providers (TMDB/JustWatch) and updates availability.
 * 
 * Usage: npx tsx services/backfill.ts
 */

import { createClient } from '@supabase/supabase-js'; // Mock import in this env
// In a real app we'd need: npm install @supabase/supabase-js

const MOCK_MOVIES = [
    { id: 'm1', title: 'The Matrix', available: true, last_checked: '2023-01-01' },
    { id: 'm3', title: 'Inception', available: true, last_checked: '2023-01-01' }, // Stale
];

async function runBackfill() {
    console.log("🔄 Starting Availability Backfill...");

    // 1. Fetch Stale Movies (Mock)
    const staleMovies = MOCK_MOVIES.filter(m => m.id === 'm3');
    console.log(`found ${staleMovies.length} stale movies.`);

    for (const movie of staleMovies) {
        console.log(`Checking availability for: ${movie.title}...`);

        // 2. Mock API Latency
        await new Promise(r => setTimeout(r, 200));

        // 3. Determine New Status (Random or Logic)
        // Simulate 'Inception' becoming unavailable
        const newStatus = false;

        console.log(`-> UPDATE ${movie.id} available: ${newStatus}, checked_at: ${new Date().toISOString()}`);
    }

    console.log("✅ Backfill Complete.");
}

runBackfill();
