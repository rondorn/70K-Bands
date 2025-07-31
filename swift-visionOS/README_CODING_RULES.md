# 70K Bands Swift App - Coding Rules Guide

## Overview

This document explains how to use the coding rules and tools to prevent deadlocks, delays, and infinite loops in the 70K Bands Swift app.

## Files Created

### 1. `CODING_RULES.md`
Comprehensive coding guidelines that establish:
- Core principles for avoiding deadlocks and delays
- Thread safety guidelines
- Data collection rules
- Specific implementation patterns
- Error handling rules
- Performance guidelines
- Code review checklist

### 2. `.swiftlint.yml`
SwiftLint configuration that enforces:
- No force unwrapping without comments
- No blocking operations on main thread
- No infinite loops
- Proper error handling
- Thread safety checks
- Custom rules for this codebase

### 3. `pre-commit-hook.sh`
Automated script that checks for:
- Force unwrapping violations
- Main thread blocking operations
- Infinite loops
- Nested locks
- Missing timeouts
- Singleton pattern violations
- Memory leak risks

## How to Use

### 1. Install SwiftLint (if not already installed)
```bash
# Using Homebrew
brew install swiftlint

# Or using CocoaPods
pod 'SwiftLint'
```

### 2. Run SwiftLint
```bash
# Run on entire project
swiftlint

# Run on specific file
swiftlint --path path/to/file.swift

# Auto-fix some issues
swiftlint --fix
```

### 3. Use Pre-commit Hook
```bash
# Make executable (already done)
chmod +x pre-commit-hook.sh

# Run manually
./pre-commit-hook.sh

# Set up as git hook
cp pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### 4. IDE Integration
Add to your Xcode project:
1. Go to Build Phases
2. Add New Run Script Phase
3. Add: `swiftlint --config .swiftlint.yml`

## Key Rules Summary

### ✅ Do This
```swift
// Safe unwrapping
guard let value = optionalValue else { return }

// Async with completion
fetchData { result in
    DispatchQueue.main.async {
        // Update UI
    }
}

// Singleton pattern
let handler = MyHandler.shared

// Defensive programming
guard let data = jsonData as? [String: Any] else {
    print("Invalid data format")
    return
}

// Proper timeout
let semaphore = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    // Do work
    semaphore.signal()
}
_ = semaphore.wait(timeout: .now() + 0.1)
```

### ❌ Don't Do This
```swift
// Force unwrapping
let value = optionalValue!

// Blocking main thread
let data = DispatchQueue.main.sync { fetchData() }

// Direct instantiation of singleton
let handler = MyHandler()

// Infinite loop
while true {
    processData()
}

// No timeout
DispatchQueue.global().async {
    // No timeout handling
}
```

## Common Issues and Solutions

### 1. Force Unwrapping Crashes
**Problem**: `Fatal error: Unexpectedly found nil while unwrapping an Optional value`

**Solution**: Use safe unwrapping
```swift
// Before
let value = optionalValue!

// After
guard let value = optionalValue else {
    print("Value is nil")
    return defaultValue
}
```

### 2. Infinite Loops
**Problem**: App becomes unresponsive due to infinite loops

**Solution**: Add exit conditions
```swift
// Before
while true {
    processData()
}

// After
var attempts = 0
while attempts < maxAttempts {
    if processData() { break }
    attempts += 1
}
```

### 3. Main Thread Blocking
**Problem**: UI freezes during data loading

**Solution**: Use async operations
```swift
// Before
let data = DispatchQueue.main.sync { fetchData() }

// After
fetchData { result in
    DispatchQueue.main.async {
        // Update UI
    }
}
```

### 4. Thread Safety Issues
**Problem**: Data corruption from concurrent access

**Solution**: Use proper synchronization
```swift
// Before
var sharedData = [String: String]()

// After
private let lock = NSLock()
private var _sharedData = [String: String]()
var sharedData: [String: String] {
    get {
        lock.lock()
        defer { lock.unlock() }
        return _sharedData
    }
    set {
        lock.lock()
        defer { lock.unlock() }
        _sharedData = newValue
    }
}
```

## Debugging Tips

### 1. Add Debug Logging
```swift
print("[BAND_DEBUG] Starting data collection")
print("[BAND_DEBUG] Data collection complete")
```

### 2. Check for Memory Leaks
```swift
// Use weak self in closures
DispatchQueue.global().async { [weak self] in
    guard let self = self else { return }
    // Do work
}
```

### 3. Monitor Thread Usage
```swift
print("[BAND_DEBUG] Running on thread: \(Thread.current)")
```

### 4. Add Timeouts
```swift
let timeoutWorkItem = DispatchWorkItem {
    print("[BAND_DEBUG] Operation timed out")
}
DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
```

## Performance Guidelines

### 1. Use Appropriate QoS Levels
```swift
// User-initiated tasks
DispatchQueue.global(qos: .userInitiated).async { }

// Background maintenance
DispatchQueue.global(qos: .utility).async { }

// Low-priority tasks
DispatchQueue.global(qos: .background).async { }
```

### 2. Cache Frequently Used Data
```swift
// Cache data to avoid repeated network calls
private var cachedData: [String: Any]?
```

### 3. Implement Debouncing
```swift
private var lastUpdateTime: Date = Date.distantPast
private let debounceInterval: TimeInterval = 0.1

func updateData() {
    let now = Date()
    guard now.timeIntervalSince(lastUpdateTime) >= debounceInterval else { return }
    lastUpdateTime = now
    // Perform update
}
```

## Emergency Procedures

### 1. When You Encounter a Crash
1. **Don't panic** - crashes are fixable
2. **Identify the root cause** - check the stack trace
3. **Make minimal changes** - fix only what's broken
4. **Test thoroughly** - ensure the fix works
5. **Add logging** - help debug future issues

### 2. When You Encounter Performance Issues
1. **Profile the code** - identify bottlenecks
2. **Check for infinite loops** - look for while true
3. **Check for blocking operations** - look for sync calls
4. **Check for memory leaks** - look for retain cycles
5. **Add timeouts** - prevent infinite waiting

### 3. When You Encounter Thread Issues
1. **Check for race conditions** - look for shared mutable state
2. **Check for deadlocks** - look for nested locks
3. **Use proper synchronization** - NSLock or DispatchQueue
4. **Test with multiple threads** - ensure thread safety

## Code Review Checklist

Before submitting code for review, ensure:

- [ ] No force unwrapping without proper validation
- [ ] All async operations have timeouts
- [ ] No blocking operations on main thread
- [ ] Proper error handling implemented
- [ ] Thread-safe access to shared resources
- [ ] Debouncing for frequent events
- [ ] Singleton pattern used for shared handlers
- [ ] Defensive programming with type checks
- [ ] No infinite loops or recursive calls without limits
- [ ] Proper cleanup in deinit methods
- [ ] Appropriate logging added
- [ ] Memory leaks prevented with weak references
- [ ] Performance impact considered

## Getting Help

If you encounter issues:

1. **Check the coding rules** - `CODING_RULES.md`
2. **Run SwiftLint** - `swiftlint --config .swiftlint.yml`
3. **Run pre-commit hook** - `./pre-commit-hook.sh`
4. **Add debug logging** - `print("[BAND_DEBUG] ...")`
5. **Test thoroughly** - ensure changes work as expected

Remember: **Small, focused changes are better than large, complex fixes.** 