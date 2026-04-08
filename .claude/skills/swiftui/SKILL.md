# SwiftUI Expert Skill

## Overview
This is a comprehensive agent skill for writing, reviewing, and improving SwiftUI code with emphasis on modern best practices, state management, performance optimization, and iOS 26+ features like Liquid Glass.

## Core Operating Principles

The skill establishes eight foundational rules:

1. **Always consult latest API references first** to avoid deprecated patterns
2. **Prioritize native SwiftUI** over UIKit/AppKit bridging when possible
3. **Remain architecture-agnostic**—focus on correctness, not MVVM/VIPER enforcement
4. **Encourage separation of concerns** without mandating specific approaches
5. **Follow Apple's HIG standards** for consistency
6. **Gate Liquid Glass adoption** to explicit user requests
7. **Present optimizations as suggestions**, not requirements
8. **Use `#available` gating** with sensible iOS version fallbacks

## Task Workflows

**Code Review Path:**
- Identify applicable topics from the router
- Flag deprecated APIs against reference materials
- Validate version gating and fallback implementations

**Code Improvement Path:**
- Audit against topic-specific guidance
- Replace deprecated APIs systematically
- Refactor hot paths and extract complex views
- Suggest optional optimizations like image downsampling

**New Feature Implementation:**
- Design data flow before writing views
- Structure views for optimal diffing via early subview extraction
- Apply animation patterns correctly
- Ensure all interactive elements use `Button` with accessibility labels
- Gate version-specific features with fallbacks

## Topic Router Reference Matrix

The skill provides 20 reference documents covering:
- State management and property wrappers
- View composition and structure
- Performance optimization patterns
- List handling and ForEach best practices
- Layout techniques
- Navigation and sheets
- ScrollView patterns
- Focus management
- Animation (basics, transitions, advanced)
- Accessibility implementation
- Swift Charts and chart accessibility
- Image optimization
- Liquid Glass (iOS 26+)
- macOS-specific patterns (scenes, window styling, views)
- Deprecated API transitions

## Hard Rules Checklist

Twelve non-negotiable correctness requirements:
- `@State` must be `private`
- `@Binding` limited to child-modifies-parent scenarios
- Never declare passed parameters as `@State` or `@StateObject`
- Correct property wrapper usage: `@StateObject` for owned objects, `@ObservedObject` for injected
- iOS 17+: use `@State` with `@Observable`; `@Bindable` for injected observables
- `ForEach` requires stable identity (never `.indices` for dynamic content)
- Constant view count per `ForEach` iteration
- `.animation(_:value:)` always requires the value parameter
- `@FocusState` must be `private`
- No redundant focus state writes in gesture handlers
- iOS 26+ APIs require `#available` gating with fallbacks
- Chart imports must be present where chart types are used

## Reference Documentation Structure

All 20 reference documents follow consistent patterns addressing specific SwiftUI domains with modern API transitions, implementation patterns, and practical guidance for iOS 15 through 26 compatibility.
