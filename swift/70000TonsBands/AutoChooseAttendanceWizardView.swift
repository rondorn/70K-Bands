//
//  AutoChooseAttendanceWizardView.swift
//  70K Bands
//
//  Multi-step Auto Choose Attendance wizard. Matches app dark aesthetic.
//

import SwiftUI

// MARK: - Wizard steps

private enum WizardStep: Int, CaseIterable {
    case intro
    case unknownBands
    case sleepHours
    case meetAndGreet
    case clinics
    case specialEvents
    case building
    case done
}

// MARK: - Wizard View

struct AutoChooseAttendanceWizardView: View {
    let eventYear: Int
    let onDismiss: () -> Void
    /// When set, called so the host can dismiss the wizard and show the band list; back should return to the wizard.
    var onOpenBandList: (() -> Void)? = nil
    /// When set, called to open the band detail screen for the given band name (set Must/Might/Wont). If nil, posts AutoChooseAttendanceOpenBandDetail notification.
    var onOpenBandDetail: ((String) -> Void)? = nil
    
    private let priorityManager = SQLitePriorityManager.shared
    private let attendedHandle = ShowsAttended()
    
    @State private var step: WizardStep = .intro
    @State private var events: [EventData] = []
    @State private var unknownBandNames: [String] = []
    /// Latest show user wants to see: half-hours from midnight (0=12:00am, 1=12:30am, ..., 11=5:30am). Derived from schedule.
    @State private var latestShowHalfHours: Int = 0
    /// Max half-hour offered in picker (0–11), derived from schedule so e.g. latest show 5:15am → offer up to 5:30am (11).
    @State private var latestShowHalfHoursOptionMax: Int = 11
    @State private var meetAndGreetChoice: MGOption = .allMust
    @State private var clinicsChoice: ClinicsOption = .allMust
    @State private var selectedClinicIds: Set<String> = []
    @State private var selectedSpecialEventIds: Set<String> = []
    @State private var abortMessage: String? = nil
    @State private var fixUnknownBands: Bool = false
    
    @State private var builder: AIScheduleBuilder?
    @State private var currentBuildStep: AIScheduleBuildStep?
    @State private var showDoneAlert = false
    @State private var completedCount = 0
    @State private var isBuilding = false
    
    private enum MGOption: String, CaseIterable {
        case allMust = "All"
        case notInterested = "None"
    }
    
    private enum ClinicsOption: String, CaseIterable {
        case allMust = "All"
        case notInterested = "None"
    }
    
    private var hasMeetAndGreets: Bool {
        events.contains { ($0.eventType ?? "") == meetAndGreetype }
    }
    
    private var hasClinics: Bool {
        events.contains { ($0.eventType ?? "") == clinicType }
    }
    
    private var hasSpecialEvents: Bool {
        events.contains { ($0.eventType ?? "") == specialEventType }
    }
    
    private func eventId(_ event: EventData) -> String {
        "\(event.bandName):\(event.location):\(event.startTime ?? ""):\(event.eventType ?? "")"
    }
    
    /// Respects OS time format (12h AM/PM vs 24h). Used for Latest show picker labels.
    private static let latestShowTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                if let msg = abortMessage {
                    abortView(message: msg)
                } else {
                    stepContent
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if abortMessage == nil && step != .building {
                        Button(NSLocalizedString("Cancel", comment: "")) {
                            onDismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                loadEvents()
                if events.isEmpty {
                    abortMessage = NSLocalizedString("AIScheduleNoEvents", comment: "")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DetailScreenDismissing"))) { _ in
                loadEvents()
            }
        }
        .alert(NSLocalizedString("AIScheduleDoneTitle", comment: "Done"), isPresented: $showDoneAlert) {
            Button(NSLocalizedString("OK", comment: "")) {
                showDoneAlert = false
                setShowOnlyWillAttened(true)
                writeFiltersFile()
                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                onDismiss()
            }
        } message: {
            Text(String(format: NSLocalizedString("AIScheduleDoneMessage", comment: ""), completedCount) + "\n\n" + NSLocalizedString("AIScheduleDoneMessageDetail", comment: ""))
        }
    }
    
    private var stepTitle: String {
        switch step {
        case .intro: return NSLocalizedString("AutoChooseAttendanceTitle", comment: "")
        case .unknownBands: return NSLocalizedString("AutoChooseAttendanceUnknownBandsTitle", comment: "")
        case .sleepHours: return NSLocalizedString("AutoChooseAttendanceLatestShowTitle", comment: "Latest show")
        case .meetAndGreet: return NSLocalizedString("AIScheduleMeetGreetHeader", comment: "")
        case .clinics: return NSLocalizedString("AIScheduleClinicsHeader", comment: "")
        case .specialEvents: return NSLocalizedString("AIScheduleSpecialEventsHeader", comment: "Special Events")
        case .building: return NSLocalizedString("AutoChooseAttendanceBuilding", comment: "")
        case .done: return NSLocalizedString("AutoChooseAttendanceTitle", comment: "")
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        VStack(spacing: 24) {
            switch step {
            case .intro:
                introStep
            case .unknownBands:
                unknownBandsStep
            case .sleepHours:
                sleepStep
            case .meetAndGreet:
                meetAndGreetStep
            case .clinics:
                clinicsStep
            case .specialEvents:
                specialEventsStep
            case .building:
                buildingStep
            case .done:
                EmptyView()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var introStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(format: NSLocalizedString("AutoChooseAttendanceIntro", comment: ""), FestivalConfig.current.appName))
                .foregroundColor(.white)
                .font(.body)
            Spacer(minLength: 20)
            primaryButton(NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")) {
                advanceFromIntro()
            }
        }
    }
    
    private var unknownBandsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if unknownBandNames.isEmpty {
                Text(NSLocalizedString("AutoChooseAttendanceNoUnknownBands", comment: ""))
                    .foregroundColor(.white)
                Spacer(minLength: 20)
                primaryButton(NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")) {
                    step = nextStep(after: .unknownBands)
                }
            } else if unknownBandNames.count > 10 {
                Text(NSLocalizedString("AutoChooseAttendanceTooManyUnknown", comment: ""))
                    .foregroundColor(.white)
                Spacer(minLength: 20)
                primaryButton(NSLocalizedString("Cancel", comment: "")) {
                    abortMessage = NSLocalizedString("AutoChooseAttendanceTooManyUnknown", comment: "")
                }
            } else {
                Text(String(format: NSLocalizedString("AutoChooseAttendanceFixUnknownPrompt", comment: ""), unknownBandNames.count))
                    .foregroundColor(.white)
                Text(NSLocalizedString("AutoChooseAttendanceFixUnknownOrWont", comment: ""))
                    .foregroundColor(.gray)
                    .font(.caption)
                if let openBandList = onOpenBandList {
                    secondaryButton(NSLocalizedString("AutoChooseAttendanceGoToBandList", comment: "Go to band list")) {
                        openBandList()
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(unknownBandNames, id: \.self) { name in
                            unknownBandRow(bandName: name, onDetails: { openBandDetail(name) })
                        }
                    }
                }
                .frame(maxHeight: 280)
                HStack(spacing: 12) {
                    secondaryButton(NSLocalizedString("AutoChooseAttendanceTreatAsWont", comment: "Treat as Wont")) {
                        advanceTreatingUnknownAsWont()
                    }
                    primaryButton(NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")) {
                        advanceFromUnknownBands()
                    }
                }
            }
        }
    }
    
    private func openBandDetail(_ bandName: String) {
        if let open = onOpenBandDetail {
            open(bandName)
        } else {
            NotificationCenter.default.post(
                name: Notification.Name("AutoChooseAttendanceOpenBandDetail"),
                object: nil,
                userInfo: ["bandName": bandName]
            )
        }
    }
    
    private func unknownBandRow(bandName: String, onDetails: @escaping () -> Void) -> some View {
        HStack {
            Text(bandName)
                .foregroundColor(.white)
            Spacer()
            Button(NSLocalizedString("AutoChooseAttendanceDetails", comment: "Details")) {
                onDetails()
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.6))
            .cornerRadius(6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var sleepStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("AutoChooseAttendanceLatestShowPrompt", comment: "The latest show you want to see."))
                .foregroundColor(.white)
            Text(NSLocalizedString("AutoChooseAttendanceLatestShowHint", comment: "Shows starting at or after the next hour will be excluded (e.g. 2am excludes from 1am on)."))
                .foregroundColor(.gray)
                .font(.caption)
            Picker("", selection: $latestShowHalfHours) {
                ForEach(0...latestShowHalfHoursOptionMax, id: \.self) { halfHour in
                    Text(latestShowHalfHourLabel(halfHour)).tag(halfHour)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)
            .frame(height: 120)
            Spacer(minLength: 20)
            primaryButton(NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")) {
                step = nextStep(after: .sleepHours)
            }
        }
        .onAppear { updateLatestShowHourFromSchedule() }
    }
    
    /// Formats a half-hour slot (0=00:00, 11=05:30) using the system's time display preference (12h AM/PM vs 24h).
    private func latestShowHalfHourLabel(_ halfHour: Int) -> String {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = 1
        comps.day = 1
        comps.hour = halfHour / 2
        comps.minute = (halfHour % 2) * 30
        guard let date = Calendar.current.date(from: comps) else {
            return "\(halfHour / 2):\((halfHour % 2) * 30)"
        }
        return AutoChooseAttendanceWizardView.latestShowTimeFormatter.string(from: date)
    }
    
    private var meetAndGreetStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !hasMeetAndGreets {
                Text(NSLocalizedString("AutoChooseAttendanceNoMeetAndGreets", comment: ""))
                    .foregroundColor(.white)
            } else {
                Text(NSLocalizedString("AutoChooseAttendanceMeetAndGreetQuestion", comment: ""))
                    .foregroundColor(.white)
                radioOption(selected: meetAndGreetChoice == .allMust) {
                    meetAndGreetChoice = .allMust
                } label: {
                    Text(NSLocalizedString("AutoChooseAttendanceMGOptionAll", comment: "All of your Must bands"))
                }
                radioOption(selected: meetAndGreetChoice == .notInterested) {
                    meetAndGreetChoice = .notInterested
                } label: {
                    Text(NSLocalizedString("AutoChooseAttendanceMGOptionNone", comment: "Not interested"))
                }
            }
            Spacer(minLength: 20)
            primaryButton(NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")) {
                step = nextStep(after: .meetAndGreet)
            }
        }
    }
    
    private var clinicEvents: [EventData] {
        events.filter { ($0.eventType ?? "") == clinicType }
            .sorted { ($0.timeIndex, $0.bandName) < ($1.timeIndex, $1.bandName) }
    }
    
    private var clinicsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !hasClinics {
                Text(NSLocalizedString("AutoChooseAttendanceNoClinics", comment: ""))
                    .foregroundColor(.white)
            } else {
                Text(NSLocalizedString("AutoChooseAttendanceClinicsQuestion", comment: ""))
                    .foregroundColor(.white)
                Text(NSLocalizedString("AutoChooseAttendanceClinicsChecklistHint", comment: "Check each you want to attend. Notes from schedule (e.g. Song writing clinic)."))
                    .font(.caption)
                    .foregroundColor(.gray)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(clinicEvents, id: \.self, content: clinicChecklistRow)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            Spacer(minLength: 20)
            primaryButton(hasSpecialEvents ? NSLocalizedString("AutoChooseAttendanceNext", comment: "Next") : NSLocalizedString("AIScheduleBuild", comment: "Build schedule")) {
                step = nextStep(after: .clinics)
            }
        }
    }
    
    private func clinicChecklistRow(_ event: EventData) -> some View {
        let id = eventId(event)
        let notesText = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Toggle(isOn: Binding(
            get: { selectedClinicIds.contains(id) },
            set: { if $0 { selectedClinicIds.insert(id) } else { selectedClinicIds.remove(id) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notesText.isEmpty ? event.bandName : "\(event.bandName) – \(notesText)")
                    .foregroundColor(.white)
                Text("\(event.location) · \(event.day ?? "") · \(formatTimeStringForDisplay(event.startTime ?? ""))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .tint(.accentColor)
    }
    
    private var specialEvents: [EventData] {
        events.filter { ($0.eventType ?? "") == specialEventType }
            .sorted { ($0.timeIndex, $0.bandName) < ($1.timeIndex, $1.bandName) }
    }
    
    private var specialEventsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !hasSpecialEvents {
                Text(NSLocalizedString("AutoChooseAttendanceNoSpecialEvents", comment: "No special events in the schedule."))
                    .foregroundColor(.white)
            } else {
                Text(NSLocalizedString("AutoChooseAttendanceSpecialEventsQuestion", comment: "Which special events do you want to attend?"))
                    .foregroundColor(.white)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(specialEvents, id: \.self, content: specialEventChecklistRow)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            Spacer(minLength: 20)
            primaryButton(NSLocalizedString("AIScheduleBuild", comment: "Build schedule")) {
                step = nextStep(after: .specialEvents)
            }
        }
    }
    
    private func specialEventChecklistRow(_ event: EventData) -> some View {
        let id = eventId(event)
        let notesText = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Toggle(isOn: Binding(
            get: { selectedSpecialEventIds.contains(id) },
            set: { if $0 { selectedSpecialEventIds.insert(id) } else { selectedSpecialEventIds.remove(id) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notesText.isEmpty ? event.bandName : "\(event.bandName) – \(notesText)")
                    .foregroundColor(.white)
                Text("\(event.location) · \(event.day ?? "") · \(formatTimeStringForDisplay(event.startTime ?? ""))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .tint(.accentColor)
    }
    
    /// Radio-button style row: circle (filled when selected) + label. Tappable to select.
    private func radioOption<Label: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: selected ? "circle.inset.filled" : "circle")
                    .font(.body)
                    .foregroundColor(selected ? .accentColor : .gray)
                label()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var buildingStep: some View {
        if case .needMustConflict(let a, let b) = currentBuildStep {
            mustConflictResolutionView(eventA: a, eventB: b)
        } else {
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                Text(NSLocalizedString("AutoChooseAttendanceBuilding", comment: ""))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func mustConflictResolutionView(eventA: EventData, eventB: EventData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("AIScheduleMustConflictTitle", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
            Text(NSLocalizedString("AIScheduleMustConflictMessage", comment: ""))
                .foregroundColor(.gray)
                .font(.subheadline)
            ScrollView {
                VStack(spacing: 12) {
                    conflictEventCard(event: eventA) {
                        resolveMustConflict(choose: eventA)
                    }
                    conflictEventCard(event: eventB) {
                        resolveMustConflict(choose: eventB)
                    }
                }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                onDismiss()
            }
            .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Other SHOWS of this band in the schedule (different time/place) to help user resolve conflict. Only shows count—not Meet and Greets, clinics, or other event types.
    private func seeingThemElsewhere(for event: EventData) -> String {
        let sameEvent: (EventData) -> Bool = { other in
            other.bandName == event.bandName
                && other.location == event.location
                && (other.startTime ?? "") == (event.startTime ?? "")
                && (other.eventType ?? "") == (event.eventType ?? "")
        }
        let others = events.filter { $0.bandName == event.bandName && !sameEvent($0) && ($0.eventType ?? "") == showType }
        if others.isEmpty {
            return NSLocalizedString("AIScheduleSeeingThemNowhereElse", comment: "Seeing them: Nowhere else")
        }
        let first = others.first!
        let loc = first.location
        let day = (first.day ?? "").trimmingCharacters(in: .whitespaces)
        let place = day.isEmpty ? loc : "\(loc) \(day)"
        return String(format: NSLocalizedString("AIScheduleSeeingThemFormat", comment: "Seeing them: %@"), place)
    }
    
    private func conflictEventCard(event: EventData, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.bandName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(formatTimeStringForDisplay(event.startTime ?? ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(event.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(seeingThemElsewhere(for: event))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.12))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    /// Formats a time string (24h or 12h) for display using the system's time preference.
    private func formatTimeStringForDisplay(_ time: String) -> String {
        guard let (hour, minutes) = parseHourMinutesFromStartTime(time) else { return time }
        var comps = DateComponents()
        comps.year = 2000
        comps.month = 1
        comps.day = 1
        comps.hour = hour
        comps.minute = minutes
        guard let date = Calendar.current.date(from: comps) else { return time }
        return AutoChooseAttendanceWizardView.latestShowTimeFormatter.string(from: date)
    }
    
    private func abortView(message: String) -> some View {
        VStack(spacing: 24) {
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            primaryButton(NSLocalizedString("Done", comment: "")) {
                onDismiss()
            }
        }
    }
    
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(10)
        }
    }
    
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.6))
                .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    
    private func loadEvents() {
        events = DataManager.shared.fetchEvents(forYear: eventYear)
        let bandsWithShows = Set(events.filter { ($0.eventType ?? "") == showType }.map { $0.bandName })
        unknownBandNames = bandsWithShows.filter { name in
            let p = priorityManager.getPriority(for: name, eventYear: eventYear)
            return p == 0  // Only count Unknown (no priority set); 1=Must, 2=Might, 3=Wont
        }.sorted()
        updateLatestShowHourFromSchedule()
    }
    
    /// Derive latest-show picker range and default from schedule: find latest show start in late night (12am–5:59am); offer 30-min slots up to that time (e.g. 5:15am → offer up to 5:30am).
    private func updateLatestShowHourFromSchedule() {
        var maxEffectiveHalfHours = 0
        for event in events {
            guard (event.eventType ?? "") == showType,
                  let startTime = event.startTime, !startTime.isEmpty,
                  let (hour, minutes) = parseHourMinutesFromStartTime(startTime) else { continue }
            guard (0..<6).contains(hour) else { continue } // late night only
            let halfHours = hour * 2 + (minutes > 0 ? 1 : 0) // 5:15 → 11 (5:30 slot)
            maxEffectiveHalfHours = max(maxEffectiveHalfHours, min(11, halfHours))
        }
        latestShowHalfHoursOptionMax = max(0, min(11, maxEffectiveHalfHours))
        latestShowHalfHours = latestShowHalfHoursOptionMax
    }
    
    /// Parses "1:00 AM", "3:30 AM" (12h) or "05:15", "00:30" (24h) to (hour 0-23, minutes 0-59). Returns nil if unparseable.
    private func parseHourMinutesFromStartTime(_ startTime: String) -> (Int, Int)? {
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
    
    private func advanceFromIntro() {
        if unknownBandNames.isEmpty {
            step = nextStep(after: .unknownBands)
        } else {
            step = .unknownBands
        }
    }
    
    private func nextStep(after current: WizardStep) -> WizardStep {
        switch current {
        case .intro: return .unknownBands
        case .unknownBands: return .sleepHours
        case .sleepHours:
            if hasMeetAndGreets { return .meetAndGreet }
            if hasClinics { return .clinics }
            if hasSpecialEvents { return .specialEvents }
            startBuilding(); return .building
        case .meetAndGreet:
            if hasClinics { return .clinics }
            if hasSpecialEvents { return .specialEvents }
            startBuilding(); return .building
        case .clinics:
            if hasSpecialEvents { return .specialEvents }
            startBuilding(); return .building
        case .specialEvents:
            startBuilding(); return .building
        default: return .building
        }
    }
    
    private func advanceTreatingUnknownAsWont() {
        for name in unknownBandNames {
            priorityManager.setPriority(for: name, priority: 3, eventYear: eventYear) { _ in }
        }
        unknownBandNames = []
        step = nextStep(after: .unknownBands)
    }
    
    private func advanceFromUnknownBands() {
        loadEvents()
        step = nextStep(after: .unknownBands)
    }
    
    private func startBuilding() {
        step = .building
        isBuilding = true
        let markMAndG = (hasMeetAndGreets && meetAndGreetChoice == .allMust)
        // Clinics and special events come from checklists only; builder does not add them
        let yearString = String(eventYear)
        let existingAttended = events.filter { event in
            guard let startTime = event.startTime, !startTime.isEmpty else { return false }
            var et = event.eventType ?? ""
            if et == unofficalEventTypeOld { et = unofficalEventType }
            let status = attendedHandle.getShowAttendedStatus(
                band: event.bandName,
                location: event.location,
                startTime: startTime,
                eventType: et,
                eventYearString: yearString
            )
            return status != sawNoneStatus
        }
        let selectedClinicsList = events.filter { ($0.eventType ?? "") == clinicType && selectedClinicIds.contains(eventId($0)) }
        let selectedSpecialsList = events.filter { ($0.eventType ?? "") == specialEventType && selectedSpecialEventIds.contains(eventId($0)) }
        var b = AIScheduleBuilder(
            markAllMustMeetAndGreets: markMAndG,
            markAllMustClinics: false,
            priorityManager: priorityManager,
            eventYear: eventYear,
            latestShowCutoffHalfHours: latestShowHalfHours
        )
        let firstStep = b.start(events: events, existingAttended: existingAttended, selectedClinicEvents: selectedClinicsList, selectedSpecialEvents: selectedSpecialsList)
        builder = b
        currentBuildStep = firstStep
        if case .completed = firstStep {
            finishBuild(with: firstStep)
        } else {
            isBuilding = false
            checkStepForAlerts()
        }
    }
    
    private func checkStepForAlerts() {
        guard let step = currentBuildStep else { return }
        switch step {
        case .needMustConflict:
            break // Shown in-wizard in buildingStep
        case .completed:
            finishBuild(with: step)
        }
    }
    
    private func finishBuild(with buildStep: AIScheduleBuildStep) {
        guard case .completed(let toMark) = buildStep else { return }
        // toMark already includes resolved shows, M&G, and any selected clinics/specials that survived conflict resolution
        let yearString = String(eventYear)
        let currentAttended = attendedHandle.getShowsAttended()
        AIScheduleStorage.saveBackup(attended: currentAttended, year: eventYear)
        let am = AttendanceManager()
        let ts = Date().timeIntervalSince1970
        for event in toMark {
            guard let startTime = event.startTime, !startTime.isEmpty else { continue }
            var et = event.eventType ?? showType
            if et == unofficalEventTypeOld { et = unofficalEventType }
            let index = "\(event.bandName):\(event.location):\(startTime):\(et):\(yearString)"
            am.setAttendanceStatusByIndex(index: index, status: 2, timestamp: ts, attendanceSource: "Auto")
        }
        completedCount = toMark.count
        AIScheduleStorage.setHasRunAI(for: eventYear, value: true)
        currentBuildStep = nil
        builder = nil
        NotificationCenter.default.post(name: Notification.Name("RefreshLandscapeSchedule"), object: nil)
        showDoneAlert = true
    }
    
    private func resolveMustConflict(choose event: EventData) {
        guard var b = builder else { return }
        let next = b.nextStep(resolution: .mustConflict(choose: event))
        builder = b
        currentBuildStep = next
        checkStepForAlerts()
    }
    
}
