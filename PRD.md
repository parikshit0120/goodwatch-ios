# GoodWatch iOS — Product Requirements Document

> **Version:** 1.0 (reverse-engineered from codebase, 2026-02-13)
> **Owner:** Parikshit Jhajharia
> **Status:** Live on App Store (Bundle: PJWorks.goodwatch.movies.v1)

---

## 1. PRODUCT VISION

**One-liner:** "Finally. Someone decided for me."

GoodWatch is a single-decision movie recommendation engine. Users answer 4 quick questions about their mood, platforms, language, and duration — and get exactly ONE movie recommendation backed by a composite GoodScore. No scrolling. No lists. No decision paralysis. Just press play.

A secondary "Explore" journey exists for users who want to browse/search the full catalog.

---

## 2. CORE PRINCIPLES

| Principle | What It Means |
|-----------|---------------|
| **One movie at a time** | Never show lists, grids, or multiple options in the Pick For Me flow |
| **Low regret over maximum delight** | GoodScore favors safe 8.0s over risky 9.5s |
| **Availability is a hard gate** | Never recommend something the user can't actually watch |
| **Causal justification** | Always connect the recommendation to the user's stated mood |
| **Feedback is enforced** | Post-watch feedback is mandatory — no silent progression |
| **Animated/kids content hidden** | Until user proves taste maturity (5+ accepted recommendations) |
| **Personalization through action** | Tag weights update on every watch/reject — the engine learns silently |

---

## 3. USER JOURNEYS

### Journey 1: "Pick For Me" (Core Product)

Linear flow — each screen collects one preference, builds UserContext.

```
Landing → Auth → Mood → Platforms+Languages → Duration → Emotional Hook → Loading → RECOMMENDATION
```

### Journey 2: "Explore" (Browse/Discover)

Tab-based catalog browsing — requires authentication.

```
Landing → ExploreAuth → ExploreView (6 tabs: Discover / New / Platform / Rent / Saved / Profile)
```

---

## 4. SCREEN-BY-SCREEN SPEC

### 4.1 Landing View

| | |
|---|---|
| **Purpose** | Entry point. Two CTAs split the user into journeys |
| **Primary CTA** | "Pick for me" → gold gradient button, full width |
| **Secondary CTA** | "Explore & Search" → dark gray outlined button |
| **Background** | 4x8 poster grid (32 hardcoded TMDB posters, tilted -8deg, 55% opacity) |
| **Navigation** | Pick for me: if authenticated → Mood; else → Auth. Explore: if authenticated → ExploreView; else → ExploreAuth |
| **Animation** | Logo fades in (600ms), text fades in (600ms +300ms delay), posters load concurrently then reveal together |

### 4.2 Auth View

| | |
|---|---|
| **Purpose** | Optional authentication. Users can skip to anonymous |
| **Auth Options** | Apple Sign-In, Google Sign-In, "Continue without account" |
| **Newsletter** | Opt-in toggle (default: ON), subscribes email to Supabase newsletter_subscribers |
| **Fallback** | If OAuth fails, silently falls back to anonymous |
| **Data Saved** | User created in Supabase, display name cached in UserDefaults |
| **Navigation** | On auth success → MoodSelector. On skip → MoodSelector (anonymous) |

### 4.3 Mood Selector (Step 1/4)

| | |
|---|---|
| **Purpose** | Establish desired emotional outcome |
| **Question** | "What's the vibe?" |
| **Options** | 5 mood cards with poster thumbnail: |
| | **Feel-good** — "Light and uplifting" (tags: feel_good, uplifting, safe_bet, light, calm) |
| | **Easy watch** — "Nothing too heavy" (tags: light, background_friendly, safe_bet, calm) |
| | **Surprise me** — "I'm open to anything" (tags: []) |
| | **Gripping** — "Edge of my seat" (tags: tense, high_energy, full_attention, medium) |
| | **Dark & Heavy** — "Hit me with the feels" (tags: dark, bittersweet, heavy, acquired_taste) |
| **Data** | ctx.mood + ctx.intent (includes energy, cognitive_load, intent_tags) |
| **Persistence** | Mood saved to Supabase user_profiles, step 2 saved to Keychain |
| **Navigation** | Next → PlatformSelector. Back → Auth. Home → Landing |

### 4.4 Platform Selector (Step 2/4)

| | |
|---|---|
| **Purpose** | Which OTT platforms + languages the user has access to |
| **Question** | "Which platforms do you have?" |
| **Platform Options** | Netflix, Prime Video, JioHotstar, Apple TV+, SonyLIV, Zee5 (3x2 grid with logos) |
| **Language Options** | 16 languages as chips. Auto-disabled if unavailable on selected platforms |
| **"Select All"** | Toggle to select/deselect all platforms |
| **Validation** | Must have >= 1 platform AND >= 1 language to proceed |
| **Data** | ctx.otts + ctx.languages |
| **Persistence** | Platforms + languages saved to Supabase, step 3 saved to Keychain |
| **Navigation** | Next → DurationSelector. Back → MoodSelector. Home → Landing |

### 4.5 Duration Selector (Step 3/4)

| | |
|---|---|
| **Purpose** | How long the user wants to watch |
| **Question** | "How long do you want to watch?" |
| **Options** | 3 cards: |
| | **90 minutes** — "Quick watch" (60-90 min) |
| | **2-2.5 hours** — "Full movie experience" (120-150 min) |
| | **Series/Binge** — "Multiple episodes" (sets requiresSeries=true, content_type="tv") |
| **Series Check** | When Series selected, queries Supabase to verify availability. Shows warning if limited |
| **Data** | ctx.minDuration, ctx.maxDuration, ctx.requiresSeries |
| **Persistence** | Runtime preference saved to Supabase, step 4 to Keychain |
| **Navigation** | Next → EmotionalHook. Back → PlatformSelector. Home → Landing |

### 4.6 Emotional Hook (Step 4/4)

| | |
|---|---|
| **Purpose** | Final pre-flight. Builds anticipation + runs availability pre-check |
| **Visual** | Blurred rotating movie posters with gold ring pulse animation |
| **Copy** | Sequential reveal: "Your perfect pick is ready." → "Matched to your mood, time, and taste." → "One tap. One pick. Done." |
| **CTA** | "Show me" (runs availability check before proceeding) |
| **Availability Alert** | If no matches found: overlay with explanation + options to change platforms/language/duration or "Try Anyway" |
| **Navigation** | Show me → ConfidenceMoment + triggers fetchRecommendation(). Back → DurationSelector. Home → Landing |

### 4.7 Confidence Moment (Loading)

| | |
|---|---|
| **Purpose** | Loading screen while engine runs. Builds anticipation |
| **Duration** | ~1.2 seconds (auto-completes) |
| **Visual** | 3 gold dots pulsing in wave pattern |
| **Copy** | "Finding your film..." + random movie trivia (15-item bank) |
| **Gate** | Only transitions to MainScreen when BOTH: min time elapsed AND recommendation ready |

### 4.8 Main Screen (THE PRODUCT)

| | |
|---|---|
| **Purpose** | THE recommendation reveal with GoodScore |
| **Poster** | 240x340pt, corner radius 16pt, content type badge (MOVIE/SERIES) |
| **Title** | 28pt bold, 2-line max |
| **Metadata** | Year + Runtime + Genre chips (max 3) |
| **"Why This"** | Causal copy connecting mood to recommendation (gold italic) |
| **Pitch** | First sentence of overview + director/cast line |
| **GoodScore** | Hero element: 64pt gold number in bordered box with glow animation |
| **Primary CTA** | "Watch on [Platform]" — gold gradient, opens OTT deep link |
| **Also Available** | Up to 3 additional platform chips |
| **Secondary** | "Not tonight" + "Already seen" text buttons |
| **Reveal Animation** | 7-step choreographed sequence over 1.6 seconds (see Section 7) |

### 4.9 Rejection Sheet (Overlay)

| | |
|---|---|
| **Purpose** | Collect rejection reason for engine learning |
| **Trigger** | "Not tonight" tap on MainScreen |
| **Visual** | Bottom sheet with dimmed background |
| **Question** | "Why not tonight?" |
| **Options** | "Too long" / "Not in the mood" / "Not interested" + "Just show me another" |
| **Learning** | Selected reason → -0.1 tag weight delta on movie's tags |

### 4.10 Post-Watch Feedback

| | |
|---|---|
| **Purpose** | Collect whether user actually watched the recommended movie |
| **Trigger** | App relaunch 2+ hours after "Watch Now" (scheduled by GWFeedbackEnforcer) |
| **Question** | "How was [Movie Title]?" |
| **Options** | "Finished it" (+0.15 tag delta) / "Didn't finish" (-0.1 tag delta) / "Skip" (no delta) |
| **Blocking** | Shown before any other screen until user responds |

### 4.11 Enjoy Screen

| | |
|---|---|
| **Purpose** | Confirmation after Watch Now pressed |
| **Visual** | Blurred movie backdrop, poster thumbnail, "Enjoy!" (gold) |
| **Options** | "Pick another" (gold CTA) / "Done for tonight" (text link) |
| **Auto-dismiss** | Returns to Landing after 5 seconds if no tap |

### 4.12 Explore View

| | |
|---|---|
| **Purpose** | Full catalog browse/search (secondary journey) |
| **Auth** | Mandatory (ExploreAuthView if not signed in) |
| **Tabs** | Discover (search+filter) / New Releases / By Platform / Rent / Watchlist / Profile |
| **Header** | Tab title + Home button (switch back to Pick For Me) |
| **Components** | 3-column movie grid, filter sheets, sort menus, movie detail modals |

---

## 5. DATA ARCHITECTURE

### 5.1 UserContext (Built Across Screens 1-4)

```swift
struct UserContext {
    var otts: [OTTPlatform]       // Platforms user subscribes to
    var mood: Mood                 // Emotional vibe
    var maxDuration: Int           // Runtime upper bound (minutes)
    var minDuration: Int           // Runtime lower bound (minutes)
    var languages: [Language]      // Preferred languages
    var intent: GWIntent           // Engine input (mood + energy + cognitive load + tags)
    var requiresSeries: Bool       // True → filter to content_type="tv"
}
```

### 5.2 GWIntent (Derived from Mood Selection)

```swift
struct GWIntent {
    let mood: String               // "feel_good", "light", "neutral", "intense", "dark"
    let energy: EnergyLevel        // .calm, .tense, .high_energy
    let cognitive_load: CognitiveLoad  // .light, .medium, .heavy
    let intent_tags: [String]      // Tags for engine matching
}
```

### 5.3 Interaction Logging

| Interaction | Trigger | Tag Weight Delta | Supabase Table |
|------------|---------|-----------------|----------------|
| `shown` | Movie displayed on MainScreen | None | user_interactions |
| `watch_now` | User taps Watch Now CTA | +0.15 on movie's tags | user_interactions |
| `not_tonight` | User rejects with reason | -0.1 on movie's tags | user_interactions |
| `already_seen` | User marks as seen | None | user_interactions |
| `show_another` | User wants different pick | -0.02 on movie's tags | user_interactions |
| `feedback_completed` | User finished watching | +0.15 on movie's tags | user_interactions |
| `feedback_abandoned` | User didn't finish | -0.1 on movie's tags | user_interactions |

### 5.4 User Maturity System

| Metric | Threshold | Effect |
|--------|-----------|--------|
| `watchNowCount` | >= 5 | `isMatureUser = true` → unlocks animated/kids content |
| `hasWatchedDocumentary` | true | Unlocks documentary recommendations |
| `hasWatchedKidsContent` | true | Allows kids content in future |

### 5.5 Decision Timing

Every recommendation tracks:
- `recommendationShownTime` — when movie was displayed
- `decisionSeconds` — time between display and accept/reject
- `wasAccepted` — boolean
- Threshold-gated: collected always, used for analytics after 20+ samples

---

## 6. RECOMMENDATION ENGINE

### 6.1 Pipeline

```
1. Fetch 1000 movies from Supabase
   (filtered by: languages, content_type)
     ↓
2. Validate each movie against profile
   (platform match, runtime window, excluded IDs, content gate)
     ↓
3. Score valid movies
   (composite_score + tag alignment + platform bias)
     ↓
4. Apply quality gate
   (minimum GoodScore: 7.5 immature / 7.0 mature)
     ↓
5. Return top-scoring movie
   OR fallback with relaxed filters
   OR empty state with stop condition
```

### 6.2 GoodScore Calculation

- Primary: `composite_score` (pre-calculated weighted average of TMDB + IMDB + RT + Metacritic)
- Fallback: `vote_average * 10` (when composite_score unavailable — 44% of catalog)
- Display: rounded to nearest integer, 0-100 scale

### 6.3 Fallback Levels

When no movie matches strict criteria, engine relaxes filters progressively:
1. Full match (all filters)
2. Relaxed tag matching (wider mood interpretation)
3. Relaxed runtime (expand by 30 minutes each direction)
4. Final: any available movie above quality gate

### 6.4 After Rejection ("Not Tonight")

- Uses `recommendAfterNotTonight()` — avoids movies with similar tags to rejected movie
- Expands excluded set with rejected movie ID
- Fetches historical exclusions (last 7 days rejected + last 30 days shown)

---

## 7. ANIMATION SPEC — MAIN SCREEN REVEAL

The recommendation reveal is the emotional core of the product. Timing is precise:

| Step | Time | Element | Animation |
|------|------|---------|-----------|
| 1 | 0ms | Poster | Fade in + scale 0.95→1.0 (400ms easeOut) |
| 2 | 600ms | Title | Fade in (300ms easeOut) |
| 3 | 700ms | GoodScore Box | Appear + scale 0.9→1.0 (100ms easeOut) |
| 4 | 800ms | GoodScore Number | Spring reveal: scale 0.8→1.05→1.0 + glow (500ms spring) |
| 5 | 1100ms | "Why This" copy | Fade in (300ms easeOut) |
| 6 | 1400ms | Watch Now button | Slide up 20pt + fade in (300ms easeOut) |
| 7 | 1600ms | Secondary actions | Fade in (200ms easeIn) |

---

## 8. DESIGN SYSTEM

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0A0A` | App background |
| Text Primary | `#E8E6E3` | Headlines, titles |
| Text Secondary | `#8E8E93` | Body, metadata |
| Gold Accent | `#D4AF37` | GoodScore, CTAs, emphasis only |
| Surface Dark | `#1C1C1E` | Cards, containers |
| Surface Border | White 10% | Subtle borders |

### Typography (SF Rounded)
| Style | Size | Weight |
|-------|------|--------|
| Score | 64pt | Bold |
| Title | 28pt | Bold |
| Headline | 24pt | Semibold |
| Button | 18pt | Semibold |
| Body | 16pt | Regular/Medium |
| Small | 14pt | Regular/Medium |
| Tiny | 12pt | Semibold |

### Spacing
- Screen padding: 24pt
- Element gap: 16pt
- Section gap: 32pt
- Border radius: 8/12/16/20pt (sm/md/lg/xl)

### Platform Colors
| Platform | Hex |
|----------|-----|
| Netflix | `#E50914` |
| Prime Video | `#00A8E1` |
| JioHotstar | `#1F80E0` |
| Apple TV+ | `#A2A2A2` |
| Zee5 | `#8230C6` |
| SonyLIV | `#555555` |

---

## 9. RESUME & PERSISTENCE

### Keychain (Onboarding Step)
- Step 2: Mood selected
- Step 3: Platforms + languages selected
- Step 4: Duration selected
- Step 5: Emotional hook passed
- Step 6+: Onboarding complete

On launch: if step 2-5 AND user authenticated → resume from saved screen. If step 6+ → always start fresh from Landing.

### UserDefaults
- `TagWeightStore` — per-user tag weights (`[String: Double]`)
- `WatchlistManager` — per-user saved movie IDs
- `gw_user_display_name` — cached display name from OAuth
- `gw_device_id` — device identifier
- `gw_user_id` — cached Supabase user ID

### Supabase (Server-Side)
- `user_profiles` — platforms, languages, mood preferences, runtime
- `user_interactions` — full interaction history (shown/accepted/rejected)
- `app_events` — analytics events (dual-logged with Firebase)

---

## 10. SUPPORTED CONTENT

### Languages (16)
English, Hindi, Tamil, Telugu, Malayalam, Korean, Kannada, Bengali, Marathi, Spanish, Japanese, French, Punjabi, Chinese, Portuguese, Gujarati

### OTT Platforms (6)
Netflix, Prime Video, JioHotstar, Apple TV+, Zee5, SonyLIV

### Content Types
- Movies (default)
- TV Series / Shows (when "Series/Binge" selected)

### Catalog
- 22,370+ titles in Supabase
- 44% lack IMDB ratings (fallback to TMDB vote_average)
- ~255 have full composite scores (OMDB enrichment ongoing)
- Daily enrichment via GitHub Actions (1000 movies/day OMDB free tier)

---

## 11. KNOWN LIMITATIONS

1. Apple Sign-In doesn't work in Simulator — physical device or TestFlight only
2. Composite scores incomplete — most movies fall back to TMDB vote_average
3. Series runtime may show total duration instead of per-episode
4. Newsletter data split across 2 Supabase projects (iOS vs web)
5. No offline support — requires network for all operations
6. Explore feature requires mandatory authentication (no guest browse)
