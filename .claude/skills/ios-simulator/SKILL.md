# iOS Simulator Skill

## Overview
The ios-simulator-skill is a comprehensive toolkit providing 21 production-ready scripts for iOS app testing, building, and automation. Version 1.3.0 emphasizes semantic UI navigation using accessibility APIs rather than pixel-based coordinates.

## Core Philosophy
The skill prioritizes "structured data instead of pixel coordinates" for interacting with iOS simulators. This approach leverages the accessibility tree—offering element types, labels, frames, and tap targets—as a more economical and reliable alternative to screenshot analysis.

## Script Categories (21 Total)

**Build & Development (2 scripts)**
- `build_and_test.py`: Xcode project building with live streaming and xcresult parsing
- `log_monitor.py`: Real-time logging with severity filtering and deduplication

**Navigation & Interaction (5 scripts)**
- `screen_mapper.py`: Current screen analysis with element breakdown
- `navigator.py`: Semantic element finding via text, type, or ID
- `gesture.py`: Swipes, scrolls, pinches, and complex gestures
- `keyboard.py`: Text input and hardware button control
- `app_launcher.py`: App lifecycle and deep link management

**Testing & Analysis (5 scripts)**
- `accessibility_audit.py`: WCAG compliance checking
- `visual_diff.py`: Screenshot pixel comparison
- `test_recorder.py`: Automated test documentation
- `app_state_capture.py`: Comprehensive debugging snapshots
- `sim_health_check.sh`: Environment verification

**Advanced Testing & Permissions (4 scripts)**
- `clipboard.py`, `status_bar.py`, `push_notification.py`, `privacy_manager.py`

**Device Lifecycle Management (5 scripts)**
- Boot, shutdown, create, delete, and erase simulator operations

## Key Features
- Auto-UDID detection and device name resolution
- Batch operations support
- JSON output for CI/CD integration
- Token-efficient output (10-50 tokens for accessibility trees vs. 1,600-6,300 for screenshots)
- Zero-configuration setup on macOS with Xcode
