//
//  AutoChooseAttendanceWizardView.swift
//  70K Bands
//
//  Multi-step Auto Choose Attendance wizard. Matches app dark aesthetic.
//

import SwiftUI

// MARK: - Custom toggle row with lighter off-state so switches stay visible on black (list view and preference sheet)

private let wizardToggleOffTrack = Color(white: 0.35)

private struct WizardToggleRow<Label: View>: View {
    @Binding var isOn: Bool
    @ViewBuilder let label: () -> Label
    
    var body: some View {
        HStack {
            label()
            Spacer(minLength: 8)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOn.toggle()
                }
            }) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isOn ? Color.accentColor : wizardToggleOffTrack)
                        .frame(width: 51, height: 31)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 27, height: 27)
                        .padding(2)
                        .offset(x: isOn ? 20 : 0)
                }
                .frame(width: 51, height: 31)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Wizard steps

private enum WizardStep: Int, CaseIterable {
    case intro
    case unknownBands
    case sleepHours
    case unofficialEvents
    case meetAndGreet
    case clinics
    case specialEvents
    case building
    case done
}

// MARK: - Wizard View

struct AutoChooseAttendanceWizardView: View {
    let eventYear: Int
    /// goToSchedule: true = user completed the wizard → host should dismiss to list view; false = user cancelled → host only dismisses wizard (e.g. stay on preferences).
    let onDismiss: (Bool) -> Void
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
    @State private var selectedUnofficialEventIds: Set<String> = []
    @State private var selectedMeetAndGreetIds: Set<String> = []
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
    /// True after we clear attendance for a new build; cancel must restore from `AIScheduleStorage` backup.
    @State private var attendanceClearedForActiveWizardRun = false
    
    private enum ClinicsOption: String, CaseIterable {
        case allMust = "All"
        case notInterested = "None"
    }
    
    private var hasUnofficialEvents: Bool {
        events.contains { let t = $0.eventType ?? ""; return t == unofficalEventType || t == unofficalEventTypeOld }
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
    
    /// Stable per-row id for wizard toggles. Must differ across schedule rows that share band/location/time/type (e.g. Karaoke on Day 1 vs Day 2).
    private func eventId(_ event: EventData) -> String {
        let st = event.startTime ?? ""
        let et = event.eventType ?? ""
        let day = (event.day ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(event.bandName):\(event.location):\(st):\(et):\(day):\(event.timeIndex)"
    }
    
    /// Respects OS time format (12h AM/PM vs 24h). Used for Latest show picker labels only; internal logic always uses half-hour indices (0–11).
    private static var latestShowTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }
    
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
        .overlay {
            if showDoneAlert {
                doneAlertOverlay
            }
        }
        .onDisappear {
            restoreWizardAttendanceIfNeeded()
        }
    }
    
    /// Custom done alert with dark background to match the initial Plan Your Schedule prompt.
    private var doneAlertOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { }
            VStack(spacing: 16) {
                Text(NSLocalizedString("AIScheduleDoneTitle", comment: "Done"))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(String(format: NSLocalizedString("AIScheduleDoneMessage", comment: ""), completedCount) + "\n\n" + NSLocalizedString("AIScheduleDoneMessageDetail", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(NSLocalizedString("OK", comment: "")) {
                    showDoneAlert = false
                    setShowOnlyWillAttened(true)
                    writeFiltersFile()
                    NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                    onDismiss(true)
                }
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 280)
            .background(Color(white: 0.10))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        }
    }
    
    private var stepTitle: String {
        switch step {
        case .intro: return NSLocalizedString("AutoChooseAttendanceTitle", comment: "")
        case .unknownBands: return NSLocalizedString("AutoChooseAttendanceUnknownBandsTitle", comment: "")
        case .sleepHours: return NSLocalizedString("AutoChooseAttendanceLatestShowTitle", comment: "Latest show")
        case .unofficialEvents: return NSLocalizedString("AIScheduleUnofficialEventsHeader", comment: "Unofficial / Cruiser Organized")
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
            case .unofficialEvents:
                unofficialEventsStep
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
            if abortMessage == nil && step != .building {
                Spacer(minLength: 20)
                wizardBottomBar
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Single row: Cancel, Back (when not intro), Next (or Build schedule). Shown where the old Next button was.
    @ViewBuilder
    private var wizardBottomBar: some View {
        HStack(spacing: 12) {
            secondaryButton(NSLocalizedString("Cancel", comment: "")) {
                dismissWizardCancelled()
            }
            if step != .intro {
                secondaryButton(NSLocalizedString("Back", comment: "Back button")) {
                    previousStep()
                }
            }
            Spacer(minLength: 0)
            primaryButton(wizardNextButtonTitle) {
                performWizardNext()
            }
        }
    }
    
    private var wizardNextButtonTitle: String {
        switch step {
        case .intro, .unknownBands, .sleepHours, .unofficialEvents, .meetAndGreet:
            return NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")
        case .clinics:
            return hasSpecialEvents ? NSLocalizedString("AutoChooseAttendanceNext", comment: "Next") : NSLocalizedString("AIScheduleBuild", comment: "Build schedule")
        case .specialEvents:
            return NSLocalizedString("AIScheduleBuild", comment: "Build schedule")
        case .building, .done:
            return NSLocalizedString("AutoChooseAttendanceNext", comment: "Next")
        }
    }
    
    private func performWizardNext() {
        switch step {
        case .intro:
            advanceFromIntro()
        case .unknownBands:
            if unknownBandNames.count > 10 {
                abortMessage = NSLocalizedString("AutoChooseAttendanceTooManyUnknown", comment: "")
            } else {
                advanceFromUnknownBands()
            }
        case .sleepHours:
            step = nextStep(after: .sleepHours)
        case .unofficialEvents:
            step = nextStep(after: .unofficialEvents)
        case .meetAndGreet:
            step = nextStep(after: .meetAndGreet)
        case .clinics:
            step = nextStep(after: .clinics)
        case .specialEvents:
            step = nextStep(after: .specialEvents)
        case .building, .done:
            break
        }
    }
    
    private var introStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(format: NSLocalizedString("AutoChooseAttendanceIntro", comment: ""), FestivalConfig.current.appName))
                .foregroundColor(.white)
                .font(.body)
            Spacer(minLength: 20)
        }
    }
    
    private var unknownBandsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if unknownBandNames.isEmpty {
                Text(NSLocalizedString("AutoChooseAttendanceNoUnknownBands", comment: ""))
                    .foregroundColor(.white)
                Spacer(minLength: 20)
            } else if unknownBandNames.count > 10 {
                Text(NSLocalizedString("AutoChooseAttendanceTooManyUnknown", comment: ""))
                    .foregroundColor(.white)
                Spacer(minLength: 20)
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
                secondaryButton(NSLocalizedString("AutoChooseAttendanceTreatAsWont", comment: "Treat as Wont")) {
                    advanceTreatingUnknownAsWont()
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
            Text(NSLocalizedString("AutoChooseAttendanceLatestShowHint", comment: "Shows that begin after this specified time will be excluded. For instance, if you set this time to 2 am, a show scheduled for 2 am will be included, but a show scheduled for 2:30 am or later will be excluded."))
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
            } else if meetAndGreetEventsForMustBands.isEmpty {
                Text(NSLocalizedString("AutoChooseAttendanceNoMeetAndGreets", comment: ""))
                    .foregroundColor(.white)
            } else {
                Text(NSLocalizedString("AutoChooseAttendanceMeetAndGreetQuestion", comment: ""))
                    .foregroundColor(.white)
                Text("Showing Meet & Greets for Must bands only.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(NSLocalizedString("AutoChooseAttendanceMeetAndGreetChecklistHint", comment: "Check each event you want to attend."))
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(spacing: 10) {
                    Button("Add All") {
                        selectedMeetAndGreetIds = Set(meetAndGreetEventsForMustBands.map { eventId($0) })
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(10)

                    Button("Remove All") {
                        selectedMeetAndGreetIds.removeAll()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(10)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(meetAndGreetEventsForMustBands, id: \.self, content: meetAndGreetChecklistRow)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            Spacer(minLength: 20)
        }
    }
    
    private func meetAndGreetChecklistRow(_ event: EventData) -> some View {
        let id = eventId(event)
        let notesText = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return WizardToggleRow(isOn: Binding(
            get: { selectedMeetAndGreetIds.contains(id) },
            set: { if $0 { selectedMeetAndGreetIds.insert(id) } else { selectedMeetAndGreetIds.remove(id) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notesText.isEmpty ? event.bandName : "\(event.bandName) – \(notesText)")
                    .foregroundColor(.white)
                Text("\(event.location) · \(event.day ?? "") · \(formatTimeStringForDisplay(event.startTime ?? ""))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var unofficialEventsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !hasUnofficialEvents || unofficialEventsForWizardChecklist.isEmpty {
                Text(NSLocalizedString("AutoChooseAttendanceNoUnofficialEvents", comment: "No Unofficial / Cruiser Organized events in the schedule."))
                    .foregroundColor(.white)
            } else {
                Text(NSLocalizedString("AutoChooseAttendanceUnofficialQuestion", comment: "What Unofficial / Cruiser Organized events do you want to attend?"))
                    .foregroundColor(.white)
                Text(NSLocalizedString("AutoChooseAttendanceClinicsChecklistHint", comment: "Check each you want to attend. Notes from schedule (e.g. Song writing clinic)."))
                    .font(.caption)
                    .foregroundColor(.gray)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(unofficialEventsForWizardChecklist, id: \.self, content: unofficialChecklistRow)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func unofficialChecklistRow(_ event: EventData) -> some View {
        let id = eventId(event)
        let notesText = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return WizardToggleRow(isOn: Binding(
            get: { selectedUnofficialEventIds.contains(id) },
            set: { if $0 { selectedUnofficialEventIds.insert(id) } else { selectedUnofficialEventIds.remove(id) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notesText.isEmpty ? event.bandName : "\(event.bandName) – \(notesText)")
                    .foregroundColor(.white)
                Text("\(event.location) · \(event.day ?? "") · \(formatTimeStringForDisplay(event.startTime ?? ""))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    /// All Unofficial / Cruiser Organized events (includes pre-party rows that use the event title as bandName and are not Must-ranked).
    private var unofficialEventsForWizardChecklist: [EventData] {
        events.filter { event in
            let t = event.eventType ?? ""
            return t == unofficalEventType || t == unofficalEventTypeOld
        }
        .sorted { ($0.timeIndex, $0.bandName) < ($1.timeIndex, $1.bandName) }
    }
    
    /// Meet and Greet events for bands the user marked as Must (priority 1). Used for the M&G checklist.
    private var meetAndGreetEventsForMustBands: [EventData] {
        events.filter { ($0.eventType ?? "") == meetAndGreetype && priorityManager.getPriority(for: $0.bandName, eventYear: eventYear) == 1 }
            .sorted { ($0.timeIndex, $0.bandName) < ($1.timeIndex, $1.bandName) }
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
        }
    }
    
    private func clinicChecklistRow(_ event: EventData) -> some View {
        let id = eventId(event)
        let notesText = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return WizardToggleRow(isOn: Binding(
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
        }
    }
    
    private func specialEventChecklistRow(_ event: EventData) -> some View {
        let id = eventId(event)
        let notesText = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return WizardToggleRow(isOn: Binding(
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
        VStack(spacing: 0) {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)

            // Fixed bottom row: Cancel (left), Both (right) as proper buttons
            HStack(alignment: .center, spacing: 16) {
                Button(NSLocalizedString("Cancel", comment: "")) {
                    dismissWizardCancelled()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(10)

                Spacer(minLength: 0)

                Button(NSLocalizedString("AIScheduleMustConflictBoth", comment: "Both")) {
                    resolveMustConflictChooseBoth(currentEvent: eventA)
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(10)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.horizontal)
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
        let dayLabel = (event.day ?? "").trimmingCharacters(in: .whitespaces)
        let timeStr = formatTimeStringForDisplay(event.startTime ?? "")
        let dayAndTime = dayLabel.isEmpty ? timeStr : "\(dayLabel) - \(timeStr)"
        let eventType = event.eventType ?? showType
        let isShowEvent = eventType == showType
        let genre = (DataManager.shared.fetchBand(byName: event.bandName, eventYear: eventYear)?.genre ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.bandName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !isShowEvent {
                    Text(convertEventTypeToLocalLanguage(eventType: eventType))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(dayAndTime)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(event.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !genre.isEmpty {
                    Text("\(NSLocalizedString("genre", comment: "Genre")): \(genre)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if isShowEvent {
                    Text(seeingThemElsewhere(for: event))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                dismissWizardCancelled()
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
            if hasUnofficialEvents { return .unofficialEvents }
            if hasMeetAndGreets { return .meetAndGreet }
            if hasClinics { return .clinics }
            if hasSpecialEvents { return .specialEvents }
            startBuilding(); return .building
        case .unofficialEvents:
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
    
    /// Previous step for Back button; nil when already at intro.
    private func previousStep() {
        switch step {
        case .intro: break
        case .unknownBands: step = .intro
        case .sleepHours: step = unknownBandNames.isEmpty ? .intro : .unknownBands
        case .unofficialEvents: step = .sleepHours
        case .meetAndGreet: step = hasUnofficialEvents ? .unofficialEvents : .sleepHours
        case .clinics: step = hasMeetAndGreets ? .meetAndGreet : (hasUnofficialEvents ? .unofficialEvents : .sleepHours)
        case .specialEvents:
            if hasClinics {
                step = .clinics
            } else if hasMeetAndGreets {
                step = .meetAndGreet
            } else if hasUnofficialEvents {
                step = .unofficialEvents
            } else {
                step = .sleepHours
            }
        case .building, .done: break
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
        // Meet and Greet: checklist selection; when empty, builder adds no M&G (markAllMustMeetAndGreets false)
        let selectedMeetAndGreetList = events.filter { ($0.eventType ?? "") == meetAndGreetype && selectedMeetAndGreetIds.contains(eventId($0)) }
        // Unofficial / Cruiser Organized: checklist selection (all types in wizard list, e.g. pre-party)
        let selectedUnofficialList = events.filter { event in
            let t = event.eventType ?? ""
            guard t == unofficalEventType || t == unofficalEventTypeOld else { return false }
            return selectedUnofficialEventIds.contains(eventId(event))
        }
        let selectedClinicsList = events.filter { ($0.eventType ?? "") == clinicType && selectedClinicIds.contains(eventId($0)) }
        let selectedSpecialsList = events.filter { ($0.eventType ?? "") == specialEventType && selectedSpecialEventIds.contains(eventId($0)) }

        AIScheduleStorage.saveWizardRollbackBackup(attended: attendedHandle.getShowsAttended(), year: eventYear)
        AttendanceManager().clearAllAttendance(forYear: eventYear) {
            DispatchQueue.main.async {
                self.attendanceClearedForActiveWizardRun = true
                self.runScheduleBuilderAfterAttendanceClear(
                    selectedMeetAndGreetList: selectedMeetAndGreetList,
                    selectedUnofficialList: selectedUnofficialList,
                    selectedClinicsList: selectedClinicsList,
                    selectedSpecialsList: selectedSpecialsList
                )
            }
        }
    }

    /// Runs after SQLite clears this year's attendance so `existingAttended` is empty (fresh run + Must conflicts prompt).
    private func runScheduleBuilderAfterAttendanceClear(
        selectedMeetAndGreetList: [EventData],
        selectedUnofficialList: [EventData],
        selectedClinicsList: [EventData],
        selectedSpecialsList: [EventData]
    ) {
        let existingAttended: [EventData] = []
        var b = AIScheduleBuilder(
            markAllMustMeetAndGreets: false,
            markAllMustClinics: false,
            priorityManager: priorityManager,
            eventYear: eventYear,
            latestShowCutoffHalfHours: latestShowHalfHours
        )
        let firstStep = b.start(
            events: events,
            existingAttended: existingAttended,
            selectedClinicEvents: selectedClinicsList,
            selectedSpecialEvents: selectedSpecialsList,
            selectedMeetAndGreetEvents: selectedMeetAndGreetList,
            selectedUnofficialEvents: selectedUnofficialList
        )
        builder = b
        currentBuildStep = firstStep
        if case .completed = firstStep {
            finishBuild(with: firstStep)
        } else {
            isBuilding = false
            checkStepForAlerts()
        }
    }

    private func dismissWizardCancelled() {
        restoreWizardAttendanceIfNeeded()
        onDismiss(false)
    }

    private func restoreWizardAttendanceIfNeeded() {
        guard attendanceClearedForActiveWizardRun else { return }
        attendanceClearedForActiveWizardRun = false
        AIScheduleStorage.restoreWizardCancelled(attendedHandle: attendedHandle, year: eventYear)
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
        attendanceClearedForActiveWizardRun = false
        // toMark already includes resolved shows, M&G, and any selected clinics/specials that survived conflict resolution
        let yearString = String(eventYear)
        let collidingBases = AttendanceIndexKeys.collidingBaseKeys(forYear: eventYear)
        let am = AttendanceManager()
        let ts = Date().timeIntervalSince1970
        for event in toMark {
            guard let startTime = event.startTime, !startTime.isEmpty else { continue }
            var et = event.eventType ?? showType
            if et == unofficalEventTypeOld { et = unofficalEventType }
            let index = AttendanceIndexKeys.storageKey(
                band: event.bandName,
                location: event.location,
                startTime: startTime,
                eventType: et,
                eventYearString: yearString,
                scheduleDayFromDatabase: event.day,
                collidingBases: collidingBases
            )
            am.setAttendanceStatusByIndex(index: index, status: 2, timestamp: ts)
        }
        completedCount = toMark.count
        AIScheduleStorage.clearBackup(year: eventYear)
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
    
    private func resolveMustConflictChooseBoth(currentEvent: EventData) {
        guard var b = builder else { return }
        let next = b.nextStep(resolution: .mustConflictChooseBoth(currentEvent: currentEvent))
        builder = b
        currentBuildStep = next
        checkStepForAlerts()
    }
    
}
