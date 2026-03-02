//
//  AIScheduleBuilder.swift
//  70000TonsBands
//
//  Rule-based "Create AI schedule" builder. Uses sleep, Must/Might/Wont,
//  Meet and Greet and Clinic options, and resolves Must conflicts and
//  "both shows missed" for bands that play twice.
//

import Foundation

// MARK: - Step & Resolution

/// Result of one builder step; UI handles resolution then calls nextStep again.
enum AIScheduleBuildStep: Equatable {
    case completed([EventData])
    case needMustConflict(EventData, EventData)
    case needBothShowsMissed(bandName: String, showA: EventData, showB: EventData)
}

/// User resolution for a conflict; pass back into nextStep.
enum AIScheduleResolution {
    case mustConflict(choose: EventData)
    case bothShowsMissed(attendA: Bool, attendB: Bool, skipBand: Bool)
}

// MARK: - Builder

struct AIScheduleBuilder {
    let sleepHours: Int
    /// Latest show cutoff as half-hours from midnight (0=12:00am, 1=12:30am, ..., 11=5:30am). Shows starting after this time in late night are excluded.
    let latestShowCutoffHalfHours: Int?
    let markAllMustMeetAndGreets: Bool
    let markAllMustClinics: Bool
    let priorityManager: SQLitePriorityManager
    let eventYear: Int
    let eventYearString: String
    
    private var allCandidates: [EventData] = []
    private var chosen: Set<EventData> = []
    /// Events already marked will-attend; no new event may conflict with these (except M&G vs M&G).
    private var existingAttended: Set<EventData> = []
    private var candidateIndex: Int = 0
    private var checkedBothMissedBands: Set<String> = []
    private var phase: Phase = .buildingShows
    
    private enum Phase {
        case buildingShows
        case checkingBothMissed
    }
    
    init(sleepHours: Int, markAllMustMeetAndGreets: Bool, markAllMustClinics: Bool, priorityManager: SQLitePriorityManager, eventYear: Int, latestShowCutoffHalfHours: Int? = nil) {
        self.sleepHours = sleepHours
        self.latestShowCutoffHalfHours = latestShowCutoffHalfHours.map { min(11, max(0, $0)) }
        self.markAllMustMeetAndGreets = markAllMustMeetAndGreets
        self.markAllMustClinics = markAllMustClinics
        self.priorityManager = priorityManager
        self.eventYear = eventYear
        self.eventYearString = String(eventYear)
    }
    
    /// Build the candidate list (filter by sleep, type, priority) and return first step.
    /// - Parameter existingAttended: Events already marked will-attend; treated as mandatory (no new conflicts allowed except M&G vs M&G).
    mutating func start(events: [EventData], existingAttended: [EventData] = []) -> AIScheduleBuildStep {
        self.existingAttended = Set(existingAttended)
        let dayStops = computeDayStopTimes(events: events, sleepHours: sleepHours)
        var candidates: [EventData] = []
        
        for event in events {
            guard let date = event.date, let startTime = event.startTime, !startTime.isEmpty else { continue }
            let eventType = event.eventType ?? ""
            let priority = priorityManager.getPriority(for: event.bandName, eventYear: eventYear)
            
            // Sleep cutoff: do not include events that start after day stop time
            if let stop = dayStops[date], event.timeIndex >= stop {
                continue
            }
            
            // Shows: Must (1) or Might (2)
            if eventType == showType {
                if priority == 1 || priority == 2 {
                    if let cutoffHalfHours = latestShowCutoffHalfHours, shouldExcludeShowByLatestCutoff(startTime: startTime, cutoffHalfHours: cutoffHalfHours) {
                        continue
                    }
                    candidates.append(event)
                }
                continue
            }
            
            // Meet and Greet: only if option on and band is Must
            if eventType == meetAndGreetype {
                if markAllMustMeetAndGreets && priority == 1 {
                    candidates.append(event)
                }
                continue
            }
            
            // Clinic: only if option on and band is Must (clinics tied to bands)
            if eventType == clinicType {
                if markAllMustClinics && priority == 1 {
                    candidates.append(event)
                }
                continue
            }
            
            // Other types (Special, Unofficial, etc.): skip for AI schedule
        }
        
        allCandidates = candidates.sorted { $0.timeIndex < $1.timeIndex }
        chosen = self.existingAttended
        candidateIndex = 0
        checkedBothMissedBands = []
        phase = .buildingShows
        
        return nextStep(resolution: nil)
    }
    
    /// Continue building; pass nil when no resolution needed, or the user's choice after a prompt.
    mutating func nextStep(resolution: AIScheduleResolution?) -> AIScheduleBuildStep {
        if let res = resolution {
            switch res {
            case .mustConflict(choose: let ev):
                chosen.insert(ev)
                candidateIndex += 1
            case .bothShowsMissed(attendA: let a, attendB: let b, skipBand: _):
                if a, let showA = pendingShowA { chosen.insert(showA) }
                if b, let showB = pendingShowB { chosen.insert(showB) }
                if let band = pendingBandName { checkedBothMissedBands.insert(band) }
                pendingShowA = nil
                pendingShowB = nil
                pendingBandName = nil
            }
        }
        
        // Phase 1: walk show/M&G/clinic candidates and resolve overlaps
        if phase == .buildingShows {
            while candidateIndex < allCandidates.count {
                let event = allCandidates[candidateIndex]
                if chosen.contains(event) {
                    candidateIndex += 1
                    continue
                }
                
                let overlapping = chosen.filter { overlaps(event, $0) }
                // Existing attended are mandatory: no new event may conflict unless both are Meet and Greets.
                let conflictingExisting = overlapping.filter { existingAttended.contains($0) }
                if !conflictingExisting.isEmpty {
                    let eventIsMAndG = isMeetAndGreet(event)
                    let allConflictsAreMAndGOnly = conflictingExisting.allSatisfy { isMeetAndGreet($0) } && eventIsMAndG
                    if !allConflictsAreMAndGOnly {
                        candidateIndex += 1
                        continue
                    }
                    // M&G vs M&G: allow (person may only be there part of the time)
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                if overlapping.isEmpty {
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                
                let priorityEvent = priorityManager.getPriority(for: event.bandName, eventYear: eventYear)
                let isMust = (priorityEvent == 1)
                
                // If current is Might and all overlapping are Might, take first (this one)
                if !isMust && overlapping.allSatisfy({ priorityManager.getPriority(for: $0.bandName, eventYear: eventYear) == 2 }) {
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                
                // If one overlapping is Must and current is Might, skip current
                if !isMust && overlapping.contains(where: { priorityManager.getPriority(for: $0.bandName, eventYear: eventYear) == 1 }) {
                    candidateIndex += 1
                    continue
                }
                
                // Must vs Must (or Must vs Must in overlapping): need user choice
                if isMust, let other = overlapping.first(where: { priorityManager.getPriority(for: $0.bandName, eventYear: eventYear) == 1 }) {
                    return .needMustConflict(event, other)
                }
                
                // Might vs Might: pick first (already in chosen), skip current
                candidateIndex += 1
            }
            
            phase = .checkingBothMissed
        }
        
        // Phase 2: for each Must band with exactly 2 shows, if neither chosen → prompt
        if phase == .checkingBothMissed {
            let mustBands = Set(allCandidates.filter { priorityManager.getPriority(for: $0.bandName, eventYear: eventYear) == 1 }.map { $0.bandName })
            for bandName in mustBands where !checkedBothMissedBands.contains(bandName) {
                let showEvents = allCandidates.filter { $0.bandName == bandName && ($0.eventType ?? "") == showType }
                guard showEvents.count == 2 else { continue }
                let (showA, showB) = showEvents[0].timeIndex < showEvents[1].timeIndex ? (showEvents[0], showEvents[1]) : (showEvents[1], showEvents[0])
                if !chosen.contains(showA) && !chosen.contains(showB) {
                    pendingShowA = showA
                    pendingShowB = showB
                    pendingBandName = bandName
                    return .needBothShowsMissed(bandName: bandName, showA: showA, showB: showB)
                }
                checkedBothMissedBands.insert(bandName)
            }
        }
        
        return .completed(Array(chosen))
    }
    
    private var pendingShowA: EventData?
    private var pendingShowB: EventData?
    private var pendingBandName: String?
    
    private func overlaps(_ a: EventData, _ b: EventData) -> Bool {
        a.timeIndex < b.endTimeIndex && b.timeIndex < a.endTimeIndex
    }
    
    private func isMeetAndGreet(_ event: EventData) -> Bool {
        (event.eventType ?? "") == meetAndGreetype
    }
    
    /// Exclude show if it starts in late-night (12am–5:59am) *after* the chosen latest time. Cutoff is half-hours from midnight (0=12:00am, 11=5:30am).
    private func shouldExcludeShowByLatestCutoff(startTime: String, cutoffHalfHours: Int) -> Bool {
        guard let (hour, minutes) = parseHourAndMinutesFromStartTime(startTime) else { return false }
        let lateNightRange = 0..<6
        guard lateNightRange.contains(hour) else { return false }
        let cutoffHour = cutoffHalfHours / 2
        let cutoffMinutes = (cutoffHalfHours % 2) * 30
        if hour > cutoffHour { return true }
        if hour == cutoffHour { return minutes > cutoffMinutes }
        return false
    }
    
    /// Parses "1:00 AM", "2:30 AM" (12h) or "05:15", "00:30" (24h) to (hour 0-23, minutes 0-59). Returns nil if unparseable.
    private func parseHourAndMinutesFromStartTime(_ startTime: String) -> (Int, Int)? {
        let trimmed = startTime.trimmingCharacters(in: .whitespaces)
        let upper = trimmed.uppercased()
        let isPM = upper.contains("PM")
        let isAM = upper.contains("AM")
        if isAM || isPM {
            let numPart = trimmed
                .replacingOccurrences(of: "AM", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "PM", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            let components = numPart.split(separator: ":")
            guard let first = components.first.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) else { return nil }
            let minutes: Int
            if components.count > 1 {
                let minStr = String(components[1])
                let digits = minStr.prefix(while: { $0.isNumber })
                minutes = Int(digits).map { min(59, max(0, $0)) } ?? 0
            } else {
                minutes = 0
            }
            var hour = first
            if isPM && hour != 12 { hour += 12 }
            if isAM && hour == 12 { hour = 0 }
            return (max(0, min(23, hour)), min(59, max(0, minutes)))
        }
        let components = trimmed.split(separator: ":")
        guard components.count >= 1,
              let hour = Int(components[0].trimmingCharacters(in: .whitespaces)),
              (0...23).contains(hour) else { return nil }
        let minutes: Int
        if components.count > 1 {
            let minStr = String(components[1])
            let digits = minStr.prefix(while: { $0.isNumber })
            minutes = Int(digits).map { min(59, max(0, $0)) } ?? 0
        } else {
            minutes = 0
        }
        return (hour, min(59, max(0, minutes)))
    }
    
    /// Per calendar day (date string), latest timeIndex allowed for event start (no shows after this).
    private func computeDayStopTimes(events: [EventData], sleepHours: Int) -> [String: Double] {
        var dayStarts: [String: Double] = [:]
        for event in events {
            guard let date = event.date else { continue }
            let t = event.timeIndex
            if dayStarts[date] == nil || t < dayStarts[date]! {
                dayStarts[date] = t
            }
        }
        let secondsPerDay = 86400.0
        let stopOffset = Double(24 - sleepHours) * 3600
        var result: [String: Double] = [:]
        for (date, start) in dayStarts {
            result[date] = start + stopOffset
        }
        return result
    }
}

