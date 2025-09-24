//
//  CurrentYearQuickFix.swift
//  70000TonsBands
//
//  QUICK FIX for the recurring "Current Year" synchronization issue
//  Problem: Changing from numeric year to "Current" dismisses preferences before data loads
//

import Foundation

// MARK: - Current Year Synchronization Fix

extension PreferencesViewModel {
    
    // REPLACE the existing logic around lines 733-760 in performYearChangeWithFullLogic()
    // 
    // CURRENT PROBLEMATIC CODE:
    // } else {
    //     // For "Current" year - dismisses immediately before data loads
    //     let isActualYearChangeToCurrentBool = ...
    //     if isActualYearChangeToCurrentBool {
    //         hideExpiredEvents = true
    //         // ... setup code ...
    //         navigateBackToMainScreen()  // ❌ TOO EARLY!
    //     }
    // }
    //
    // REPLACE WITH THIS:
    
    @MainActor
    private func handleCurrentYearChangeCompletion() async {
        let isActualYearChangeToCurrentBool = (currentYearSetting != eventYearChangeAttempt && eventYearChangeAttempt == "Current") || (!currentYearSetting.isYearString && eventYearChangeAttempt == "Current")
        
        print("🎯 [CURRENT_YEAR_FIX] Handling Current year change completion")
        print("🎯 [CURRENT_YEAR_FIX] - currentYearSetting: '\(currentYearSetting)'")
        print("🎯 [CURRENT_YEAR_FIX] - eventYearChangeAttempt: '\(eventYearChangeAttempt)'")
        print("🎯 [CURRENT_YEAR_FIX] - isActualYearChangeToCurrentBool: \(isActualYearChangeToCurrentBool)")
        
        if isActualYearChangeToCurrentBool {
            print("🎯 [CURRENT_YEAR_FIX] This IS a year change TO Current - waiting for resolution")
            
            // Auto-enable hideExpiredEvents for Current year
            hideExpiredEvents = true
            setHideExpireScheduleData(true)
            
            // CRITICAL: Wait for Current year to be properly resolved
            await waitForCurrentYearResolution()
            
        } else {
            print("🎯 [CURRENT_YEAR_FIX] This is NOT a year change TO Current - dismissing immediately")
            // Not a year change TO Current, safe to dismiss immediately
            isLoadingData = false
            navigateBackToMainScreen()
        }
    }
    
    @MainActor
    private func waitForCurrentYearResolution() async {
        print("🔄 [CURRENT_YEAR_FIX] Waiting for Current year resolution...")
        
        // Keep loading state active - don't dismiss yet
        // isLoadingData should remain true
        
        var attempts = 0
        let maxAttempts = 15 // 15 attempts = 7.5 seconds max wait
        
        while attempts < maxAttempts {
            attempts += 1
            print("🔄 [CURRENT_YEAR_FIX] Resolution attempt \(attempts)/\(maxAttempts)")
            
            // Check if Current year has been resolved to actual numeric year
            let currentEventYear = eventYear
            let resolvedYear = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let yearString = getPointerUrlData(keyValue: "eventYear")
                    DispatchQueue.main.async {
                        continuation.resume(returning: yearString)
                    }
                }
            }
            
            print("🔄 [CURRENT_YEAR_FIX] Current eventYear: \(currentEventYear), resolved: '\(resolvedYear)'")
            
            // Check if we have valid data
            let bandCount = bandNamesHandler.shared.getBandNames().count
            print("🔄 [CURRENT_YEAR_FIX] Band count: \(bandCount)")
            
            // Success conditions:
            // 1. We have a valid resolved year
            // 2. We have band data loaded
            // 3. eventYear matches resolved year
            if !resolvedYear.isEmpty,
               let resolvedYearInt = Int(resolvedYear),
               resolvedYearInt == currentEventYear,
               bandCount > 0 {
                
                print("✅ [CURRENT_YEAR_FIX] Current year successfully resolved!")
                print("✅ [CURRENT_YEAR_FIX] - Resolved to year: \(resolvedYearInt)")
                print("✅ [CURRENT_YEAR_FIX] - Band data loaded: \(bandCount) bands")
                
                // Write preferences to ensure consistency
                writeFiltersFile()
                
                // Success - safe to dismiss
                isLoadingData = false
                navigateBackToMainScreen()
                return
            }
            
            // Wait 0.5 seconds before next attempt
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Timeout reached - show error but still dismiss to prevent stuck state
        print("⚠️ [CURRENT_YEAR_FIX] Current year resolution timed out after \(maxAttempts) attempts")
        print("⚠️ [CURRENT_YEAR_FIX] Dismissing anyway to prevent stuck preferences screen")
        
        showNetworkError = true
        isLoadingData = false
        
        // Still navigate back even on timeout to prevent stuck preferences
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigateBackToMainScreen()
        }
    }
}

// MARK: - Usage Instructions

/*
 
 TO APPLY THIS FIX:
 
 1. In PreferencesViewModel.swift, find the performYearChangeWithFullLogic() method
 
 2. Look for the section around lines 733-760 that handles "Current" year:
    
    } else {
        // For "Current" year - only auto-enable hideExpiredEvents if this is an actual year change TO Current
        let isActualYearChangeToCurrentBool = (currentYearSetting != eventYearChangeAttempt && eventYearChangeAttempt == "Current") || (!currentYearSetting.isYearString && eventYearChangeAttempt == "Current")
        // ... existing code ...
        navigateBackToMainScreen()  // ← THIS IS THE PROBLEM LINE
    }
 
 3. REPLACE that entire else block with this single line:
    
    } else {
        await handleCurrentYearChangeCompletion()
    }
 
 4. ADD the two methods from this file (handleCurrentYearChangeCompletion and waitForCurrentYearResolution) to your PreferencesViewModel class
 
 5. TEST:
    - Start in 2024 (numeric year)
    - Change to "Current" in preferences
    - Should see loading spinner (not immediate dismissal)
    - Should show correct current year data when loading completes
    - Should NOT show stale 2024 data
 
 WHAT THIS FIX DOES:
 - Keeps preferences screen open until Current year is properly resolved
 - Waits for actual data to load before dismissing
 - Shows loading state during resolution
 - Has timeout protection to prevent stuck preferences
 - Ensures consistent state before navigation
 
 */

