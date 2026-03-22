#!/bin/bash

# Script to capture screenshots from iOS Simulator
# Usage: ./capture_screenshot.sh [screen_name]

SIMULATOR_ID="E1B942FC-9E41-4DC1-982A-A5B2A9D09912"
SCREENSHOT_DIR="/Users/parikshitjhajharia/Desktop/Personal/GoodWatch CodeBase/goodwatch-ios/UI Screenshots"

# Get screen name from argument or use timestamp
if [ -z "$1" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SCREEN_NAME="screenshot_${TIMESTAMP}"
else
    SCREEN_NAME="$1"
fi

# Capture screenshot
xcrun simctl io ${SIMULATOR_ID} screenshot "${SCREENSHOT_DIR}/${SCREEN_NAME}.png"

echo "Screenshot saved: ${SCREENSHOT_DIR}/${SCREEN_NAME}.png"
