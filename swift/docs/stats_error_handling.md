# Stats Error Handling Implementation

## Overview

The stats screen has been enhanced with comprehensive error handling to prevent displaying 'Error (4xx)' pages and ensure users always see meaningful content or fallback to old stats when available.

## Key Features

### 1. Error Detection
- **HTTP Status Code Detection**: Automatically detects 4xx HTTP status codes
- **HTML Content Analysis**: Scans downloaded HTML for error indicators
- **Page Title Analysis**: Checks for error-related titles
- **Content Length Validation**: Identifies suspiciously short content

### 2. Retry Logic
- **Exponential Backoff**: Retries with increasing delays (1s, 2s, 4s)
- **Maximum 3 Retries**: Prevents infinite retry loops
- **Network Error Handling**: Handles connection failures gracefully

### 3. Fallback Mechanism
- **Old Stats Backup**: Automatically backs up current stats before downloading new ones
- **Automatic Restoration**: Restores old stats when new download fails
- **Graceful Degradation**: Shows user-friendly message when no stats available

### 4. User Experience
- **Immediate Display**: Shows cached content immediately while downloading
- **Loading States**: Clear loading indicators during download
- **Error Messages**: User-friendly error messages with actionable information

## Implementation Details

### MasterViewController Changes

#### `statsButtonTapped(_:)`
- Enhanced to handle retry logic and fallback
- Manages file backup and restoration
- Coordinates with WebViewController for error handling

#### `downloadStatsWithRetry(maxRetries:currentRetry:fileUrl:oldStatsUrl:fileExists:oldFileExists:)`
- Implements retry logic with exponential backoff
- Detects HTTP errors and invalid content
- Manages file operations safely

#### `handleStatsDownloadError(currentRetry:maxRetries:fileUrl:oldStatsUrl:fileExists:oldFileExists:)`
- Handles retry logic and fallback decisions
- Implements exponential backoff timing

#### `fallbackToOldStats(fileUrl:oldStatsUrl:fileExists:oldFileExists:)`
- Restores old stats when available
- Shows error message when no fallback available

#### `isErrorPage(_:)`
- Comprehensive error detection in HTML content
- Checks for multiple error indicators
- Validates content length and structure

### WebViewController Changes

#### Enhanced Navigation Delegates
- `webView(_:didFinish:)`: Checks loaded content for errors
- `webView(_:didFailProvisionalNavigation:withError:)`: Handles navigation failures
- `checkForErrorPage(_:)`: Analyzes page content for errors

#### Error Handling Methods
- `handleStatsPageError()`: Coordinates with MasterViewController
- `showStatsUnavailableMessage()`: Displays user-friendly error page

## Error Detection Criteria

### HTTP Status Codes
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 4xx: Any other client error

### HTML Content Indicators
- "Error (4xx)" patterns
- "404", "403", "401", "400" in content
- "not found", "forbidden", "unauthorized"
- "bad request", "page not found"
- "access denied", "server error"
- "temporarily unavailable", "service unavailable"

### Content Validation
- Content length < 100 characters (suspiciously short)
- Error indicators in page title
- Basic HTML error page structure

## File Management

### Backup Strategy
1. Before downloading new stats, current `stats.html` is moved to `stats.html.old`
2. New content is written to `stats.html`
3. If new content is valid, old backup is deleted
4. If new content is invalid, old backup is restored

### Fallback Process
1. When error detected, check for `stats.html.old`
2. If old file exists, restore it to `stats.html`
3. If no old file, show error message
4. Refresh WebView with restored content

## User Experience Flow

### Normal Operation
1. User taps Stats button
2. Cached content displayed immediately (if available)
3. New content downloaded in background
4. WebView refreshed with new content when ready

### Error Handling Flow
1. User taps Stats button
2. Cached content displayed immediately (if available)
3. Download attempt fails or returns error
4. Retry up to 3 times with exponential backoff
5. If all retries fail, attempt to restore old stats
6. If no old stats available, show error message

### Error Message Display
- Clean, app-themed error page
- Clear explanation of the issue
- Suggestion to try again later
- Consistent with app's dark theme

## Testing

### Test Coverage
- Valid stats content detection
- 404/403 error detection
- Short content detection
- Retry logic validation
- Fallback mechanism testing
- Complete error handling flow

### Test Files
- `statsErrorHandlingTest.swift`: Comprehensive test suite
- Mock classes for isolated testing
- Various error scenarios covered

## Benefits

1. **Reliability**: Users never see raw error pages
2. **Resilience**: Automatic retry and fallback mechanisms
3. **User Experience**: Seamless experience even during errors
4. **Data Preservation**: Old stats preserved for fallback
5. **Maintainability**: Clear error handling patterns

## Future Enhancements

1. **Offline Mode**: Cache stats for offline viewing
2. **Background Refresh**: Periodic stats updates
3. **User Notifications**: Alert users when stats are updated
4. **Analytics**: Track error rates and retry success rates
5. **Custom Error Pages**: More detailed error information 