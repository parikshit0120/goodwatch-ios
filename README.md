# GoodWatch iOS

Mood-based movie discovery app built with SwiftUI.

## Features

- **Onboarding** - Mood and genre preference selection
- **Tonight's Pick** - Time-sensitive daily recommendation
- **Discover** - Tinder-style swipe interface for movie discovery
- **Watchlist** - Save movies to watch later
- **Curated Lists** - Browse themed movie collections
- **Profile** - View stats and achievements
- **Movie Details** - Rich information with AI-powered insights

## Tech Stack

- SwiftUI
- Supabase backend
- TMDB for movie data
- Gemini AI for recommendations

## Architecture

```
GoodWatch/
├── GoodWatchApp.swift      # App entry point
├── Models.swift            # Data models
├── Theme.swift             # Design system
├── GoodWatchViewModel.swift # Main view model
├── OnboardingViews.swift   # Onboarding flow
├── HomeView.swift          # Home with Tonight's Pick
├── DiscoverView.swift      # Swipe interface
├── WatchlistView.swift     # Saved movies
├── ListsHubView.swift      # Curated collections
├── ProfileView.swift       # User profile
├── MovieDetailView.swift   # Movie details
└── MoreViews.swift         # Additional screens
```

## Setup

1. Open `GoodWatch.xcodeproj` in Xcode
2. Configure your Supabase credentials
3. Build and run

## License

Proprietary - GoodWatch
