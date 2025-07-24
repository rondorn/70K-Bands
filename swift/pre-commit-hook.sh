#!/bin/bash

# Pre-commit hook for 70K Bands Swift App
# Checks for coding rule violations to prevent deadlocks, delays, and infinite loops

echo "🔍 Running pre-commit checks..."

# Check for force unwrapping without comments
echo "Checking for force unwrapping..."
if grep -r --include="*.swift" -n "!" . | grep -v "//.*force.*unwrap" | grep -v "//.*swiftlint.*disable"; then
    echo "❌ ERROR: Found force unwrapping without proper comments"
    echo "Please use safe unwrapping with guard let or if let, or add a comment explaining why force unwrap is necessary"
    exit 1
fi

# Check for blocking operations on main thread
echo "Checking for blocking operations on main thread..."
if grep -r --include="*.swift" -n "DispatchQueue\.main\.sync" .; then
    echo "❌ ERROR: Found blocking operations on main thread"
    echo "Please use async with completion handlers instead"
    exit 1
fi

# Check for infinite loops
echo "Checking for infinite loops..."
if grep -r --include="*.swift" -n "while\s\+true" .; then
    echo "❌ ERROR: Found potential infinite loops"
    echo "Please add exit conditions to prevent deadlocks"
    exit 1
fi

# Check for nested locks
echo "Checking for nested locks..."
if grep -r --include="*.swift" -A 5 -B 5 "\.lock()" . | grep -A 10 -B 10 "\.lock()" | grep -q "\.lock()"; then
    echo "❌ WARNING: Found potential nested locks"
    echo "Please review for deadlock risk"
fi

# Check for missing timeouts in async operations
echo "Checking for async operations without timeouts..."
if grep -r --include="*.swift" -n "DispatchQueue\.global.*async" . | grep -v "timeout"; then
    echo "⚠️  WARNING: Found async operations without explicit timeouts"
    echo "Consider adding timeouts to prevent infinite waiting"
fi

# Check for singleton pattern violations
echo "Checking for singleton pattern violations..."
if grep -r --include="*.swift" -n "MyHandler()\|bandNamesHandler()\|scheduleHandler()\|imageHandler()\|CustomBandDescription()" . | grep -v "shared"; then
    echo "❌ ERROR: Found direct instantiation of singleton classes"
    echo "Please use .shared instead of () for singleton classes"
    exit 1
fi

# Check for missing error handling
echo "Checking for missing error handling..."
if grep -r --include="*.swift" -n "try!" .; then
    echo "❌ ERROR: Found force try without error handling"
    echo "Please use proper error handling with do-catch blocks"
    exit 1
fi

# Check for memory leaks in closures
echo "Checking for potential memory leaks..."
if grep -r --include="*.swift" -n "\[weak self\]" . | wc -l | grep -q "0"; then
    echo "⚠️  WARNING: No weak self usage found in closures"
    echo "Consider using [weak self] in closures to prevent retain cycles"
fi

# Check for proper notification debouncing
echo "Checking for notification debouncing..."
if grep -r --include="*.swift" -n "NotificationCenter.*post" . | grep -v "debounce\|throttle"; then
    echo "⚠️  WARNING: Found notification posting without debouncing"
    echo "Consider implementing debouncing for frequent notifications"
fi

# Check for proper timeout values
echo "Checking for timeout values..."
if grep -r --include="*.swift" -n "timeout.*0\." . | grep -v "0\.[1-9]"; then
    echo "⚠️  WARNING: Found very short timeout values"
    echo "Consider using longer timeouts (0.1s or more) for network operations"
fi

# Check for proper QoS usage
echo "Checking for proper QoS usage..."
if grep -r --include="*.swift" -n "DispatchQueue\.global" . | grep -v "qos"; then
    echo "⚠️  WARNING: Found DispatchQueue.global without explicit QoS"
    echo "Please specify QoS level for better performance"
fi

# Check for defensive programming
echo "Checking for defensive programming..."
if grep -r --include="*.swift" -n "guard let\|if let" . | wc -l | grep -q "0"; then
    echo "⚠️  WARNING: No safe unwrapping found"
    echo "Consider using guard let or if let for safer code"
fi

# Check for proper cleanup
echo "Checking for proper cleanup..."
if grep -r --include="*.swift" -n "deinit" . | wc -l | grep -q "0"; then
    echo "⚠️  WARNING: No deinit methods found"
    echo "Consider adding cleanup code in deinit methods"
fi

# Check for proper logging
echo "Checking for proper logging..."
if grep -r --include="*.swift" -n "print.*\[BAND_DEBUG\]" . | wc -l | grep -q "0"; then
    echo "⚠️  WARNING: No debug logging found"
    echo "Consider adding [BAND_DEBUG] logs for better debugging"
fi

echo "✅ Pre-commit checks completed successfully!"
echo "📝 Remember to:"
echo "   - Test your changes thoroughly"
echo "   - Review for thread safety"
echo "   - Check for memory leaks"
echo "   - Ensure proper error handling"
echo "   - Add appropriate logging"

exit 0 