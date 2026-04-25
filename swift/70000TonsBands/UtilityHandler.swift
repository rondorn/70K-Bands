//
//  UtilityHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/15/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit


    
func showAlert (_ message: String, title:String){
    
    let alert = UIAlertView()
    if (message.isEmpty == false){
        
        if (title.isEmpty == false){
            alert.title = title
        } else {
            alert.title = FestivalConfig.current.appName
        }
        
        alert.message = message
        alert.addButton(withTitle: "Ok")
        alert.show()
    }
}

func displayTimeIn24() -> Bool {
    
    var is24 = false
    
    let locale = NSLocale.current
    let formatter : String = DateFormatter.dateFormat(fromTemplate: "j", options:0, locale:locale)!
    if formatter.contains("a") {
        is24 = false
    } else {
        is24 = true
    }
    
    return is24
}

func formatTimeValue(timeValue: String) -> String {
    
    var newDate = ""
    
    if (timeValue.isEmpty == false){
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        
        let date = dateFormatter.date(from: timeValue)
        
        if (displayTimeIn24() == false){
            dateFormatter.dateFormat = "h:mma"
        }
        if (date != nil){
            newDate = dateFormatter.string(from: date!)
        }
    }
    
    return newDate
}

func getDateFormatter() -> DateFormatter {
    
    let dateFormatter = DateFormatter()
    
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.timeStyle = DateFormatter.Style.short
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    return dateFormatter
}

// MARK: - Schedule date normalization

/// Calendar dates in SQLite / schedule data use a single canonical storage form; UI uses the user's locale.
enum ScheduleDateNormalization {

    /// Stored in SQLite `date` column and schedule dictionaries for calendar dates (not festival labels like `Day 1`).
    static let canonicalDateFormat = "yyyy-MM-dd"

    /// Normalize CSV / legacy calendar strings to canonical `yyyy-MM-dd`. Returns nil if unparseable or non-calendar (e.g. festival day label).
    static func canonicalStorageCalendarDate(from source: String) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isFestivalDayLabel(trimmed) {
            return nil
        }
        guard let date = parseCalendarDateOnly(trimmed) else { return nil }
        return formatCanonicalStorageString(from: date)
    }

    private static func isFestivalDayLabel(_ s: String) -> Bool {
        s.range(of: "^Day\\s+\\d+", options: .regularExpression) != nil
    }

    /// Parses a calendar date string (canonical or common US CSV forms). Does not parse festival labels.
    static func parseCalendarDateOnly(_ source: String) -> Date? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isFestivalDayLabel(trimmed) else { return nil }

        let formats = [
            canonicalDateFormat,
            "yyyy-M-d",
            "M/d/yyyy",
            "MM/dd/yyyy",
            "M/d/yy",
            "MM/dd/yy",
            "yyyy/M/d",
        ]

        for format in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            df.dateFormat = format
            if let d = df.date(from: trimmed) {
                return d
            }
        }
        return nil
    }

    static func formatCanonicalStorageString(from date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = canonicalDateFormat
        return df.string(from: date)
    }

    /// User-visible string: **locale** short date for calendar values; festival day labels (`Day 1`) unchanged; unknown text unchanged.
    static func displayLocalizedScheduleField(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }
        if isFestivalDayLabel(t) {
            return t
        }
        if let d = parseCalendarDateOnly(t) {
            let out = DateFormatter()
            out.locale = .current
            out.timeZone = TimeZone.current
            out.dateStyle = .short
            out.timeStyle = .none
            return out.string(from: d)
        }
        return t
    }
}

/// Formats schedule **Day** column or embedded calendar text for display using the **current** locale.
func monthDateRegionalFormatting(dateValue: String) -> String {
    ScheduleDateNormalization.displayLocalizedScheduleField(dateValue)
}

// MARK: - Main list Day label (tag 10) — text only

/// Console filter tag: **`[DAY_LABEL_SWAP]`** (region probe once + every `d/d` label pass).
private enum DayLabelSwapLog {
    static var didLogRegionProbe = false
}

/// Strips ICU `'`…`'` literal spans from a date pattern so `d`/`m` positions are reliable.
private func stripICUQuotedFragmentsFromDatePattern(_ s: String) -> String {
    var out = ""
    var i = s.startIndex
    while i < s.endIndex {
        if s[i] == "'" {
            let after = s.index(after: i)
            if after < s.endIndex, s[after] == "'" {
                out.append("'")
                i = s.index(after: after)
                continue
            }
            var j = after
            while j < s.endIndex, s[j] != "'" { j = s.index(after: j) }
            i = (j < s.endIndex) ? s.index(after: j) : j
            continue
        }
        out.append(s[i])
        i = s.index(after: i)
    }
    return out
}

/// Region wants **day/month** ordering for short month+day (from localized `Md` pattern only).
private func regionUsesDayBeforeMonthForListDayLabel() -> Bool {
    let rawOpt = DateFormatter.dateFormat(fromTemplate: "Md", options: 0, locale: .current)
    let rawDisplay = rawOpt ?? "(nil)"
    let strippedLower: String
    let dayBeforeMonth: Bool
    if let raw = rawOpt {
        let p = stripICUQuotedFragmentsFromDatePattern(raw).lowercased()
        strippedLower = p
        if let dPos = p.firstIndex(where: { $0 == "d" || $0 == "j" }),
           let mPos = p.firstIndex(where: { $0 == "m" || $0 == "l" }) {
            dayBeforeMonth = dPos < mPos
        } else {
            dayBeforeMonth = false
        }
    } else {
        strippedLower = ""
        dayBeforeMonth = false
    }

    if !DayLabelSwapLog.didLogRegionProbe {
        DayLabelSwapLog.didLogRegionProbe = true
        print("[DAY_LABEL_SWAP] REGION_PROBE locale=\(Locale.current.identifier) calendar=\(Calendar.current.identifier) MdRaw=\(rawDisplay) MdStrippedLower=\(strippedLower) dayBeforeMonth=\(dayBeforeMonth)")
    }

    return dayBeforeMonth
}

/// Text for schedule **Day** label: **main list** `dayView` (tag 10) and **band detail** schedule row day cell. **Input is only that label string** (e.g. `1/26`; `Day 1` → stripped to `1` by callers). If it matches `digit(s)/digit(s)` and the region’s `Md` order is day-first, returns `day/month`; otherwise returns the same string unchanged. No other fields are read.
func dayListLabelTextForRegion(_ displayedDayText: String) -> String {
    let t = displayedDayText.trimmingCharacters(in: .whitespacesAndNewlines)
    let slashMatched = (t.range(of: #"^\d{1,2}/\d{1,2}$"#, options: .regularExpression) != nil)
    guard slashMatched else { return displayedDayText }

    let dayFirst = regionUsesDayBeforeMonthForListDayLabel()
    let parts = t.split(separator: "/", omittingEmptySubsequences: false)
    let out: String
    if dayFirst, parts.count == 2 {
        out = "\(parts[1])/\(parts[0])"
    } else {
        out = displayedDayText
    }

    print("[DAY_LABEL_SWAP] LABEL in='\(displayedDayText)' trimmed='\(t)' slashMatched=true regionDayFirst=\(dayFirst) out='\(out)'")
    return out
}
