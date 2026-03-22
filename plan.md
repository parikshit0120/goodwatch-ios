# Plan: Profile Button + Delete Account

## Task 1: Add Delete Account to ProfileTab.swift

**File:** `GoodWatch/App/screens/explore/ProfileTab.swift`

In the `accountSection` computed property (line 339), add a "Delete Account" button below the existing "Sign Out" button:
- Add `@State private var showDeleteConfirmation: Bool = false` state
- Add a Divider + "Delete Account" button row (red text, `trash` icon) below Sign Out
- Add `.alert("Delete Account", isPresented: $showDeleteConfirmation)` with destructive confirmation
- On confirm: call `UserService.shared.deleteAccount()` async, then `handleSignOut()`
- Apple requires: confirmation dialog before account deletion (App Review Guideline 5.1.1(v))

## Task 2: Add `onProfile` closure to 6 onboarding/result screens

Add `var onProfile: (() -> Void)? = nil` parameter and a `person.circle` button next to the existing `house.fill` button on each screen:

| Screen | File | Where to add |
|--------|------|-------------|
| MoodSelectorView | `screens/MoodSelectorView.swift` | Next to `house.fill` at line ~96-103 |
| PlatformSelectorView | `screens/PlatformSelectorView.swift` | Next to `house.fill` at line ~48-51 |
| LanguagePriorityView | `screens/LanguagePriorityView.swift` | Next to `house.fill` at line ~76-79 |
| DurationSelectorView | `screens/DurationSelectorView.swift` | Next to `house.fill` at line ~98-102 |
| MainScreenView | `screens/MainScreenView.swift` | Next to `house.fill` at line ~222-228 |
| PickCarouselView | `screens/PickCarouselView.swift` | Next to `house.fill` at line ~65-69 |

Pattern: Add `person.circle` button RIGHT BEFORE the `house.fill` button in each header HStack.

## Task 3: Wire up profile sheet in RootFlowView.swift

**File:** `GoodWatch/App/screens/RootFlowView.swift` (PROTECTED)

- Add `@State private var showProfileSheet: Bool = false`
- Add `.sheet(isPresented: $showProfileSheet)` presenting ProfileTab in a NavigationView with dark background
- Pass `onProfile: { showProfileSheet = true }` to each screen instantiation (MoodSelector, PlatformSelector, LanguagePriority, DurationSelector, MainScreenView via mainScreenContent, PickCarouselView)

## Files modified:
1. `ProfileTab.swift` — Add Delete Account button + confirmation alert
2. `MoodSelectorView.swift` — Add `onProfile` param + button
3. `PlatformSelectorView.swift` — Add `onProfile` param + button
4. `LanguagePriorityView.swift` — Add `onProfile` param + button
5. `DurationSelectorView.swift` — Add `onProfile` param + button
6. `MainScreenView.swift` — Add `onProfile` param + button (PROTECTED)
7. `PickCarouselView.swift` — Add `onProfile` param + button
8. `RootFlowView.swift` — Add sheet state + wire closures (PROTECTED)

## Build & install after all changes
