# Quick Reference - 70K Bands Swift App

## 🚨 Critical Rules (Never Break These)

### 1. No Force Unwrapping
```swift
// ❌ CRASH RISK
let value = optionalValue!

// ✅ SAFE
guard let value = optionalValue else { return }
```

### 2. No Main Thread Blocking
```swift
// ❌ UI FREEZE
let data = DispatchQueue.main.sync { fetchData() }

// ✅ ASYNC
fetchData { result in
    DispatchQueue.main.async {
        // Update UI
    }
}
```

### 3. No Infinite Loops
```swift
// ❌ DEADLOCK
while true { processData() }

// ✅ BOUNDED
var attempts = 0
while attempts < maxAttempts {
    if processData() { break }
    attempts += 1
}
```

### 4. Use Singleton Patternbrew
```swift
// ❌ WRONG
let handler = MyHandler()

// ✅ CORRECT
let handler = MyHandler.shared
```

## 🔧 Common Patterns

### Safe Data Access
```swift
// Thread-safe dictionary access
private let lock = NSLock()
private var _data = [String: String]()

var data: [String: String] {
    get {
        lock.lock()
        defer { lock.unlock() }
        return _data
    }
    set {
        lock.lock()
        defer { lock.unlock() }
        _data = newValue
    }
}
```

### Async with Timeout
```swift
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        completion(.success(data))
    }
    task.resume()
    
    // Timeout after 10 seconds
    DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
        task.cancel()
        completion(.failure(NetworkError.timeout))
    }
}
```

### Debounced Notifications
```swift
private var lastNotificationTime: Date = Date.distantPast
private let debounceInterval: TimeInterval = 0.1

func postNotification() {
    let now = Date()
    guard now.timeIntervalSince(lastNotificationTime) >= debounceInterval else {
        return
    }
    lastNotificationTime = now
    NotificationCenter.default.post(name: .myNotification, object: nil)
}
```

### Defensive Programming
```swift
// Type checking before operations
guard let dict = jsonData as? [String: Any] else {
    print("[BAND_DEBUG] Invalid data format")
    return
}

// Safe array access
guard index < array.count else {
    print("[BAND_DEBUG] Index out of bounds")
    return
}
```

### Memory Leak Prevention
```swift
// Use weak self in closures
DispatchQueue.global().async { [weak self] in
    guard let self = self else { return }
    // Do work
}

// Remove notification observers
deinit {
    NotificationCenter.default.removeObserver(self)
}
```

## 🐛 Debugging Patterns

### Debug Logging
```swift
print("[BAND_DEBUG] Starting operation")
print("[BAND_DEBUG] Operation complete")
```

### Error Handling
```swift
do {
    let data = try JSONSerialization.jsonObject(with: jsonData)
    // Process data
} catch {
    print("[BAND_DEBUG] JSON parsing error: \(error)")
    // Handle error
}
```

### Timeout Pattern
```swift
let semaphore = DispatchSemaphore(value: 0)
var result: Data = Data()

DispatchQueue.global().async {
    result = self.fetchData()
    semaphore.signal()
}

_ = semaphore.wait(timeout: .now() + 0.1)
return result
```

## 📋 Checklist Before Committing

- [ ] No `!` force unwrapping
- [ ] No `DispatchQueue.main.sync`
- [ ] No `while true` loops
- [ ] Using `.shared` for singletons
- [ ] Added `[BAND_DEBUG]` logs
- [ ] Proper error handling
- [ ] Timeouts for async operations
- [ ] Weak references in closures
- [ ] Thread-safe data access
- [ ] Debounced notifications

## 🚨 Emergency Fixes

### When You See a Crash
1. **Check stack trace** - identify the line
2. **Look for force unwrapping** - replace with safe unwrapping
3. **Add defensive checks** - validate data before use
4. **Test the fix** - ensure it works
5. **Add logging** - help debug future issues

### When UI Freezes
1. **Check for main thread blocking** - look for `DispatchQueue.main.sync`
2. **Check for infinite loops** - look for `while true`
3. **Add timeouts** - prevent infinite waiting
4. **Use async operations** - move work to background

### When Data is Corrupted
1. **Check for race conditions** - look for shared mutable state
2. **Add proper locking** - use NSLock or DispatchQueue
3. **Validate data types** - add defensive type checks
4. **Test with multiple threads** - ensure thread safety

## ⚡ Performance Tips

### QoS Levels
```swift
.userInitiated    // User-initiated tasks
.userInteractive  // UI updates
.utility         // Background maintenance
.background      // Low-priority tasks
```

### Caching
```swift
// Cache frequently accessed data
private var cachedData: [String: Any]?

// Invalidate cache when needed
func invalidateCache() {
    cachedData = nil
}
```

### Batch Operations
```swift
// Process data in batches
let batchSize = 100
for i in stride(from: 0, to: data.count, by: batchSize) {
    let batch = Array(data[i..<min(i + batchSize, data.count)])
    processBatch(batch)
}
```

## 📞 Quick Commands

```bash
# Run SwiftLint
swiftlint --config .swiftlint.yml

# Run pre-commit checks
./pre-commit-hook.sh

# Check for force unwrapping
grep -r --include="*.swift" -n "!" .

# Check for main thread blocking
grep -r --include="*.swift" -n "DispatchQueue\.main\.sync" .

# Check for infinite loops
grep -r --include="*.swift" -n "while\s\+true" .
```

Remember: **Small, focused changes prevent big problems!** 