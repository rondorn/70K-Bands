//
//  MinimumVersionWarningManager.swift
//  70000TonsBands
//
//  Created by Cursor on 2026-01-15.
//

import Foundation
import UIKit

/// Displays an "outdated app version" warning when the pointer file specifies a higher minimum version.
///
/// Requirements implemented:
/// - Read `Current::androidMinimum` from the cached pointer file.
/// - Compare against the installed iOS app version.
/// - If outdated, show a message prompting update.
/// - Only show once per 7 days, unless the minimum version value changes (then show again immediately).
final class MinimumVersionWarningManager {
    
    private enum DefaultsKeys {
        static let lastShownAt = "MinVersionWarningLastShownAt"
        static let lastSeenMinimum = "MinVersionWarningLastSeenMinimum"
    }
    
    // IMPORTANT: iOS should use iosMinimum (Android will use androidMinimum in the next phase).
    private static let minimumKeyInPointerFile = "iosMinimum"
    private static let oneWeekSeconds: TimeInterval = 7 * 24 * 60 * 60
    
    static func checkAndShowIfNeeded(reason: String) {
        let defaults = UserDefaults.standard
        
        guard let minimumVersion = readPointerCurrentValue(key: minimumKeyInPointerFile), !minimumVersion.isEmpty else {
            print("🧩 [MIN_VERSION] No Current::\(minimumKeyInPointerFile) found in cached pointer file (reason: \(reason))")
            return
        }
        
        guard let installedVersion = installedAppVersion(), !installedVersion.isEmpty else {
            print("🧩 [MIN_VERSION] Could not determine installed app version (reason: \(reason))")
            return
        }
        
        let isOutdated = isVersion(installedVersion, lessThan: minimumVersion)
        print("🧩 [MIN_VERSION] Installed=\(installedVersion) Minimum=\(minimumVersion) Outdated=\(isOutdated) (reason: \(reason))")
        
        guard isOutdated else {
            return
        }
        
        let lastSeenMinimum = defaults.string(forKey: DefaultsKeys.lastSeenMinimum) ?? ""
        let lastShownAt = defaults.object(forKey: DefaultsKeys.lastShownAt) as? Date
        
        let minimumChanged = (lastSeenMinimum != minimumVersion)
        let weekPassed: Bool
        if let lastShownAt {
            weekPassed = Date().timeIntervalSince(lastShownAt) >= oneWeekSeconds
        } else {
            weekPassed = true
        }
        
        guard minimumChanged || weekPassed else {
            print("🧩 [MIN_VERSION] Suppressing alert (shown <7 days ago and minimum unchanged)")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let presenter = topMostViewController() else {
                print("🧩 [MIN_VERSION] No presenter available to show alert")
                return
            }
            
            // Avoid stacking alerts if something else is already presenting one.
            if presenter is UIAlertController {
                print("🧩 [MIN_VERSION] Topmost VC is already an alert; skipping min-version alert")
                return
            }
            
            let message = NSLocalizedString(
                "OutdatedAppVersionMessage",
                comment: "Shown when installed app version is older than the minimum supported version"
            )
            let alert = UIAlertController(title: FestivalConfig.current.appName, message: message, preferredStyle: .alert)
            let okTitle = NSLocalizedString("Ok", comment: "OK button")
            alert.addAction(UIAlertAction(title: okTitle, style: .default, handler: nil))
            presenter.present(alert, animated: true, completion: nil)
            
            defaults.set(Date(), forKey: DefaultsKeys.lastShownAt)
            defaults.set(minimumVersion, forKey: DefaultsKeys.lastSeenMinimum)
            defaults.synchronize()
            
            print("🧩 [MIN_VERSION] Alert displayed and recorded (minimumChanged=\(minimumChanged), weekPassed=\(weekPassed))")
        }
    }
    
    // MARK: - Pointer file parsing
    
    private static func readPointerCurrentValue(key: String) -> String? {
        let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
        guard FileManager.default.fileExists(atPath: cachedPointerFile) else {
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
            if content.isEmpty {
                return nil
            }
            
            // Expected line format: "Current::androidMinimum::<version>"
            for rawLine in content.components(separatedBy: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty {
                    continue
                }
                
                if line.hasPrefix("Current::\(key)::") {
                    let components = line.components(separatedBy: "::")
                    if components.count >= 3 {
                        return components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Fallback parsing in case of unexpected spacing but correct delimiter count.
                let components = line.components(separatedBy: "::")
                if components.count >= 3,
                   components[0].trimmingCharacters(in: .whitespacesAndNewlines) == "Current",
                   components[1].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                    return components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("🧩 [MIN_VERSION] Failed reading cached pointer file: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Version comparison
    
    private static func installedAppVersion() -> String? {
        // Prefer the marketing version (e.g., 2.3.1); fall back to build number if needed.
        let info = Bundle.main.infoDictionary
        if let short = info?["CFBundleShortVersionString"] as? String, !short.isEmpty {
            return short
        }
        if let build = info?["CFBundleVersion"] as? String, !build.isEmpty {
            return build
        }
        return nil
    }
    
    private static func isVersion(_ version: String, lessThan other: String) -> Bool {
        let a = normalizeVersionComponents(version)
        let b = normalizeVersionComponents(other)
        let maxCount = max(a.count, b.count)
        
        for i in 0..<maxCount {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv {
                return av < bv
            }
        }
        return false
    }
    
    private static func normalizeVersionComponents(_ version: String) -> [Int] {
        // Keep only digits and '.'; treat non-numeric components as 0.
        return version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ".")
            .map { part -> Int in
                let digits = part.filter { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
    
    // MARK: - Presentation
    
    private static func topMostViewController() -> UIViewController? {
        // Prefer AppDelegate window if present (this project uses a single window setup).
        let root = appDelegate?.window?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        guard let root else { return nil }
        
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}

