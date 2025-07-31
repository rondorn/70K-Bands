# 70K Bands Swift App - Coding Rules

## Core Principles

### 1. Avoid Deadlocks and Delays
- **Never use blocking operations on the main thread**
- **Use async/await or completion handlers for long-running operations**
- **Implement timeouts for all network and file operations**
- **Use DispatchQueue with appropriate QoS levels**
- **Avoid nested locks or complex synchronization patterns**

### 2. Prevent Infinite Loops
- **Always implement exit conditions in loops**
- **Use debouncing for notification handlers**
- **Implement request deduplication**
- **Add maximum retry limits**
- **Use timeouts for all async operations**

### 3. Thread Safety Guidelines
- **Use singleton pattern for shared resources**
- **Implement proper locking with NSLock or DispatchQueue**
- **Avoid global mutable state when possible**
- **Use atomic operations for simple counters/flags**
- **Implement defensive programming with type checks**

### 4. Data Collection Rules
- **Background data loading only**
- **UI updates on main thread only**
- **Cache data to avoid repeated network calls**
- **Implement fallback mechanisms for network failures**
- **Use local CSV files as backup data sources**

## Specific Implementation Rules

### Singleton Pattern
```swift
// ✅ Correct
open class MyHandler {
    static let shared = MyHandler()
    private init() { /* setup */ }
}

// ❌ Wrong
let handler = MyHandler() // Creates new instance
```

### Thread-Safe Operations
```swift
// ✅ Correct - Non-blocking with timeout
func getData() -> Data {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Data = Data()
    DispatchQueue.global().async {
        result = self.fetchData()
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 0.1)
    return result
}

// ❌ Wrong - Blocking operation
func getData() -> Data {
    return DispatchQueue.global().sync { self.fetchData() }
}
```

### Defensive Programming
```swift
// ✅ Correct - Safe unwrapping
guard let value = optionalValue else {
    print("Warning: Value is nil")
    return defaultValue
}

// ❌ Wrong - Force unwrapping
let value = optionalValue! // Can crash
```

### Notification Debouncing
```swift
// ✅ Correct - Debounced notifications
private var lastNotificationTime: Date = Date.distantPast
private let notificationDebounceInterval: TimeInterval = 0.1

func postNotification() {
    let now = Date()
    guard now.timeIntervalSince(lastNotificationTime) >= notificationDebounceInterval else {
        return
    }
    lastNotificationTime = now
    NotificationCenter.default.post(name: .myNotification, object: nil)
}
```

### Data Collection Coordination
```swift
// ✅ Correct - Coordinated data loading
class DataCollectionCoordinator {
    private var isCollecting = false
    private let collectionQueue = DispatchQueue(label: "dataCollection")
    
    func requestCollection() {
        collectionQueue.async {
            guard !self.isCollecting else { return }
            self.isCollecting = true
            // Start collection
        }
    }
}
```

## Error Handling Rules

### Network Operations
```swift
// ✅ Correct - Timeout and error handling
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

### File Operations
```swift
// ✅ Correct - Safe file reading
func readFile(path: String) -> String? {
    guard FileManager.default.fileExists(atPath: path) else {
        print("File does not exist: \(path)")
        return nil
    }
    
    do {
        return try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        print("Error reading file: \(error)")
        return nil
    }
}
```

## Performance Rules

### Memory Management
- **Use weak references in closures to prevent retain cycles**
- **Implement proper cleanup in deinit methods**
- **Avoid strong reference cycles in notification observers**

### Caching Strategy
- **Cache frequently accessed data**
- **Implement cache invalidation strategies**
- **Use appropriate cache sizes to prevent memory issues**

### Background Processing
- **Use DispatchQueue.global(qos: .userInitiated) for user-initiated tasks**
- **Use DispatchQueue.global(qos: .utility) for background maintenance**
- **Use DispatchQueue.global(qos: .background) for low-priority tasks**

## Code Review Checklist

Before committing code, ensure:

- [ ] No force unwrapping (`!`) without proper validation
- [ ] All async operations have timeouts
- [ ] No blocking operations on main thread
- [ ] Proper error handling implemented
- [ ] Thread-safe access to shared resources
- [ ] Debouncing for frequent events
- [ ] Singleton pattern used for shared handlers
- [ ] Defensive programming with type checks
- [ ] No infinite loops or recursive calls without limits
- [ ] Proper cleanup in deinit methods

## Common Anti-Patterns to Avoid

### ❌ Don't Do This
```swift
// Force unwrapping
let value = optionalValue!

// Blocking main thread
let data = DispatchQueue.main.sync { fetchData() }

// No timeout
URLSession.shared.dataTask(with: url) { data, response, error in
    // No timeout handling
}

// Infinite loop potential
while true {
    processData()
}

// Nested locks
lock1.lock()
lock2.lock()
// Deadlock risk
```

### ✅ Do This Instead
```swift
// Safe unwrapping
guard let value = optionalValue else { return }

// Async with completion
fetchData { result in
    DispatchQueue.main.async {
        // Update UI
    }
}

// With timeout
let task = URLSession.shared.dataTask(with: url) { data, response, error in
    // Handle response
}
task.resume()
DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
    task.cancel()
}

// Bounded loop
var attempts = 0
while attempts < maxAttempts {
    if processData() { break }
    attempts += 1
}

// Single lock or use DispatchQueue
DispatchQueue(label: "myQueue").async {
    // Thread-safe operation
}
```

## Testing Rules

### Unit Tests
- **Test all error conditions**
- **Test timeout scenarios**
- **Test thread safety**
- **Test memory leaks**

### Integration Tests
- **Test data collection coordination**
- **Test cache behavior**
- **Test network failure scenarios**

## Documentation Requirements

- **Document all public methods with clear parameter and return descriptions**
- **Document thread safety guarantees**
- **Document timeout values and retry logic**
- **Document error handling behavior**

## Emergency Fixes

When dealing with crashes or performance issues:

1. **Identify the root cause** - don't just add more error handling
2. **Make minimal changes** to fix the specific issue
3. **Test thoroughly** before deploying
4. **Add logging** to help debug future issues
5. **Consider the impact** on other parts of the system

## Version Control

- **Make small, focused commits**
- **Use descriptive commit messages**
- **Test changes before committing**
- **Review code for rule violations** 