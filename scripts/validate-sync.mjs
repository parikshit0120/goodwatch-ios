#!/usr/bin/env node

/**
 * GoodWatch Sync Validation Script
 *
 * Runs after OTT sync to verify data integrity for MOVIES AND TV SERIES.
 * Fails if critical thresholds are not met.
 *
 * CRITICAL: This script ensures no wrong info/suggestions go to users.
 * All checks must pass before the app serves content.
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('ERROR: Missing required environment variables');
  console.error('- SUPABASE_URL:', SUPABASE_URL ? 'SET' : 'MISSING');
  console.error('- SUPABASE_SERVICE_KEY:', SUPABASE_SERVICE_KEY ? 'SET' : 'MISSING');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ============================================
// VALIDATION THRESHOLDS
// ============================================

const THRESHOLDS = {
  // Minimum MOVIES content requirements
  movies: {
    minTotal: 3000,
    minWithStreaming: 2000,
    minFirstTimeEligible: 200,  // 7.5+ rating, 2000+ votes
    minPosterCoverage: 90,
  },

  // Minimum TV SERIES content requirements
  series: {
    minTotal: 500,
    minWithStreaming: 300,
    minFirstTimeEligible: 50,   // 7.5+ rating, 500+ votes (series have fewer votes)
  },

  // Provider-specific minimums for MOVIES (CRITICAL - ensures no stale data)
  minMovieProviderCounts: {
    'Netflix': 300,
    'Amazon Prime Video': 300,
    'JioHotstar': 150,
    'Zee5': 50,
    'SonyLIV': 30,
    'Apple TV+': 10,
  },

  // Provider-specific minimums for TV SERIES
  minSeriesProviderCounts: {
    'Netflix': 100,
    'Amazon Prime Video': 100,
    'JioHotstar': 50,
  },

  // Language coverage for first-time tier (movies only)
  minLanguageCounts: {
    'en': 100,    // English
    'hi': 30,     // Hindi
    'ta': 15,     // Tamil
    'te': 15,     // Telugu
    'ml': 10,     // Malayalam
  },

  // Freshness requirements
  maxSyncAgeHours: 96,  // 4 days
  minRecentContent: 100, // Content from last 2 years
};

// ============================================
// VALIDATION LOGIC
// ============================================

const results = {
  checks: [],
  passed: true,
  criticalFailures: [],
};

function addCheck(name, passed, details, isCritical = false) {
  results.checks.push({ name, passed, details, isCritical });
  if (!passed) {
    results.passed = false;
    if (isCritical) {
      results.criticalFailures.push({ name, details });
    }
  }
  const icon = passed ? '✅' : (isCritical ? '🚨' : '❌');
  console.log(`${icon} ${name}: ${details}`);
}

async function runValidation() {
  console.log('='.repeat(60));
  console.log('GoodWatch Sync Validation - MOVIES & TV SERIES');
  console.log(`Started: ${new Date().toISOString()}`);
  console.log('='.repeat(60));
  console.log('');

  // ============================================
  // 1. MOVIES CONTENT CHECKS
  // ============================================
  console.log('--- MOVIES Content Checks ---');

  // Total movies count
  const { count: totalMovies, error: moviesError } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'movie');

  if (moviesError) {
    addCheck('Database connection', false, `Error: ${moviesError.message}`, true);
    return;
  }

  addCheck(
    'Total movies',
    (totalMovies || 0) >= THRESHOLDS.movies.minTotal,
    `${totalMovies || 0} (min: ${THRESHOLDS.movies.minTotal})`
  );

  // Movies with streaming providers
  const { count: moviesWithStreaming } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'movie')
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]');

  addCheck(
    'Movies with streaming',
    (moviesWithStreaming || 0) >= THRESHOLDS.movies.minWithStreaming,
    `${moviesWithStreaming || 0} (min: ${THRESHOLDS.movies.minWithStreaming})`,
    true  // CRITICAL
  );

  // First-time eligible movies
  const { count: firstTimeMovies } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'movie')
    .gte('vote_average', 7.5)
    .gte('vote_count', 2000)
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]');

  addCheck(
    'First-time eligible movies (7.5+/2000 votes)',
    (firstTimeMovies || 0) >= THRESHOLDS.movies.minFirstTimeEligible,
    `${firstTimeMovies || 0} (min: ${THRESHOLDS.movies.minFirstTimeEligible})`,
    true  // CRITICAL
  );

  // ============================================
  // 2. TV SERIES CONTENT CHECKS
  // ============================================
  console.log('\n--- TV SERIES Content Checks ---');

  // Total series count
  const { count: totalSeries } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'series');

  addCheck(
    'Total TV series',
    (totalSeries || 0) >= THRESHOLDS.series.minTotal,
    `${totalSeries || 0} (min: ${THRESHOLDS.series.minTotal})`
  );

  // Series with streaming providers
  const { count: seriesWithStreaming } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'series')
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]');

  addCheck(
    'TV series with streaming',
    (seriesWithStreaming || 0) >= THRESHOLDS.series.minWithStreaming,
    `${seriesWithStreaming || 0} (min: ${THRESHOLDS.series.minWithStreaming})`,
    true  // CRITICAL
  );

  // First-time eligible series (lower vote threshold for series)
  const { count: firstTimeSeries } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'series')
    .gte('vote_average', 7.5)
    .gte('vote_count', 500)
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]');

  addCheck(
    'First-time eligible series (7.5+/500 votes)',
    (firstTimeSeries || 0) >= THRESHOLDS.series.minFirstTimeEligible,
    `${firstTimeSeries || 0} (min: ${THRESHOLDS.series.minFirstTimeEligible})`
  );

  // ============================================
  // 3. CONTENT TYPE VALIDATION
  // ============================================
  console.log('\n--- Content Type Validation ---');

  // Check that content_type is properly set
  const { count: nullContentType } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .is('content_type', null);

  addCheck(
    'All content has content_type',
    (nullContentType || 0) === 0,
    nullContentType === 0 ? 'All content typed' : `${nullContentType} items missing content_type`,
    true  // CRITICAL - need to distinguish movies from series
  );

  // Verify content_type values are valid
  const { count: invalidContentType } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .not('content_type', 'in', '("movie","series")');

  addCheck(
    'Valid content_type values',
    (invalidContentType || 0) === 0,
    invalidContentType === 0 ? 'All valid' : `${invalidContentType} invalid types`,
    true
  );

  // ============================================
  // 4. PROVIDER-SPECIFIC CHECKS - MOVIES (CRITICAL)
  // ============================================
  console.log('\n--- Movie Provider Coverage (CRITICAL) ---');

  // Fetch movies with providers
  const { data: moviesWithProviderData } = await supabase
    .from('movies')
    .select('ott_providers')
    .eq('content_type', 'movie')
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]')
    .limit(10000);

  const movieProviderCounts = {};
  for (const item of moviesWithProviderData || []) {
    const providers = item.ott_providers || [];
    for (const p of providers) {
      const name = p.name || 'Unknown';
      movieProviderCounts[name] = (movieProviderCounts[name] || 0) + 1;
    }
  }

  // Check each required movie provider
  for (const [provider, minCount] of Object.entries(THRESHOLDS.minMovieProviderCounts)) {
    const count = movieProviderCounts[provider] || 0;
    addCheck(
      `Movie Provider: ${provider}`,
      count >= minCount,
      `${count} movies (min: ${minCount})`,
      true  // CRITICAL
    );
  }

  console.log('\n  All movie provider counts:');
  const sortedMovieProviders = Object.entries(movieProviderCounts).sort((a, b) => b[1] - a[1]);
  for (const [name, count] of sortedMovieProviders) {
    console.log(`    ${name}: ${count}`);
  }

  // ============================================
  // 5. PROVIDER-SPECIFIC CHECKS - TV SERIES
  // ============================================
  console.log('\n--- TV Series Provider Coverage ---');

  // Fetch series with providers
  const { data: seriesWithProviderData } = await supabase
    .from('movies')
    .select('ott_providers')
    .eq('content_type', 'series')
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]')
    .limit(10000);

  const seriesProviderCounts = {};
  for (const item of seriesWithProviderData || []) {
    const providers = item.ott_providers || [];
    for (const p of providers) {
      const name = p.name || 'Unknown';
      seriesProviderCounts[name] = (seriesProviderCounts[name] || 0) + 1;
    }
  }

  // Check each required series provider
  for (const [provider, minCount] of Object.entries(THRESHOLDS.minSeriesProviderCounts)) {
    const count = seriesProviderCounts[provider] || 0;
    addCheck(
      `Series Provider: ${provider}`,
      count >= minCount,
      `${count} series (min: ${minCount})`
    );
  }

  console.log('\n  All TV series provider counts:');
  const sortedSeriesProviders = Object.entries(seriesProviderCounts).sort((a, b) => b[1] - a[1]);
  for (const [name, count] of sortedSeriesProviders) {
    console.log(`    ${name}: ${count}`);
  }

  // ============================================
  // 6. LANGUAGE COVERAGE CHECKS (Movies)
  // ============================================
  console.log('\n--- Language Coverage (First-Time Movies) ---');

  for (const [lang, minCount] of Object.entries(THRESHOLDS.minLanguageCounts)) {
    const { count } = await supabase
      .from('movies')
      .select('*', { count: 'exact', head: true })
      .eq('content_type', 'movie')
      .eq('original_language', lang)
      .gte('vote_average', 7.5)
      .gte('vote_count', 2000)
      .not('ott_providers', 'is', null)
      .neq('ott_providers', '[]');

    addCheck(
      `Language: ${lang}`,
      (count || 0) >= minCount,
      `${count || 0} first-time eligible movies (min: ${minCount})`
    );
  }

  // ============================================
  // 7. FRESHNESS CHECKS
  // ============================================
  console.log('\n--- Freshness Checks ---');

  const currentYear = new Date().getFullYear();

  // Recent movies
  const { count: recentMovies } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'movie')
    .gte('release_date', `${currentYear - 1}-01-01`)
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]');

  // Recent series
  const { count: recentSeries } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .eq('content_type', 'series')
    .gte('release_date', `${currentYear - 1}-01-01`)
    .not('ott_providers', 'is', null)
    .neq('ott_providers', '[]');

  const totalRecent = (recentMovies || 0) + (recentSeries || 0);
  addCheck(
    'Recent content (last 2 years)',
    totalRecent >= THRESHOLDS.minRecentContent,
    `${totalRecent} total (${recentMovies || 0} movies, ${recentSeries || 0} series) (min: ${THRESHOLDS.minRecentContent})`
  );

  // ============================================
  // 8. DATA INTEGRITY CHECKS
  // ============================================
  console.log('\n--- Data Integrity Checks ---');

  // Check for legacy provider names (JioCinema, Hotstar should be JioHotstar)
  const legacyProviderNames = ['Hotstar', 'Disney+ Hotstar', 'JioCinema'];
  let hasLegacyProviders = false;

  const allProviderData = [...(moviesWithProviderData || []), ...(seriesWithProviderData || [])];
  for (const item of allProviderData) {
    const providers = item.ott_providers || [];
    for (const p of providers) {
      if (legacyProviderNames.includes(p.name)) {
        hasLegacyProviders = true;
        break;
      }
    }
    if (hasLegacyProviders) break;
  }

  addCheck(
    'No legacy provider names',
    !hasLegacyProviders,
    hasLegacyProviders
      ? 'FOUND legacy names (Hotstar/JioCinema) - should be JioHotstar'
      : 'All providers use current names',
    true  // CRITICAL - legacy names cause broken deep links
  );

  // Check poster coverage
  const { count: withPoster } = await supabase
    .from('movies')
    .select('*', { count: 'exact', head: true })
    .not('poster_path', 'is', null)
    .neq('poster_path', '');

  const totalContent = (totalMovies || 0) + (totalSeries || 0);
  const posterCoverage = totalContent > 0 ? Math.round((withPoster / totalContent) * 100) : 0;
  addCheck(
    'Poster coverage',
    posterCoverage >= THRESHOLDS.movies.minPosterCoverage,
    `${posterCoverage}% (min: ${THRESHOLDS.movies.minPosterCoverage}%)`
  );

  // ============================================
  // SUMMARY
  // ============================================
  console.log('\n' + '='.repeat(60));
  console.log('VALIDATION SUMMARY');
  console.log('='.repeat(60));

  const passedCount = results.checks.filter(c => c.passed).length;
  const totalCount = results.checks.length;
  const criticalCount = results.criticalFailures.length;

  console.log(`\nContent totals:`);
  console.log(`  Movies: ${totalMovies || 0} (${moviesWithStreaming || 0} with streaming)`);
  console.log(`  TV Series: ${totalSeries || 0} (${seriesWithStreaming || 0} with streaming)`);
  console.log(`  Total: ${totalContent}`);

  console.log(`\nValidation results:`);
  console.log(`  Passed: ${passedCount}/${totalCount} checks`);
  console.log(`  Critical failures: ${criticalCount}`);
  console.log(`  Overall: ${results.passed ? 'PASS ✅' : 'FAIL ❌'}`);

  if (!results.passed) {
    console.log('\n🚨 FAILED CHECKS:');
    results.checks
      .filter(c => !c.passed)
      .forEach(c => {
        const prefix = c.isCritical ? '  🚨 [CRITICAL]' : '  ❌';
        console.log(`${prefix} ${c.name}: ${c.details}`);
      });

    if (criticalCount > 0) {
      console.log('\n⛔ CRITICAL FAILURES DETECTED!');
      console.log('The sync has data integrity issues that could cause wrong suggestions.');
      console.log('Please investigate and re-run the sync before serving content.');
    }

    process.exit(1);
  }

  console.log('\n✅ All validation checks passed!');
  console.log('Movies and TV Series data is ready to serve.');
}

// Run validation with error handling
runValidation().catch(error => {
  console.error('\n🚨 VALIDATION SCRIPT CRASHED:');
  console.error(error);
  process.exit(1);
});
