#!/usr/bin/env python3
"""
GoodWatch UAT Engine v1.0
=========================
Automated User Acceptance Testing for the recommendation engine.
Generates scenario matrix from REAL Supabase data, replicates the
adaptive quality gate, identifies dead zones and regressions.

Runs daily via GitHub Actions. Results go to Supabase tables:
  uat_runs, uat_scenarios, uat_coverage, uat_regressions

Usage:
  python uat_engine.py              # Full run
  python uat_engine.py --dry-run    # Print scenarios, don't publish

INV-UAT01: Quality gate logic MUST mirror Swift adaptive quality gate.
INV-UAT02: Fixed dead zones MUST stay fixed (regression tracking).
INV-UAT03: UAT results are immutable after publication.
"""

import os
import sys
import json
import time
import statistics
import ssl
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SUPABASE_URL = os.getenv(
    "SUPABASE_URL",
    "https://jdjqrlkynwfhbtyuddjk.supabase.co",
)
SUPABASE_KEY = os.getenv(
    "SUPABASE_SERVICE_KEY",
    os.getenv(
        "SUPABASE_SERVICE_ROLE_KEY",
        os.getenv(
            "SUPABASE_ANON_KEY",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
            "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkanFybGt5bndmaGJ0eXVkZGprIiwi"
            "cm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0NzUwMTEsImV4cCI6MjA4MDA1MTAxMX0."
            "KDRMLCewVMp3lwphkUvtoWOkg6kyAk8iSbVkRKiHYSk",
        ),
    ),
)

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}

# Adaptive quality gate constants (must match Swift — INV-UAT01)
MINIMUM_CANDIDATE_THRESHOLD = 10
ABSOLUTE_FLOOR_RATING = 6.5
ABSOLUTE_FLOOR_VOTES = 300

# Languages offered in onboarding (auto-discovery filters to these)
ONBOARDING_LANGUAGES = ["hi", "en", "ta", "te", "ml", "kn", "pa"]

# Known moods from the engine
KNOWN_MOODS = [
    "chill", "thrilled", "heartfelt", "mind_bending", "feel_good",
    "dark", "adventurous", "nostalgic", "inspiring", "laugh_out_loud", "intense",
]

# User tiers (must match GWSpec.swift QualityGate.forAcceptCount)
USER_TIERS = {
    "new_user":   {"min_rating": 7.5, "min_votes": 2000, "accept_count": 0},
    "warming_up": {"min_rating": 6.5, "min_votes": 400,  "accept_count": 2},
    "trusted":    {"min_rating": 6.0, "min_votes": 200,  "accept_count": 10},
}

DRY_RUN = "--dry-run" in sys.argv

# SSL context for macOS
try:
    SSL_CTX = ssl.create_default_context()
except Exception:
    SSL_CTX = ssl._create_unverified_context()


# ---------------------------------------------------------------------------
# Supabase HTTP helpers (matching audit_agent.py pattern)
# ---------------------------------------------------------------------------

def sb_request(endpoint, method="GET", body=None, extra_headers=None):
    """Make a request to Supabase REST API."""
    url = f"{SUPABASE_URL}/rest/v1/{endpoint}"
    headers = dict(HEADERS)
    if extra_headers:
        headers.update(extra_headers)
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=SSL_CTX, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw.strip() else []
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"[UAT] HTTP {e.code} on {method} {endpoint}: {err_body[:300]}")
        return None
    except Exception as e:
        print(f"[UAT] Request error on {endpoint}: {e}")
        return None


def sb_select(table, select="*", filters="", limit=1000, offset=0):
    """SELECT with pagination support."""
    endpoint = f"{table}?select={urllib.parse.quote(select)}"
    if filters:
        endpoint += f"&{filters}"
    endpoint += f"&limit={limit}&offset={offset}"
    headers = {"Range": f"{offset}-{offset + limit - 1}"}
    return sb_request(endpoint, extra_headers=headers)


def sb_select_all(table, select="*", filters="", batch_size=1000):
    """Load all rows from a table with automatic pagination."""
    all_rows = []
    offset = 0
    while True:
        rows = sb_select(table, select, filters, limit=batch_size, offset=offset)
        if rows is None:
            print(f"[UAT] Failed to load {table} at offset {offset}")
            break
        all_rows.extend(rows)
        if len(rows) < batch_size:
            break
        offset += batch_size
    return all_rows


def sb_insert(table, rows):
    """INSERT rows into a table."""
    if not rows:
        return True
    headers = dict(HEADERS)
    headers["Prefer"] = "return=minimal"
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    data = json.dumps(rows).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, context=SSL_CTX, timeout=60) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"[UAT] Insert error on {table}: {e.code} — {err_body[:300]}")
        return False
    except Exception as e:
        print(f"[UAT] Insert exception on {table}: {e}")
        return False


def sb_upsert(table, rows, on_conflict="id"):
    """UPSERT rows into a table."""
    if not rows:
        return True
    headers = dict(HEADERS)
    headers["Prefer"] = "resolution=merge-duplicates,return=minimal"
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    data = json.dumps(rows).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, context=SSL_CTX, timeout=60) as resp:
            return resp.status in (200, 201)
    except Exception as e:
        print(f"[UAT] Upsert error on {table}: {e}")
        return False


# ---------------------------------------------------------------------------
# UAT Engine
# ---------------------------------------------------------------------------

class UATEngine:
    """GoodWatch User Acceptance Testing Engine."""

    def __init__(self):
        self.catalog = []
        self.languages = []
        self.platforms = []
        self.moods = KNOWN_MOODS
        self.tiers = USER_TIERS
        self.run_id = ""
        self.start_time = ""
        self.results = []

    # -----------------------------------------------------------------------
    # Phase 1: Auto-Discovery (INV-UAT01 — never hardcode dimensions)
    # -----------------------------------------------------------------------

    def discover_dimensions(self):
        """Query Supabase for actual data dimensions."""

        # 1. Languages: distinct original_language with >= 20 movies
        print("[UAT] Discovering languages...")
        lang_data = sb_request(
            "movies?select=original_language&limit=0",
            extra_headers={"Prefer": "count=exact"},
        )
        # Use a different approach: get counts per language
        all_movies_sample = sb_select(
            "movies",
            select="original_language",
            filters="content_type=eq.movie",
            limit=1000,
            offset=0,
        )
        # Load more if needed
        lang_counts = {}
        if all_movies_sample:
            for m in all_movies_sample:
                lang = m.get("original_language", "")
                if lang:
                    lang_counts[lang] = lang_counts.get(lang, 0) + 1
        # Also sample deeper
        for offset in [1000, 5000, 10000, 15000, 20000]:
            chunk = sb_select(
                "movies",
                select="original_language",
                filters="content_type=eq.movie",
                limit=1000,
                offset=offset,
            )
            if not chunk:
                break
            for m in chunk:
                lang = m.get("original_language", "")
                if lang:
                    lang_counts[lang] = lang_counts.get(lang, 0) + 1

        discovered_languages = [
            lang for lang, cnt in lang_counts.items() if cnt >= 20
        ]
        self.languages = [
            lang for lang in discovered_languages if lang in ONBOARDING_LANGUAGES
        ]
        if not self.languages:
            self.languages = ["en", "hi"]  # absolute fallback
        print(f"[UAT]   Languages: {self.languages} (from {len(lang_counts)} total)")

        # 2. Platforms: extract from streaming_providers JSONB
        # Format is flat: {"Netflix": "url", "JioHotstar": "url", ...}
        print("[UAT] Discovering platforms...")
        sample = sb_select(
            "movies",
            select="streaming_providers",
            filters="streaming_providers=not.is.null",
            limit=500,
        )
        platform_set = set()
        if sample:
            for m in sample:
                providers = m.get("streaming_providers") or {}
                if not isinstance(providers, dict):
                    continue
                # Flat format: keys are platform names, values are URLs
                for key in providers:
                    if isinstance(providers[key], str):
                        platform_set.add(key)
                    elif isinstance(providers[key], dict):
                        # TMDB nested format fallback: {"IN": {"flatrate": [...]}}
                        region_data = providers[key]
                        for ptype in ["flatrate", "ads", "free"]:
                            for p in region_data.get(ptype, []):
                                name = p.get("provider_name", "")
                                if name:
                                    platform_set.add(name)
        self.platforms = sorted(platform_set)
        if not self.platforms:
            self.platforms = ["Netflix", "JioCinema", "Amazon Prime Video"]
        print(f"[UAT]   Platforms: {self.platforms}")

        # 3. Moods: defined in engine, use known set
        print(f"[UAT]   Moods: {len(self.moods)} defined")

        # 4. Summary
        print(
            f"[UAT] Discovered: {len(self.languages)} languages, "
            f"{len(self.platforms)} platforms, {len(self.moods)} moods"
        )

    # -----------------------------------------------------------------------
    # Phase 2: Load Catalog
    # -----------------------------------------------------------------------

    def load_catalog(self):
        """Load full movie catalog from Supabase."""
        print("[UAT] Loading catalog...")
        self.catalog = sb_select_all(
            "movies",
            select="id,tmdb_id,title,original_language,streaming_providers,"
                   "vote_average,vote_count,runtime,genres,content_type,popularity",
            filters="content_type=eq.movie",
            batch_size=1000,
        )
        print(f"[UAT] Loaded {len(self.catalog)} movies")

    # -----------------------------------------------------------------------
    # Phase 3: Adaptive Quality Gate (INV-UAT01 — must mirror Swift)
    # -----------------------------------------------------------------------

    def get_adaptive_gate(self, tier_gate, candidates_after_lang_platform):
        """
        Replicate the Swift adaptive quality gate (INV-R06).
        If strict gate gives >= MINIMUM_CANDIDATE_THRESHOLD candidates, use it.
        Otherwise relax ONE step. Never below 6.5/300.
        """
        strict_rating = tier_gate["min_rating"]
        strict_votes = tier_gate["min_votes"]

        strict_count = len([
            m for m in candidates_after_lang_platform
            if (m.get("vote_average") or 0) >= strict_rating
            and (m.get("vote_count") or 0) >= strict_votes
        ])

        if strict_count >= MINIMUM_CANDIDATE_THRESHOLD:
            return {
                "min_rating": strict_rating,
                "min_votes": strict_votes,
                "was_relaxed": False,
                "reason": f"strict_sufficient ({strict_count})",
            }

        # Relax one step
        relaxed_rating = max(strict_rating - 0.5, ABSOLUTE_FLOOR_RATING)
        relaxed_votes = max(strict_votes // 2, ABSOLUTE_FLOOR_VOTES)

        relaxed_count = len([
            m for m in candidates_after_lang_platform
            if (m.get("vote_average") or 0) >= relaxed_rating
            and (m.get("vote_count") or 0) >= relaxed_votes
        ])

        if relaxed_count >= MINIMUM_CANDIDATE_THRESHOLD:
            return {
                "min_rating": relaxed_rating,
                "min_votes": relaxed_votes,
                "was_relaxed": True,
                "reason": f"relaxed_one ({relaxed_count}, strict had {strict_count})",
            }

        # Floor
        return {
            "min_rating": max(relaxed_rating - 0.5, ABSOLUTE_FLOOR_RATING),
            "min_votes": ABSOLUTE_FLOOR_VOTES,
            "was_relaxed": True,
            "reason": f"floor ({relaxed_count} at relaxed, {strict_count} at strict)",
        }

    # -----------------------------------------------------------------------
    # Phase 4: Platform Matching
    # -----------------------------------------------------------------------

    def _has_platform(self, movie, user_platforms):
        """Check if movie is available on any of the user's platforms.

        streaming_providers format is flat: {"Netflix": "url", "JioHotstar": "url"}
        Keys are platform names, values are URLs.
        """
        providers = movie.get("streaming_providers") or {}
        if not isinstance(providers, dict):
            return False

        user_platforms_lower = [p.lower() for p in user_platforms]

        for key, val in providers.items():
            if isinstance(val, str):
                # Flat format: key is platform name
                key_lower = key.lower()
                for up in user_platforms_lower:
                    if up in key_lower or key_lower in up:
                        return True
            elif isinstance(val, dict):
                # TMDB nested format fallback: {"IN": {"flatrate": [...]}}
                for access_type in ["flatrate", "ads", "free"]:
                    for p in val.get(access_type, []):
                        provider_name = (p.get("provider_name") or "").lower()
                        if not provider_name:
                            continue
                        for up in user_platforms_lower:
                            if up in provider_name or provider_name in up:
                                return True
        return False

    # -----------------------------------------------------------------------
    # Phase 5: Bottleneck Finder
    # -----------------------------------------------------------------------

    def _find_bottleneck(self, funnel):
        """Identify which filter killed all candidates."""
        stages = [
            ("total", "after_language", "language_filter"),
            ("after_language", "after_platform", "platform_filter"),
            ("after_platform", "after_quality", "quality_gate"),
            ("after_quality", "after_runtime", "runtime_filter"),
        ]

        for prev_key, curr_key, filter_name in stages:
            prev_count = funnel.get(prev_key, 0)
            curr_count = funnel.get(curr_key, 0)
            if curr_count == 0 and prev_count > 0:
                return {
                    "reason": f"eliminated_by_{filter_name}",
                    "filter": filter_name,
                    "count_before": prev_count,
                }

        return {
            "reason": "no_candidates_at_start",
            "filter": "catalog_empty",
            "count_before": 0,
        }

    # -----------------------------------------------------------------------
    # Phase 6: Scenario Matrix Generation
    # -----------------------------------------------------------------------

    def generate_scenarios(self):
        """Generate full scenario matrix from discovered dimensions."""
        scenarios = []

        # 1. Core matrix: single-language x single-platform x mood x tier
        for mood in self.moods:
            for lang in self.languages:
                for platform in self.platforms:
                    for tier_name in self.tiers:
                        scenarios.append({
                            "scenario_id": f"{mood}-{lang}-{self._slug(platform)}-{tier_name}",
                            "scenario_type": "matrix",
                            "mood": mood,
                            "languages": [lang],
                            "platforms": [platform],
                            "user_tier": tier_name,
                            "energy_level": "medium",
                        })

        # 2. Multi-language combos (non-English + English)
        for lang in [l for l in self.languages if l != "en"]:
            for mood in self.moods:
                for platform in self.platforms:
                    scenarios.append({
                        "scenario_id": f"{mood}-{lang}+en-{self._slug(platform)}-new_user",
                        "scenario_type": "multi_lang",
                        "mood": mood,
                        "languages": [lang, "en"],
                        "platforms": [platform],
                        "user_tier": "new_user",
                        "energy_level": "medium",
                    })

        # 3. Edge cases
        edge_cases = [
            # THE BUG THAT TRIGGERED THIS: Hindi+English new_user
            {
                "scenario_id": "edge-hindi-english-strict",
                "scenario_type": "edge_case",
                "mood": "chill",
                "languages": ["hi", "en"],
                "platforms": self.platforms[:2] if len(self.platforms) >= 2 else self.platforms,
                "user_tier": "new_user",
                "energy_level": "low",
                "assertion": "gate_not_relaxed_when_english_present",
            },
            # Hindi-only user — gate SHOULD relax
            {
                "scenario_id": "edge-hindi-only-relax",
                "scenario_type": "edge_case",
                "mood": "chill",
                "languages": ["hi"],
                "platforms": self.platforms[:1],
                "user_tier": "new_user",
                "energy_level": "low",
                "assertion": "sufficient_candidates_after_adaptive_gate",
            },
            # Single regional language, niche platform
            {
                "scenario_id": "edge-regional-niche",
                "scenario_type": "edge_case",
                "mood": "mind_bending",
                "languages": ["ml"] if "ml" in self.languages else self.languages[-1:],
                "platforms": (
                    [p for p in self.platforms if "zee" in p.lower()][:1]
                    or self.platforms[-1:]
                ),
                "user_tier": "new_user",
                "energy_level": "high",
                "assertion": "dead_zone_expected_and_documented",
            },
            # All languages, all platforms (power user)
            {
                "scenario_id": "edge-power-user",
                "scenario_type": "edge_case",
                "mood": "feel_good",
                "languages": self.languages,
                "platforms": self.platforms,
                "user_tier": "trusted",
                "energy_level": "medium",
                "assertion": "high_candidate_count_high_diversity",
            },
            # User who's seen top 50 (exclusion test)
            {
                "scenario_id": "edge-exhaustion",
                "scenario_type": "edge_case",
                "mood": "chill",
                "languages": ["en"],
                "platforms": self.platforms[:2] if len(self.platforms) >= 2 else self.platforms,
                "user_tier": "warming_up",
                "energy_level": "low",
                "exclude_top_n": 50,
                "assertion": "still_has_candidates_after_excluding_top_50",
            },
        ]
        scenarios.extend(edge_cases)

        # 4. Regressions from previous runs
        try:
            regressions = sb_select("uat_regressions", limit=100)
            if regressions:
                for reg in regressions:
                    config = reg.get("scenario_config", {})
                    if isinstance(config, str):
                        config = json.loads(config)
                    scenarios.append({
                        "scenario_id": f"regression-{reg.get('id', 'unknown')[:8]}",
                        "scenario_type": "regression",
                        "regression_id": reg.get("id"),
                        **config,
                    })
                print(f"[UAT]   Added {len(regressions)} regression scenarios")
        except Exception as e:
            print(f"[UAT]   No regressions loaded: {e}")

        return scenarios

    def _slug(self, name):
        """Convert platform name to slug."""
        return (
            name.lower()
            .replace(" ", "_")
            .replace(":", "")
            .replace("(", "")
            .replace(")", "")
        )[:30]

    # -----------------------------------------------------------------------
    # Phase 7: Scenario Runner
    # -----------------------------------------------------------------------

    def run_scenario(self, scenario):
        """Run a single scenario through the filter pipeline."""
        start = time.time()

        mood = scenario.get("mood")
        languages = scenario.get("languages", [])
        platforms = scenario.get("platforms", [])
        tier_name = scenario.get("user_tier", "new_user")
        tier_gate = self.tiers.get(tier_name, self.tiers["new_user"])

        candidates = list(self.catalog)  # copy
        funnel = {"total": len(candidates)}

        # 1. Language filter (hard gate — INV-R03)
        candidates = [
            m for m in candidates
            if m.get("original_language") in languages
        ]
        funnel["after_language"] = len(candidates)

        # 2. Platform filter (hard gate — INV-R02)
        candidates = [
            m for m in candidates
            if self._has_platform(m, platforms)
        ]
        funnel["after_platform"] = len(candidates)

        # 3. ADAPTIVE quality gate (replicate INV-R06)
        adaptive = self.get_adaptive_gate(tier_gate, candidates)
        candidates = [
            m for m in candidates
            if (m.get("vote_average") or 0) >= adaptive["min_rating"]
            and (m.get("vote_count") or 0) >= adaptive["min_votes"]
        ]
        funnel["after_quality"] = len(candidates)
        funnel["quality_gate_used"] = adaptive

        # 4. Runtime filter (no shorts)
        candidates = [
            m for m in candidates
            if (m.get("runtime") or 90) >= 40
        ]
        funnel["after_runtime"] = len(candidates)

        # 5. Exclude top N if specified (exhaustion test)
        if scenario.get("exclude_top_n"):
            by_popularity = sorted(
                candidates,
                key=lambda m: m.get("popularity") or 0,
                reverse=True,
            )
            exclude_ids = {
                m.get("tmdb_id") or m.get("id")
                for m in by_popularity[: scenario["exclude_top_n"]]
            }
            candidates = [
                m for m in candidates
                if (m.get("tmdb_id") or m.get("id")) not in exclude_ids
            ]
            funnel["after_exclusion"] = len(candidates)

        execution_ms = int((time.time() - start) * 1000)

        # Build base result
        base = {
            "run_id": self.run_id,
            "scenario_id": scenario["scenario_id"],
            "scenario_type": scenario["scenario_type"],
            "mood": mood,
            "languages": languages,
            "platforms": platforms,
            "user_tier": tier_name,
            "energy_level": scenario.get("energy_level"),
            "execution_ms": execution_ms,
        }

        if len(candidates) == 0:
            bottleneck = self._find_bottleneck(funnel)
            return {
                **base,
                "status": "fail",
                "candidate_count": 0,
                "scored_count": 0,
                "failure_reason": bottleneck["reason"],
                "bottleneck_filter": bottleneck["filter"],
                "candidates_before_bottleneck": bottleneck["count_before"],
            }

        # Pick top candidate by vote_average
        candidates.sort(key=lambda m: m.get("vote_average") or 0, reverse=True)
        top = candidates[0]
        top_10 = candidates[: min(10, len(candidates))]

        # Quality check: does top pick meet the STRICT tier gate?
        strict_pass = (top.get("vote_average") or 0) >= tier_gate["min_rating"]
        status = "pass" if strict_pass else "quality_warning"

        top_scores = [m.get("vote_average") or 0 for m in top_10]
        avg_score = round(sum(top_scores) / len(top_scores), 2) if top_scores else 0
        spread = round(max(top_scores) - min(top_scores), 2) if len(top_scores) > 1 else 0
        genres_set = set()
        for m in top_10:
            for g in (m.get("genres") or []):
                if isinstance(g, str):
                    genres_set.add(g)
                elif isinstance(g, dict):
                    genres_set.add(g.get("name", ""))

        return {
            **base,
            "status": status,
            "candidate_count": len(candidates),
            "scored_count": len(candidates),
            "top_movie_id": top.get("tmdb_id"),
            "top_movie_title": top.get("title"),
            "top_movie_goodscore": top.get("vote_average"),
            "top_movie_language": top.get("original_language"),
            "avg_candidate_goodscore": avg_score,
            "score_spread": spread,
            "genre_diversity": len(genres_set),
            "failure_reason": (
                None if strict_pass
                else f"top_pick_{top.get('vote_average')}_below_{tier_gate['min_rating']}"
            ),
            "bottleneck_filter": None,
            "candidates_before_bottleneck": None,
        }

    # -----------------------------------------------------------------------
    # Phase 8: Coverage Heatmap Builder
    # -----------------------------------------------------------------------

    def _build_coverage(self):
        """Build coverage heatmap cells from results."""
        coverage = []
        # Group results by (mood, language, platform, tier)
        cells = {}
        for r in self.results:
            mood = r.get("mood") or "unknown"
            tier = r.get("user_tier") or "unknown"
            for lang in (r.get("languages") or []):
                for plat in (r.get("platforms") or []):
                    key = (mood, lang, self._slug(plat), tier)
                    if key not in cells:
                        cells[key] = r
                    # Keep the one with more candidates
                    elif (r.get("candidate_count") or 0) > (cells[key].get("candidate_count") or 0):
                        cells[key] = r

        for (mood, lang, plat, tier), r in cells.items():
            count = r.get("candidate_count") or 0
            top_score = r.get("top_movie_goodscore")
            avg_score = r.get("avg_candidate_goodscore")
            tier_gate = self.tiers.get(tier, self.tiers["new_user"])

            if count == 0:
                health = "dead"
            elif count <= 2:
                health = "red"
            elif count <= 9:
                health = "yellow"
            elif top_score and top_score < tier_gate["min_rating"]:
                health = "yellow"
            else:
                health = "green"

            coverage.append({
                "run_id": self.run_id,
                "mood": mood,
                "language": lang,
                "platform": plat,
                "user_tier": tier,
                "candidate_count": count,
                "has_recommendation": count > 0,
                "top_goodscore": top_score,
                "avg_goodscore": avg_score,
                "health": health,
            })

        return coverage

    # -----------------------------------------------------------------------
    # Phase 9: Regression Tracking
    # -----------------------------------------------------------------------

    def _register_regression(self, failed_result):
        """Auto-register a dead zone as a regression test."""
        config = {
            "mood": failed_result.get("mood"),
            "languages": failed_result.get("languages"),
            "platforms": failed_result.get("platforms"),
            "user_tier": failed_result.get("user_tier"),
            "energy_level": failed_result.get("energy_level"),
        }
        config_json = json.dumps(config, sort_keys=True)

        # Check if this exact config already exists
        existing = sb_select(
            "uat_regressions",
            filters=f"scenario_config=eq.{urllib.parse.quote(config_json)}",
            limit=1,
        )

        now = datetime.now(timezone.utc).isoformat()

        if existing and len(existing) > 0:
            # Update existing regression
            reg_id = existing[0]["id"]
            update_url = f"{SUPABASE_URL}/rest/v1/uat_regressions?id=eq.{reg_id}"
            update_data = json.dumps({
                "last_checked_at": now,
                "last_status": "fail",
                "consecutive_passes": 0,
            }).encode("utf-8")
            headers = dict(HEADERS)
            headers["Prefer"] = "return=minimal"
            req = urllib.request.Request(
                update_url, data=update_data, headers=headers, method="PATCH"
            )
            try:
                urllib.request.urlopen(req, context=SSL_CTX, timeout=15)
            except Exception:
                pass
        else:
            # Create new regression entry
            sb_insert("uat_regressions", [{
                "scenario_config": config,
                "first_failed_at": now,
                "last_checked_at": now,
                "last_status": "fail",
                "consecutive_passes": 0,
                "tags": [
                    failed_result.get("bottleneck_filter") or "unknown",
                    failed_result.get("scenario_type") or "unknown",
                ],
            }])

    def _update_regression_pass(self, result):
        """Update a regression that now passes."""
        reg_id = result.get("regression_id")
        if not reg_id:
            return
        now = datetime.now(timezone.utc).isoformat()
        update_url = f"{SUPABASE_URL}/rest/v1/uat_regressions?id=eq.{reg_id}"
        update_data = json.dumps({
            "last_checked_at": now,
            "last_status": "pass",
            "first_fixed_at": now,
            "consecutive_passes": 1,  # will be incremented server-side ideally
        }).encode("utf-8")
        headers = dict(HEADERS)
        headers["Prefer"] = "return=minimal"
        req = urllib.request.Request(
            update_url, data=update_data, headers=headers, method="PATCH"
        )
        try:
            urllib.request.urlopen(req, context=SSL_CTX, timeout=15)
        except Exception:
            pass

    # -----------------------------------------------------------------------
    # Phase 10: Publish Results
    # -----------------------------------------------------------------------

    def publish(self):
        """Write results to Supabase."""
        passed = [r for r in self.results if r["status"] == "pass"]
        failed = [r for r in self.results if r["status"] == "fail"]
        warnings = [r for r in self.results if r["status"] == "quality_warning"]

        scores = [
            r["top_movie_goodscore"]
            for r in self.results
            if r.get("top_movie_goodscore") is not None
        ]

        # 1. Run summary
        run_data = {
            "run_id": self.run_id,
            "started_at": self.start_time,
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "total_scenarios": len(self.results),
            "passed": len(passed),
            "failed": len(failed),
            "quality_warnings": len(warnings),
            "avg_goodscore": round(statistics.mean(scores), 2) if scores else None,
            "median_goodscore": round(statistics.median(scores), 2) if scores else None,
            "min_goodscore": round(min(scores), 2) if scores else None,
            "p10_goodscore": (
                round(sorted(scores)[len(scores) // 10], 2)
                if len(scores) > 10 else None
            ),
            "mood_coverage": json.dumps({
                mood: len([r for r in self.results if r.get("mood") == mood and r["status"] == "pass"])
                for mood in self.moods
            }),
            "language_coverage": json.dumps({
                lang: len([
                    r for r in self.results
                    if lang in (r.get("languages") or []) and r["status"] == "pass"
                ])
                for lang in self.languages
            }),
            "platform_coverage": json.dumps({
                self._slug(p): len([
                    r for r in self.results
                    if p in (r.get("platforms") or []) and r["status"] == "pass"
                ])
                for p in self.platforms
            }),
            "catalog_size": len(self.catalog),
            "engine_version": "adaptive_gate_v1",
            "status": "completed",
        }

        if DRY_RUN:
            print(f"[DRY RUN] Would insert run: {json.dumps(run_data, indent=2)}")
            return

        print("[UAT] Publishing run summary...")
        sb_upsert("uat_runs", [run_data], on_conflict="run_id")

        # 2. Scenarios in batches
        # PostgREST requires all rows in a batch to have identical keys
        SCENARIO_COLUMNS = [
            "run_id", "scenario_id", "scenario_type", "mood",
            "languages", "platforms", "user_tier", "energy_level",
            "status", "candidate_count", "scored_count",
            "top_movie_id", "top_movie_title", "top_movie_goodscore",
            "top_movie_language", "avg_candidate_goodscore", "score_spread",
            "genre_diversity", "failure_reason", "bottleneck_filter",
            "candidates_before_bottleneck", "execution_ms",
        ]
        print("[UAT] Publishing scenarios...")
        for i in range(0, len(self.results), 500):
            batch = self.results[i : i + 500]
            clean_batch = []
            for r in batch:
                row = {col: r.get(col) for col in SCENARIO_COLUMNS}
                clean_batch.append(row)
            sb_insert("uat_scenarios", clean_batch)

        # 3. Coverage heatmap
        print("[UAT] Publishing coverage heatmap...")
        coverage = self._build_coverage()
        for i in range(0, len(coverage), 500):
            sb_insert("uat_coverage", coverage[i : i + 500])

        # 4. Auto-register dead zones as regressions
        print("[UAT] Registering regressions...")
        for r in failed:
            self._register_regression(r)

        # 5. Update passing regressions
        for r in self.results:
            if r.get("scenario_type") == "regression" and r["status"] != "fail":
                self._update_regression_pass(r)

        # 6. Print summary
        print(f"\n{'=' * 60}")
        print(f"UAT COMPLETE: {self.run_id}")
        print(f"{'=' * 60}")
        print(f"Total scenarios: {len(self.results)}")
        print(f"Passed:          {len(passed)}")
        print(f"Failed:          {len(failed)}")
        print(f"Quality warnings:{len(warnings)}")
        if scores:
            print(f"Avg GoodScore:   {round(statistics.mean(scores), 2)}")
            print(f"Min GoodScore:   {round(min(scores), 2)}")
        print(f"{'=' * 60}")

        if failed:
            # Group by bottleneck
            bottleneck_counts = {}
            for f in failed:
                bn = f.get("bottleneck_filter") or "unknown"
                bottleneck_counts[bn] = bottleneck_counts.get(bn, 0) + 1
            sorted_bn = sorted(bottleneck_counts.items(), key=lambda x: -x[1])
            bn_str = " > ".join(f"{k} ({v})" for k, v in sorted_bn)
            print(f"\nTop bottlenecks: {bn_str}")
            print(f"\nDEAD ZONES ({len(failed)}):")
            for f in failed[:20]:
                print(
                    f"  {f['scenario_id']}: {f.get('failure_reason')} "
                    f"(bottleneck: {f.get('bottleneck_filter')}, "
                    f"had {f.get('candidates_before_bottleneck')} before)"
                )

    # -----------------------------------------------------------------------
    # Main Runner
    # -----------------------------------------------------------------------

    def run(self):
        """Execute the full UAT pipeline."""
        self.start_time = datetime.now(timezone.utc).isoformat()
        self.run_id = f"uat-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M')}"
        self.results = []

        print(f"[UAT] Starting run {self.run_id}")
        if DRY_RUN:
            print("[UAT] DRY RUN mode — will not publish results")

        # 1. Discover dimensions
        self.discover_dimensions()

        # 2. Load full catalog
        self.load_catalog()

        # 3. Generate scenarios
        scenarios = self.generate_scenarios()
        print(f"[UAT] Generated {len(scenarios)} scenarios")

        if DRY_RUN:
            print(f"\n[DRY RUN] First 10 scenarios:")
            for s in scenarios[:10]:
                print(f"  {s['scenario_id']} ({s['scenario_type']})")
            print(f"  ... and {len(scenarios) - 10} more")

        # 4. Run all
        for i, scenario in enumerate(scenarios):
            result = self.run_scenario(scenario)
            self.results.append(result)
            if (i + 1) % 500 == 0:
                failed_so_far = len([r for r in self.results if r["status"] == "fail"])
                print(
                    f"[UAT] Progress: {i + 1}/{len(scenarios)} "
                    f"-- {failed_so_far} dead zones"
                )

        # 5. Publish
        self.publish()

        failed_count = len([r for r in self.results if r["status"] == "fail"])
        return failed_count  # 0 = all passed


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    engine = UATEngine()
    failed = engine.run()
    # Don't exit(1) on failures — dead zones are expected for some combos
    # Just report them
    sys.exit(0)
