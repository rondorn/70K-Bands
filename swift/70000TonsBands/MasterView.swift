//
//  MasterView.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import SwiftUI
import UIKit

struct MasterView: View {
    @StateObject private var viewModel = MasterViewModel()
    @State private var selectedBand: String? = nil
    @State private var showingPreferences = false
    @State private var showingStats = false
    @State private var searchText = ""
    @State private var showingFilterMenu = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                if viewModel.isSearchVisible {
                    SearchBar(text: $searchText, onSearchButtonClicked: {
                        viewModel.performSearch(searchText)
                    }, onCancel: {
                        searchText = ""
                        viewModel.cancelSearch()
                    })
                }
                
                // Main Content
                ZStack {
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        bandListView
                    }
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // Menu button
                    Button(action: { showingFilterMenu.toggle() }) {
                        Image(systemName: "line.horizontal.3")
                    }
                    .popover(isPresented: $showingFilterMenu) {
                        FilterMenuView(viewModel: viewModel)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Search button
                    Button(action: { viewModel.toggleSearch() }) {
                        Image(systemName: "magnifyingglass")
                    }
                    
                    // Stats button
                    Button(action: { showingStats.toggle() }) {
                        Image(systemName: "chart.bar")
                    }
                    .sheet(isPresented: $showingStats) {
                        WebView(url: viewModel.statsURL)
                    }
                    
                    // Preferences button
                    Button(action: { showingPreferences.toggle() }) {
                        Image(systemName: "gear")
                    }
                    .sheet(isPresented: $showingPreferences) {
                        PreferencesView()
                    }
                    
                    // Share button
                    Button(action: { viewModel.shareData() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .preferredColorScheme(.dark)
            .background(Color.black.edgesIgnoringSafeArea(.all))
            
            // Detail view placeholder
            Text("Select a band to see details")
                .foregroundColor(.secondary)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .onAppear {
            viewModel.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshDisplay"))) { _ in
            viewModel.refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("iCloudRefresh"))) { _ in
            viewModel.refreshData()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2.0)
            
            Text("Loading band data...")
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private var bandListView: some View {
        List(viewModel.filteredBands, id: \.self, selection: $selectedBand) { bandName in
            NavigationLink(
                destination: DetailView(bandName: bandName),
                tag: bandName,
                selection: $selectedBand
            ) {
                BandRowView(
                    bandName: bandName,
                    priority: viewModel.getBandPriority(bandName),
                    hasEvents: viewModel.bandHasEvents(bandName),
                    eventCount: viewModel.getBandEventCount(bandName)
                )
            }
            .listRowBackground(Color.black)
        }
        .listStyle(PlainListStyle())
        .background(Color.black)
        .onChange(of: searchText) { newValue in
            viewModel.filterBands(searchText: newValue)
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        await viewModel.performFullRefresh()
        isRefreshing = false
    }
}

struct BandRowView: View {
    let bandName: String
    let priority: Int
    let hasEvents: Bool
    let eventCount: Int
    
    var body: some View {
        HStack {
            // Priority indicator
            priorityIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bandName)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                if hasEvents {
                    Text("\(eventCount) event\(eventCount == 1 ? "" : "s")")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Spacer()
            
            // Event indicator
            if hasEvents {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var priorityIcon: some View {
        Group {
            switch priority {
            case 1: // Must See
                Image(systemName: "star.fill")
                    .foregroundColor(.red)
            case 2: // Might See
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            case 3: // Won't See
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            default: // Unknown
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 14))
        .frame(width: 20)
    }
}

struct FilterMenuView: View {
    @ObservedObject var viewModel: MasterViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Show/Hide Filters") {
                    Toggle("Must See", isOn: $viewModel.showMustSee)
                    Toggle("Might See", isOn: $viewModel.showMightSee)
                    Toggle("Won't See", isOn: $viewModel.showWontSee)
                    Toggle("Unknown", isOn: $viewModel.showUnknown)
                }
                
                Section("Sort Options") {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        Text("Band Name").tag(SortOption.name)
                        Text("Event Time").tag(SortOption.time)
                        Text("Priority").tag(SortOption.priority)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("View Options") {
                    Toggle("Show Only Bands with Events", isOn: $viewModel.showOnlyBandsWithEvents)
                    Toggle("Hide Expired Events", isOn: $viewModel.hideExpiredEvents)
                }
            }
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    let onCancel: () -> Void
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            TextField("Search bands...", text: $text, onEditingChanged: { editing in
                isEditing = editing
            }, onCommit: onSearchButtonClicked)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .overlay(
                HStack {
                    Spacer()
                    if !text.isEmpty {
                        Button(action: {
                            text = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 8)
                    }
                }
            )
            
            if isEditing {
                Button("Cancel") {
                    text = ""
                    isEditing = false
                    onCancel()
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black)
    }
}

enum SortOption: CaseIterable {
    case name, time, priority
    
    var displayName: String {
        switch self {
        case .name: return "Band Name"
        case .time: return "Event Time"
        case .priority: return "Priority"
        }
    }
}

#Preview {
    MasterView()
}
