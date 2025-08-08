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
        Form {
                // Show/Hide Expired Section
                Section(NSLocalizedString("showHideExpiredLabel", comment: "")) {
                    Toggle(NSLocalizedString("hideExpiredEvents", comment: ""), isOn: $viewModel.hideExpiredEvents)
                }
                
                // Prompt For Attended Status Section
                Section("Prompt For Attended Status") {
                    Toggle("Prompt For Attended Status", isOn: $viewModel.promptForAttended)
                }
                
                // Alert Preferences Section
                Section(NSLocalizedString("AlertPreferences", comment: "")) {
                    Toggle("Alert On Must See Bands", isOn: $viewModel.alertOnMustSee)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert On Might See Bands", isOn: $viewModel.alertOnMightSee)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert Only for Will Attend Events", isOn: $viewModel.alertOnlyForWillAttend)
                    
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
                    
                    Toggle("Alert For Shows", isOn: $viewModel.alertForShows)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert For Special Events", isOn: $viewModel.alertForSpecialEvents)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert For Unofficial Events", isOn: $viewModel.alertForCruiserOrganized)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert For Meeting and Greet Events", isOn: $viewModel.alertForMeetAndGreet)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert For Clinics", isOn: $viewModel.alertForClinics)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                    
                    Toggle("Alert For Album Listening Events", isOn: $viewModel.alertForAlbumListening)
                        .disabled(viewModel.alertOnlyForWillAttend)
                        .foregroundColor(viewModel.alertOnlyForWillAttend ? .secondary : .primary)
                }
                
                // Detail Screen Section
                Section(NSLocalizedString("DetailScreenSection", comment: "")) {
                    Toggle(NSLocalizedString("NoteFontSize", comment: ""), isOn: $viewModel.noteFontSizeLarge)
                }
                
                // Misc Section
                Section(NSLocalizedString("MiscSection", comment: "")) {
                    HStack {
                        Text(NSLocalizedString("SelectYearLabel", comment: ""))
                        Spacer()
                        Menu(viewModel.selectedYear) {
                            ForEach(viewModel.availableYears, id: \.self) { year in
                                Button(year) {
                                    viewModel.selectYear(year)
                                }
                            }
                        }
                        .foregroundColor(.blue)
                        .disabled(viewModel.isLoadingData)
                    }
                    
                    if viewModel.isLoadingData {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UserID: \(viewModel.userId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Build: \(viewModel.buildInfo)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
        }
        .navigationTitle(NSLocalizedString("PreferenceHeader", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only show close button on iPad split view (modal presentation)
            if UIDevice.current.userInterfaceIdiom == .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Ok", comment: "")) {
                        // Send notification to dismiss preferences
                        NotificationCenter.default.post(name: Notification.Name("DismissPreferencesScreen"), object: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.refreshAvailableYears()
            viewModel.loadCurrentPreferences()
            minutesText = String(viewModel.minutesBeforeAlert)
        }
        .onDisappear {
            viewModel.refreshDataAndNotifications()
        }
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
        .onChange(of: viewModel.minutesBeforeAlert) { newValue in
            minutesText = String(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissPreferencesScreen"))) { _ in
            // This will be handled by MasterViewController for in-frame display
            presentationMode.wrappedValue.dismiss()
        }
        .overlay(
            // Fullscreen loading overlay
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
                                .font(.title2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingData)
                }
            }
        )
    }
}

#Preview {
    PreferencesView()
}

// Note: String.isYearString extension is defined in PreferencesViewModel.swift
