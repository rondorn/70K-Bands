//
//  PreferencesView.swift
//  70K Bands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Environment: presenter for modal (avoids SwiftUI sheet re-presentation when Preferences re-renders)
private struct PreferencesPresenterKey: EnvironmentKey {
    static let defaultValue: UIViewController? = nil
}
extension EnvironmentValues {
    var preferencesPresenter: UIViewController? {
        get { self[PreferencesPresenterKey.self] }
        set { self[PreferencesPresenterKey.self] = newValue }
    }
}

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.preferencesPresenter) private var preferencesPresenter: UIViewController?
    @State private var minutesText: String = ""
    
    var body: some View {
        mainContent
            .modifier(NavigationModifier())
            .modifier(AlertModifiers(viewModel: viewModel, minutesText: $minutesText))
            .modifier(LifecycleModifiers(viewModel: viewModel, minutesText: $minutesText, presentationMode: presentationMode))
            .overlay(loadingOverlay)
    }
    
    private var mainContent: some View {
        Form {
            alertPreferencesSection
            detailScreenSection
            miscSection
            autoChooseAttendanceSection
            informationSection
            advancedPreferencesSection
        }
        .sheet(isPresented: $viewModel.showAutoChooseAttendanceWizard, onDismiss: {
            viewModel.showAutoChooseAttendanceWizard = false
            viewModel.refreshAutoChosenDataState()
        }) {
            AutoChooseAttendanceWizardView(eventYear: viewModel.selectedYearAsInt, onDismiss: { goToSchedule in
                viewModel.showAutoChooseAttendanceWizard = false
                if goToSchedule {
                    presentationMode.wrappedValue.dismiss()
                }
                viewModel.refreshAutoChosenDataState()
            })
        }
        .overlay {
            if viewModel.showReplaceAutoChoicesConfirmation {
                darkConfirmOverlay(
                    title: NSLocalizedString("AutoChooseAttendanceReplaceTitle", comment: ""),
                    message: NSLocalizedString("AutoChooseAttendanceReplaceMessage", comment: ""),
                    noAction: { viewModel.showReplaceAutoChoicesConfirmation = false },
                    yesAction: { viewModel.showReplaceAutoChoicesConfirmation = false; viewModel.confirmReplaceAutoChoicesAndStartWizard() }
                )
            }
        }
        .overlay {
            if viewModel.showClearAllConfirmation {
                darkConfirmOverlay(
                    title: NSLocalizedString("AutoChooseAttendanceClearAllTitle", comment: ""),
                    message: viewModel.clearAllCount == 0
                        ? NSLocalizedString("AutoChooseAttendanceClearAllMessageNone", comment: "")
                        : String(format: NSLocalizedString("AutoChooseAttendanceClearAllMessage", comment: ""), viewModel.clearAllCount),
                    noAction: { viewModel.showClearAllConfirmation = false },
                    yesAction: { viewModel.showClearAllConfirmation = false; viewModel.confirmClearAllAttendance() }
                )
            }
        }
        .onAppear {
            viewModel.refreshAutoChosenDataState()
        }
        .onChange(of: viewModel.selectedYear) { _ in
            viewModel.refreshAutoChosenDataState()
        }
    }
    
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoadingData {
                ZStack {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2.0)
                        
                        Text(NSLocalizedString("waiting_for_data", comment: ""))
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .medium, design: .default))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingData)
            } else if viewModel.scheduleQRBandFileDownloading {
                ZStack {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2.0)
                        Text(NSLocalizedString("QR downloading band list", comment: ""))
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .medium, design: .default))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
    }
    
    /// Dark-styled confirmation dialog to match Plan Your Schedule prompt (dark background, No left / Yes right).
    private func darkConfirmOverlay(title: String, message: String, noAction: @escaping () -> Void, yesAction: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { }
            VStack(spacing: 16) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button(NSLocalizedString("No", comment: "")) {
                        noAction()
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    Button(NSLocalizedString("Yes", comment: "")) {
                        yesAction()
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(Color(white: 0.10))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        }
    }
    
    // MARK: - View Components
    
    private var alertPreferencesSection: some View {
        Section(NSLocalizedString("AlertPreferences", comment: "")) {
            Toggle(NSLocalizedString("Alert On Must See Bands", comment: ""), isOn: $viewModel.alertOnMustSee)
                .disabled(viewModel.alertOnlyForWillAttend)
                .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
            
            Toggle(NSLocalizedString("Alert On Might See Bands", comment: ""), isOn: $viewModel.alertOnMightSee)
                .disabled(viewModel.alertOnlyForWillAttend)
                .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
            
            Toggle(NSLocalizedString("Alert Only for Will Attend Events", comment: ""), isOn: $viewModel.alertOnlyForWillAttend)
            
            minutesBeforeAlertView
            
            alertTogglesView
        }
    }
    
    private var minutesBeforeAlertView: some View {
        HStack {
            Text(NSLocalizedString("Minutes Before Event to Alert", comment: ""))
            Spacer()
            TextField(NSLocalizedString("Minutes", comment: "Minutes number field placeholder"), text: $minutesText)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 60)
                .onChange(of: minutesText) { newValue in
                    if let intValue = Int(newValue), intValue >= 0 && intValue <= 60 {
                        viewModel.minutesBeforeAlert = intValue
                    }
                }
        }
    }
    
    private var alertTogglesView: some View {
        Group {
            alertToggleRow(NSLocalizedString("Alert For Shows", comment: ""), binding: $viewModel.alertForShows)
            alertToggleRow(NSLocalizedString("Alert For Special Events", comment: ""), binding: $viewModel.alertForSpecialEvents)
            alertToggleRow(NSLocalizedString("Alert For Unofficial Events", comment: ""), binding: $viewModel.alertForCruiserOrganized)
            alertToggleRow(NSLocalizedString("Alert For Meeting and Greet Events", comment: ""), binding: $viewModel.alertForMeetAndGreet)
            alertToggleRow(NSLocalizedString("Alert For Clinics", comment: ""), binding: $viewModel.alertForClinics)
            alertToggleRow(NSLocalizedString("Alert For Album Listening Events", comment: ""), binding: $viewModel.alertForAlbumListening)
        }
    }
    
    private func alertToggleRow(_ title: String, binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
            .disabled(viewModel.alertOnlyForWillAttend)
            .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
    }
    
    private var detailScreenSection: some View {
        Section(NSLocalizedString("DetailScreenSection", comment: "")) {
            Toggle(NSLocalizedString("NoteFontSize", comment: ""), isOn: $viewModel.noteFontSizeLarge)
            Toggle(NSLocalizedString("OpenYouTubeApp", comment: ""), isOn: $viewModel.openYouTubeApp)
            Toggle(NSLocalizedString("AllLinksOpenInExternalBrowser", comment: ""), isOn: $viewModel.allLinksOpenInExternalBrowser)
        }
    }
    
    private var informationSection: some View {
        Section(NSLocalizedString("Information", comment: "")) {
            NavigationLink(destination: AboutView()) {
                Text("About")
                    .font(.body)
            }
            informationRowView(label: NSLocalizedString("User Identifier", comment: ""), value: viewModel.userId)
            informationRowView(label: NSLocalizedString("Build", comment: ""), value: viewModel.buildInfo)
        }
    }
    
    private func informationRowView(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private var miscSection: some View {
        Section(NSLocalizedString("MiscSection", comment: "")) {
            yearSelectionView
            
            if viewModel.isLoadingData {
                loadingIndicatorView
            }
        }
    }
    
    private var autoChooseAttendanceSection: some View {
        Group {
            if FestivalConfig.current.aiSchedule {
                Section(NSLocalizedString("AutoChooseAttendanceSection", comment: "Auto Choose Attendance")) {
                    Button(NSLocalizedString("AutoChooseAttendanceTriggerWizard", comment: "Trigger Auto Choose Attendance Wizard")) {
                        viewModel.triggerAutoChooseAttendanceWizard()
                    }
                    Button(NSLocalizedString("AutoChooseAttendanceClearAll", comment: "Clear all attendance")) {
                        viewModel.requestClearAllAttendance()
                    }
                    .disabled(viewModel.clearAllCount == 0)
                }
            }
        }
    }
    
    private var yearSelectionView: some View {
        HStack {
            Text(NSLocalizedString("SelectYearLabel", comment: ""))
            Spacer()
            Menu(viewModel.selectedYear) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Button(action: {
                        viewModel.selectYear(year)
                    }) {
                        HStack {
                            Text(year)
                            if year == viewModel.selectedYear {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .foregroundColor(.blue)
            .disabled(viewModel.isLoadingData)
        }
    }
    
    private var loadingIndicatorView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var advancedPreferencesSection: some View {
        Section {
            // Warning text
            Text(NSLocalizedString("AdvancedPreferencesWarning", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            
            // Pointer URL
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Pointer URL", comment: ""))
                    .font(.body)
                    .foregroundColor(.primary)
                Picker("", selection: $viewModel.pointerUrl) {
                    ForEach(viewModel.pointerUrlOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            // Custom Pointer URL
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Custom Pointer URL", comment: ""))
                    .font(.body)
                    .foregroundColor(.primary)
                TextField(NSLocalizedString("CustomPointerUrlPlaceholder", comment: ""), text: $viewModel.customPointerUrl)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            .padding(.vertical, 4)
            
            // Scan QR Code Schedule (70K only; MDF has no real-world use case)
            if FestivalConfig.current.scheduleQRShareEnabled {
                Button(action: presentQRScannerIfAvailable) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("Scan QR Code Schedule", comment: "Preferences button to scan schedule QR"))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(NSLocalizedString("AdvancedPreferences", comment: ""))
        }
        .alert(NSLocalizedString("Schedule from QR", comment: "QR import result title"), isPresented: Binding(
            get: { viewModel.scheduleQRImportResult != nil },
            set: { if !$0 { viewModel.scheduleQRImportResult = nil } }
        )) {
            Button(NSLocalizedString("OK", comment: "")) {
                viewModel.scheduleQRImportResult = nil
            }
        } message: {
            if let result = viewModel.scheduleQRImportResult {
                Text(result.message)
            }
        }
        .onChange(of: viewModel.scheduleQRScanReadyAfterDownload) { newValue in
            if newValue { presentQRScannerIfReadyAfterDownload() }
        }
    }

    /// Presents the schedule QR scanner modally via UIKit so it is only presented once (avoids SwiftUI sheet re-present when Preferences re-renders).
    private func presentQRScannerIfAvailable() {
        guard let presenter = preferencesPresenter else { return }
        let year = viewModel.selectedYearAsInt
        if !isBandFileAvailableForQR(eventYear: year) {
            guard NetworkTesting.isNetworkAvailable() else {
                viewModel.scheduleQRImportResult = (false, bandFileRequiredMessageNoNetwork())
                return
            }
            viewModel.scheduleQRBandFileDownloading = true
            BandCSVImporter().downloadAndImportBands(forceDownload: true) { [viewModel] success in
                DispatchQueue.main.async {
                    viewModel.scheduleQRBandFileDownloading = false
                    if success, isBandFileAvailableForQR(eventYear: year) {
                        viewModel.scheduleQRScanReadyAfterDownload = true
                    } else {
                        viewModel.scheduleQRImportResult = (false, NSLocalizedString("QR band file download failed", comment: ""))
                    }
                }
            }
            return
        }
        presentQRScanner()
    }

    private func presentQRScanner() {
        guard let presenter = preferencesPresenter else { return }
        var scannerVC: UIHostingController<ScheduleBinaryQRScannerView>!
        scannerVC = UIHostingController(rootView: ScheduleBinaryQRScannerView(
            onScan: { payloads in
                let done = viewModel.handleScannedPayload(payloads)
                if done {
                    scannerVC.dismiss(animated: true) {
                        NotificationCenter.default.post(name: Notification.Name("DismissPreferencesScreen"), object: nil)
                    }
                }
                return done
            },
            onCancel: {
                scannerVC.dismiss(animated: true)
            }
        ))
        scannerVC.modalPresentationStyle = .pageSheet
        presenter.present(scannerVC, animated: true)
    }
}

// MARK: - QR scan after band file download
extension PreferencesView {
    /// When band file download completes successfully, present the scanner (called from onChange).
    func presentQRScannerIfReadyAfterDownload() {
        guard viewModel.scheduleQRScanReadyAfterDownload else { return }
        viewModel.scheduleQRScanReadyAfterDownload = false
        presentQRScanner()
    }
}

// MARK: - Custom ViewModifiers

struct NavigationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationTitle("\(FestivalConfig.current.appName) \(NSLocalizedString("Preferences", comment: ""))")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ConditionalToolbarModifier())
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
            .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct AlertModifiers: ViewModifier {
    @ObservedObject var viewModel: PreferencesViewModel
    @Binding var minutesText: String
    
    func body(content: Content) -> some View {
        content
            .alert(NSLocalizedString("changeYearDialogBoxTitle", comment: ""), isPresented: $viewModel.showYearChangeConfirmation) {
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                    viewModel.cancelYearChange()
                }
                Button(NSLocalizedString("Ok", comment: "")) {
                    viewModel.confirmYearChange()
                }
            } message: {
                Text(NSLocalizedString("restartMessage", comment: ""))
            }
            .alert("Invalid Input", isPresented: $viewModel.showValidationError) {
                Button("OK") {
                    minutesText = String(viewModel.minutesBeforeAlert)
                }
            } message: {
                Text("Minutes must be a value between 0 and 60.")
            }
            .alert(NSLocalizedString("changeYearDialogBoxTitle", comment: ""), isPresented: $viewModel.showBandEventChoice) {
                Button(NSLocalizedString("bandListButton", comment: "")) {
                    viewModel.selectBandList()
                }
                Button(NSLocalizedString("eventListButton", comment: "")) {
                    viewModel.selectEventList()
                }
            } message: {
                Text(NSLocalizedString("eventOrBandPrompt", comment: ""))
            }
            .alert(NSLocalizedString("changeYearDialogBoxTitle", comment: ""), isPresented: $viewModel.showNetworkError) {
                Button(NSLocalizedString("Ok", comment: "")) {
                    viewModel.dismissNetworkError()
                }
            } message: {
                Text(NSLocalizedString("yearChangeAborted", comment: ""))
            }
            .alert("Year Change Failed", isPresented: $viewModel.showDownloadError) {
                Button(NSLocalizedString("Ok", comment: "")) {
                    viewModel.dismissDownloadError()
                }
            } message: {
                Text("Failed to download data for the selected year. Reverted to previous year.")
            }
    }
}

struct LifecycleModifiers: ViewModifier {
    let viewModel: PreferencesViewModel
    @Binding var minutesText: String
    let presentationMode: Binding<PresentationMode>
    @State private var hasLoadedInitialPreferences = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.refreshAvailableYears()
                
                // 🔧 FIX: Only load preferences on first appearance to prevent iPad split-screen reversion
                if !hasLoadedInitialPreferences {
                    print("🎛️ [PREFERENCES_SYNC] Loading initial preferences (first appearance)")
                    viewModel.loadCurrentPreferences()
                    hasLoadedInitialPreferences = true
                } else {
                    print("🎛️ [PREFERENCES_SYNC] Skipping preference reload (subsequent appearance) - preserving user changes")
                }
                
                minutesText = String(viewModel.minutesBeforeAlert)
            }
            .onChange(of: viewModel.minutesBeforeAlert) { newValue in
                minutesText = String(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissPreferencesScreen"))) { _ in
                presentationMode.wrappedValue.dismiss()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissPreferencesScreenAfterYearChange"))) { _ in
                presentationMode.wrappedValue.dismiss()
            }
    }
}

struct ConditionalToolbarModifier: ViewModifier {
    @EnvironmentObject private var deviceSize: DeviceSizeManager
    func body(content: Content) -> some View {
        if deviceSize.isLargeDisplay {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("Close", comment: "")) {
                            // Send notification to dismiss preferences
                            NotificationCenter.default.post(name: Notification.Name("DismissPreferencesScreen"), object: nil)
                        }
                        .font(.system(size: 17, weight: .semibold, design: .default))
                    }
                }
        } else {
            content
        }
    }
}

#Preview {
    PreferencesView().environmentObject(DeviceSizeManager.shared)
}

// Note: String.isYearString extension is defined in PreferencesViewModel.swift
