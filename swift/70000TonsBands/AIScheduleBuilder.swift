//
//  AIScheduleBuilder.swift
//  70000TonsBands
//
//  Rule-based "Create AI schedule" builder. Uses Must/Might/Wont,
//  Meet and Greet and Clinic options, and resolves Must/Might conflicts.
//

import Foundation

// MARK: - Step & Resolution

/// Result of one builder step; UI handles resolution then calls nextStep again.
enum AIScheduleBuildStep: Equatable {
    case completed([EventData])
    case needMustConflict(EventData, EventData)
}

/// User resolution for a conflict; pass back into nextStep.
enum AIScheduleResolution {
    case mustConflict(choose: EventData)
    /// User chose both events; add the current candidate without removing the overlapping one from chosen.
    case mustConflictChooseBoth(currentEvent: EventData)
}

// MARK: - Builder

struct AIScheduleBuilder {
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
    /// User-selected clinics/specials/unofficial; participate in conflict resolution (mandatory when overlapping > 15 min).
    private var selectedClinicSet: Set<EventData> = []
    private var selectedSpecialSet: Set<EventData> = []
    private var selectedUnofficialSet: Set<EventData> = []
    private var candidateIndex: Int = 0
    private var phase: Phase = .buildingShows
    
    private enum Phase {
        case buildingShows
    }
    
    init(markAllMustMeetAndGreets: Bool, markAllMustClinics: Bool, priorityManager: SQLitePriorityManager, eventYear: Int, latestShowCutoffHalfHours: Int? = nil) {
        self.latestShowCutoffHalfHours = latestShowCutoffHalfHours.map { min(11, max(0, $0)) }
        self.markAllMustMeetAndGreets = markAllMustMeetAndGreets
        self.markAllMustClinics = markAllMustClinics
        self.priorityManager = priorityManager
        self.eventYear = eventYear
        self.eventYearString = String(eventYear)
    }
    
    /// Build the candidate list (filter by sleep, type, priority) and return first step.
    /// - Parameter existingAttended: Events already marked will-attend; treated as mandatory (no new conflicts allowed except M&G vs M&G).
    /// - Parameter selectedClinicEvents: User-checked clinics; added to candidates and participate in conflict resolution.
    /// - Parameter selectedSpecialEvents: User-checked special events; added to candidates and participate in conflict resolution.
    /// - Parameter selectedMeetAndGreetEvents: User-checked Meet and Greets (e.g. from wizard checklist). When non-empty, only these M&G events are added; otherwise markAllMustMeetAndGreets + Must priority is used.
    /// - Parameter selectedUnofficialEvents: User-checked Unofficial / Cruiser Organized events (e.g. from wizard checklist). When non-empty, only these are added.
    mutating func start(events: [EventData], existingAttended: [EventData] = [], selectedClinicEvents: [EventData] = [], selectedSpecialEvents: [EventData] = [], selectedMeetAndGreetEvents: [EventData] = [], selectedUnofficialEvents: [EventData] = []) -> AIScheduleBuildStep {
        self.existingAttended = Set(existingAttended)
        self.selectedClinicSet = Set(selectedClinicEvents)
        self.selectedSpecialSet = Set(selectedSpecialEvents)
        self.selectedUnofficialSet = Set(selectedUnofficialEvents)
        let selectedMAndGSet = Set(selectedMeetAndGreetEvents)
        var candidates: [EventData] = []
        
        for event in events {
            guard let date = event.date, let startTime = event.startTime, !startTime.isEmpty else { continue }
            let eventType = event.eventType ?? ""
            let priority = priorityManager.getPriority(for: event.bandName, eventYear: eventYear)
            
            // Time-based exclusion for shows: ONLY "latest show" (latestShowCutoffHalfHours) applies.
            // Cutoff is 0:00–last time on that day; e.g. 3:30am = no exclusion; 1:00am = exclude only shows starting 1:30am–3:30am.
            // We do NOT use sleep-hours-based day stop (it was keyed off calendar date and excluded evening shows incorrectly).
            
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
            
            // Meet and Greet: user-selected list, or all Must when markAllMustMeetAndGreets
            if eventType == meetAndGreetype {
                if !selectedMAndGSet.isEmpty {
                    if selectedMAndGSet.contains(event) {
                        candidates.append(event)
                    }
                } else if markAllMustMeetAndGreets && priority == 1 {
                    candidates.append(event)
                }
                continue
            }
            
            // Clinic: only added via selectedClinicEvents (user checklist), not here
            if eventType == clinicType {
                continue
            }
            
            // Unofficial / Cruiser Organized: only added via selectedUnofficialEvents (user checklist)
            if eventType == unofficalEventType || eventType == unofficalEventTypeOld {
                if selectedUnofficialSet.contains(event) {
                    candidates.append(event)
                }
                continue
            }
            
            // Special events: only added via selectedSpecialEvents (user checklist), not here
            if eventType == specialEventType {
                continue
            }
        }
        
        candidates.append(contentsOf: selectedClinicEvents)
        candidates.append(contentsOf: selectedSpecialEvents)
        allCandidates = candidates.sorted { $0.timeIndex < $1.timeIndex }
        chosen = self.existingAttended
        candidateIndex = 0
        phase = .buildingShows
        
        let showCount = allCandidates.filter { ($0.eventType ?? "") == showType }.count
        let mustShowCount = allCandidates.filter { ($0.eventType ?? "") == showType && priorityManager.getPriority(for: $0.bandName, eventYear: eventYear) == 1 }.count
        print("📋 [AIScheduleBuilder] start: events=\(events.count), existingAttended=\(existingAttended.count), allCandidates=\(allCandidates.count) (shows=\(showCount), Must shows=\(mustShowCount))")
        // Diagnostic: candidate order and priority for TYR / The Absence at 13:00
        for (idx, c) in allCandidates.enumerated() where c.bandName == "TYR" || c.bandName == "The Absence" {
            let st = c.startTime ?? ""
            guard st.contains("13") || st == "1:00" else { continue }
            let p = priorityManager.getPriority(for: c.bandName, eventYear: eventYear)
            print("📋 [AIScheduleBuilder] CANDIDATE_ORDER index=\(idx) \(c.bandName) \(eventLabel(c)) date=\(c.date ?? "nil") priority=\(p) (1=Must 2=Might)")
        }
        
        return nextStep(resolution: nil)
    }
    
    /// Continue building; pass nil when no resolution needed, or the user's choice after a prompt.
    mutating func nextStep(resolution: AIScheduleResolution?) -> AIScheduleBuildStep {
        if let res = resolution {
            switch res {
            case .mustConflict(choose: let ev):
                print("📋 [AIScheduleBuilder] resolution: mustConflict(choose=\(eventLabel(ev)))")
                // Remove only shows that overlap ev by more than 15 min (short-overlap exception keeps both)
                chosen = chosen.filter { $0 == ev || !overlaps(ev, $0) || overlapDurationSeconds(ev, $0) <= Self.shortOverlapThresholdSeconds }
                chosen.insert(ev)
                candidateIndex += 1
            case .mustConflictChooseBoth(currentEvent: let ev):
                print("📋 [AIScheduleBuilder] resolution: mustConflictChooseBoth(current=\(eventLabel(ev)))")
                chosen.insert(ev)
                candidateIndex += 1
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
                // Diagnostic: log overlap check for TYR / The Absence at 13:00
                if event.bandName == "TYR" || event.bandName == "The Absence", (event.startTime ?? "").hasPrefix("13:") || (event.startTime ?? "").hasPrefix("1:") {
                    let dayNorm = normalizedCalendarDay(from: event.date)
                    print("📋 [AIScheduleBuilder] OVERLAP_DEBUG current=\(eventLabel(event)) date=\(event.date ?? "nil") normalizedDay=\(dayNorm ?? "nil") timeIndex=\(event.timeIndex) endTimeIndex=\(event.endTimeIndex) overlapping.count=\(overlapping.count)")
                    for o in overlapping {
                        let oDay = normalizedCalendarDay(from: o.date)
                        let ov = overlaps(event, o)
                        print("📋 [AIScheduleBuilder] OVERLAP_DEBUG   vs \(eventLabel(o)) date=\(o.date ?? "nil") normalizedDay=\(oDay ?? "nil") overlaps(\(ov))")
                    }
                }
                // 15-min exception: exactly one overlapping event with overlap <= 15 min → allow both (no conflict).
                if isShortOverlapException(event: event, overlapping: Array(overlapping)) {
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                // Existing attended are mandatory: no new event may conflict unless both are Meet and Greets (or overlap <= 15 min).
                let conflictingExisting = overlapping.filter { existingAttended.contains($0) && overlapDurationSeconds(event, $0) > Self.shortOverlapThresholdSeconds }
                if !conflictingExisting.isEmpty {
                    let eventIsMAndG = isMeetAndGreet(event)
                    let allConflictsAreMAndGOnly = conflictingExisting.allSatisfy { isMeetAndGreet($0) } && eventIsMAndG
                    if !allConflictsAreMAndGOnly {
                        print("📋 [AIScheduleBuilder] phase1 skip (conflicts existing): \(eventLabel(event)) overlapping=\(overlapping.count)")
                        candidateIndex += 1
                        continue
                    }
                    // M&G vs M&G: allow (person may only be there part of the time)
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                if overlapping.isEmpty {
                    if event.bandName == "TYR" || event.bandName == "The Absence" {
                        print("📋 [AIScheduleBuilder] ADD_DEBUG adding (no overlap): \(eventLabel(event))")
                    }
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                
                // Meet and Greet vs Meet and Greet: overlapping is allowed. Only shows are excluded by overlap; do not prompt to choose.
                if isMeetAndGreet(event) && overlapping.allSatisfy({ isMeetAndGreet($0) }) {
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                
                // Mandatory = Must show, or M&G (we're adding them), or user-selected clinic, or user-selected special. All participate in conflict resolution (> 15 min).
                let eventMandatory = isMandatory(event)
                let overlappingMandatory = overlapping.first(where: { isMandatory($0) })
                let overlappingAllNonMandatory = overlapping.allSatisfy { !isMandatory($0) }
                
                // If current is not mandatory and something overlapping is mandatory → skip current
                if !eventMandatory && overlappingMandatory != nil {
                    print("📋 [AIScheduleBuilder] phase1 skip (non-mandatory vs mandatory): \(eventLabel(event)) overlapping=\(eventLabel(overlappingMandatory!))")
                    candidateIndex += 1
                    continue
                }
                
                // Both mandatory (Must vs Must, or show vs selected clinic/special, etc.): need user choice
                if eventMandatory, let other = overlappingMandatory {
                    print("📋 [AIScheduleBuilder] needMustConflict: current=\(eventLabel(event)) other=\(eventLabel(other))")
                    return .needMustConflict(event, other)
                }
                
                // Current mandatory, overlapping all non-mandatory (e.g. Might shows): add current, remove overlapping
                if eventMandatory && overlappingAllNonMandatory {
                    for o in overlapping {
                        chosen.remove(o)
                    }
                    chosen.insert(event)
                    candidateIndex += 1
                    continue
                }
                
                // Current non-mandatory, overlapping all non-mandatory (e.g. Might vs Might): need user choice
                if !eventMandatory && overlappingAllNonMandatory {
                    guard let other = overlapping.first else {
                        candidateIndex += 1
                        continue
                    }
                    print("📋 [AIScheduleBuilder] needMustConflict (non-mandatory vs non-mandatory): current=\(eventLabel(event)) other=\(eventLabel(other))")
                    return .needMustConflict(event, other)
                }
                
                // Fallback: skip
                print("📋 [AIScheduleBuilder] phase1 skip (fallback): \(eventLabel(event)) overlapping=\(overlapping.count)")
                candidateIndex += 1
            }
            
            print("📋 [AIScheduleBuilder] phase1 done: chosen=\(chosen.count), candidateIndex=\(candidateIndex)/\(allCandidates.count)")
        }
        
        let chosenList = Array(chosen)
        let tyr13 = chosenList.filter { $0.bandName == "TYR" && (($0.startTime ?? "").hasPrefix("13:") || ($0.startTime ?? "").hasPrefix("1:")) }
        let absence13 = chosenList.filter { $0.bandName == "The Absence" && (($0.startTime ?? "").hasPrefix("13:") || ($0.startTime ?? "").hasPrefix("1:")) }
        print("📋 [AIScheduleBuilder] completed: chosen=\(chosen.count) | TYR@13: \(tyr13.count) events, The Absence@13: \(absence13.count) events")
        if !tyr13.isEmpty { for e in tyr13 { print("📋 [AIScheduleBuilder] CHOSEN_TYR13 \(eventLabel(e))") } }
        if !absence13.isEmpty { for e in absence13 { print("📋 [AIScheduleBuilder] CHOSEN_ABSENCE13 \(eventLabel(e))") } }
        return .completed(chosenList)
    }
    
    /// Two events conflict only if they are on the same calendar day and their time ranges overlap.
    /// Events on different days (e.g. same band, same time on Day 2 vs Day 4) must not be treated as conflicts.
    /// Uses normalized calendar day so "01/26/2011" and "1/26/2011" are treated as the same day.
    /// Applies midnight-wrap: if an event's end time is earlier than its start on the same calendar day (e.g. 23:15–00:00 or 23:45–01:30), end is treated as next day (+24h) so overnight events overlap correctly.
    private func overlaps(_ a: EventData, _ b: EventData) -> Bool {
        let dayA = normalizedCalendarDay(from: a.date)
        let dayB = normalizedCalendarDay(from: b.date)
        if let dayA = dayA, let dayB = dayB, dayA != dayB {
            return false
        }
        var endA = a.endTimeIndex
        if a.timeIndex > endA { endA += 86400 }
        var endB = b.endTimeIndex
        if b.timeIndex > endB { endB += 86400 }
        return a.timeIndex < endB && b.timeIndex < endA
    }
    
    /// Overlap duration in seconds (0 if different days or no overlap). Uses same-day and midnight-wrap logic as overlaps.
    /// MUST be measured as: end time of earlier event → start time of later event (the period both are running).
    /// Do NOT use start-to-start; that undercounts overlap (e.g. 11:00 vs 11:15 gives 15 min but real overlap is 11:15→11:45 = 30 min).
    private static let shortOverlapThresholdSeconds: Double = 900 // 15 minutes
    
    private func overlapDurationSeconds(_ a: EventData, _ b: EventData) -> Double {
        let dayA = normalizedCalendarDay(from: a.date)
        let dayB = normalizedCalendarDay(from: b.date)
        if let dayA = dayA, let dayB = dayB, dayA != dayB {
            return 0
        }
        // Explicit: earlier = smaller start time, later = larger start time. Overlap = (end of earlier) − (start of later).
        let (earlier, later) = a.timeIndex <= b.timeIndex ? (a, b) : (b, a)
        var endOfEarlier = earlier.endTimeIndex
        if earlier.timeIndex > endOfEarlier { endOfEarlier += 86400 }
        var startOfLater = later.timeIndex
        if earlier.timeIndex > startOfLater { startOfLater += 86400 }
        return max(0, endOfEarlier - startOfLater)
    }
    
    /// True if the overlap is short enough to ignore (both events can be marked). Requires exactly one overlapping event with overlap <= 15 min. Two such overlaps (e.g. one at start, one at end) → not allowed.
    private func isShortOverlapException(event: EventData, overlapping: [EventData]) -> Bool {
        guard overlapping.count == 1, let other = overlapping.first else { return false }
        return overlapDurationSeconds(event, other) <= Self.shortOverlapThresholdSeconds
    }
    
    /// Returns "yyyy-MM-dd" for the given date string, or nil if unparseable. Ensures same-day comparison works even when formats differ (e.g. "01/26/2011" vs "1/26/2011").
    private func normalizedCalendarDay(from dateString: String?) -> String? {
        guard let s = dateString, !s.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "M-d-yyyy", "MM-dd-yyyy"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: s) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }
        return nil
    }
    
    private func isMeetAndGreet(_ event: EventData) -> Bool {
        (event.eventType ?? "") == meetAndGreetype
    }
    
    /// True if this event is "mandatory" for conflict resolution: Must show, M&G we're adding, or user-selected clinic/special.
    private func isMandatory(_ event: EventData) -> Bool {
        let eventType = event.eventType ?? ""
        if eventType == showType {
            return priorityManager.getPriority(for: event.bandName, eventYear: eventYear) == 1
        }
        if eventType == meetAndGreetype {
            return true
        }
        if eventType == clinicType {
            return selectedClinicSet.contains(event)
        }
        if eventType == specialEventType {
            return selectedSpecialSet.contains(event)
        }
        if eventType == unofficalEventType || eventType == unofficalEventTypeOld {
            return selectedUnofficialSet.contains(event)
        }
        return false
    }
    
    private func eventLabel(_ event: EventData) -> String {
        "\(event.bandName):\(event.location):\(event.startTime ?? ""):\(event.eventType ?? "")"
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
}

