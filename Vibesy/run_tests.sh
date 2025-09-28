#!/bin/bash

# Vibesy iOS App - Test Runner Script
# This script runs the comprehensive unit test suite

set -e

echo "🧪 Starting Vibesy Unit Tests..."
echo "======================================="

# Change to project directory
cd /Users/alexandercleoni/Business/Clients/FoundAVibe/Development/vibesy-ios-app/Vibesy

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -project Vibesy.xcodeproj -scheme Vibesy

# Run unit tests
echo "🚀 Running unit tests..."
xcodebuild test \
    -project Vibesy.xcodeproj \
    -scheme Vibesy \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults.xcresult

# Generate test report
echo "📊 Generating test report..."
if command -v xcresult >/dev/null 2>&1; then
    xcresult get --format json --path TestResults.xcresult > test_results.json
    echo "✅ Test results saved to test_results.json"
else
    echo "⚠️  xcresult tool not found. Install Xcode command line tools to generate detailed reports."
fi

echo "======================================="
echo "✅ Unit tests completed!"
echo ""
echo "📋 Test Summary:"
echo "- Domain Models: Event, UserProfile, Guest, PriceDetails"
echo "- Services: EnhancedSecurityService, VibesyUserPasswordService, EventModel" 
echo "- Business Logic: Validation, error handling, async operations"
echo "- Security: Password validation, encryption, rate limiting"
echo "- Performance: Memory usage, execution speed"
echo ""
echo "📁 Test files created:"
echo "  - VibesyTests/Domain/EventTests.swift"
echo "  - VibesyTests/Domain/UserProfileTests.swift"
echo "  - VibesyTests/Services/EnhancedSecurityServiceTests.swift"
echo "  - VibesyTests/Services/VibesyUserPasswordServiceTests.swift"
echo "  - VibesyTests/Services/EventModelTests.swift"