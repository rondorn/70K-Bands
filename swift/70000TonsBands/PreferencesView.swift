//
//  PreferencesView.swift
//  70K Bands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import SwiftUI

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @Environment(\.presentationMode) var presentationMode
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
            expiredEventsSection
            promptForAttendedSection
            alertPreferencesSection
            detailScreenSection
            miscSection
            informationSection
            advancedPreferencesSection
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
            }
        }
    }
    
    // MARK: - View Components
    
    private var expiredEventsSection: some View {
        Section(NSLocalizedString("showHideExpiredLabel", comment: "")) {
            Toggle(NSLocalizedString("hideExpiredEvents", comment: ""), isOn: $viewModel.hideExpiredEvents)
        }
    }
    
    private var promptForAttendedSection: some View {
        Section("Prompt For Attended Status") {
            Toggle("Prompt For Attended Status", isOn: $viewModel.promptForAttended)
        }
    }
    
    private var alertPreferencesSection: some View {
        Section(NSLocalizedString("AlertPreferences", comment: "")) {
            Toggle("Alert On Must See Bands", isOn: $viewModel.alertOnMustSee)
                .disabled(viewModel.alertOnlyForWillAttend)
                .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
            
            Toggle("Alert On Might See Bands", isOn: $viewModel.alertOnMightSee)
                .disabled(viewModel.alertOnlyForWillAttend)
                .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
            
            Toggle("Alert Only for Will Attend Events", isOn: $viewModel.alertOnlyForWillAttend)
            
            minutesBeforeAlertView
            
            alertTogglesView
        }
    }
    
    private var minutesBeforeAlertView: some View {
        HStack {
            Text("Minutes Before Event to Alert")
            Spacer()
            TextField("Minutes", text: $minutesText)
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
            alertToggleRow("Alert For Shows", binding: $viewModel.alertForShows)
            alertToggleRow("Alert For Special Events", binding: $viewModel.alertForSpecialEvents)
            alertToggleRow("Alert For Unofficial Events", binding: $viewModel.alertForCruiserOrganized)
            alertToggleRow("Alert For Meeting and Greet Events", binding: $viewModel.alertForMeetAndGreet)
            alertToggleRow("Alert For Clinics", binding: $viewModel.alertForClinics)
            alertToggleRow("Alert For Album Listening Events", binding: $viewModel.alertForAlbumListening)
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
                Text("Custom Pointer URL")
                    .font(.body)
                    .foregroundColor(.primary)
                TextField("Leave empty to use default", text: $viewModel.customPointerUrl)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            .padding(.vertical, 4)
        } header: {
            Text(NSLocalizedString("AdvancedPreferences", comment: ""))
        }
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
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
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
    PreferencesView()
}

// Note: String.isYearString extension is defined in PreferencesViewModel.swift
