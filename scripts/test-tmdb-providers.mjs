#!/usr/bin/env node

/**
 * Test script to verify TMDB API returns correct data for Indian OTT providers
 *
 * Usage:
 *   TMDB_API_KEY=your_key node scripts/test-tmdb-providers.mjs
 *
 * Or provide API key as argument:
 *   node scripts/test-tmdb-providers.mjs your_api_key
 */

const TMDB_API_KEY = process.argv[2] || process.env.TMDB_API_KEY;

if (!TMDB_API_KEY) {
  console.error('Please provide TMDB_API_KEY as environment variable or argument');
  console.error('Usage: TMDB_API_KEY=xxx node scripts/test-tmdb-providers.mjs');
  console.error('   Or: node scripts/test-tmdb-providers.mjs YOUR_API_KEY');
  process.exit(1);
}

const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

// Indian OTT provider IDs to test
const PROVIDERS_TO_TEST = {
  8: 'Netflix',
  119: 'Amazon Prime Video',
  122: 'Hotstar (old ID)',
  2336: 'JioHotstar (new ID)',
  350: 'Apple TV+',
  237: 'SonyLIV',
  232: 'Zee5',
  220: 'JioCinema',
  309: 'Sun Nxt',
  614: 'VI movies and tv',
};

async function tmdbFetch(endpoint, params = {}) {
  const url = new URL(`${TMDB_BASE_URL}${endpoint}`);
  url.searchParams.set('api_key', TMDB_API_KEY);

  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, String(value));
  }

  const response = await fetch(url.toString());

  if (!response.ok) {
    throw new Error(`TMDB API error: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

async function getAvailableProviders() {
  console.log('='.repeat(60));
  console.log('STEP 1: Get all available movie providers for India (IN)');
  console.log('='.repeat(60));

  try {
    const data = await tmdbFetch('/watch/providers/movie', {
      language: 'en-US',
      watch_region: 'IN',
    });

    console.log(`\nFound ${data.results?.length || 0} providers available in India:\n`);

    // Sort by display_priority
    const sorted = (data.results || []).sort((a, b) => a.display_priority - b.display_priority);

    console.log('ID    | Priority | Provider Name');
    console.log('-'.repeat(50));

    for (const p of sorted.slice(0, 30)) {
      const marker = PROVIDERS_TO_TEST[p.provider_id] ? ' ✓' : '';
      console.log(`${String(p.provider_id).padStart(5)} | ${String(p.display_priority).padStart(8)} | ${p.provider_name}${marker}`);
    }

    if (sorted.length > 30) {
      console.log(`... and ${sorted.length - 30} more`);
    }

    return sorted;
  } catch (error) {
    console.error('Error fetching providers:', error.message);
    return [];
  }
}

async function testProviderDiscovery(providerId, providerName) {
  try {
    // Test discover endpoint
    const data = await tmdbFetch('/discover/movie', {
      watch_region: 'IN',
      with_watch_providers: providerId,
      with_watch_monetization_types: 'flatrate',
      sort_by: 'popularity.desc',
      page: 1,
    });

    return {
      providerId,
      providerName,
      totalResults: data.total_results || 0,
      totalPages: data.total_pages || 0,
      sampleTitles: (data.results || []).slice(0, 3).map(m => m.title),
    };
  } catch (error) {
    return {
      providerId,
      providerName,
      error: error.message,
    };
  }
}

async function testProviderCounts() {
  console.log('\n' + '='.repeat(60));
  console.log('STEP 2: Test movie counts for each provider');
  console.log('='.repeat(60));

  const results = [];

  for (const [providerId, providerName] of Object.entries(PROVIDERS_TO_TEST)) {
    console.log(`\nTesting ${providerName} (ID: ${providerId})...`);

    const result = await testProviderDiscovery(Number(providerId), providerName);
    results.push(result);

    if (result.error) {
      console.log(`  ❌ Error: ${result.error}`);
    } else {
      console.log(`  ✓ Total movies: ${result.totalResults} (${result.totalPages} pages)`);
      if (result.sampleTitles.length > 0) {
        console.log(`  Sample: ${result.sampleTitles.join(', ')}`);
      }
    }

    // Rate limit
    await new Promise(r => setTimeout(r, 300));
  }

  console.log('\n' + '='.repeat(60));
  console.log('SUMMARY: Provider Movie Counts (flatrate in India)');
  console.log('='.repeat(60));

  results.sort((a, b) => (b.totalResults || 0) - (a.totalResults || 0));

  console.log('\nProvider                    | Movies | Pages');
  console.log('-'.repeat(50));

  for (const r of results) {
    if (r.error) {
      console.log(`${r.providerName.padEnd(27)} | ERROR: ${r.error}`);
    } else {
      const status = r.totalResults === 0 ? ' ⚠️' : '';
      console.log(`${r.providerName.padEnd(27)} | ${String(r.totalResults).padStart(6)} | ${r.totalPages}${status}`);
    }
  }

  return results;
}

async function testSpecificMovie() {
  console.log('\n' + '='.repeat(60));
  console.log('STEP 3: Test watch providers for a known popular Indian movie');
  console.log('='.repeat(60));

  // Test with "RRR" (TMDB ID: 579974) - known to be on Netflix India
  const testMovies = [
    { id: 579974, title: 'RRR' },
    { id: 614930, title: 'Pathaan' },
    { id: 866398, title: 'Jawan' },
  ];

  for (const movie of testMovies) {
    console.log(`\nChecking providers for "${movie.title}" (ID: ${movie.id})...`);

    try {
      const data = await tmdbFetch(`/movie/${movie.id}/watch/providers`);
      const inProviders = data.results?.IN;

      if (!inProviders) {
        console.log('  No providers found for India');
        continue;
      }

      if (inProviders.flatrate) {
        console.log('  Flatrate (streaming):');
        for (const p of inProviders.flatrate) {
          const known = PROVIDERS_TO_TEST[p.provider_id] ? ' ✓' : '';
          console.log(`    - ${p.provider_name} (ID: ${p.provider_id})${known}`);
        }
      }

      if (inProviders.rent) {
        console.log(`  Rent: ${inProviders.rent.map(p => p.provider_name).join(', ')}`);
      }

      if (inProviders.buy) {
        console.log(`  Buy: ${inProviders.buy.map(p => p.provider_name).join(', ')}`);
      }
    } catch (error) {
      console.log(`  Error: ${error.message}`);
    }

    await new Promise(r => setTimeout(r, 300));
  }
}

async function main() {
  console.log('TMDB Provider Test for GoodWatch');
  console.log(`API Key: ${TMDB_API_KEY.substring(0, 10)}...`);
  console.log('Watch Region: IN (India)');
  console.log('');

  await getAvailableProviders();
  await testProviderCounts();
  await testSpecificMovie();

  console.log('\n' + '='.repeat(60));
  console.log('TEST COMPLETE');
  console.log('='.repeat(60));
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
