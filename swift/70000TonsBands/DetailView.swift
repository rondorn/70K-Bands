//
//  DetailView.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import SwiftUI
import WebKit

struct DetailView: View {
    let bandName: String
    @StateObject private var viewModel: DetailViewModel
    @State private var showingWebView = false
    @State private var webURL: URL?
    @State private var showingTranslation = false
    @State private var showingNoteEditor = false
    
    init(bandName: String) {
        self.bandName = bandName
        self._viewModel = StateObject(wrappedValue: DetailViewModel(bandName: bandName))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Band Logo
                if let logoImage = viewModel.bandLogo {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 80)
                        .frame(maxWidth: .infinity)
                }
                
                // Priority Section
                prioritySection
                
                // Band Information
                bandInfoSection
                
                // Events Section
                if !viewModel.events.isEmpty {
                    eventsSection
                }
                
                // Links Section
                if viewModel.hasAnyLinks {
                    linksSection
                }
                
                // Notes Section
                notesSection
            }
            .padding()
        }
        .navigationTitle(bandName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Share") {
                    viewModel.shareData()
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let url = webURL {
                WebView(url: url)
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(
                bandName: bandName,
                initialText: viewModel.customNotes,
                onSave: { notes in
                    viewModel.saveCustomNotes(notes)
                }
            )
        }
        .preferredColorScheme(.dark)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.loadData()
        }
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                priorityIcon(for: viewModel.priority)
                
                Picker("Priority", selection: $viewModel.priority) {
                    Text("Unknown").tag(0)
                    Text("Must See").tag(1)
                    Text("Might See").tag(2)
                    Text("Won't See").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.priority) { newValue in
                    viewModel.updatePriority(newValue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var bandInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Band Information")
                .font(.headline)
                .foregroundColor(.white)
            
            if !viewModel.country.isEmpty {
                InfoRow(label: "Country", value: viewModel.country)
            }
            
            if !viewModel.genre.isEmpty {
                InfoRow(label: "Genre", value: viewModel.genre)
            }
            
            if !viewModel.lastOnCruise.isEmpty {
                InfoRow(label: "Last on Cruise", value: viewModel.lastOnCruise)
            }
            
            if !viewModel.noteWorthy.isEmpty {
                InfoRow(label: "Note Worthy", value: viewModel.noteWorthy)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Events")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(Array(viewModel.events.enumerated()), id: \.offset) { index, event in
                EventRowView(event: event)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visit Links")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if !viewModel.officialURL.isEmpty {
                    LinkButton(title: "Official Site", systemImage: "globe") {
                        openURL(viewModel.officialURL)
                    }
                }
                
                if !viewModel.wikipediaURL.isEmpty {
                    LinkButton(title: "Wikipedia", systemImage: "book") {
                        openURL(viewModel.wikipediaURL)
                    }
                }
                
                if !viewModel.youtubeURL.isEmpty {
                    LinkButton(title: "YouTube", systemImage: "play.rectangle") {
                        openURL(viewModel.youtubeURL)
                    }
                }
                
                if !viewModel.metalArchivesURL.isEmpty {
                    LinkButton(title: "Metal Archives", systemImage: "archivebox") {
                        openURL(viewModel.metalArchivesURL)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Notes")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Edit") {
                    showingNoteEditor = true
                }
                .foregroundColor(.blue)
                
                if !viewModel.customNotes.isEmpty {
                    Button("Translate") {
                        viewModel.translateNotes()
                    }
                    .foregroundColor(.green)
                }
            }
            
            if viewModel.customNotes.isEmpty {
                Text("No custom notes. Tap Edit to add some.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(viewModel.displayedNotes)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
            }
            
            // Language toggle if translation is available
            if viewModel.hasTranslation {
                HStack {
                    Button(viewModel.isShowingTranslation ? "Show English" : "Show Translation") {
                        viewModel.toggleTranslation()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func priorityIcon(for priority: Int) -> some View {
        Group {
            switch priority {
            case 1:
                Image(systemName: "star.fill")
                    .foregroundColor(.red)
            case 2:
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            case 3:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            default:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 20))
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            webURL = url
            showingWebView = true
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

struct EventRowView: View {
    let event: BandEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Location color indicator
                Rectangle()
                    .fill(Color(event.locationColor))
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.location)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if !event.eventType.isEmpty {
                        Text(event.eventType)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if !event.notes.isEmpty {
                        Text(event.notes)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let startTime = event.startTime {
                        Text(DateFormatter.timeFormatter.string(from: startTime))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let endTime = event.endTime {
                        Text(DateFormatter.timeFormatter.string(from: endTime))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Day indicator
                if !event.day.isEmpty {
                    VStack(spacing: 2) {
                        Text("Day")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .background(Color.gray)
                        
                        Text(event.day)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .background(Color.gray)
                    }
                    .cornerRadius(4)
                }
            }
            
            // Attended indicator
            if event.isAttended {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Attended")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

struct LinkButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }
}

struct NoteEditorView: View {
    let bandName: String
    @State private var noteText: String
    let onSave: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    init(bandName: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.bandName = bandName
        self._noteText = State(initialValue: initialText)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $noteText)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
            }
            .navigationTitle("Notes for \(bandName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(noteText)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Supporting Types

struct BandEvent {
    let location: String
    let eventType: String
    let notes: String
    let startTime: Date?
    let endTime: Date?
    let day: String
    let locationColor: UIColor
    let isAttended: Bool
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationView {
        DetailView(bandName: "Sample Band")
    }
}
