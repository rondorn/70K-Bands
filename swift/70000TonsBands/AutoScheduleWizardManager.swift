//
//  AutoScheduleWizardManager.swift
//  70000TonsBands
//
//  When the pointer file has Current::AutoScheduleFlag = Yes and a schedule name,
//  offers to run the personalized schedule wizard (once per Current::AutoScheduleName).
//  Current::AutoScheduleFlagRepeat = Yes uses the "rerun" message; otherwise "create" message.
//

import Foundation
import UIKit

/// Reads Current::AutoScheduleFlag, AutoScheduleFlagRepeat, AutoScheduleName from the pointer file
/// and shows an alert to run the schedule wizard when appropriate.
/// Once the user runs the wizard for a given AutoScheduleName, it won't prompt again until the name changes.
final class AutoScheduleWizardManager {

    private static let defaultsKeyLastRunScheduleName = "AutoScheduleWizardLastRunScheduleName"
    private static let notificationPresentWizardWithoutAlert = "PresentAutoChooseAttendanceWizardWithoutAlert"
    private static let pointerKeys = (flag: "AutoScheduleFlag", repeat: "AutoScheduleFlagRepeat", name: "AutoScheduleName")

    /// Call when pointer data may have updated (e.g. after PointerDataUpdated).
    /// Reads pointer file; if AutoScheduleFlag=Yes and schedule not yet run for current AutoScheduleName, shows alert.
    /// Prompt is driven only by pointer file (AutoScheduleFlag=Yes). Other app config is not used.
    static func checkAndShowIfNeeded(reason: String) {
        guard let flag = readPointerCurrentValue(key: pointerKeys.flag), flag == "Yes" else {
            print("🧙 [AUTO_SCHEDULE] AutoScheduleFlag != Yes or missing, skipping (reason: \(reason))")
            return
        }

        // Use pointer schedule name when present; otherwise a stable default so wizard still runs when flag=Yes.
        let eventYearForName: Int = {
            if let y = readPointerCurrentValue(key: "eventYear"), let i = Int(y), i > 2000 { return i }
            return Int(getPointerUrlData(keyValue: "eventYear")) ?? Calendar.current.component(.year, from: Date())
        }()
        let scheduleName: String = {
            guard let name = readPointerCurrentValue(key: pointerKeys.name), !name.isEmpty else {
                return "Schedule-\(eventYearForName)"
            }
            return name
        }()

        let lastRun = UserDefaults.standard.string(forKey: defaultsKeyLastRunScheduleName) ?? ""
        if lastRun == scheduleName {
            print("🧙 [AUTO_SCHEDULE] Already ran wizard for '\(scheduleName)', skipping (reason: \(reason))")
            return
        }

        let isRepeat = (readPointerCurrentValue(key: pointerKeys.repeat) ?? "").lowercased() == "yes"
        let eventYear: Int = {
            if let y = readPointerCurrentValue(key: "eventYear"), let i = Int(y), i > 2000 { return i }
            return Int(getPointerUrlData(keyValue: "eventYear")) ?? Calendar.current.component(.year, from: Date())
        }()

        let messageKey = isRepeat ? "AutoScheduleReleasedRerunPrompt" : "AutoScheduleReleasedCreatePrompt"
        let messageFormat = NSLocalizedString(messageKey, comment: "Auto schedule released - offer wizard; first line includes %@ for Current::AutoScheduleName")
        let message = String(format: messageFormat, locale: Locale.current, scheduleName)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let presenter = topMostViewController() else {
                print("🧙 [AUTO_SCHEDULE] No presenter available")
                return
            }
            if presenter is UIAlertController {
                print("🧙 [AUTO_SCHEDULE] Topmost VC is already an alert; skipping")
                return
            }

            let title = NSLocalizedString("AutoChooseAttendanceTitle", comment: "Plan Your Schedule")
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.overrideUserInterfaceStyle = .dark
            let noTitle = NSLocalizedString("No", comment: "No button")
            let yesTitle = NSLocalizedString("Yes", comment: "Yes button")
            alert.addAction(UIAlertAction(title: noTitle, style: .cancel) { _ in
                UserDefaults.standard.set(scheduleName, forKey: defaultsKeyLastRunScheduleName)
                UserDefaults.standard.synchronize()
            })
            alert.addAction(UIAlertAction(title: yesTitle, style: .default) { _ in
                UserDefaults.standard.set(scheduleName, forKey: defaultsKeyLastRunScheduleName)
                UserDefaults.standard.synchronize()
                NotificationCenter.default.post(
                    name: Notification.Name(notificationPresentWizardWithoutAlert),
                    object: nil,
                    userInfo: ["eventYear": eventYear]
                )
            })
            presenter.present(alert, animated: true) {
                Self.applyDarkAlertBackground(alert)
            }
        }
    }

    // MARK: - Pointer file parsing

    /// Reads a key from the pointer file. Checks "Current", then the resolved event year (e.g. "2024", "2026"), then "Default",
    /// so the key is found whether the file uses Current::, year::, or Default:: lines.
    private static func readPointerCurrentValue(key: String) -> String? {
        let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
        guard FileManager.default.fileExists(atPath: cachedPointerFile) else {
            return nil
        }
        do {
            let content = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
            if content.isEmpty { return nil }
            var bySection: [String: [String: String]] = [:]
            for rawLine in content.components(separatedBy: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { continue }
                let parts = line.components(separatedBy: "::")
                guard parts.count >= 3 else { continue }
                let section = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let k = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let v = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                if bySection[section] == nil { bySection[section] = [:] }
                bySection[section]?[k] = v
            }
            let eventYearStr = bySection["Current"]?["eventYear"] ?? bySection["Default"]?["eventYear"]
            let order: [String] = ["Current", eventYearStr].compactMap { $0 } + (eventYearStr != nil ? [] : []) + ["Default"]
            let sectionsToTry = ["Current", eventYearStr, "Default"].compactMap { $0 }.uniqued()
            for section in sectionsToTry {
                if let value = bySection[section]?[key], !value.isEmpty {
                    return value
                }
            }
        } catch {
            print("🧙 [AUTO_SCHEDULE] Failed reading cached pointer file: \(error)")
        }
        return nil
    }

    /// Applies a much darker grey background to the alert card so it matches the app and improves text contrast.
    private static func applyDarkAlertBackground(_ alert: UIAlertController) {
        let veryDarkGrey = UIColor(white: 0.10, alpha: 1.0)
        if let card = alert.view.subviews.first {
            card.backgroundColor = veryDarkGrey
        }
    }

    private static func topMostViewController() -> UIViewController? {
        let root = appDelegate?.window?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        guard let root else { return nil }
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}
