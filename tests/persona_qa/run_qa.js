#!/usr/bin/env node
// ============================================================
// GoodWatch 1000-Persona QA Engine
// ============================================================
// Mirrors GWRecommendationEngine.swift scoring & filtering logic.
// Fetches movies from Supabase, generates 1000 synthetic personas,
// runs each through the JS engine, checks invariants, outputs report.
// ============================================================

import { writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---- Configuration ----
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jdjqrlkynwfhbtyuddjk.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkanFybGt5bndmaGJ0eXVkZGprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0NzUwMTEsImV4cCI6MjA4MDA1MTAxMX0.KDRMLCewVMp3lwphkUvtoWOkg6kyAk8iSbVkRKiHYSk';
const PERSONA_COUNT = 1000;
const RECS_PER_PERSONA = 10;

// ---- Constants mirroring Swift engine ----
const MOOD_MAPPINGS = {
  feel_good: {
    moodKey: 'feel_good', displayName: 'Feel-good',
    targetComfortMin: 7, targetComfortMax: null,
    targetDarknessMin: null, targetDarknessMax: 4,
    targetEmotionalIntensityMin: null, targetEmotionalIntensityMax: null,
    targetEnergyMin: null, targetEnergyMax: null,
    targetComplexityMin: null, targetComplexityMax: null,
    targetRewatchabilityMin: null, targetRewatchabilityMax: null,
    targetHumourMin: null, targetHumourMax: null,
    targetMentalstimulationMin: null, targetMentalstimulationMax: null,
    idealComfort: 8.0, idealDarkness: 2.0,
    idealEmotionalIntensity: 4.0, idealEnergy: 6.0,
    idealComplexity: 4.0, idealRewatchability: 7.0,
    idealHumour: 6.0, idealMentalstimulation: 4.0,
    compatibleTags: ['feel_good', 'uplifting', 'safe_bet', 'light', 'calm'],
    antiTags: ['dark', 'disturbing'],
    weightComfort: 0.9, weightDarkness: 0.8,
    weightEmotionalIntensity: 0.4, weightEnergy: 0.5,
    weightComplexity: 0.3, weightRewatchability: 0.5,
    weightHumour: 0.6, weightMentalstimulation: 0.3,
  },
  easy_watch: {
    moodKey: 'easy_watch', displayName: 'Easy watch',
    targetComfortMin: 5, targetComfortMax: null,
    targetDarknessMin: null, targetDarknessMax: 4,
    targetEmotionalIntensityMin: null, targetEmotionalIntensityMax: null,
    targetEnergyMin: null, targetEnergyMax: null,
    targetComplexityMin: null, targetComplexityMax: null,
    targetRewatchabilityMin: null, targetRewatchabilityMax: null,
    targetHumourMin: null, targetHumourMax: null,
    targetMentalstimulationMin: null, targetMentalstimulationMax: null,
    idealComfort: 7.0, idealDarkness: 2.0,
    idealEmotionalIntensity: 4.0, idealEnergy: 5.0,
    idealComplexity: 3.0, idealRewatchability: 6.0,
    idealHumour: 5.0, idealMentalstimulation: 3.0,
    compatibleTags: ['light', 'background_friendly', 'safe_bet', 'calm'],
    antiTags: ['dark', 'disturbing', 'acquired_taste'],
    weightComfort: 0.8, weightDarkness: 0.7,
    weightEmotionalIntensity: 0.4, weightEnergy: 0.4,
    weightComplexity: 0.6, weightRewatchability: 0.5,
    weightHumour: 0.4, weightMentalstimulation: 0.3,
  },
  surprise_me: {
    moodKey: 'surprise_me', displayName: 'Surprise me',
    targetComfortMin: null, targetComfortMax: null,
    targetDarknessMin: null, targetDarknessMax: null,
    targetEmotionalIntensityMin: null, targetEmotionalIntensityMax: null,
    targetEnergyMin: null, targetEnergyMax: null,
    targetComplexityMin: null, targetComplexityMax: null,
    targetRewatchabilityMin: null, targetRewatchabilityMax: null,
    targetHumourMin: null, targetHumourMax: null,
    targetMentalstimulationMin: null, targetMentalstimulationMax: null,
    idealComfort: 5.0, idealDarkness: 5.0,
    idealEmotionalIntensity: 5.0, idealEnergy: 5.0,
    idealComplexity: 5.0, idealRewatchability: 5.0,
    idealHumour: 5.0, idealMentalstimulation: 5.0,
    compatibleTags: [],
    antiTags: [],
    weightComfort: 0.5, weightDarkness: 0.5,
    weightEmotionalIntensity: 0.5, weightEnergy: 0.5,
    weightComplexity: 0.5, weightRewatchability: 0.5,
    weightHumour: 0.5, weightMentalstimulation: 0.5,
  },
  gripping: {
    moodKey: 'gripping', displayName: 'Gripping',
    targetComfortMin: null, targetComfortMax: null,
    targetDarknessMin: null, targetDarknessMax: null,
    targetEmotionalIntensityMin: 7, targetEmotionalIntensityMax: null,
    targetEnergyMin: null, targetEnergyMax: null,
    targetComplexityMin: null, targetComplexityMax: null,
    targetRewatchabilityMin: null, targetRewatchabilityMax: null,
    targetHumourMin: null, targetHumourMax: null,
    targetMentalstimulationMin: null, targetMentalstimulationMax: null,
    idealComfort: 4.0, idealDarkness: 5.0,
    idealEmotionalIntensity: 8.0, idealEnergy: 7.0,
    idealComplexity: 6.0, idealRewatchability: 5.0,
    idealHumour: 3.0, idealMentalstimulation: 6.0,
    compatibleTags: ['tense', 'high_energy', 'full_attention', 'medium'],
    antiTags: [],
    weightComfort: 0.3, weightDarkness: 0.4,
    weightEmotionalIntensity: 0.9, weightEnergy: 0.7,
    weightComplexity: 0.5, weightRewatchability: 0.3,
    weightHumour: 0.3, weightMentalstimulation: 0.5,
  },
  dark_heavy: {
    moodKey: 'dark_heavy', displayName: 'Dark & Heavy',
    targetComfortMin: null, targetComfortMax: 5,
    targetDarknessMin: 7, targetDarknessMax: null,
    targetEmotionalIntensityMin: null, targetEmotionalIntensityMax: null,
    targetEnergyMin: null, targetEnergyMax: null,
    targetComplexityMin: null, targetComplexityMax: null,
    targetRewatchabilityMin: null, targetRewatchabilityMax: null,
    targetHumourMin: null, targetHumourMax: null,
    targetMentalstimulationMin: null, targetMentalstimulationMax: null,
    idealComfort: 3.0, idealDarkness: 8.0,
    idealEmotionalIntensity: 8.0, idealEnergy: 6.0,
    idealComplexity: 7.0, idealRewatchability: 4.0,
    idealHumour: 2.0, idealMentalstimulation: 6.0,
    compatibleTags: ['dark', 'bittersweet', 'heavy', 'full_attention', 'acquired_taste'],
    antiTags: [],
    weightComfort: 0.7, weightDarkness: 0.9,
    weightEmotionalIntensity: 0.7, weightEnergy: 0.4,
    weightComplexity: 0.5, weightRewatchability: 0.3,
    weightHumour: 0.3, weightMentalstimulation: 0.4,
  },
};

const MOOD_KEYS = Object.keys(MOOD_MAPPINGS);

const OTT_PLATFORMS = ['netflix', 'prime', 'jio_hotstar', 'apple_tv', 'sony_liv', 'zee5'];

const PLATFORM_EXPANSIONS = {
  netflix: ['netflix', 'netflix kids'],
  prime: ['amazon prime video', 'amazon prime video with ads', 'amazon video', 'prime video'],
  jio_hotstar: ['jiohotstar', 'hotstar', 'disney+ hotstar', 'jio hotstar'],
  apple_tv: ['apple tv', 'apple tv+'],
  sony_liv: ['sony liv', 'sonyliv'],
  zee5: ['zee5'],
};

const LANGUAGE_ISO_MAP = {
  english: 'en', hindi: 'hi', tamil: 'ta', telugu: 'te',
  malayalam: 'ml', kannada: 'kn', marathi: 'mr', korean: 'ko',
  japanese: 'ja', spanish: 'es', french: 'fr', bengali: 'bn',
  punjabi: 'pa', gujarati: 'gu', chinese: 'zh', portuguese: 'pt',
};

const ALL_LANGUAGES = ['english', 'hindi', 'tamil', 'telugu', 'malayalam', 'kannada', 'punjabi'];

const GENRE_PREFS = ['action', 'drama', 'comedy', 'thriller', 'romance', 'horror', 'sci-fi', 'documentary', 'any'];

const AGE_GROUPS = ['18-24', '25-34', '35-44', '45+'];

// ---- Supabase Fetcher ----
async function fetchMovies() {
  console.log('[QA] Fetching movies from Supabase...');
  const allMovies = [];
  let offset = 0;
  const batchSize = 1000;

  while (true) {
    const url = `${SUPABASE_URL}/rest/v1/movies?select=*&is_standup=eq.false&order=composite_score.desc.nullslast,imdb_rating.desc.nullslast&limit=${batchSize}&offset=${offset}`;
    const res = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
      },
    });

    if (!res.ok) throw new Error(`Supabase fetch failed: ${res.status} ${res.statusText}`);
    const batch = await res.json();
    if (batch.length === 0) break;
    allMovies.push(...batch);
    offset += batchSize;
    if (batch.length < batchSize) break;
  }

  console.log(`[QA] Fetched ${allMovies.length} movies from Supabase`);
  return allMovies;
}

// ---- Movie Conversion (Movie -> GWMovie, mirrors GWSpec.swift init(from:)) ----
function toGWMovie(raw) {
  const id = raw.id;
  const title = raw.title || '';
  const year = raw.year || 2020;

  // Runtime: series with runtime > 120 or null -> 0
  const ct = (raw.content_type || '').toLowerCase();
  const isSeries = ct === 'series' || ct === 'tv';
  let runtime;
  if (isSeries) {
    runtime = (raw.runtime && raw.runtime > 0 && raw.runtime <= 120) ? raw.runtime : 0;
  } else {
    runtime = raw.runtime || 120;
  }

  const language = raw.original_language || 'en';

  // Parse ott_providers
  let providers = [];
  if (raw.ott_providers) {
    if (typeof raw.ott_providers === 'string') {
      try { providers = JSON.parse(raw.ott_providers); } catch { providers = []; }
    } else if (Array.isArray(raw.ott_providers)) {
      providers = raw.ott_providers;
    }
  }
  const platforms = providers.map(p => p.name || '').filter(Boolean);

  // Parse genres
  let genres = [];
  if (raw.genres) {
    if (typeof raw.genres === 'string') {
      try { genres = JSON.parse(raw.genres).map(g => g.name || g); } catch { genres = []; }
    } else if (Array.isArray(raw.genres)) {
      genres = raw.genres.map(g => (typeof g === 'string') ? g : (g.name || ''));
    }
  }

  // Emotional profile
  let ep = null;
  if (raw.emotional_profile) {
    if (typeof raw.emotional_profile === 'string') {
      try { ep = JSON.parse(raw.emotional_profile); } catch { ep = null; }
    } else {
      ep = raw.emotional_profile;
    }
    // Normalize keys
    if (ep) {
      ep = {
        complexity: ep.complexity ?? null,
        darkness: ep.darkness ?? null,
        comfort: ep.comfort ?? null,
        energy: ep.energy ?? null,
        mentalStimulation: ep.mental_stimulation ?? ep.mentalStimulation ?? null,
        rewatchability: ep.rewatchability ?? null,
        emotionalIntensity: ep.emotional_intensity ?? ep.emotionalIntensity ?? null,
        humour: ep.humour ?? null,
      };
    }
  }

  // Derive tags
  const tags = deriveTags(ep, raw.imdb_rating ?? raw.vote_average ?? 7.0);

  // GoodScore (0-10 scale)
  const sourceRating = raw.composite_score ?? raw.imdb_rating ?? raw.vote_average ?? 0.0;
  const goodscore = sourceRating;

  // Composite score on 0-100 scale
  let composite_score;
  if (raw.composite_score && raw.composite_score > 0) {
    composite_score = raw.composite_score * 10;
  } else if (raw.imdb_rating && raw.vote_average && raw.imdb_rating > 0 && raw.vote_average > 0) {
    composite_score = ((raw.imdb_rating * 0.75) + (raw.vote_average * 0.25)) * 10;
  } else {
    composite_score = sourceRating * 10;
  }

  const voteCount = raw.imdb_votes ?? raw.vote_count ?? 0;
  const available = raw.available != null ? raw.available : (platforms.length > 0);
  const contentType = raw.content_type || null;

  // Dubbed languages
  const dubbedLanguages = raw.dubbed_languages || [];
  const dubConfidence = raw.dub_confidence || 'unknown';

  return {
    id, title, year, runtime, language, platforms, genres, tags,
    goodscore, composite_score, voteCount, available, contentType,
    emotionalProfile: ep, isSeries, dubbedLanguages, dubConfidence,
  };
}

// ---- Tag Derivation (mirrors GWSpec.swift deriveTags) ----
function deriveTags(ep, rating) {
  const tags = [];

  if (!ep) {
    return ['medium', 'polarizing', 'full_attention'];
  }

  // Cognitive Load
  const complexity = ep.complexity ?? 5;
  if (complexity <= 3) tags.push('light');
  else if (complexity <= 6) tags.push('medium');
  else tags.push('heavy');

  // Emotional Outcome
  const darkness = ep.darkness ?? 5;
  const comfort = ep.comfort ?? 5;
  if (darkness >= 7) tags.push('dark');
  else if (comfort >= 7) tags.push('feel_good');
  else if (comfort >= 5 && darkness <= 4) tags.push('uplifting');
  else tags.push('bittersweet');

  // Energy
  const energy = ep.energy ?? 5;
  if (energy <= 3) tags.push('calm');
  else if (energy >= 7) tags.push('high_energy');
  else tags.push('tense');

  // Attention
  const mentalStim = ep.mentalStimulation ?? 5;
  if (mentalStim <= 3) tags.push('background_friendly');
  else if ((ep.rewatchability ?? 5) >= 7) tags.push('rewatchable');
  else tags.push('full_attention');

  // Regret Risk
  const intensity = ep.emotionalIntensity ?? 5;
  if (rating >= 7.5 && intensity <= 6) tags.push('safe_bet');
  else if (intensity >= 8 || darkness >= 8) tags.push('acquired_taste');
  else tags.push('polarizing');

  return tags;
}

// ---- Language Matching (mirrors engine isValidMovie Rule 1) ----
function languageMatches(movieLang, userLangs) {
  if (userLangs.length === 0) return true;
  const ml = movieLang.toLowerCase();
  return userLangs.some(lang => {
    const l = lang.toLowerCase();
    const iso = LANGUAGE_ISO_MAP[l] || l;
    return ml.includes(l) || ml === iso;
  });
}

// ---- Platform Matching (mirrors engine isValidMovie Rule 2) ----
function platformMatches(moviePlatforms, userPlatforms) {
  if (userPlatforms.length === 0) return true;
  const moviePlats = new Set(moviePlatforms.map(p => p.toLowerCase()));

  const expanded = new Set();
  for (const p of userPlatforms) {
    const key = p.toLowerCase();
    expanded.add(key);
    const exps = PLATFORM_EXPANSIONS[key];
    if (exps) exps.forEach(e => expanded.add(e));
  }

  for (const mp of moviePlats) {
    for (const up of expanded) {
      if (mp.includes(up) || up.includes(mp)) return true;
    }
  }
  return false;
}

// ---- Mood Filter (mirrors passesRemoteMoodFilter) ----
function passesMoodFilter(movie, mapping, intentTags) {
  const hasDimensionalGates =
    mapping.targetComfortMin != null || mapping.targetComfortMax != null ||
    mapping.targetDarknessMin != null || mapping.targetDarknessMax != null ||
    mapping.targetEmotionalIntensityMin != null || mapping.targetEmotionalIntensityMax != null ||
    mapping.targetEnergyMin != null || mapping.targetEnergyMax != null ||
    mapping.targetComplexityMin != null || mapping.targetComplexityMax != null ||
    mapping.targetRewatchabilityMin != null || mapping.targetRewatchabilityMax != null ||
    mapping.targetHumourMin != null || mapping.targetHumourMax != null ||
    mapping.targetMentalstimulationMin != null || mapping.targetMentalstimulationMax != null;

  const ep = movie.emotionalProfile;
  if (!ep) {
    if (hasDimensionalGates) return false;
    if (mapping.compatibleTags.length > 0) {
      const movieTags = new Set(movie.tags);
      return mapping.compatibleTags.some(t => movieTags.has(t));
    }
    return true;
  }

  // Check dimensional ranges
  const checks = [
    [mapping.targetComfortMin, mapping.targetComfortMax, ep.comfort],
    [mapping.targetDarknessMin, mapping.targetDarknessMax, ep.darkness],
    [mapping.targetEmotionalIntensityMin, mapping.targetEmotionalIntensityMax, ep.emotionalIntensity],
    [mapping.targetEnergyMin, mapping.targetEnergyMax, ep.energy],
    [mapping.targetComplexityMin, mapping.targetComplexityMax, ep.complexity],
    [mapping.targetRewatchabilityMin, mapping.targetRewatchabilityMax, ep.rewatchability],
    [mapping.targetHumourMin, mapping.targetHumourMax, ep.humour],
    [mapping.targetMentalstimulationMin, mapping.targetMentalstimulationMax, ep.mentalStimulation],
  ];

  for (const [min, max, val] of checks) {
    if (min != null) {
      if (val == null) return false;
      if (val < min) return false;
    }
    if (max != null) {
      if (val == null) return false;
      if (val > max) return false;
    }
  }

  // Anti-tag check
  if (mapping.antiTags.length > 0) {
    const movieTags = new Set(movie.tags);
    if (mapping.antiTags.some(t => movieTags.has(t))) return false;
  }

  return true;
}

// ---- GoodScore Threshold (mirrors gwGoodscoreThreshold) ----
function goodscoreThreshold(mood, style) {
  let base;
  switch (mood.toLowerCase()) {
    case 'tired': base = 88; break;
    case 'adventurous': base = 75; break;
    default: base = 80;
  }

  switch (style) {
    case 'safe': break;
    case 'balanced': base -= 2; break;
    case 'adventurous': base = 70; break;
  }

  return base;
}

// ---- Tiered Score (mirrors engine Rule 5B) ----
function tieredScore(movie) {
  if (movie.composite_score > 0) return movie.composite_score;
  return movie.goodscore > 10 ? movie.goodscore : movie.goodscore * 10;
}

// ---- Normalized Rating (mirrors engine normalizedRating) ----
function normalizedRating(movie) {
  return movie.goodscore > 10 ? movie.goodscore / 10.0 : movie.goodscore;
}

// ---- Full Validation (mirrors isValidMovie) ----
function isValidMovie(movie, profile, excluding = new Set(), skipYearGate = false, skipGoodscoreGate = false) {
  // Explicit exclusion
  if (excluding.has(movie.id)) return { valid: false, reason: 'excluding_set' };

  // Available
  if (!movie.available) return { valid: false, reason: 'unavailable' };

  // Language match
  if (!languageMatches(movie.language, profile.preferredLanguages))
    return { valid: false, reason: 'language' };

  // Platform match
  if (!platformMatches(movie.platforms, profile.platforms))
    return { valid: false, reason: 'platform' };

  // Already interacted
  if (profile.excludedIds.has(movie.id))
    return { valid: false, reason: 'interacted' };

  // Runtime in window
  if (movie.runtime < profile.runtimeWindow.min || movie.runtime > profile.runtimeWindow.max)
    return { valid: false, reason: 'runtime' };

  // Shorts exclusion (< 40 min for non-series)
  if (!movie.isSeries && movie.runtime > 0 && movie.runtime < 40)
    return { valid: false, reason: 'runtime_short' };

  // Concert/behind-the-scenes exclusion
  const genreLower = movie.genres.map(g => g.toLowerCase());
  const titleLower = movie.title.toLowerCase();
  if (genreLower.includes('concert') || titleLower.includes('concert film') ||
      titleLower.includes('behind the scenes') || titleLower.includes('making of'))
    return { valid: false, reason: 'content_exclusion' };

  // Content type match
  if (profile.requiresSeries) {
    if (!movie.isSeries) return { valid: false, reason: 'content_type' };
  } else {
    if (movie.isSeries) return { valid: false, reason: 'content_type' };
  }

  // Tiered hard gates + GoodScore threshold
  if (!skipGoodscoreGate) {
    const ts = tieredScore(movie);
    const pts = profile.interactionPoints;
    if (pts < 10) {
      if (ts < 80) return { valid: false, reason: 'tiered_score' };
      if (!skipYearGate && movie.year > 0 && movie.year < 2010) return { valid: false, reason: 'tiered_year' };
    } else if (pts < 50) {
      if (ts < 70) return { valid: false, reason: 'tiered_score' };
      if (!skipYearGate && movie.year > 0 && movie.year < 2005) return { valid: false, reason: 'tiered_year' };
    } else if (pts < 100) {
      if (ts < 65) return { valid: false, reason: 'tiered_score' };
      if (!skipYearGate && movie.year > 0 && movie.year < 2000) return { valid: false, reason: 'tiered_year' };
    } else {
      if (ts < 60) return { valid: false, reason: 'tiered_score' };
      if (!skipYearGate && movie.year > 0 && movie.year < 1990) return { valid: false, reason: 'tiered_year' };
    }
    const threshold = goodscoreThreshold(profile.mood, profile.recommendationStyle);
    if (ts < threshold) return { valid: false, reason: 'goodscore' };
  }

  // Mood filter
  const mapping = profile.moodMapping;
  if (mapping && mapping.moodKey !== 'surprise_me') {
    if (!passesMoodFilter(movie, mapping, profile.intentTags))
      return { valid: false, reason: 'mood' };
  } else if (!mapping) {
    // Tag intersection fallback
    if (profile.intentTags.length > 0) {
      const movieTags = new Set(movie.tags);
      if (!profile.intentTags.some(t => movieTags.has(t)))
        return { valid: false, reason: 'tags' };
    }
  }

  return { valid: true };
}

// ---- Adaptive Quality Gate (mirrors getEffectiveQualityGate) ----
function getAdaptiveGate(seenCount, candidates) {
  let strictRating, strictVotes;
  if (seenCount === 0) { strictRating = 7.5; strictVotes = 2000; }
  else if (seenCount <= 3) { strictRating = 6.5; strictVotes = 400; }
  else if (seenCount <= 10) { strictRating = 6.2; strictVotes = 300; }
  else { strictRating = 6.0; strictVotes = 200; }

  const strictCount = candidates.filter(m =>
    normalizedRating(m) >= strictRating && m.voteCount >= strictVotes
  ).length;

  if (strictCount >= 10) return { minRating: strictRating, minVotes: strictVotes };

  const relaxedRating = Math.max(strictRating - 0.5, 6.5);
  const relaxedVotes = Math.max(Math.floor(strictVotes / 2), 300);

  const relaxedCount = candidates.filter(m =>
    normalizedRating(m) >= relaxedRating && m.voteCount >= relaxedVotes
  ).length;

  if (relaxedCount >= 10) return { minRating: relaxedRating, minVotes: relaxedVotes };

  return { minRating: Math.max(relaxedRating - 0.5, 6.5), minVotes: 300 };
}

// ---- Compute Score (mirrors computeScore in engine) ----
function computeScore(movie, profile) {
  const movieTags = new Set(movie.tags);
  const intentTags = new Set(profile.intentTags);

  // 1. Tag alignment / mood affinity
  let tagAlignment;
  const mapping = profile.moodMapping;
  if (mapping && mapping.moodKey !== 'surprise_me') {
    tagAlignment = computeMoodAffinity(movie, mapping, intentTags, profile.tagWeights);
    // Anti-tag penalty
    if (mapping.antiTags && mapping.antiTags.length > 0) {
      const antiOverlap = mapping.antiTags.filter(t => movieTags.has(t)).length;
      tagAlignment = Math.max(0, tagAlignment - antiOverlap * 0.10);
    }
  } else {
    // Fallback tag alignment
    let weightedAlignment = 0;
    let totalWeight = 0;
    for (const tag of intentTags) {
      const weight = profile.tagWeights[tag] ?? 1.0;
      totalWeight += weight;
      if (movieTags.has(tag)) weightedAlignment += weight;
    }
    tagAlignment = totalWeight > 0 ? weightedAlignment / totalWeight : 0.0;
  }

  // 2. Regret safety
  let regretSafety;
  if (movieTags.has('safe_bet')) {
    regretSafety = 1.0 * (profile.tagWeights['safe_bet'] ?? 1.0);
  } else if (movieTags.has('polarizing')) {
    regretSafety = 0.4 * (profile.tagWeights['polarizing'] ?? 1.0);
  } else {
    regretSafety = 0.6 * (profile.tagWeights['acquired_taste'] ?? 1.0);
  }
  regretSafety = Math.min(Math.max(regretSafety, 0), 1);

  // 3. Platform bias (neutral = 0.5 for QA)
  const platformBiasScore = 0.5;

  // 4. Dimensional learning penalty (0 for QA)
  const dimensionalPenalty = 0.0;

  // No taste engine or trend boosts in QA
  const baseScore = (tagAlignment * 0.50) +
                    (regretSafety * 0.25) +
                    (platformBiasScore * 0.15) +
                    ((1.0 - dimensionalPenalty) * 0.10);

  // Language priority bonus
  const languageBonus = computeLanguageBonus(movie.language, profile.preferredLanguages);

  return Math.min(Math.max(baseScore + languageBonus, 0), 1);
}

function computeMoodAffinity(movie, mapping, intentTags, tagWeights) {
  const ep = movie.emotionalProfile;
  if (!ep) {
    // Fallback to tag alignment
    const movieTags = new Set(movie.tags);
    let wa = 0, tw = 0;
    for (const t of intentTags) {
      const w = tagWeights[t] ?? 1.0;
      tw += w;
      if (movieTags.has(t)) wa += w;
    }
    return tw > 0 ? wa / tw : 0.0;
  }

  const dims = [
    [ep.comfort ?? 5, mapping.idealComfort ?? 5, mapping.weightComfort],
    [ep.darkness ?? 5, mapping.idealDarkness ?? 5, mapping.weightDarkness],
    [ep.emotionalIntensity ?? 5, mapping.idealEmotionalIntensity ?? 5, mapping.weightEmotionalIntensity],
    [ep.energy ?? 5, mapping.idealEnergy ?? 5, mapping.weightEnergy],
    [ep.complexity ?? 5, mapping.idealComplexity ?? 5, mapping.weightComplexity],
    [ep.rewatchability ?? 5, mapping.idealRewatchability ?? 5, mapping.weightRewatchability],
    [ep.humour ?? 5, mapping.idealHumour ?? 5, mapping.weightHumour],
    [ep.mentalStimulation ?? 5, mapping.idealMentalstimulation ?? 5, mapping.weightMentalstimulation],
  ];

  let totalWeightedDistance = 0;
  let totalWeight = 0;
  for (const [movieVal, ideal, weight] of dims) {
    const distance = Math.abs(movieVal - ideal) / 10.0;
    totalWeightedDistance += distance * weight;
    totalWeight += weight;
  }

  if (totalWeight === 0) return 0.5;
  return 1.0 - (totalWeightedDistance / totalWeight);
}

function computeLanguageBonus(movieLanguage, prioritizedLanguages) {
  if (prioritizedLanguages.length <= 1) return 0.0;
  const ml = movieLanguage.toLowerCase();

  // No tonight primary in QA -> equal bonus for all languages
  if (prioritizedLanguages.some(lang => {
    const l = lang.toLowerCase();
    const iso = LANGUAGE_ISO_MAP[l] || l;
    return ml.includes(l) || ml === iso;
  })) {
    return 0.06;
  }
  return 0.0;
}

// ---- Weighted Random Pick (mirrors weightedRandomPick, temperature=0.15) ----
function weightedRandomPick(candidates) {
  if (candidates.length === 0) return null;
  if (candidates.length === 1) return candidates[0].movie;

  const temperature = 0.15;
  const maxScore = candidates[0].score;
  const weights = candidates.map(c => Math.exp((c.score - maxScore) / temperature));
  const totalWeight = weights.reduce((a, b) => a + b, 0);

  const roll = Math.random() * totalWeight;
  let cumulative = 0;
  for (let i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (roll < cumulative) return candidates[i].movie;
  }
  return candidates[candidates.length - 1].movie;
}

// ---- Deterministic Weighted Pick (same seed for determinism test) ----
function deterministicPick(candidates, seed) {
  if (candidates.length === 0) return null;
  if (candidates.length === 1) return candidates[0].movie;

  const temperature = 0.15;
  const maxScore = candidates[0].score;
  const weights = candidates.map(c => Math.exp((c.score - maxScore) / temperature));
  const totalWeight = weights.reduce((a, b) => a + b, 0);

  // Seeded pseudo-random
  const roll = seededRandom(seed) * totalWeight;
  let cumulative = 0;
  for (let i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (roll < cumulative) return candidates[i].movie;
  }
  return candidates[candidates.length - 1].movie;
}

function seededRandom(seed) {
  let x = Math.sin(seed * 9301 + 49297) * 49297;
  return x - Math.floor(x);
}

// ---- Relax Mood Mapping (widen dimensional ranges by +/-pct) ----
function relaxMoodMapping(mapping, pct) {
  if (!mapping) return null;
  function relaxMin(val) {
    if (val == null) return null;
    return Math.max(0, Math.floor(val * (1.0 - pct)));
  }
  function relaxMax(val) {
    if (val == null) return null;
    return Math.min(10, Math.ceil(val * (1.0 + pct)));
  }
  return {
    ...mapping,
    targetComfortMin: relaxMin(mapping.targetComfortMin),
    targetComfortMax: relaxMax(mapping.targetComfortMax),
    targetDarknessMin: relaxMin(mapping.targetDarknessMin),
    targetDarknessMax: relaxMax(mapping.targetDarknessMax),
    targetEmotionalIntensityMin: relaxMin(mapping.targetEmotionalIntensityMin),
    targetEmotionalIntensityMax: relaxMax(mapping.targetEmotionalIntensityMax),
    targetEnergyMin: relaxMin(mapping.targetEnergyMin),
    targetEnergyMax: relaxMax(mapping.targetEnergyMax),
    targetComplexityMin: relaxMin(mapping.targetComplexityMin),
    targetComplexityMax: relaxMax(mapping.targetComplexityMax),
    targetRewatchabilityMin: relaxMin(mapping.targetRewatchabilityMin),
    targetRewatchabilityMax: relaxMax(mapping.targetRewatchabilityMax),
    targetHumourMin: relaxMin(mapping.targetHumourMin),
    targetHumourMax: relaxMax(mapping.targetHumourMax),
    targetMentalstimulationMin: relaxMin(mapping.targetMentalstimulationMin),
    targetMentalstimulationMax: relaxMax(mapping.targetMentalstimulationMax),
  };
}

// ---- Recommend Function (mirrors GWRecommendationEngine.recommend) ----
function recommend(movies, profile, excluding = new Set(), genreHistory = {}) {
  if (movies.length === 0) return null;
  if (profile.preferredLanguages.length === 0 || profile.platforms.length === 0)
    return null;

  // Get basic pool for adaptive gate
  const basicPool = movies.filter(m => {
    if (!m.available) return false;
    if (!languageMatches(m.language, profile.preferredLanguages)) return false;
    if (!platformMatches(m.platforms, profile.platforms)) return false;
    if (profile.excludedIds.has(m.id)) return false;
    return true;
  });

  const gate = getAdaptiveGate(profile.seenCount, basicPool);

  // Filter valid movies
  let validMovies = movies.filter(m => {
    const result = isValidMovie(m, profile, excluding);
    if (!result.valid) return false;
    return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
  });

  // Dimensional gate fallback: if 0 candidates with mood gate, retry without
  if (validMovies.length === 0 && profile.moodMapping) {
    const fallbackProfile = { ...profile, moodMapping: null };
    validMovies = movies.filter(m => {
      const result = isValidMovie(m, fallbackProfile, excluding);
      if (!result.valid) return false;
      return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
    });
  }

  // Progressive Pool Relaxation (Dead Zone Fix)
  if (validMovies.length < 10) {
    // Step 1: Drop year filter
    if (validMovies.length < 10) {
      validMovies = movies.filter(m => {
        const result = isValidMovie(m, profile, excluding, true);
        if (!result.valid) return false;
        return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
      });
    }

    // Step 2: Relax mood dimensions by +/-20%
    if (validMovies.length < 10) {
      const relaxedProfile = { ...profile };
      if (profile.moodMapping) {
        relaxedProfile.moodMapping = relaxMoodMapping(profile.moodMapping, 0.2);
      }
      validMovies = movies.filter(m => {
        const result = isValidMovie(m, relaxedProfile, excluding, true);
        if (!result.valid) return false;
        return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
      });
    }

    // Step 3: Drop to tier 2 quality gate
    if (validMovies.length < 10) {
      const tier2Profile = {
        ...profile,
        interactionPoints: Math.max(profile.interactionPoints, 10),
        recommendationStyle: 'adventurous',
      };
      if (profile.moodMapping) {
        tier2Profile.moodMapping = relaxMoodMapping(profile.moodMapping, 0.2);
      }
      validMovies = movies.filter(m => {
        const result = isValidMovie(m, tier2Profile, excluding, true);
        if (!result.valid) return false;
        return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
      });
    }

    // Step 4: Never return fewer than 5 -- pad with best available
    if (validMovies.length < 5) {
      const existingIds = new Set(validMovies.map(m => m.id));
      const padProfile = {
        ...profile,
        interactionPoints: 1000,
        moodMapping: null,
        intentTags: [],
        recommendationStyle: 'adventurous',
        runtimeWindow: { min: 0, max: 999 },
      };
      const bestAvailable = movies.filter(m => {
        if (existingIds.has(m.id)) return false;
        const result = isValidMovie(m, padProfile, excluding, true, true);
        return result.valid;
      }).sort((a, b) => b.goodscore - a.goodscore);
      const needed = Math.max(0, 5 - validMovies.length);
      validMovies = validMovies.concat(bestAvailable.slice(0, needed));
    }

    // Step 5: Last resort — relax content type (allow movies for series users, vice versa)
    if (validMovies.length < 5) {
      const existingIds2 = new Set(validMovies.map(m => m.id));
      const anyTypeProfile = {
        ...profile,
        interactionPoints: 1000,
        moodMapping: null,
        intentTags: [],
        recommendationStyle: 'adventurous',
        runtimeWindow: { min: 0, max: 999 },
        requiresSeries: !profile.requiresSeries, // flip content type
      };
      const anyTypeFallback = movies.filter(m => {
        if (existingIds2.has(m.id)) return false;
        return isValidMovie(m, anyTypeProfile, excluding, true, true).valid;
      }).sort((a, b) => b.goodscore - a.goodscore);
      const needed2 = Math.max(0, 5 - validMovies.length);
      validMovies = validMovies.concat(anyTypeFallback.slice(0, needed2));
    }
  }

  if (validMovies.length === 0) return null;

  // Score and sort
  const scored = validMovies.map(m => ({ movie: m, score: computeScore(m, profile) }));
  scored.sort((a, b) => {
    if (a.score !== b.score) return b.score - a.score;
    return b.movie.goodscore - a.movie.goodscore;
  });

  // Genre diversity: use PRIMARY genre (first in list) for diversity tracking.
  // Remove movies whose primary genre is over-represented in session history.
  const diversePool = scored.filter(item => {
    const primaryGenre = (item.movie.genres[0] || '').toLowerCase();
    return !primaryGenre || (genreHistory[primaryGenre] || 0) < 3;
  });
  const pool = diversePool.length > 0 ? diversePool : scored;
  const topN = pool.slice(0, 10);
  return weightedRandomPick(topN);
}

// ---- Deterministic Recommend (for determinism test) ----
function recommendDeterministic(movies, profile, seed) {
  if (movies.length === 0) return null;
  if (profile.preferredLanguages.length === 0 || profile.platforms.length === 0)
    return null;

  const basicPool = movies.filter(m => {
    if (!m.available) return false;
    if (!languageMatches(m.language, profile.preferredLanguages)) return false;
    if (!platformMatches(m.platforms, profile.platforms)) return false;
    if (profile.excludedIds.has(m.id)) return false;
    return true;
  });

  const gate = getAdaptiveGate(profile.seenCount, basicPool);

  let validMovies = movies.filter(m => {
    const result = isValidMovie(m, profile);
    if (!result.valid) return false;
    return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
  });

  if (validMovies.length === 0 && profile.moodMapping) {
    const fallbackProfile = { ...profile, moodMapping: null };
    validMovies = movies.filter(m => {
      const result = isValidMovie(m, fallbackProfile);
      if (!result.valid) return false;
      return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
    });
  }

  // Progressive Pool Relaxation (same as recommend)
  if (validMovies.length < 10) {
    if (validMovies.length < 10) {
      validMovies = movies.filter(m => {
        const result = isValidMovie(m, profile, new Set(), true);
        if (!result.valid) return false;
        return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
      });
    }
    if (validMovies.length < 10) {
      const relaxedProfile = { ...profile };
      if (profile.moodMapping) relaxedProfile.moodMapping = relaxMoodMapping(profile.moodMapping, 0.2);
      validMovies = movies.filter(m => {
        const result = isValidMovie(m, relaxedProfile, new Set(), true);
        if (!result.valid) return false;
        return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
      });
    }
    if (validMovies.length < 10) {
      const tier2Profile = {
        ...profile,
        interactionPoints: Math.max(profile.interactionPoints, 10),
        recommendationStyle: 'adventurous',
      };
      if (profile.moodMapping) tier2Profile.moodMapping = relaxMoodMapping(profile.moodMapping, 0.2);
      validMovies = movies.filter(m => {
        const result = isValidMovie(m, tier2Profile, new Set(), true);
        if (!result.valid) return false;
        return normalizedRating(m) >= gate.minRating && m.voteCount >= gate.minVotes;
      });
    }
    if (validMovies.length < 5) {
      const existingIds = new Set(validMovies.map(m => m.id));
      const padProfile = {
        ...profile,
        interactionPoints: 1000,
        moodMapping: null,
        intentTags: [],
        recommendationStyle: 'adventurous',
        runtimeWindow: { min: 0, max: 999 },
      };
      const bestAvailable = movies.filter(m => {
        if (existingIds.has(m.id)) return false;
        return isValidMovie(m, padProfile, new Set(), true, true).valid;
      }).sort((a, b) => b.goodscore - a.goodscore);
      validMovies = validMovies.concat(bestAvailable.slice(0, Math.max(0, 5 - validMovies.length)));
    }
    // Step 5: Last resort — relax content type
    if (validMovies.length < 5) {
      const existingIds2 = new Set(validMovies.map(m => m.id));
      const anyTypeProfile = {
        ...profile,
        interactionPoints: 1000,
        moodMapping: null,
        intentTags: [],
        recommendationStyle: 'adventurous',
        runtimeWindow: { min: 0, max: 999 },
        requiresSeries: !profile.requiresSeries,
      };
      const anyTypeFallback = movies.filter(m => {
        if (existingIds2.has(m.id)) return false;
        return isValidMovie(m, anyTypeProfile, new Set(), true, true).valid;
      }).sort((a, b) => b.goodscore - a.goodscore);
      validMovies = validMovies.concat(anyTypeFallback.slice(0, Math.max(0, 5 - validMovies.length)));
    }
  }

  if (validMovies.length === 0) return null;

  const scored = validMovies.map(m => ({ movie: m, score: computeScore(m, profile) }));
  scored.sort((a, b) => {
    if (a.score !== b.score) return b.score - a.score;
    return b.movie.goodscore - a.movie.goodscore;
  });

  // Genre diversity: local reranking only (no session history for determinism test)
  const topN = scored.slice(0, 10);
  return deterministicPick(topN, seed);
}

// ---- Generate N Recommendations (excluding previously picked) ----
function generateRecommendations(movies, profile, count) {
  const results = [];
  const excluded = new Set(profile.excludedIds);
  const genreHistory = {};
  const maxRetries = 3;

  for (let i = 0; i < count; i++) {
    let pick = null;
    let retries = 0;
    while (retries <= maxRetries) {
      pick = recommend(movies, { ...profile, excludedIds: excluded }, excluded, genreHistory);
      if (!pick) break;
      const pg = (pick.genres[0] || '').toLowerCase();
      if (pg && (genreHistory[pg] || 0) >= 3 && retries < maxRetries) {
        excluded.add(pick.id);
        retries++;
        pick = null;
        continue;
      }
      break;
    }
    if (!pick) break;
    results.push(pick);
    excluded.add(pick.id);
    // Track PRIMARY genre counts across sequential picks
    const primaryGenre = (pick.genres[0] || '').toLowerCase();
    if (primaryGenre) {
      genreHistory[primaryGenre] = (genreHistory[primaryGenre] || 0) + 1;
    }
  }
  return results;
}

// ---- Persona Generator ----
function generatePersonas(count) {
  const personas = [];
  for (let i = 0; i < count; i++) {
    const mood = MOOD_KEYS[i % MOOD_KEYS.length];
    const mapping = MOOD_MAPPINGS[mood];

    // Time available
    const timeOptions = [
      { min: 60, max: 90 },
      { min: 60, max: 120 },
      { min: 60, max: 180 },
    ];
    const runtimeWindow = timeOptions[i % timeOptions.length];

    // Platform
    const platformIdx = i % (OTT_PLATFORMS.length + 1);
    const platforms = platformIdx < OTT_PLATFORMS.length
      ? [OTT_PLATFORMS[platformIdx]]
      : OTT_PLATFORMS.slice(0, 3); // "any" = multiple

    // Language
    const langOptions = [
      ['hindi'],
      ['english'],
      ['hindi', 'english'],
      ['tamil'],
      ['telugu'],
      ['malayalam'],
      ['hindi', 'english', 'tamil'],
    ];
    const languages = langOptions[i % langOptions.length];

    // Previously seen count
    const seenOptions = [0, 5, 20, 50];
    const seenCount = seenOptions[Math.floor(i / (count / seenOptions.length)) % seenOptions.length];

    // Genre preference
    const genrePref = GENRE_PREFS[i % GENRE_PREFS.length];

    // Age group
    const ageGroup = AGE_GROUPS[i % AGE_GROUPS.length];

    // Session count (interaction points)
    const sessionOptions = [0, 15, 60]; // first=tier1, 5th=tier2, 20th=tier3
    const interactionPoints = sessionOptions[i % sessionOptions.length];

    // Requires series
    const requiresSeries = (i % 10 === 9); // 10% of personas want series

    // Recommendation style
    const styles = ['safe', 'balanced', 'adventurous'];
    const style = styles[i % styles.length];

    personas.push({
      id: `persona_${String(i).padStart(4, '0')}`,
      mood,
      moodMapping: mapping,
      runtimeWindow,
      platforms,
      preferredLanguages: languages,
      seenCount,
      genrePreference: genrePref,
      ageGroup,
      interactionPoints,
      requiresSeries,
      recommendationStyle: style,
      intentTags: mapping.compatibleTags.length > 0 ? mapping.compatibleTags : ['safe_bet', 'feel_good'],
      tagWeights: {},
      excludedIds: new Set(),
    });
  }
  return personas;
}

// ---- Invariant Checks ----
function checkInvariants(persona, recommendations, movies) {
  const results = {
    nonRepetition: { pass: true, details: '' },
    moodAccuracy: { pass: true, details: '' },
    platformAvailability: { pass: true, details: '' },
    qualityFloor: { pass: true, details: '' },
    diversity: { pass: true, details: '' },
    languageMatch: { pass: true, details: '' },
    coldStart: { pass: true, details: '' },
    veteranUser: { pass: true, details: '' },
    responseDeterminism: { pass: true, details: '' },
    noNullResults: { pass: true, details: '' },
  };

  // 1. Non-repetition: no duplicate movies in recommendations
  const ids = recommendations.map(r => r.id);
  const unique = new Set(ids);
  if (unique.size !== ids.length) {
    results.nonRepetition = {
      pass: false,
      details: `${ids.length - unique.size} duplicate(s) found in ${ids.length} recommendations`,
    };
  }

  // 2. Mood accuracy: check recommendations match mood profile
  if (persona.moodMapping && persona.moodMapping.moodKey !== 'surprise_me') {
    let moodMismatches = 0;
    for (const rec of recommendations) {
      if (!passesMoodFilter(rec, persona.moodMapping, persona.intentTags)) {
        moodMismatches++;
      }
    }
    // Allow dimensional fallback: check tag overlap instead
    if (moodMismatches > 0) {
      let tagMismatches = 0;
      for (const rec of recommendations) {
        const movieTags = new Set(rec.tags);
        const hasMoodTag = persona.intentTags.some(t => movieTags.has(t));
        if (!hasMoodTag && !passesMoodFilter(rec, persona.moodMapping, persona.intentTags)) {
          tagMismatches++;
        }
      }
      if (tagMismatches > recommendations.length * 0.3) {
        results.moodAccuracy = {
          pass: false,
          details: `${tagMismatches}/${recommendations.length} recs have no mood match (mood: ${persona.mood})`,
        };
      }
    }
  }

  // 3. Platform availability: all recs on user's platform(s)
  for (const rec of recommendations) {
    if (!platformMatches(rec.platforms, persona.platforms)) {
      results.platformAvailability = {
        pass: false,
        details: `"${rec.title}" not on user platforms [${persona.platforms}], has [${rec.platforms}]`,
      };
      break;
    }
  }

  // 4. Quality floor: TMDB/goodscore >= 6.0 (on 0-10 scale)
  for (const rec of recommendations) {
    const rating = normalizedRating(rec);
    if (rating < 6.0) {
      results.qualityFloor = {
        pass: false,
        details: `"${rec.title}" score ${rating.toFixed(1)} < 6.0`,
      };
      break;
    }
  }

  // 5. Diversity: not more than 3 movies from same PRIMARY genre in top 10
  const genreCounts = {};
  for (const rec of recommendations) {
    const primaryGenre = (rec.genres[0] || '').toLowerCase();
    if (primaryGenre) {
      genreCounts[primaryGenre] = (genreCounts[primaryGenre] || 0) + 1;
    }
  }
  for (const [genre, count] of Object.entries(genreCounts)) {
    if (count > 3 && recommendations.length >= 5) {
      results.diversity = {
        pass: false,
        details: `Primary genre "${genre}" appears ${count} times in ${recommendations.length} recs`,
      };
      break;
    }
  }

  // 6. Language match: recs match user's language preferences
  for (const rec of recommendations) {
    if (!languageMatches(rec.language, persona.preferredLanguages)) {
      results.languageMatch = {
        pass: false,
        details: `"${rec.title}" lang="${rec.language}" not in [${persona.preferredLanguages}]`,
      };
      break;
    }
  }

  // 7. Cold start: first-time user (0 seen) still gets recs
  if (persona.seenCount === 0) {
    if (recommendations.length < RECS_PER_PERSONA) {
      // Not a hard fail if we got at least 5
      if (recommendations.length < 5) {
        results.coldStart = {
          pass: false,
          details: `Cold start user got only ${recommendations.length} recs (need >= 5)`,
        };
      }
    }
  }

  // 8. Veteran user: 50 seen movies still gets recs they haven't seen
  if (persona.seenCount >= 50) {
    if (recommendations.length < RECS_PER_PERSONA && recommendations.length < 5) {
      results.veteranUser = {
        pass: false,
        details: `Veteran user (${persona.seenCount} seen) got only ${recommendations.length} recs`,
      };
    }
  }

  // 9. Response determinism: same profile run twice with same seed yields same top result
  const profile = {
    ...persona,
    excludedIds: new Set(),
  };
  const det1 = recommendDeterministic(movies, profile, 42);
  const det2 = recommendDeterministic(movies, profile, 42);
  if (det1 && det2 && det1.id !== det2.id) {
    results.responseDeterminism = {
      pass: false,
      details: `Deterministic mismatch: "${det1.title}" vs "${det2.title}"`,
    };
  }

  // 10. No null results: every persona gets at least 5 recs
  if (recommendations.length < 5) {
    results.noNullResults = {
      pass: false,
      details: `Only ${recommendations.length} recs (need >= 5). mood=${persona.mood}, lang=[${persona.preferredLanguages}], platform=[${persona.platforms}]`,
    };
  }

  return results;
}

// ---- Report Generator ----
function generateReport(allResults, startTime) {
  const endTime = Date.now();
  const duration = ((endTime - startTime) / 1000).toFixed(1);
  const date = new Date().toISOString().split('T')[0];

  const invariantNames = [
    'nonRepetition', 'moodAccuracy', 'platformAvailability', 'qualityFloor',
    'diversity', 'languageMatch', 'coldStart', 'veteranUser',
    'responseDeterminism', 'noNullResults',
  ];

  const invariantLabels = {
    nonRepetition: 'Non-repetition',
    moodAccuracy: 'Mood accuracy',
    platformAvailability: 'Platform availability',
    qualityFloor: 'Quality floor (>= 6.0)',
    diversity: 'Genre diversity (<= 3/genre)',
    languageMatch: 'Language match',
    coldStart: 'Cold start (>= 5 recs)',
    veteranUser: 'Veteran user (>= 5 recs)',
    responseDeterminism: 'Response determinism',
    noNullResults: 'No null results (>= 5)',
  };

  const severity = {
    nonRepetition: 'CRITICAL',
    moodAccuracy: 'WARN',
    platformAvailability: 'CRITICAL',
    qualityFloor: 'CRITICAL',
    diversity: 'WARN',
    languageMatch: 'CRITICAL',
    coldStart: 'CRITICAL',
    veteranUser: 'WARN',
    responseDeterminism: 'WARN',
    noNullResults: 'CRITICAL',
  };

  // Tally results
  const totals = {};
  for (const name of invariantNames) {
    totals[name] = { pass: 0, fail: 0, failures: [] };
  }

  for (const { persona, results } of allResults) {
    for (const name of invariantNames) {
      if (results[name].pass) {
        totals[name].pass++;
      } else {
        totals[name].fail++;
        totals[name].failures.push({ persona, details: results[name].details });
      }
    }
  }

  const total = allResults.length;

  // Compute pass rates
  const passRates = {};
  let criticalFailures = 0;
  let warnings = 0;
  let allCriticalAbove90 = true;

  for (const name of invariantNames) {
    const rate = ((totals[name].pass / total) * 100).toFixed(1);
    passRates[name] = rate;
    if (severity[name] === 'CRITICAL' && totals[name].fail > 0) {
      criticalFailures += totals[name].fail;
      if (parseFloat(rate) < 90) allCriticalAbove90 = false;
    }
    if (severity[name] === 'WARN' && totals[name].fail > 0) {
      warnings += totals[name].fail;
    }
  }

  const overallPassRate = (
    (invariantNames.reduce((sum, name) => sum + totals[name].pass, 0) /
     (total * invariantNames.length)) * 100
  ).toFixed(1);

  const verdict = allCriticalAbove90 ? 'GO' : 'NO-GO';

  // Mood failure rates
  const moodFailures = {};
  for (const { persona, results } of allResults) {
    const mood = persona.mood;
    if (!moodFailures[mood]) moodFailures[mood] = { total: 0, fails: 0 };
    moodFailures[mood].total++;
    const anyFail = invariantNames.some(n => !results[n].pass);
    if (anyFail) moodFailures[mood].fails++;
  }
  const moodRanked = Object.entries(moodFailures)
    .map(([mood, d]) => ({ mood, rate: ((d.fails / d.total) * 100).toFixed(1), fails: d.fails, total: d.total }))
    .sort((a, b) => parseFloat(b.rate) - parseFloat(a.rate));

  // Platform failure rates
  const platformFailures = {};
  for (const { persona, results } of allResults) {
    const pKey = persona.platforms.sort().join('+');
    if (!platformFailures[pKey]) platformFailures[pKey] = { total: 0, fails: 0 };
    platformFailures[pKey].total++;
    const anyFail = invariantNames.some(n => !results[n].pass);
    if (anyFail) platformFailures[pKey].fails++;
  }
  const platRanked = Object.entries(platformFailures)
    .map(([plat, d]) => ({ platform: plat, rate: ((d.fails / d.total) * 100).toFixed(1), fails: d.fails, total: d.total }))
    .sort((a, b) => parseFloat(b.rate) - parseFloat(a.rate));

  // Build report
  let report = `# GoodWatch 1000-Persona QA Report
Generated: ${date}
Duration: ${duration}s

## OVERALL VERDICT: ${verdict}

## Summary
- Total personas tested: ${total}
- Overall pass rate: ${overallPassRate}%
- Critical failures: ${criticalFailures}
- Warnings: ${warnings}

## Invariant Results
| Invariant | Pass Rate | Failures | Severity |
|-----------|-----------|----------|----------|
`;

  for (const name of invariantNames) {
    report += `| ${invariantLabels[name]} | ${passRates[name]}% | ${totals[name].fail} | ${severity[name]} |\n`;
  }

  // Critical Failures
  report += `\n## Critical Failures (blockers for launch)\n`;
  const critInvariants = invariantNames.filter(n => severity[n] === 'CRITICAL' && totals[n].fail > 0);
  if (critInvariants.length === 0) {
    report += `None - all CRITICAL invariants passing.\n`;
  } else {
    for (const name of critInvariants) {
      report += `\n### ${invariantLabels[name]} (${totals[name].fail} failures)\n`;
      const samples = totals[name].failures.slice(0, 5);
      for (const s of samples) {
        report += `- **${s.persona.id}** [mood=${s.persona.mood}, lang=${s.persona.preferredLanguages}, platform=${s.persona.platforms}]: ${s.details}\n`;
      }
      if (totals[name].failures.length > 5) {
        report += `- ... and ${totals[name].failures.length - 5} more\n`;
      }
    }
  }

  // Top 10 Worst Performing Moods
  report += `\n## Top 10 Worst Performing Moods\n`;
  report += `| Rank | Mood | Failure Rate | Failures / Total |\n`;
  report += `|------|------|-------------|------------------|\n`;
  for (let i = 0; i < Math.min(moodRanked.length, 10); i++) {
    const m = moodRanked[i];
    report += `| ${i + 1} | ${m.mood} | ${m.rate}% | ${m.fails}/${m.total} |\n`;
  }

  // Top 10 Worst Performing Platforms
  report += `\n## Top 10 Worst Performing Platforms\n`;
  report += `| Rank | Platform | Failure Rate | Failures / Total |\n`;
  report += `|------|----------|-------------|------------------|\n`;
  for (let i = 0; i < Math.min(platRanked.length, 10); i++) {
    const p = platRanked[i];
    report += `| ${i + 1} | ${p.platform} | ${p.rate}% | ${p.fails}/${p.total} |\n`;
  }

  // Sample Failures (5 examples per invariant)
  report += `\n## Sample Failures (up to 5 examples per invariant)\n`;
  for (const name of invariantNames) {
    if (totals[name].fail === 0) continue;
    report += `\n### ${invariantLabels[name]}\n`;
    const samples = totals[name].failures.slice(0, 5);
    for (const s of samples) {
      report += `- **${s.persona.id}** [mood=${s.persona.mood}, lang=[${s.persona.preferredLanguages}], platform=[${s.persona.platforms}], seen=${s.persona.seenCount}, series=${s.persona.requiresSeries}, style=${s.persona.recommendationStyle}]\n`;
      report += `  ${s.details}\n`;
    }
  }

  // Recommendations
  report += `\n## Recommendations\n`;
  const recs = [];

  // Analyze failures to suggest fixes
  if (totals.noNullResults.fail > 0) {
    // Check which combos produce nulls
    const nullProfiles = totals.noNullResults.failures.slice(0, 20);
    const langCounts = {};
    const platCounts = {};
    for (const f of nullProfiles) {
      const lKey = f.persona.preferredLanguages.sort().join('+');
      langCounts[lKey] = (langCounts[lKey] || 0) + 1;
      const pKey = f.persona.platforms.sort().join('+');
      platCounts[pKey] = (platCounts[pKey] || 0) + 1;
    }
    const worstLang = Object.entries(langCounts).sort((a, b) => b[1] - a[1])[0];
    const worstPlat = Object.entries(platCounts).sort((a, b) => b[1] - a[1])[0];
    if (worstLang) recs.push(`Expand catalog for ${worstLang[0]} language users (${worstLang[1]} null results)`);
    if (worstPlat) recs.push(`Improve coverage on ${worstPlat[0]} platform (${worstPlat[1]} null results)`);
  }

  if (totals.diversity.fail > 0) {
    recs.push(`Add genre diversity penalty to scoring to prevent >3 same-genre picks in top 10`);
  }

  if (totals.moodAccuracy.fail > 0) {
    const worstMood = moodRanked.find(m => m.fails > 0);
    if (worstMood) recs.push(`Review mood mapping for "${worstMood.mood}" - highest mismatch rate at ${worstMood.rate}%`);
  }

  if (totals.qualityFloor.fail > 0) {
    recs.push(`Tighten adaptive quality gate floor - some movies below 6.0 rating are slipping through`);
  }

  if (recs.length === 0) recs.push('No critical fixes needed. Engine is performing well.');

  for (let i = 0; i < Math.min(recs.length, 5); i++) {
    report += `${i + 1}. ${recs[i]}\n`;
  }

  // GO / NO-GO Verdict
  report += `\n## GO / NO-GO Verdict\n`;
  if (verdict === 'GO') {
    report += `**GO** - All CRITICAL invariants are above 90% pass rate.\n`;
  } else {
    const failing = critInvariants.filter(n => parseFloat(passRates[n]) < 90);
    report += `**NO-GO** - The following CRITICAL invariants are below 90%:\n`;
    for (const name of failing) {
      report += `- ${invariantLabels[name]}: ${passRates[name]}%\n`;
    }
  }

  return report;
}

// ---- Main Execution ----
async function main() {
  const startTime = Date.now();
  console.log(`[QA] GoodWatch 1000-Persona QA Engine`);
  console.log(`[QA] ================================`);

  // Step 1: Fetch movies
  const rawMovies = await fetchMovies();
  const movies = rawMovies.map(toGWMovie);
  console.log(`[QA] Converted ${movies.length} movies to GWMovie format`);

  // Stats
  const available = movies.filter(m => m.available).length;
  const withEP = movies.filter(m => m.emotionalProfile != null).length;
  const withPlatforms = movies.filter(m => m.platforms.length > 0).length;
  console.log(`[QA] Available: ${available}, With emotional_profile: ${withEP}, With platforms: ${withPlatforms}`);

  // Step 2: Generate personas
  const personas = generatePersonas(PERSONA_COUNT);
  console.log(`[QA] Generated ${personas.length} personas`);

  // For veteran users, simulate seen movies by marking random IDs as excluded
  const availableMovieIds = movies.filter(m => m.available).map(m => m.id);
  for (const persona of personas) {
    if (persona.seenCount > 0) {
      const shuffled = [...availableMovieIds].sort(() => Math.random() - 0.5);
      const seen = shuffled.slice(0, Math.min(persona.seenCount, shuffled.length));
      persona.excludedIds = new Set(seen);
    }
  }

  // Step 3: Run each persona
  console.log(`[QA] Running ${PERSONA_COUNT} personas x ${RECS_PER_PERSONA} recs each...`);
  const allResults = [];
  let progress = 0;

  for (const persona of personas) {
    const recs = generateRecommendations(movies, persona, RECS_PER_PERSONA);
    const results = checkInvariants(persona, recs, movies);
    allResults.push({ persona, results, recCount: recs.length });

    progress++;
    if (progress % 100 === 0) {
      console.log(`[QA] Progress: ${progress}/${PERSONA_COUNT}`);
    }
  }

  console.log(`[QA] All personas completed`);

  // Step 4: Generate report
  const report = generateReport(allResults, startTime);

  // Write report
  const reportPath = join(__dirname, 'QA_REPORT.md');
  writeFileSync(reportPath, report);
  console.log(`[QA] Report written to ${reportPath}`);

  // Print report to stdout
  console.log('\n' + report);

  // Exit with appropriate code
  const hasNogo = report.includes('## GO / NO-GO Verdict\n**NO-GO**');
  process.exit(hasNogo ? 1 : 0);
}

main().catch(err => {
  console.error('[QA] Fatal error:', err);
  process.exit(2);
});
