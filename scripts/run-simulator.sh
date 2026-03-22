#!/bin/bash

# Configuration
PROJECT_DIR="/Users/parikshitjhajharia/Desktop/personal/GoodWatch CodeBase/goodwatch-ios"
PROJECT_NAME="GoodWatch"
SCHEME="GoodWatch"
SIMULATOR_NAME="iPhone 16 Pro"
SIMULATOR_ID="E1B942FC-9E41-4DC1-982A-A5B2A9D09912"
BUNDLE_ID="com.parikshit.goodwatch.movies"

echo "🔄 Stopping all running simulators..."
xcrun simctl shutdown all 2>/dev/null

# Terminate the app if running
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null

echo "🔨 Building app..."
xcodebuild -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$PROJECT_DIR/DerivedData" \
    build 2>&1 | grep -E "(error:|warning:|BUILD|Compiling)" || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📱 Booting simulator..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true

echo "🖥️  Opening Simulator app..."
open -a Simulator

# Wait for simulator to be ready
sleep 2

echo "📲 Installing app..."
APP_PATH=$(find "$PROJECT_DIR/DerivedData" -name "*.app" -type d | head -1)
if [ -n "$APP_PATH" ]; then
    xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
    echo "🚀 Launching app..."
    xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
    echo "✅ App launched successfully!"
else
    echo "❌ Could not find built app"
    exit 1
fi
