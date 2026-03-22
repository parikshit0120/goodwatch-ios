# GoodWatch - Quick Start Guide

## 🚀 Open & Run in 3 Steps

### Step 1: Open Xcode Project
```bash
cd "/Users/parikshitjhajharia/Desktop/Personal/GoodWatch CodeBase/goodwatch-ios"
open GoodWatch.xcodeproj
```

### Step 2: Select Simulator
In Xcode toolbar:
- Click device dropdown
- Select **"iPhone 15 Pro"** (or any iOS 17+ device)

### Step 3: Build & Run
- Press **Cmd+R** (or click ▶️ Play button)
- Wait ~30 seconds for build + simulator launch
- App opens automatically

---

## ✅ What's New

### 1. Brighter Landing Screen
- "GoodWatch" wordmark now clearly visible (strengthened gradient)
- No more text getting lost in poster background

### 2. Rejection Buttons Work!
**Already fully implemented - they track user behavior:**
- ✅ Logs to Supabase (`interactions` table)
- ✅ Updates dimensional learning (too_long, not_in_mood, not_interested)
- ✅ Tracks platform bias (Netflix rejects, Prime accepts, etc.)
- ✅ Adjusts tag weights (avoids similar movies next time)
- ✅ Records decision timing (how long user deliberated)

**To verify**: Tap "Not tonight" → "Too long" → Check Xcode console for logs:
```
📊 Learning signal recorded: too_long for user <UUID>
📊 Platform reject recorded: Netflix for user <UUID>
✅ Recorded interaction: not_tonight for movie <UUID>
```

### 3. Explore Feature
**NEW: Search/browse 22,370+ movies**
- Tap magnifying glass icon (top-right of Main Screen)
- 3 tabs: **Discover** | **New Releases** | **By Platform**
- Search, filter (6 categories), sort, browse grid
- Movie detail sheets with "Watch On" badges

---

## 🧪 Test Flow

1. **Launch app** → Landing screen (posters + GoodWatch branding)
2. **Tap "Pick for me"** → Onboarding flow (mood, platforms, duration)
3. **Get recommendation** → Main screen with GoodScore
4. **Test rejection**:
   - Tap "Not tonight"
   - Tap "Too long"
   - New movie loads
   - Check console for learning logs ✅
5. **Test explore**:
   - Tap magnifying glass icon 🔍
   - Try search: "inception"
   - Apply filters: Genre → Action, Sci-Fi
   - Tap movie card → Detail sheet opens
   - Tap back arrow → Returns to Main Screen

---

## 📂 New Files (All Included in Project)

**Explore Feature** (11 files):
```
GoodWatch/App/screens/explore/
├── DiscoverTab.swift
├── DiscoverViewModel.swift
├── FilterSheet.swift
├── MovieDetailSheet.swift
├── MovieGridCard.swift
├── NewReleasesTab.swift
├── NewReleasesViewModel.swift
├── PlatformTab.swift
├── PlatformViewModel.swift
└── SortMenuSheet.swift

GoodWatch/App/screens/
└── ExploreView.swift

GoodWatch/App/Services/
└── ExploreService.swift
```

**Modified Files** (3):
- `LandingView.swift` (brighter gradient)
- `MainScreenView.swift` (added explore icon)
- `RootFlowView.swift` (wired explore navigation)

---

## 🐛 Troubleshooting

### Build Errors?
**Missing files in Xcode:**
1. Right-click `GoodWatch/App/screens` folder
2. "Add Files to GoodWatch..."
3. Select `explore/` folder with all Swift files
4. ✅ Check "Copy items if needed"
5. ✅ Check target: "GoodWatch"
6. Click Add

### No Movies in Explore?
- Check internet connection
- Verify Supabase credentials in `.env`
- Check Xcode console for error logs

### Rejection Buttons Silent?
- Open Debug console: Cmd+Shift+Y
- Run in Debug mode (not Release)
- User must be authenticated (completes onboarding)

---

## 📊 User Learning System (How It Works)

When user taps **"Too long"**:

1. **Supabase Log**:
   ```json
   {
     "user_id": "abc-123",
     "movie_id": "def-456",
     "action": "not_tonight",
     "rejection_reason": "Too long",
     "created_at": "2024-02-10T12:00:00Z"
   }
   ```

2. **Dimensional Learning** (local):
   ```json
   {
     "too_long": 5,
     "not_in_mood": 2,
     "not_interested": 1
   }
   ```

3. **Platform Bias** (local):
   ```json
   {
     "accepts": {"Netflix": 10, "Prime Video": 5},
     "rejects": {"Netflix": 2, "Jio Hotstar": 1}
   }
   ```

4. **Tag Weights** (local):
   ```json
   {
     "feel_good": 1.2,
     "uplifting": 1.1,
     "dark": 0.8,
     "heavy": 0.7
   }
   ```

5. **Next Recommendation**:
   - Engine uses all this data
   - Avoids similar emotional tags
   - Prefers shorter runtimes
   - Suggests different platform

**Over time**: App learns your taste and gets better!

---

## 🎯 Key Features

✅ **Smart Recommendations** - Learns from every interaction
✅ **22,370+ Movies** - Complete catalog with filters
✅ **6 OTT Platforms** - Netflix, Prime, JioHotstar, Apple TV+, Zee5, SonyLIV
✅ **Behavior Tracking** - Every tap builds your profile
✅ **Explore Mode** - Search, filter, browse anytime
✅ **Tag Weights** - Personalized scoring system
✅ **Platform Bias** - Learns which OTTs you prefer
✅ **Decision Timing** - Tracks deliberation patterns

---

## 📱 Deploy to Physical iPhone

**Requirements**:
- iPhone with iOS 17+
- USB cable
- Free Apple Developer account

**Steps**:
1. Connect iPhone via USB
2. Select iPhone from device menu (replace simulator)
3. Xcode → Signing & Capabilities → Select Team (your Apple ID)
4. Cmd+R to build
5. On iPhone: Settings → General → Device Management → Trust profile
6. App runs on device!

---

## 🎉 You're Ready!

**Xcode Project**: Fully configured with all new files
**Visual Issues**: Fixed (brighter text on landing screen)
**Rejection Logic**: Already working (tracks all user behavior)
**Explore Feature**: Complete with search, filters, sort

**Just open Xcode and press Cmd+R!**

---

## 📚 Documentation

- `EXPLORE_IMPLEMENTATION.md` - Complete feature breakdown
- `VISUAL_FIXES_AND_DEPLOYMENT.md` - Detailed deployment guide
- Xcode console logs - Real-time debugging

**Questions?** Check the console logs or review the detailed guides above.
