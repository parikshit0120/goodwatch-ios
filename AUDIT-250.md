# GoodWatch 250-Point Audit Specification

Every check maps to a specific guardrail from INVARIANTS.md, CLAUDE.md, or product decisions made during development.

---

## A. DATA INTEGRITY (30 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| A01 | Total movies >= 22,000 | CLAUDE.md catalog size | critical |
| A02 | 100% movies have emotional_profile NOT NULL | INV-R06 dimensional scoring | critical |
| A03 | All emotional_profiles have exactly 8 dimensions (comfort, darkness, emotionalIntensity, energy, complexity, rewatchability, humour, mentalStimulation) | v1.3 8-dim system | critical |
| A04 | 100% movies have tags NOT NULL | INV-R05 tag alignment = 50% of score | critical |
| A05 | Each movie has exactly 5 tag categories: weight, mood, energy, rewatchability, risk | Tag system spec | high |
| A06 | All emotional_profile dimension values within 1-10 range | Data validity | critical |
| A07 | No emotional_profile with all dimensions identical (stuck profiles) | Quality gate | high |
| A08 | 100% movies have poster_path | UI display requirement | high |
| A09 | 100% movies have overview text (synopsis) | Fix 2: card summary | high |
| A10 | 100% movies have at least 1 genre | Fix 5: primary genre display | high |
| A11 | 100% movies have release_date | Recency gate dependency | medium |
| A12 | 100% movies have runtime > 0 | Duration filter dependency | high |
| A13 | 100% movies have vote_average > 0 | Quality threshold dependency | high |
| A14 | 0 duplicate movies by tmdb_id | Data integrity | critical |
| A15 | No movies with runtime < 40 in main pool | Fix 4: shorts exclusion | high |
| A16 | No stand-up specials in recommendation pool (genre check) | Fix 4: stand-up exclusion | high |
| A17 | OTT provider data (watch_providers) present for >= 60% of movies | INV-R02 availability | critical |
| A18 | Ratings enrichment coverage >= 90% (ratings_enriched_at NOT NULL) | Enrichment pipeline | medium |
| A19 | Movie count per language: Hindi >= 2000, English >= 5000, Tamil >= 1000, Telugu >= 1000 | Multi-language support | high |
| A20 | Profile accuracy: dark movies sample (darkness >= 6) — 10 known titles | Audit spot-check | high |
| A21 | Profile accuracy: feel-good movies sample (comfort >= 7) — 10 known titles | Audit spot-check | high |
| A22 | Profile accuracy: complex movies sample (complexity >= 7) — 10 known titles | Audit spot-check | high |
| A23 | Profile accuracy: comedies sample (humour >= 6) — 10 known titles | Audit spot-check | high |
| A24 | No movies with vote_count = 0 AND vote_average > 0 (suspicious data) | Data quality | medium |
| A25 | All tag weight values are valid: light, medium, heavy | Tag enum validation | medium |
| A26 | All tag mood values are valid: feel_good, dark, bittersweet, uplifting | Tag enum validation | medium |
| A27 | All tag energy values are valid: calm, tense, high_energy | Tag enum validation | medium |
| A28 | All tag rewatchability values are valid: rewatchable, one_time | Tag enum validation | medium |
| A29 | All tag risk values are valid: safe_bet, polarizing, acquired_taste | Tag enum validation | medium |
| A30 | OTT data freshness: top 500 movies have watch_providers updated within 30 days | Stale data detection | high |

## B. RECOMMENDATION ENGINE INVARIANTS (30 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| B01 | Scoring weights: tagAlignment=0.50, regretSafety=0.25, platformBias=0.15, dimensionalLearning=0.10 | INV-L02 | critical |
| B02 | Taste engine weight range: 0 to 0.15 | INV-L02 taste_engine | critical |
| B03 | Confidence boost range: 0 to 5% | INV-L02 | high |
| B04 | Tag deltas: watch_now=+0.15, not_tonight=-0.20, save_for_later=+0.05, skip(implicit)=-0.05 | INV-L01 | critical |
| B05 | Tag weight clamp range: 0.0 to 1.0 | INV-L01 | high |
| B06 | Quality thresholds: new_user >= 7.5, warming_up >= 7.0, trusted >= 6.0 | Quality gate tiers | critical |
| B07 | New user recency gate: exclude movies before 2010 | Feature flag: new_user_recency_gate | high |
| B08 | GoodScore threshold: default 80, tired mood 88, adventurous 75, late night max(base,85) | Scoring spec | high |
| B09 | computeMoodAffinity returns 0.0-1.0 range | Engine contract | critical |
| B10 | Anti-tag penalty = -0.10 per anti-tag match | Mood scoring spec | high |
| B11 | isValidMovie excludes: wrong language, unavailable platform, runtime < 40, stand-up, concert films | INV-R02, INV-R03, Fix 4 | critical |
| B12 | Engine returns exactly 1 movie (single-pick) or ordered list (carousel) — never empty without "no matches" state | INV-R01 | critical |
| B13 | Never recommend a movie the user has already watched (hard reject) | INV-R04 exclusion | critical |
| B14 | Soft reject cooldown: 7 days before re-showing | Cooldown spec | high |
| B15 | Same movie not shown twice in same session | Session dedup | high |
| B16 | Progressive picks tiers: interaction points 0-19→5, 20-49→4, 50-99→3, 100-159→2, 160+→1 | INV-R12 carousel regression fix | critical |
| B17 | Interaction points: watch_now=15, not_tonight=5, save_for_later=8, skip=2, card_reject=3, feedback_complete=20 | Interaction points spec | high |
| B18 | Interaction points ratchet: never decreases | Ratchet invariant | high |
| B19 | Temperature = 0.15 for weighted random sampling | INV-L04 | medium |
| B20 | Movies scored against correct mood dimensional targets from mood_mappings | Mood config flow | critical |
| B21 | 5 moods active: feel_good, easy_watch, surprise_me, gripping, dark_heavy | Mood system spec | critical |
| B22 | mood_mappings table has 5 rows, all active, all version 1 | Remote config | high |
| B23 | surprise_me mood has all weights = 0.3 (minimal filtering) | Surprise me = anything goes | medium |
| B24 | Feature flags all ON: remote_mood_mapping, taste_engine, progressive_picks, feedback_v2, card_rejection, implicit_skip_tracking, new_user_recency_gate, push_notifications | v1.3 feature flags | critical |
| B25 | Dimensional learning contributes only 10% of total score | Scoring weight check | high |
| B26 | tagAlignment contributes 50% of total score (heaviest factor) | INV-L02 | critical |
| B27 | No movie with GoodScore < 60 ever reaches the user | Minimum quality floor | critical |
| B28 | Language matching: P1 = +20, P2 = +15, P3 = +10, P4+ = +5, no match = -20 | Fix 4 language priority | high |
| B29 | Duration filter uses UNION of selected ranges (multi-select) | Fix 5 duration multi-select | high |
| B30 | Feed-forward: user feedback updates tag weights within same session | INV-L03 taste evolution | high |

## C. USER EXPERIENCE & RETENTION (35 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| C01 | "Pick for me" → mood → platform → duration → loading → picks (full flow, no dead ends) | Core journey | critical |
| C02 | Returning user skips mood/platform/duration (GWOnboardingMemory 30-day persistence) | Onboarding memory | critical |
| C03 | "Pick another" preserves onboarding memory (returnToLandingPreservingMemory) | Fix 6 root cause | critical |
| C04 | "Start Over" / Home clears memory (intentional reset) | Intentional UX | high |
| C05 | Recommendations persist when app goes to background and returns | Fix 2 persistence | critical |
| C06 | Last 5 recent picks visible on landing screen | Fix 3 recent picks | high |
| C07 | GoodScore badge: fixed width >= 64pt, "GOODSCORE" never wraps | Fix 1 badge layout | high |
| C08 | Card rank copy: "Top pick." / "Runner up." / "Also great." / "Worth a watch." / "Dark horse." | No possessives rule | high |
| C09 | ZERO instances of "Our best", "Your best", "our pick", "your pick", "for you" in codebase | No possessives rule | critical |
| C10 | Content type badge visible on every card: Movie / Series / Documentary | Fix 3 content type | high |
| C11 | Primary genre only (1 pill), not multiple genre pills | Fix 5 single genre | high |
| C12 | Movie overview/synopsis shown on card (2-line truncation) | Fix 2 summary | high |
| C13 | Post-rating flow does NOT dump user at homescreen with cleared memory | Fix 6 nav flow | critical |
| C14 | Language selector: 6 primary (Hindi, English, Tamil, Telugu, Malayalam, Kannada) + "More" expander | Fix 6 language trim | high |
| C15 | Language selection shows priority badges (1, 2, 3...) based on tap order | Fix 4 language priority | high |
| C16 | Duration selector allows multi-select (not mutually exclusive) | Fix 5 duration multi-select | high |
| C17 | Feedback 2-stage flow: quick reaction → optional detailed review | feedback_v2 flag | high |
| C18 | Card rejection: X button visible, max 1 rejection per position | card_rejection flag | medium |
| C19 | 3D rejection overlay animation on card dismiss | v1.3 rejection UX | medium |
| C20 | Confidence moment (loading screen) shows before picks | Journey structure | medium |
| C21 | OTT deep links open correct streaming app | Platform integration | critical |
| C22 | Apple Sign-In works | Auth | critical |
| C23 | Google Sign-In works | Auth | critical |
| C24 | Anonymous fallback works (can use app without signing in) | Auth flexibility | high |
| C25 | Watchlist syncs to Supabase (bidirectional) | Cloud persistence | high |
| C26 | Tag weights sync to Supabase (bidirectional) | Cloud persistence | high |
| C27 | No UI element shows raw debug text or placeholder text | Polish | high |
| C28 | All screens respect safe area and notch on iPhone | Layout | high |
| C29 | Dark mode consistency across all screens | Visual consistency | medium |
| C30 | No "Our", "Your", "We" in any user-facing copy (except where conversationally natural) | Brand voice: confident, not possessive | high |
| C31 | 16+ languages shown only behind "More" — primary 6 always visible | Decision fatigue reduction | high |
| C32 | Duration multi-select: minimum 1 selection enforced, can't deselect last | UX safety | medium |
| C33 | Push notifications scheduled: Fri/Sat 7pm, re-engage after 3 days | push_notifications flag | medium |
| C34 | Update banner: shows when new version available, dismissible | Update notification system | low |
| C35 | No emoji in any UI text or copy | GoodWatch brand rule | medium |

## D. PROTECTED FILES & CLAUDE CODE COMPLIANCE (30 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| D01 | CLAUDE.md exists at repo root and is non-empty | Protection system | critical |
| D02 | INVARIANTS.md exists at repo root and is non-empty | Protection system | critical |
| D03 | Pre-commit hook installed and blocks protected file changes | Section 15.1 | critical |
| D04 | skip-worktree lock active on CLAUDE.md | Lock system | high |
| D05 | skip-worktree lock active on INVARIANTS.md | Lock system | high |
| D06 | unlock.sh exists and has 60-second timeout | Protection system | high |
| D07 | GWRecommendationEngine.swift unchanged from last approved commit (hash check) | Protected file | critical |
| D08 | Movie.swift unchanged from last approved commit (hash check) | Protected file | critical |
| D09 | GWSpec.swift unchanged from last approved commit (hash check) | Protected file | critical |
| D10 | RootFlowView.swift unchanged from last approved commit (hash check) | Protected file | critical |
| D11 | CLAUDE.md Section 15 (Protection System) present and complete | Protection rules | high |
| D12 | CLAUDE.md Section 12 (Invariants quick-reference table) present | Session awareness | high |
| D13 | All 22+ invariants in INVARIANTS.md have corresponding XCTest | Test coverage | critical |
| D14 | GWProductInvariantTests.swift exists and compiles | Test infrastructure | critical |
| D15 | Invariant tests: 0 new failures since last approved run | Regression detection | critical |
| D16 | No STOP-AND-ASK checkpoint violations in recent commits (no deploy/delete without approval) | Section 15.2 | high |
| D17 | No modifications to protected files without unlock.sh trace in git log | Unauthorized changes | critical |
| D18 | SupabaseConfig.swift unchanged (no credential drift) | Protected file | high |
| D19 | project.yml (XcodeGen) matches CLAUDE.md documented config | Config consistency | medium |
| D20 | .env / .env.example present with required keys documented | Config management | medium |
| D21 | Git pre-commit hook file exists at .git/hooks/pre-commit | Hook installation | high |
| D22 | No hardcoded API keys in committed Swift files | Security | critical |
| D23 | No hardcoded Supabase service role key in client code | Security | critical |
| D24 | Firebase GoogleService-Info.plist not in .gitignore but has no secrets | Config management | medium |
| D25 | Bundle ID matches CLAUDE.md documented value | Config consistency | medium |
| D26 | CLAUDE.md rule "DO NOT TOUCH EXISTING CODE UNLESS EXPLICITLY ASKED" present | Rule 1 | critical |
| D27 | CLAUDE.md rule "Only touch code units you are specifically asked to work on" present | Rule 2 | critical |
| D28 | CLAUDE.md rule "Never ask for manual intervention" present | Rule 3 | high |
| D29 | CLAUDE.md rule "All code changes in one go" present | Rule 4 | high |
| D30 | INV-WEB-01 documented: dynamic movie page function MUST copy HTML template exactly | Website invariant | high |

## E. WEBSITE & SEO (30 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| E01 | goodwatch.movie loads (HTTP 200) within 3 seconds | Core availability | critical |
| E02 | Homepage has correct title, meta description, OG tags | SEO basics | high |
| E03 | /command-center/audit page exists and loads | This audit system | high |
| E04 | Movie pages: /movies/{slug} returns 200 for sample of 10 known movies | Movie page availability | critical |
| E05 | Movie pages: dynamic Cloudflare Pages Function fetches from Supabase on-demand | INV-WEB-01 | critical |
| E06 | Movie page HTML matches template from generate_movie_pages.py EXACTLY | INV-WEB-01 non-negotiable | critical |
| E07 | Movie page has: title, poster, GoodScore, synopsis, genres, runtime, year | Page completeness | high |
| E08 | Movie page has correct OG tags (og:title, og:image, og:description) | Social sharing | high |
| E09 | Movie page has structured data (JSON-LD schema) | SEO | medium |
| E10 | Sitemap.xml exists and is valid | SEO | high |
| E11 | Robots.txt exists and allows crawling | SEO | high |
| E12 | Blog/hub pages load correctly | Content marketing | medium |
| E13 | Newsletter signup endpoint works (Resend integration) | Growth | medium |
| E14 | App Store link on homepage points to correct listing | Conversion | high |
| E15 | Google Play link on homepage (or "Coming Soon" placeholder) | Conversion | medium |
| E16 | No broken images on homepage (all poster URLs resolve) | Visual quality | high |
| E17 | No broken internal links (sample 20 random links) | Site health | medium |
| E18 | HTTPS enforced on all pages | Security | critical |
| E19 | No mixed content warnings | Security | high |
| E20 | Page speed: homepage Lighthouse performance >= 70 | Performance | medium |
| E21 | Mobile responsive: homepage renders correctly at 375px width | Mobile UX | high |
| E22 | Cloudflare Pages deployment is active and healthy | Infrastructure | critical |
| E23 | Movie page count in sitemap >= 19,000 | SEO coverage | high |
| E24 | No 404s for top 50 most popular movies | High-traffic pages | high |
| E25 | Canonical URLs set correctly on movie pages | SEO dedup | medium |
| E26 | favicon.ico exists | Branding | low |
| E27 | Apple Smart App Banner meta tag present on homepage | App conversion | medium |
| E28 | No "Lorem ipsum" or placeholder text on any page | Polish | high |
| E29 | Website brand copy: no "Our", "Your", "We" (same rule as app) | Brand voice consistency | medium |
| E30 | Cloudflare Pages Functions: no deployment errors in last 24h | Infrastructure health | high |

## F. SUPABASE & BACKEND (25 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| F01 | Supabase project is accessible (health check) | Infrastructure | critical |
| F02 | RLS (Row Level Security) enabled on: interactions, watchlist, user_tag_weights | Security hardening | critical |
| F03 | RLS policies allow authenticated users to read/write only own data | Security | critical |
| F04 | Anonymous users can read movies table | Public data access | high |
| F05 | mood_mappings table: 5 rows, all active | Remote config | critical |
| F06 | mood_mappings: feel_good comfort=8.5, darkness=1.0 | Config accuracy | high |
| F07 | mood_mappings: dark_heavy comfort=1.5, darkness=8.5 | Config accuracy | high |
| F08 | mood_mappings: surprise_me all weights=0.3 | Config accuracy | high |
| F09 | Feature flags table: 8 flags, all enabled | v1.3 flags | critical |
| F10 | interactions table exists with correct schema | Data collection | critical |
| F11 | watchlist table exists with correct schema | User data | high |
| F12 | user_tag_weights table exists with correct schema | Taste learning | high |
| F13 | profile_audits table exists (for tracking enrichment quality) | Audit infrastructure | medium |
| F14 | app_version_history table exists | Update notification system | medium |
| F15 | Supabase REST API responds within 500ms for movies query | Performance | high |
| F16 | pgvector extension enabled | Embedding infrastructure | medium |
| F17 | No orphaned records in interactions (all movie_ids exist in movies) | Referential integrity | medium |
| F18 | Database size within Supabase plan limits | Infrastructure | high |
| F19 | No expired or revoked API keys | Security | critical |
| F20 | Supabase service role key in GitHub secrets (not in code) | Security | critical |
| F21 | Supabase anon key matches what's in app config | Config consistency | high |
| F22 | OMDB key is PATRON tier (a7be3b08, 100K/day limit) — NOT free tier | OMDB spec | medium |
| F23 | OMDB interval = 0.05s (not 1.1s free-tier throttle) | OMDB spec | medium |
| F24 | Backup: movies table has > 0 rows (not accidentally wiped) | Disaster recovery | critical |
| F25 | No SQL injection vectors in Cloudflare Pages Functions | Security | high |

## G. iOS APP BUILD & TESTS (25 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| G01 | Xcode build succeeds (0 errors) | Build health | critical |
| G02 | 0 new test failures vs last approved baseline | Regression | critical |
| G03 | GWProductInvariantTests: all pass | Invariant enforcement | critical |
| G04 | Screenshot tests: 12/12 pass | Visual regression | high |
| G05 | No compiler warnings related to deprecated APIs | Code quality | medium |
| G06 | App version = 1.3 in project config | Version tracking | high |
| G07 | Build number incremented from last submission | App Store requirement | high |
| G08 | Bundle ID = correct value per CLAUDE.md | Config | high |
| G09 | Minimum iOS deployment target documented and set | Compatibility | medium |
| G10 | All required capabilities: Sign In with Apple, Push Notifications | Entitlements | high |
| G11 | GoogleService-Info.plist present and valid | Firebase | high |
| G12 | No force-unwraps (!) in production code paths (sample check) | Crash prevention | medium |
| G13 | No print() statements in production code (only #if DEBUG) | Release hygiene | medium |
| G14 | XcodeGen (project.yml) regenerates without errors | Build system | high |
| G15 | App launches on iPhone 16 Pro Max simulator without crash | Smoke test | critical |
| G16 | App launches on iPhone SE simulator without crash | Small screen | high |
| G17 | No memory leaks detected in Instruments (basic check) | Performance | medium |
| G18 | App size < 100MB | App Store guideline | medium |
| G19 | All accessibility identifiers present for screenshot tests | Test infrastructure | medium |
| G20 | Launch arguments: --screenshots, --reset-onboarding, --force-feature-flag work | Test infrastructure | medium |
| G21 | No TODO or FIXME comments blocking release | Code readiness | low |
| G22 | CocoaPods / SPM dependencies up to date (no security vulnerabilities) | Security | medium |
| G23 | Info.plist: privacy descriptions for camera, location, etc. if used | App Store requirement | high |
| G24 | Provisioning profile valid and not expired | Signing | critical |
| G25 | No rejected API usage (private APIs, deprecated frameworks) | App Store review | high |

## H. MARKETING & GROWTH INFRASTRUCTURE (20 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| H01 | Twitter/X account exists and has posted in last 7 days | Social presence | medium |
| H02 | Instagram account exists and has posted in last 7 days | Social presence | medium |
| H03 | Pinterest account exists | Social presence | low |
| H04 | Telegram group (@GoodWatchIndia) exists and is accessible | Community | medium |
| H05 | Buffer account connected and has scheduled posts | Automation | medium |
| H06 | Newsletter (Resend) can send test email | Growth pipeline | medium |
| H07 | Blog has at least 5 posts published | Content marketing | medium |
| H08 | App Store listing: screenshots, description, keywords present | ASO | high |
| H09 | App Store listing: privacy policy URL valid | Legal | critical |
| H10 | App Store listing: support URL valid | Legal | high |
| H11 | Google Play: closed testing track has >= 12 testers | Android launch | high |
| H12 | Analytics: Firebase configured and receiving events | Data collection | high |
| H13 | Analytics: key events tracked (pick_for_me, watch_now, not_tonight, feedback) | Event coverage | high |
| H14 | SEO: Google Search Console verified | Organic discovery | high |
| H15 | SEO: at least 1000 pages indexed by Google | Organic traffic | medium |
| H16 | Referral or sharing mechanism exists (share movie pick) | Viral growth | medium |
| H17 | GitHub Actions: all workflows green (no failing crons) | Automation health | medium |
| H18 | DigitalOcean VPS: monitoring active | Infrastructure | medium |
| H19 | Domain: goodwatch.movie DNS healthy, no pending issues | Infrastructure | critical |
| H20 | SSL certificate valid and not expiring within 30 days | Security | high |

## I. RETENTION & ADDICTION LOOP (25 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| I01 | Taste engine builds profile from FIRST interaction (no cold start delay) | Engagement | critical |
| I02 | Each interaction updates tag weights immediately (within session) | INV-L03 | critical |
| I03 | Tag weight changes are visible in next recommendation (same session) | Feedback loop | critical |
| I04 | 2nd session recommendations differ from 1st (profile divergence) | Learning proof | critical |
| I05 | User with 5+ watch_now interactions gets measurably different picks than new user | Profile impact | critical |
| I06 | Mood selection changes recommendations significantly (not just cosmetic) | Mood system | critical |
| I07 | GoodScore varies across picks (not all 80-85 range) | Score diversity | high |
| I08 | Carousel offers genuine variety: different genres, languages within picks | Discovery diversity | high |
| I09 | "Surprise me" mood surfaces genuinely different movies than other moods | Wildcard behavior | high |
| I10 | Time-of-day signal works: late night picks have higher quality floor | Context awareness | medium |
| I11 | Post-watch feedback prompt triggers reliably | Feedback collection | high |
| I12 | Watchlist: user can save movies and retrieve them later | Utility | high |
| I13 | Session length: typical flow from "Pick for me" to "Watch now" < 30 seconds | Speed | high |
| I14 | Re-engagement: push notification brings user back to app | Retention hook | medium |
| I15 | Progressive constraint: 5→4→3→2→1 cards as trust builds | INV-R12 | critical |
| I16 | New user gets high-confidence, recognizable titles (not obscure catalog) | First impression | critical |
| I17 | New user recency gate working: no pre-2010 movies for new users | Feature flag | high |
| I18 | Card rejection (-0.05 implicit skip) teaches engine | Learning signal | high |
| I19 | Multiple sessions in a day: 2nd session picks differ from 1st | Session freshness | critical |
| I20 | After 10 interactions: recommendation quality noticeably improves (lower regret) | Learning curve | critical |
| I21 | User profile data persists across app reinstall (Supabase sync) | Cloud backup | critical |
| I22 | Watchlist data persists across app reinstall (Supabase sync) | Cloud backup | critical |
| I23 | Tag weights data persists across app reinstall (Supabase sync) | Cloud backup | critical |
| I24 | GoodScore explanation is understandable (not just a number) | Trust building | medium |
| I25 | "Why this" copy provides meaningful movie context | Decision confidence | high |

## J. SECURITY & COMPLIANCE (10 checks)

| ID | Check | Source | Severity |
|----|-------|--------|----------|
| J01 | RLS enabled on all user-data tables | Supabase security | critical |
| J02 | No PII stored in plain text (passwords, tokens) | Privacy | critical |
| J03 | Apple Sign-In compliant with Apple guidelines | App Store | critical |
| J04 | Google Sign-In compliant with Google guidelines | Play Store | critical |
| J05 | Privacy policy URL accessible and accurate | Legal | critical |
| J06 | Terms of service URL accessible | Legal | high |
| J07 | GDPR/data deletion: mechanism exists for user data removal | Compliance | high |
| J08 | No third-party tracking without consent | Privacy | high |
| J09 | API rate limiting in place (Supabase defaults) | Security | medium |
| J10 | No exposed admin endpoints without authentication | Security | critical |

---

**TOTAL: 260 checks** (30+30+35+30+30+25+25+20+25+10)

## Severity Distribution
- Critical: ~75 checks (must pass for launch)
- High: ~110 checks (should pass, blockers if many fail)
- Medium: ~55 checks (nice to have, fix post-launch if needed)
- Low: ~5 checks (cosmetic)

## Automated vs Manual
- ~200 checks can be automated (Supabase queries, HTTP checks, file checks, build tests)
- ~30 checks need iOS simulator (build, screenshot tests, smoke tests)
- ~20 checks need manual verification (visual inspection, flow testing)
- ~10 checks are infrastructure checks (DNS, SSL, external services)
