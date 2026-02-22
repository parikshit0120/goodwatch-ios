# GoodWatch Product Invariants

> **Purpose:** Machine-verifiable rules that define what GoodWatch IS.
> Any code change that violates an invariant is **wrong by definition**, regardless of intent.
> Read this before modifying ANY code. If a change conflicts with an invariant, the invariant wins.

---

## How This File Works

1. Every invariant has an **ID** (e.g., `INV-R01`), a **plain-English rule**, and a **verification method**
2. Invariants are grouped by domain: **R**ecommendation, **U**X/Journey, **D**ata, **L**earning
3. Each invariant maps to one or more **automated tests** in `GWProductInvariantTests.swift`
4. Before committing code, run: `xcodebuild test -project GoodWatch.xcodeproj -scheme GoodWatch -destination 'platform=iOS Simulator,id=EBB73CAE-3A8E-4D68-A90A-C3319BC9D678' -only-testing:GoodWatchTests/GWProductInvariantTests 2>&1 | tail -30`

---

## RECOMMENDATION ENGINE INVARIANTS

### INV-R01: Single Movie Output (Core Pipeline)
**Rule:** The core recommendation engine (`recommend()`) ALWAYS returns exactly ONE movie or nil. Never a list.
**Extension:** `recommendMultiple()` calls the core pipeline repeatedly with diversity constraints. Each individual pick still passes all validation rules. The multi-pick carousel is a UI presentation layer on top of the single-pick engine, not a replacement.
**Why:** The entire product identity ("Pick For Me") is built on eliminating choice paralysis. The progressive pick system narrows choices over time (5 -> 4 -> 3 -> 2 -> 1).
**Verify:** `recommend()` returns `GWRecommendationOutput` with optional single `GWMovie?`. `recommendMultiple()` returns `[GWMovie]` where each element passes `isValidMovie()`.
**Test:** `testEngineReturnsExactlyOneOrNil`
**Violated if:** Any function bypasses `isValidMovie()` to include invalid movies in the pick set.

### INV-R02: Availability Hard Gate
**Rule:** The engine NEVER recommends a movie the user cannot watch right now.
**Conditions:**
  - `movie.available == true` (has at least one streaming provider)
  - `movie.platforms` intersects with `user.platforms` (user has the service)
**Why:** Recommending something unwatchable creates immediate regret and breaks trust.
**Verify:** `isValidMovie()` rejects `.movieUnavailable` and `.platformMismatch`
**Test:** `testNeverRecommendsUnavailableMovie`, `testNeverRecommendsPlatformMismatch`
**Violated if:** MainScreenView ever shows a movie with no matching OTT platform for the user.

### INV-R03: Language Respect
**Rule:** The engine NEVER recommends a movie in a language the user didn't select.
**Why:** Showing a Hindi movie to an English-only user is a broken recommendation.
**Verify:** `isValidMovie()` rejects `.languageMismatch`
**Test:** `testNeverRecommendsWrongLanguage`
**Violated if:** A user who selected only "English" ever sees a Hindi/Korean/etc. movie.

### INV-R04: No Repeats
**Rule:** The engine NEVER recommends a movie the user has already seen, rejected, or abandoned.
**Scope:** Within session (in-memory `excludedMovieIds`) AND across sessions (Supabase `user_interactions` last 30 days).
**Verify:** `isValidMovie()` rejects `.alreadyInteracted`
**Test:** `testNeverResurfacesSeenMovie`, `testNeverResurfacesRejectedMovie`, `testNeverResurfacesAbandonedMovie`
**Violated if:** A user sees the same movie twice in any context within 30 days.

### INV-R05: Runtime Window
**Rule:** The engine NEVER recommends a movie outside the user's selected duration range.
**Verify:** `isValidMovie()` rejects `.runtimeOutOfWindow`
**Test:** `testNeverRecommendsOutsideRuntimeWindow`
**Violated if:** User selects "< 90 min" and sees a 150-minute movie.

### INV-R06: Quality Floor
**Rule:** Every recommendation must pass GoodScore threshold based on mood + time of day.
**Thresholds:** Tired=88, Late Night=85, Neutral=80, Adventurous=75 (before style adjustments).
**Why:** "Low regret over maximum delight" is a core product principle.
**Verify:** `isValidMovie()` rejects `.goodscoreBelowThreshold`
**Test:** `testNeverRecommendsBelowQualityFloor`
**Violated if:** A movie with GoodScore 60 is ever shown to a user in "tired" mood.

### INV-R07: Content Type Match
**Rule:** If user selected "Movie", engine returns movies only. If user selected "Series/Binge", engine returns series only.
**Verify:** `isValidMovie()` rejects `.contentTypeMismatch`
**Test:** `testContentTypeMatch`
**Violated if:** User in movie mode sees a TV series, or vice versa.

### INV-R08: Tag Intersection Required
**Rule:** Every recommended movie must share at least ONE tag with the user's intent tags.
**Why:** This ensures mood alignment. A "feel_good" mood should never produce a "dark" movie.
**Verify:** `isValidMovie()` rejects `.noMatchingTags`
**Test:** `testTagIntersectionRequired`
**Violated if:** User selects "Feel-good" mood and sees a dark thriller with zero matching intent tags.

### INV-R09: Maturity Gating
**Rule:** Animation/kids/family content is hidden until user has 5+ `watch_now` interactions (isMatureUser).
**Exception:** Adult-oriented animated films (has adult genre + high quality) are allowed.
**Why:** Prevents "Frog and Toad" showing up for adults who picked "feel-good".
**Verify:** `GWNewUserContentFilter.shouldExclude()` returns true for animation/kids/family when `shouldShowKidsContent == false`
**Test:** `testMaturityGatingHidesKidsContent`
**Violated if:** A new user's first recommendation is "Peppa Pig" because it matched "feel_good" + "light".

### INV-R10: Top-N Quality Guarantee
**Rule:** The returned movie must come from the top-10 scored candidates among all valid movies.
**Why:** Structural correctness (returning one movie) is necessary but not sufficient. The engine must also return a *quality* pick. A bug could cause the engine to return the worst valid movie instead of a top candidate.
**Source:** `recommend()` calls `sorted.prefix(10)` then `weightedRandomPick(from: topN)`. The output MUST be a member of `topN`.
**Test:** `testInvariant_R10_ReturnedMovieIsFromTopCandidates`
**Violated if:** The returned movie's score is not within the top-10 scores of all valid movies. This catches bugs where filtering, sorting, or random selection accidentally promotes low-quality candidates.

---

## UX / JOURNEY INVARIANTS

### INV-U01: Two Separate Journeys
**Rule:** "Pick For Me" and "Explore" are completely separate flows. They share LandingView as the ONLY entry point.
**Pick For Me:** Landing -> Auth -> Mood -> Platform -> Duration -> EmotionalHook -> ConfidenceMoment -> MainScreen
**Explore:** Landing -> ExploreAuth -> ExploreView (6 tabs)
**Violated if:** A user in Pick For Me flow accidentally enters Explore, or vice versa, without going through Landing.

### INV-U02: Pick For Me Is Linear
**Rule:** The Pick For Me onboarding is a strictly linear flow (screens 0-7). User can go back but cannot skip steps.
**Screen order:** landing(0) -> auth(1) -> mood(2) -> platform(3) -> duration(4) -> emotionalHook(5) -> confidenceMoment(6) -> mainScreen(7)
**Violated if:** User jumps from mood selection directly to MainScreen, skipping platform/duration.

### INV-U03: UI Never Filters
**Rule:** The UI receives exactly what the engine gives it. UI NEVER applies additional filtering, sorting, or overrides.
**From GWSpec.swift Section 11:**
  - "UI receives EXACTLY ONE Movie or null"
  - "UI NEVER filters"
  - "UI NEVER overrides logic"
  - "UI NEVER explains GoodScore math"
  - "UI trusts engine completely"
**Violated if:** MainScreenView, or any view in Pick For Me flow, contains `.filter()`, `.sorted()`, or conditional display logic on movie data.

### INV-U04: MainScreen Actions Contract
**Rule:** Single-pick MainScreen has exactly FOUR user actions, each with defined behavior:
1. **Watch Now** -> records `watch_now` interaction, updates tag weights (+0.15), navigates to enjoyScreen, schedules feedback, adds 3 interaction points
2. **Not Tonight** -> opens RejectionSheet, user picks reason, records `not_tonight`, updates tag weights (-0.2), fetches next, adds 2 interaction points
3. **Already Seen** -> records `already_seen`, fetches similar unseen movie, adds 1 interaction point
4. **Start Over** -> resets all session state, returns to Landing
**Multi-pick carousel actions:**
5. **Watch Now (multi)** -> same as Watch Now + records `implicit_skip` (-0.05) for all non-chosen cards + adds 1 point per skipped card
6. **Not Interested (card)** -> records `not_interested`, updates tags (-0.2), finds contrasting replacement, adds 2 interaction points
7. **Already Seen (card)** -> records `already_seen_card`, updates tags (-0.05), finds similar replacement, adds 1 interaction point
**Violated if:** A new action is added without corresponding interaction recording + tag weight update, OR an existing action's tag delta is changed.

### INV-U05: Explore Auth Is Mandatory
**Rule:** The Explore journey requires authentication. Users cannot browse the catalog anonymously.
**Why:** Explore uses Supabase queries and requires a user context.
**Flow:** Landing -> ExploreAuthView (sign-up required) -> ExploreView
**Exception:** Users already signed in (from Pick For Me) skip ExploreAuth.
**Violated if:** An unauthenticated user can access any of the 6 Explore tabs.

### INV-U06: Back Always Works
**Rule:** Every onboarding screen has a functional back button that returns to the previous screen.
**Violated if:** User gets stuck on any screen with no way to go back.

---

## DATA INVARIANTS

### INV-D01: GoodScore Calculation
**Rule:** GoodScore uses this priority: `composite_score` (enriched multi-source) > `imdb_rating` > `vote_average`.
**44% of catalog has no IMDB rating.** The fallback chain is critical.
**Formula (from GWMovie.init):**
  - If `composite_score > 0`: use it (already 0-10 scale, multiply by 10 for display)
  - Else if both IMDB + TMDB exist: `(imdb * 0.75 + tmdb * 0.25) * 10`
  - Else: `sourceRating * 10`
**Violated if:** GoodScore formula is changed without understanding the 44% null-IMDB impact.

### INV-D02: Tag Derivation
**Rule:** Movie tags are derived from `emotional_profile` using the exact thresholds in `GWMovie.deriveTags()`.
**Critical rule:** Movies WITHOUT emotional_profile get `["medium", "polarizing", "full_attention"]` — they do NOT get "safe_bet".
**Why:** Unknown content should not be treated as safe. This prevents garbage from matching "Surprise me" intent.
**Violated if:** A movie with nil `emotional_profile` is tagged "safe_bet".

### INV-D03: Per-User Tag Weights
**Rule:** TagWeightStore stores weights PER USER using `gw_tag_weights_{userId}` key in UserDefaults.
**Migration:** On first login, legacy global weights are migrated to user-specific key.
**Violated if:** Tag weights from user A affect recommendations for user B.

### INV-D04: Supabase Is Source of Truth
**Rule:** The `movies` table in Supabase (project `jdjqrlkynwfhbtyuddjk`) is the canonical movie catalog.
**Rule:** Config lives in `SupabaseConfig.swift` (hardcoded), NOT in `.env` files.
**Violated if:** Movie data is fetched from any source other than this Supabase project.

### INV-D05: Client-Side Scoring Only
**Rule:** ALL recommendation scoring, filtering, and tag weight computation happens client-side in Swift. No Supabase RPC functions, edge functions, or server-side logic participates in the recommendation pipeline.
**Why:** If scoring moves server-side, Swift unit tests can no longer verify the scoring invariants (INV-L01, INV-L02, INV-L03). The entire invariant safety net would have a blind spot.
**Current state:** Supabase is purely a data store. `fetchMoviesForAvailabilityCheck()` returns raw rows. `derive_tags` SQL exists for batch enrichment only (marketing scripts), never at recommendation time.
**Violated if:** A Supabase RPC, edge function, or any server-side code is introduced that filters, scores, or ranks movies for the recommendation pipeline.

### INV-D06: Explore ↔ Static Page Consistency (Web)
**Rule:** The website Explore page (`explore.js`) must ONLY link to movies that have corresponding static pages on the website. Zero 404s, zero wrong-movie links.
**Three-layer fail-safe:**
1. **Query filter:** `explore.js` adds `composite_score=not.is.null` to all Supabase queries, matching the page generator's filter.
2. **Slug manifest:** `explore.js` loads `/movies/_slugs.json` (a `{movie_id: actual_slug}` dict) and resolves slugs via `resolveSlug(movie)` instead of client-side `slugify()`. This handles deduped slugs (e.g., `power-2014` vs `power-2014-a1b2c3d4`) correctly. If a movie has no manifest entry, the card renders without a link (no 404).
3. **Pre-deploy validation:** `tools/validate_deploy.py` checks manifest integrity (no duplicates, all slugs have pages), Cloudflare file count, and explore.js invariants before every deploy.
**Current implementation:**
  - `generate_movie_pages.py` writes `_slugs.json` as `{movie_id: actual_slug}` dict during page generation
  - `explore.js` and the watchlist page both load the manifest and use `resolveSlug()` for all movie links
  - `validate_deploy.py` runs before every deploy to catch any drift
**Why:** If Explore shows a movie that doesn't have a static page, clicking it produces a 404 error. If two movies produce the same slug (duplicate titles + same year), one links to the wrong movie page.
**Context:** Total DB has ~22,663 movies. ~20,629 have composite_score (and static pages). ~2,034 don't. Cloudflare Pages has a 20,000 file limit per deploy. 42 movies had duplicate slugs requiring ID-based dedup.
**Violated if:** `explore.js` queries movies without `composite_score` filter, OR uses `slugify()` instead of `resolveSlug()`, OR `generate_movie_pages.py` changes its filter or slug format without updating the manifest, OR `validate_deploy.py` is bypassed.

### INV-D07: GoodScore Display Sources (Web + Apps)
**Rule:** Movie detail pages show ALL available rating sources, not just one. Display priority: IMDb (yellow), RT Critics (red), RT Audience (red), Metacritic (blue), TMDB (teal).
**Current state:** ~44% of movies lack IMDb data. OMDB API enrichment is rate-limited (1000/day free tier). Movies only show ratings that exist in the database.
**Why:** Users expect to see IMDb ratings. Showing only TMDB looks incomplete. The code is correct — it's a data enrichment bottleneck, not a code bug.
**Violated if:** The rating display template is changed to show only one source, OR the OMDB enrichment pipeline is removed.

---

## LEARNING SYSTEM INVARIANTS

### INV-L01: Tag Weight Deltas
**Rule:** Tag weight updates use EXACTLY these deltas:
| Action | Delta | Signal |
|--------|-------|--------|
| `watch_now` | +0.15 | Positive reinforcement |
| `completed` | +0.20 | Strong positive |
| `not_tonight` | -0.20 | Significant negative |
| `abandoned` | -0.40 | Strong negative |
| `show_me_another` | -0.05 | Mild negative (accumulates) |
| `implicit_skip` | -0.05 | Multi-pick: same as show_me_another |
**Violated if:** Any delta is changed without updating this table AND the corresponding test.

### INV-L02: Scoring Formula Weights
**Rule:** The recommendation scoring formula uses EXACTLY these weights:
  - Tag alignment: **50%**
  - Regret safety: **25%**
  - Platform bias: **15%**
  - Dimensional fit: **10%**
**Source:** `GWRecommendationEngine.computeScore()`
**Violated if:** Weights are changed, causing recommendation quality shift without explicit approval.

### INV-L03: Confidence Boost Threshold
**Rule:** Confidence boost activates ONLY after 10+ tags have deviated from default (1.0). Max boost is 5% of tag alignment.
**Why:** Prevents premature personalization when we don't have enough data.
**Violated if:** Confidence boost fires for a user with < 10 learned tags.

### INV-L04: Weighted Random Selection
**Rule:** Top 10 candidates undergo weighted random selection (softmax with temperature 0.15).
**Why:** Prevents deterministic repetition while still favoring quality.
**Violated if:** Recommendation becomes purely deterministic (always returns #1 scored movie).

### INV-L05: Not-Tonight Avoidance
**Rule:** After "Not Tonight", the next recommendation penalizes movies with overlapping tags to the rejected movie.
**Penalty:** `(overlap_count / total_tags) * 0.3`
**Source:** `GWRecommendationEngine.recommendAfterNotTonight()`
**Violated if:** User rejects a dark thriller and immediately gets another dark thriller.

### INV-L06: Taste Graph Scoring Weight
**Rule:** Taste graph score contributes up to 15% of total score for users with 20+ feedbacks, 0% for users with <3 feedbacks. Score is normalized 0-1 and integrated as a weighted component within the existing formula. It NEVER replaces mood_scoring — both coexist. The mood picker captures explicit session intent; the taste graph captures implicit long-term preference.
**Weight scaling:** 0-2 feedbacks = 0% weight, 3-9 = 7.5% (half), 10-19 = 12% (80%), 20+ = 15% (full). Remaining weight is distributed proportionally to existing components (tag=50%, regret=25%, platform=15%, dimensional=10%).
**Source:** `GWRecommendationEngine.computeScore()` + `GWTasteEngine.computeTasteScore()`
**Violated if:** Taste graph score exceeds 15% of total, or activates for a user with <3 feedbacks, or replaces/overrides the mood picker signal.

### INV-R11: Remote Mood Config Resilience
**Rule:** Mood-to-recommendation mapping is driven by remote config (mood_mappings table). Engine MUST fall back to hardcoded tag-based matching if remote config is unreachable. App MUST NOT crash or hang if mood_mappings fetch fails.
**Source:** `GWMoodConfigService.swift` provides remote mood mappings with hardcoded fallback defaults. `GWRecommendationEngine.isValidMovie()` Rule 7 uses dimensional filtering when remote mapping is available (version > 0), falls back to tag intersection otherwise.
**Fallback behavior:** When remote config is unavailable, GWMoodConfigService loads version-0 mappings with the same compatible_tags as the hardcoded MoodSelectorView options. The engine treats version-0 mappings as "no remote config" and uses the original tag intersection logic.
**Test:** `testInvariant_R11_MoodMappingFallback`
**Violated if:** Engine throws error when Supabase is unreachable during mood config fetch, OR app hangs/crashes when mood_mappings table is empty or unreachable, OR fallback behavior differs from original hardcoded tag-based matching.

### INV-R12: Progressive Pick Count
**Rule:** The number of picks shown decreases as the user accumulates interaction points. Pick count tiers:
| Points | Pick Count |
|--------|-----------|
| 0-19 | 5 |
| 20-49 | 4 |
| 50-99 | 3 |
| 100-159 | 2 |
| 160+ | 1 |
Points are a one-way ratchet: they never decrease. Pick count never increases once a lower tier is reached.
When `pickCount == 1`, the existing single-pick MainScreenView is used unchanged.
**Point values:** Watch Now=3, Not Interested=2, Already Seen=1, Implicit Skip=1, Show Me Another=1, Not Tonight=2.
**Source:** `GWInteractionPoints.swift` (service), `RootFlowView.swift` (routing)
**Test:** `testInvariant_R12_PickCountTiers`, `testInvariant_R12_OneWayRatchet`
**Violated if:** Pick count increases after reaching a lower tier, or points are decremented, or single-pick mode (pickCount=1) uses the carousel instead of MainScreenView.

### INV-L07: Implicit Skip Tag Delta
**Rule:** When a user taps Watch Now in multi-pick mode, all non-chosen cards receive an implicit_skip tag weight update of -0.05 (same as show_me_another).
**Why:** The user's choice of one card over others is a weak negative signal for the unchosen cards' tags.
**Source:** `RootFlowView.handleMultiPickWatchNow()`, `GWSpec.updateTagWeights(.implicit_skip)`
**Test:** `testInvariant_L01_TagWeightDeltaImplicitSkip`
**Violated if:** Implicit skip delta differs from -0.05, or implicit skip is applied to the chosen card.

---

## PROTECTED FILES

These files define invariants and their tests. They CANNOT be modified without explicit user approval in the current chat session:

| File | Why Protected |
|------|---------------|
| `INVARIANTS.md` | Defines the behavioral contracts. Weakening a rule = breaking the product. |
| `GoodWatchTests/GWProductInvariantTests.swift` | Encodes invariants as tests. Weakening a test to make code pass is a violation. |
| `GoodWatchTests/GWRecommendationEngineTests.swift` | Original engine tests. Same protection as invariant tests. |

**Anti-pattern to watch for:** A Claude session that edits a test to make broken code "pass" instead of fixing the code. This is the most dangerous form of invariant violation because it erases the safety net silently.

---

## CONTINUOUS VALIDATION (NOT JUST PRE-COMMIT)

Invariant tests should run **continuously during development**, not just before commit:

1. **After modifying ANY file in Core/, Services/, or screens/**: Run invariant tests immediately
2. **After each Ralph Wiggum story completion**: Run invariant tests before marking the story DONE
3. **Before committing**: Final gate — run all invariant + engine tests

Command: `xcodebuild test -project GoodWatch.xcodeproj -scheme GoodWatch -destination 'platform=iOS Simulator,id=EBB73CAE-3A8E-4D68-A90A-C3319BC9D678' -only-testing:GoodWatchTests/GWProductInvariantTests 2>&1 | tail -30`

**If any test fails mid-session**: STOP. Fix the code. Do not proceed to the next task with failing invariant tests.

---

## PRE-COMMIT CHECKLIST

Before committing ANY code change, verify:

- [ ] Does this change touch a **protected file**? (`GWRecommendationEngine.swift`, `GWSpec.swift`, `Movie.swift`, `RootFlowView.swift`) — If yes, was explicit approval given?
- [ ] Does this change touch an **invariant file**? (`INVARIANTS.md`, `GWProductInvariantTests.swift`) — If yes, was explicit approval given? Never weaken a test to make code pass.
- [ ] Does this change affect the **recommendation output**? — If yes, which INV-R invariants are affected?
- [ ] Does this change affect **screen navigation**? — If yes, which INV-U invariants are affected?
- [ ] Does this change affect **tag weights or scoring**? — If yes, which INV-L invariants are affected?
- [ ] Does this change affect **GoodScore calculation**? — If yes, INV-D01 applies.
- [ ] Does this change introduce **new behavior** touching recommendation, scoring, or UX? — If yes, propose a new invariant FIRST.
- [ ] Do all invariant tests pass? (Must have been run continuously, not just now)
- [ ] Is `progress.txt` updated with what was changed and why?

---

## HOW TO ADD A NEW INVARIANT

1. Write the rule in plain English with a clear "Violated if" condition
2. Assign an ID: `INV-{domain}{number}` (R=Recommendation, U=UX, D=Data, L=Learning)
3. Write a test in `GWProductInvariantTests.swift` named `testInvariant_{ID}`
4. Add to this file
5. Commit both the invariant definition and the test together

**RULE:** Every new feature that touches recommendation, scoring, UX flow, or learning MUST propose a new invariant before implementation begins. The invariant is approved first, then the code is written to satisfy it.

---

## AUDIT SYSTEM INVARIANTS

### INV-A01: Zero False Positives
Every check that reports "fail" MUST be a real, actionable problem. If a check cannot produce an accurate result in the current environment (CI vs local), it MUST report "skip" with a clear reason -- NEVER "fail". False positives train humans to ignore the audit, which is worse than no audit.

### INV-A02: No Mass Skips
No section may have more than 30% of its checks skipped. If a section cannot run most of its checks, the checks must be rewritten to work in the available environment (Supabase queries, code inspection, HTTP checks). "Requires device testing" is not an acceptable skip reason if the check can be done via database query or source code analysis.

### INV-A03: Report Only -- Never Auto-Fix
The audit agent is READ-ONLY. It MUST NOT delete data, modify rows, update flags, re-enable features, change profiles, or alter any database state. It reads and reports. The human decides what gets fixed.

### INV-A04: Every Failure Must Have Remediation
Every check that reports "fail" MUST include in its detail field: (1) what is wrong, (2) what was expected, (3) what was found, (4) which guardrail it violates (INV-xxx, CLAUDE.md section, or product decision), and (5) how to fix it (specific SQL, code change, or config update). A failure without remediation instructions is useless.

### INV-A05: Audit Score Must Be Real
The audit score (pass percentage) must reflect actual product health. Inflated scores (from mass skips or lenient thresholds) and deflated scores (from false positives or environment issues) are both violations. The score is the single number that tells the founder whether to ship or fix.

### INV-A06: Audit Results Are Immutable
Once an audit run is published to Supabase, its results MUST NOT be modified, deleted, or overwritten. Each run is a permanent historical record. The dashboard shows trends over time -- rewriting history breaks trend analysis.

### INV-A07: Dashboard Must Be Live
The audit dashboard at goodwatch.movie/command-center/audit MUST load and display the latest audit run results. If the dashboard returns 404, shows stale data (>48 hours old), or fails to render, that is a critical infrastructure failure.

### INV-A08: Protected File Hash Baselines
When a protected file (GWRecommendationEngine.swift, Movie.swift, GWSpec.swift, RootFlowView.swift, SupabaseConfig.swift, CLAUDE.md, INVARIANTS.md) is intentionally modified, its hash in the protected_file_hashes table MUST be updated in the same commit. The audit agent compares current hashes against these baselines -- a stale baseline produces false failures.

### INV-A09: New Checks Must Map to Guardrails
Every new audit check added to audit_agent.py MUST reference a specific guardrail in its source_ref field: an INV-xxx ID from INVARIANTS.md, a CLAUDE.md section, or a documented product decision. Orphan checks with no guardrail reference are not allowed.

### INV-A10: CI Environment Adaptation
The audit agent MUST detect whether it is running in CI (GitHub Actions) or locally and adapt checks accordingly. Checks that depend on local-only state (git hooks, skip-worktree, Keychain) MUST skip cleanly in CI. Checks that depend on network access MUST use proper User-Agent headers and accept standard HTTP response codes (200, 206, 301, 302).
