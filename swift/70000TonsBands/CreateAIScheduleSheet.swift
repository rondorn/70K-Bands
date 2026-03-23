//
//  CreateAIScheduleSheet.swift
//  70000TonsBands
//
//  Sheet: Meet and Greet / Clinic options, then build.
//  Resolves Must/Might conflicts via alerts, then writes will-attend.
//

import SwiftUI

// MARK: - View model

final class CreateAIScheduleSheetViewModel: ObservableObject {
    @Published var markAllMustMeetAndGreets: Bool = true
    @Published var markAllMustClinics: Bool = true
    @Published var isBuilding: Bool = false
    @Published var currentStep: AIScheduleBuildStep?
    @Published var errorMessage: String?
    @Published var completedCount: Int = 0
    
    private var builder: AIScheduleBuilder?
    private let priorityManager: SQLitePriorityManager
    private let attendedHandle: ShowsAttended
    let eventYear: Int
    
    init(priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended, eventYear: Int) {
        self.priorityManager = priorityManager
        self.attendedHandle = attendedHandle
        self.eventYear = eventYear
    }
    
    /// Returns count of unique bands that are not Must (1) or Might (2) — i.e. Unknown or Wont. Used to warn before build.
    func unknownBandCount(events: [EventData]) -> Int {
        let bandNames = Set(events.map { $0.bandName })
        let unknown = bandNames.filter { name in
            let p = priorityManager.getPriority(for: name, eventYear: eventYear)
            return p != 1 && p != 2
        }
        return unknown.count
    }
    
    /// Returns (true, count) if there is existing attendance for this year so the UI can warn.
    func existingAttendanceCount(events: [EventData]) -> (hasExisting: Bool, count: Int) {
        let yearString = String(eventYear)
        let existing = events.filter { event in
            guard let startTime = event.startTime, !startTime.isEmpty else { return false }
            var eventType = event.eventType ?? ""
            if eventType == unofficalEventTypeOld { eventType = unofficalEventType }
            let status = attendedHandle.getShowAttendedStatus(
                band: event.bandName,
                location: event.location,
                startTime: startTime,
                eventType: eventType,
                eventYearString: yearString,
                scheduleDay: event.day
            )
            return status != sawNoneStatus
        }
        return (existing.count > 0, existing.count)
    }
    
    func startBuild(events: [EventData]) {
        guard !events.isEmpty else {
            errorMessage = NSLocalizedString("AIScheduleNoEvents", comment: "No schedule events")
            return
        }
        isBuilding = true
        currentStep = nil
        errorMessage = nil
        let yearString = String(eventYear)
        let existingAttended = events.filter { event in
            guard let startTime = event.startTime, !startTime.isEmpty else { return false }
            var eventType = event.eventType ?? ""
            if eventType == unofficalEventTypeOld { eventType = unofficalEventType }
            let status = attendedHandle.getShowAttendedStatus(
                band: event.bandName,
                location: event.location,
                startTime: startTime,
                eventType: eventType,
                eventYearString: yearString,
                scheduleDay: event.day
            )
            return status != sawNoneStatus
        }
        var b = AIScheduleBuilder(
            markAllMustMeetAndGreets: markAllMustMeetAndGreets,
            markAllMustClinics: markAllMustClinics,
            priorityManager: priorityManager,
            eventYear: eventYear
        )
        let step = b.start(events: events, existingAttended: existingAttended)
        builder = b
        currentStep = step
        if case .completed = step {
            isBuilding = false
        }
    }
    
    func resolve(resolution: AIScheduleResolution) {
        guard var b = builder else { return }
        let step = b.nextStep(resolution: resolution)
        builder = b
        currentStep = step
        if case .completed = step {
            isBuilding = false
        }
    }
    
    func writeAndFinish(events: [EventData], onDone: () -> Void) {
        let yearString = String(eventYear)
        let currentAttended = attendedHandle.getShowsAttended()
        AIScheduleStorage.saveBackup(attended: currentAttended, year: eventYear)
        for event in events {
            guard let startTime = event.startTime, !startTime.isEmpty else { continue }
            var eventType = event.eventType ?? showType
            if eventType == unofficalEventTypeOld {
                eventType = unofficalEventType
            }
            attendedHandle.addShowsAttendedWithStatus(
                band: event.bandName,
                location: event.location,
                startTime: startTime,
                eventType: eventType,
                eventYearString: yearString,
                status: sawAllStatus,
                allEventsForYear: events
            )
        }
        completedCount = events.count
        currentStep = nil
        AIScheduleStorage.setHasRunAI(for: eventYear, value: true)
        onDone()
    }
}

// MARK: - Sheet view

struct CreateAIScheduleSheet: View {
    @StateObject private var viewModel: CreateAIScheduleSheetViewModel
    let onDismiss: () -> Void
    
    init(priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended, eventYear: Int, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: CreateAIScheduleSheetViewModel(priorityManager: priorityManager, attendedHandle: attendedHandle, eventYear: eventYear))
        self.onDismiss = onDismiss
    }
    
    @State private var showMustConflictAlert = false
    @State private var mustConflictEventA: EventData?
    @State private var mustConflictEventB: EventData?
    @State private var showCompletedAlert = false
    @State private var showExistingAttendanceWarning = false
    @State private var pendingBuildEvents: [EventData]?
    @State private var existingAttendanceCountForMessage = 0
    @State private var showUnknownBandsWarning = false
    @State private var unknownBandCountForMessage = 0
    @State private var pendingBuildEventsAfterUnknownWarning: [EventData]?
    @State private var unknownBandCountDisplay: Int = -1  // -1 = not loaded, 0+ = count for reminder
    
    var body: some View {
        NavigationView {
            scheduleForm
                .navigationTitle(NSLocalizedString("AIScheduleTitle", comment: "Create AI schedule"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("Cancel", comment: "")) {
                            onDismiss()
                        }
                    }
                }
                .onChange(of: viewModel.currentStep) { _ in
                    checkStepForAlerts()
                }
                .onAppear {
                    let events = DataManager.shared.fetchEvents(forYear: viewModel.eventYear)
                    unknownBandCountDisplay = viewModel.unknownBandCount(events: events)
                }
        }
        .alert(NSLocalizedString("AIScheduleMustConflictTitle", comment: "Must-see conflict"), isPresented: $showMustConflictAlert) {
            mustConflictAlertButtons
        } message: {
            Text(NSLocalizedString("AIScheduleMustConflictMessage", comment: "Two Must-see shows overlap"))
        }
        .alert(NSLocalizedString("AIScheduleDoneTitle", comment: "Schedule created"), isPresented: $showCompletedAlert) {
            Button(NSLocalizedString("OK", comment: "")) {
                showCompletedAlert = false
                onDismiss()
            }
        } message: {
            Text(String(format: NSLocalizedString("AIScheduleDoneMessage", comment: "Marked %d events as will attend"), viewModel.completedCount))
        }
        .alert(NSLocalizedString("AIScheduleExistingAttendanceTitle", comment: "Existing attendance"), isPresented: $showExistingAttendanceWarning) {
            Button(NSLocalizedString("AIScheduleExistingAttendanceContinue", comment: "Continue")) {
                if let events = pendingBuildEvents {
                    viewModel.startBuild(events: events)
                    pendingBuildEvents = nil
                    checkStepForAlerts()
                }
                showExistingAttendanceWarning = false
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                showExistingAttendanceWarning = false
                pendingBuildEvents = nil
            }
        } message: {
            Text(String(format: NSLocalizedString("AIScheduleExistingAttendanceMessage", comment: ""), existingAttendanceCountForMessage))
        }
        .alert(NSLocalizedString("AIScheduleUnknownBandsTitle", comment: "Unknown bands"), isPresented: $showUnknownBandsWarning) {
            Button(NSLocalizedString("AIScheduleUnknownBandsContinue", comment: "Continue")) {
                if let events = pendingBuildEventsAfterUnknownWarning {
                    proceedWithBuild(events: events)
                }
                showUnknownBandsWarning = false
                pendingBuildEventsAfterUnknownWarning = nil
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                showUnknownBandsWarning = false
                pendingBuildEventsAfterUnknownWarning = nil
            }
        } message: {
            Text(String(format: NSLocalizedString("AIScheduleUnknownBandsMessage", comment: ""), unknownBandCountForMessage))
        }
    }
    
    private var scheduleForm: some View {
        Form {
            Section(header: Text(NSLocalizedString("AIScheduleMeetGreetHeader", comment: "Meet and Greets"))) {
                Toggle(NSLocalizedString("AIScheduleMarkAllMustMeetGreets", comment: "Mark all Must Meet and Greets"), isOn: $viewModel.markAllMustMeetAndGreets)
                if !viewModel.markAllMustMeetAndGreets {
                    Text(NSLocalizedString("AIScheduleManualMeetGreets", comment: "I'll manually handle Meet and Greets"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Section(header: Text(NSLocalizedString("AIScheduleClinicsHeader", comment: "Clinics"))) {
                Toggle(NSLocalizedString("AIScheduleMarkAllMustClinics", comment: "Mark all Must clinics"), isOn: $viewModel.markAllMustClinics)
                if !viewModel.markAllMustClinics {
                    Text(NSLocalizedString("AIScheduleManualClinics", comment: "I'll manually handle clinics"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if let msg = viewModel.errorMessage {
                Section {
                    Text(msg).foregroundColor(.red)
                }
            }
            unknownBandsReminderSection
            Section {
                buildButton
            }
        }
    }
    
    private var buildButton: some View {
        Button(action: buildButtonAction) {
            HStack {
                if viewModel.isBuilding {
                    ProgressView().padding(.trailing, 8)
                }
                Text(NSLocalizedString("AIScheduleBuild", comment: "Build schedule"))
            }
        }
        .disabled(viewModel.isBuilding)
    }
    
    @ViewBuilder
    private var unknownBandsReminderSection: some View {
        if unknownBandCountDisplay > 0 {
            Section {
                Text(String(format: NSLocalizedString("AIScheduleUnknownBandsReminder", comment: ""), unknownBandCountDisplay))
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func buildButtonAction() {
        let events = DataManager.shared.fetchEvents(forYear: viewModel.eventYear)
        let unknownCount = viewModel.unknownBandCount(events: events)
        if unknownCount > 0 {
            unknownBandCountForMessage = unknownCount
            pendingBuildEventsAfterUnknownWarning = events
            showUnknownBandsWarning = true
            return
        }
        proceedWithBuild(events: events)
    }
    
    private func proceedWithBuild(events: [EventData]) {
        let (hasExisting, count) = viewModel.existingAttendanceCount(events: events)
        if hasExisting {
            pendingBuildEvents = events
            existingAttendanceCountForMessage = count
            showExistingAttendanceWarning = true
        } else {
            viewModel.startBuild(events: events)
            checkStepForAlerts()
        }
    }
    
    @ViewBuilder
    private var mustConflictAlertButtons: some View {
        if let a = mustConflictEventA, let b = mustConflictEventB {
            Button(a.bandName) {
                viewModel.resolve(resolution: .mustConflict(choose: a))
                showMustConflictAlert = false
                checkStepForAlerts()
            }
            Button(b.bandName) {
                viewModel.resolve(resolution: .mustConflict(choose: b))
                showMustConflictAlert = false
                checkStepForAlerts()
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                showMustConflictAlert = false
                viewModel.isBuilding = false
            }
        }
    }
    
    private func checkStepForAlerts() {
        guard let step = viewModel.currentStep else { return }
        switch step {
        case .needMustConflict(let a, let b):
            mustConflictEventA = a
            mustConflictEventB = b
            showMustConflictAlert = true
        case .completed(let events):
            viewModel.writeAndFinish(events: events, onDone: {
                showCompletedAlert = true
            })
        }
    }
}
