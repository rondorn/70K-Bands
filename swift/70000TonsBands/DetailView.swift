//
//  DetailView.swift
//  70K Bands
//
//  Created by Assistant on 1/14/25.
//  Copyright (c) 2025 Ron Dorn. All rights reserved.
//

import SwiftUI
import Translation

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var offset: CGFloat = 0
    @State private var blockSwiping = false
    
    init(bandName: String) {
        self._viewModel = StateObject(wrappedValue: DetailViewModel(bandName: bandName))
        
    }
    
    var body: some View {
        if #available(iOS 17.4, *) {
            ZStack {
                // Main content that slides with animation
                mainContent
                    .offset(x: offset)
                    .modifier(DetailNavigationModifier(viewModel: viewModel))
                    .modifier(DetailLifecycleModifiers(viewModel: viewModel))
                    .preferredColorScheme(.dark)
                    .environment(\.colorScheme, .dark)
                    .background(Color.black.edgesIgnoringSafeArea(.all))
                
                // Toast overlay stays fixed and hovers over animation
                ToastOverlayView(toastManager: viewModel.toastManager)
                
                // Loading overlay for missing essential data
                if viewModel.isLoadingEssentialData {
                    loadingDataOverlay
                }
            }
            .ignoresSafeArea(.keyboard)
        } else {
            // Fallback on earlier versions
        }
    }
    
    // MARK: - Loading Data Overlay
    private var loadingDataOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                // Loading message
                Text("Loading band data...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Please wait while we fetch the latest information")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingEssentialData)
    }
    
    private var mainContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Compact top section - non-scrollable
                VStack(spacing: 0) {
                    // Band Logo - moved to very top
                    bandLogoSection
                    
                    // Schedule Events - right after logo
                    if !viewModel.scheduleEvents.isEmpty {
                        scheduleEventsSection
                    }
                    
                    // Links Section - after schedule events
                    if viewModel.hasAnyLinks {
                        linksSection
                    }
                    
                    // Band Details - after links
                    if viewModel.hasBandDetails {
                        bandDetailsSection
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.black)
                
                // Larger space before notes section
                Spacer(minLength: 20)
                
                // Scrollable Notes Section - takes remaining space
                notesSection
                    .frame(maxHeight: .infinity)
            }
            
            // Pinned sections at bottom
            VStack(spacing: 0) {
                Spacer()
                
                // Translation button - fixed above priority section
                if viewModel.showTranslationButton {
                    translationButtonSection
                        .background(Color.black.opacity(0.95))
                        .background(.ultraThinMaterial, in: Rectangle())
                }
                
                // Priority section at very bottom
                prioritySection
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { gesture in
                    if !blockSwiping {
                        // Show drag feedback
                        offset = gesture.translation.width * 0.3
                    }
                }
                .onEnded { gesture in
                    let swipeDistance = gesture.translation.width
                    
                    // Check if it's a valid swipe
                    if abs(swipeDistance) > 120 && !blockSwiping {
                        // Check boundaries before starting animation
                        let isSwipeLeft = swipeDistance < 0  // Swipe left = next
                        let isSwipeRight = swipeDistance > 0  // Swipe right = previous
                        
                        let canNavigate = (isSwipeLeft && !viewModel.isAtEnd()) || 
                                        (isSwipeRight && !viewModel.isAtStart())
                        
                        if canNavigate {
                            performCarouselAnimation(swipeDistance: swipeDistance)
                        } else {
                            // At boundary - show toast without animation
                            if isSwipeLeft {
                                viewModel.navigateToNext()  // This will show "End of List" toast
                            } else {
                                viewModel.navigateToPrevious()  // This will show "Already at Start" toast
                            }
                            // Snap back immediately without animation
                            offset = 0
                        }
                    } else {
                        // Snap back if insufficient swipe
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                        }
                    }
                }
        )
    }
    
    private func performCarouselAnimation(swipeDistance: CGFloat) {
        blockSwiping = true
        let screenWidth = UIScreen.main.bounds.width
        
        print("DEBUG: Carousel animation - swipeDistance: \(swipeDistance)")
        
        // Phase 1: Slide current content out in swipe direction
        let slideOutTarget: CGFloat = swipeDistance > 0 ? screenWidth : -screenWidth
        
        withAnimation(.easeOut(duration: 0.3)) {
            offset = slideOutTarget
        }
        
        // Phase 2: Update data after slide-out completes, then slide new content in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Update the data first (this will cause schedule events to re-render)
            if swipeDistance > 0 {
                print("DEBUG: Navigating to previous")
                self.viewModel.navigateToPrevious()
            } else {
                print("DEBUG: Navigating to next")
                self.viewModel.navigateToNext()
            }
            
            // Wait a brief moment for the data update to complete and UI to re-render
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Position new content on opposite side (off-screen)
                let slideInStart: CGFloat = swipeDistance > 0 ? -screenWidth : screenWidth
                self.offset = slideInStart
                
                // Slide new content in
                withAnimation(.easeOut(duration: 0.4)) {
                    self.offset = 0
                }
                
                // Re-enable swiping
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.blockSwiping = false
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var bandLogoSection: some View {
        Group {
            if let image = viewModel.bandImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 90) // 25% smaller (120 * 0.75 = 90)
                    .frame(maxWidth: .infinity)
            } else if viewModel.isLoadingImage {
                // Show small loading indicator when image is being loaded
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(maxHeight: 90)
                        .frame(maxWidth: .infinity)
                    
                    // Small centered loading spinner
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8) // Make it smaller than the main loading overlay
                }
            } else {
                // Keep image area empty (no placeholder) - let the space exist but be invisible
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxHeight: 90)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 0)
    }
    
    private var scheduleEventsSection: some View {
        VStack(spacing: 2) {
            ForEach(viewModel.scheduleEvents, id: \.id) { event in
                ScheduleEventView(event: event, viewModel: viewModel)
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 0)
    }
    
    private var linksSection: some View {
        HStack(spacing: 0) {
            Text("Links:")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                .frame(width: 140, alignment: .leading) // Match DetailRow label width for alignment
            
            // Links icons aligned to start above Country field and distributed to right edge
            HStack(spacing: 0) {
                if !viewModel.officialUrl.isEmpty {
                    LinkIconButton(iconType: .globe, url: viewModel.officialUrl, viewModel: viewModel)
                    if hasMoreThanOneLink() {
                        Spacer()
                    }
                }
                if !viewModel.metalArchivesUrl.isEmpty {
                    LinkIconButton(iconType: .metalArchives, url: viewModel.metalArchivesUrl, viewModel: viewModel)
                    if hasLinksAfterMetalArchives() {
                        Spacer()
                    }
                }
                if !viewModel.wikipediaUrl.isEmpty {
                    LinkIconButton(iconType: .wikipedia, url: viewModel.wikipediaUrl, viewModel: viewModel)
                    if !viewModel.youtubeUrl.isEmpty {
                        Spacer()
                    }
                }
                if !viewModel.youtubeUrl.isEmpty {
                    LinkIconButton(iconType: .youtube, url: viewModel.youtubeUrl, viewModel: viewModel)
                        .padding(.trailing, 8) // Close to right edge but not touching
                }
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 4) // Add small space after links
    }
    
    // Helper functions for link spacing logic
    private func hasMoreThanOneLink() -> Bool {
        let linkCount = [viewModel.officialUrl, viewModel.metalArchivesUrl, viewModel.wikipediaUrl, viewModel.youtubeUrl]
            .filter { !$0.isEmpty }.count
        return linkCount > 1
    }
    
    private func hasLinksAfterMetalArchives() -> Bool {
        return !viewModel.wikipediaUrl.isEmpty || !viewModel.youtubeUrl.isEmpty
    }
    
    private var bandDetailsSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            if !viewModel.country.isEmpty {
                DetailRow(label: NSLocalizedString("country", comment: "Country"), value: viewModel.country)
            }
            if !viewModel.genre.isEmpty {
                DetailRow(label: NSLocalizedString("genre", comment: "Genre"), value: viewModel.genre)
            }
            if !viewModel.lastOnCruise.isEmpty {
                DetailRow(label: NSLocalizedString("Last On Cruise", comment: "Last On Cruise"), value: viewModel.lastOnCruise)
            }
            if !viewModel.noteWorthy.isEmpty {
                DetailRow(label: NSLocalizedString("Note", comment: "Note"), value: viewModel.noteWorthy)
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 8) // Double space after info section
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isNotesEditable {
                // Editable TextEditor for custom notes
                TextEditor(text: $viewModel.customNotes)
                    .font(.system(size: viewModel.noteFontSizeLarge ? 19 : 15)) // Reduced by 1pt
                    .foregroundColor(.white)
                    .background(Color.black)
                    .modifier(ConditionalScrollContentBackground())
                    .padding(.horizontal, 14)
                    .padding(.top, 0)
                    .onChange(of: viewModel.customNotes) { _ in
                        viewModel.notesDidChange()
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            keyboardToolbarButtons
                        }
                    }
            } else {
                // Read-only Text with hyperlink support in ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if viewModel.customNotes.isEmpty {
                            Text("")
                                .font(.system(size: viewModel.noteFontSizeLarge ? 19 : 15))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.top, 0)
                        } else {
                            // Use hyperlink text parsing for !!!!https:// links
                            HyperlinkTextView(
                                text: viewModel.customNotes,
                                fontSize: viewModel.noteFontSizeLarge ? 19 : 15
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 0)
                            .textSelection(.enabled) // Allow text selection for non-link text
                        }
                        
                        // Add bottom padding to account for pinned sections
                        Spacer(minLength: viewModel.showTranslationButton ? 140 : 80)
                    }
                }
            }
        }
        .background(Color.black)
    }
    
    private var prioritySection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Priority icon on the far left, aligned with the picker
            Image(viewModel.priorityImageName)
                .resizable()
                .frame(width: 24, height: 24)
            
            // Priority picker takes up the rest of the space
            Picker("Priority", selection: $viewModel.selectedPriority) {
                Text(NSLocalizedString("Unknown", comment: "A Unknown See Band")).tag(0)
                Text(NSLocalizedString("Must", comment: "A Must See Band")).tag(1)
                Text(NSLocalizedString("Might", comment: "A Might See Band")).tag(2)
                Text(NSLocalizedString("Wont", comment: "A Wont See Band")).tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.95))
        .background(.ultraThinMaterial, in: Rectangle())
    }
    
    private var translationButtonSection: some View {
        HStack {
            Spacer()
            
            if viewModel.isCurrentTextTranslated {
                Button(viewModel.restoreButtonText) {
                    viewModel.restoreToEnglish()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(8)
            } else {
                Button(viewModel.translateButtonText) {
                    viewModel.translateText()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Keyboard Toolbar
    
    private var keyboardToolbarButtons: some View {
        HStack {
            // Select All button
            Button(NSLocalizedString("Select All", comment: "")) {
                // Select all text in the notes field
                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            // Done button
            Button(NSLocalizedString("Done", comment: "")) {
                // Dismiss keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .foregroundColor(.blue)
            .modifier(ConditionalFontWeight())
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func apply<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}

// MARK: - View Modifiers

struct ConditionalScrollContentBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(Visibility.hidden)
        } else {
            content
        }
    }
}

struct ConditionalFontWeight: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.fontWeight(.semibold)
        } else {
            content.font(.system(size: 17, weight: .semibold))
        }
    }
}

// MARK: - Supporting Views

struct ScheduleEventView: View {
    let event: ScheduleEvent
    let viewModel: DetailViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // Venue Color Bar (Tag 1 equivalent)
            Rectangle()
                .fill(event.venueColor)
                .frame(width: 4)
            
            // Main content with distinct columns
            HStack(spacing: 0) {
                // Left section: Location, Notes, and Event Type
                VStack(alignment: .leading, spacing: 0) {
                    // FIRST ROW: Venue name
                    HStack(alignment: .center, spacing: 8) {
                        Text(event.location)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Attended Icon (positioned after venue name, matching original Tag 4 position)
                        if event.attendedIcon.size.width > 0 && event.attendedIcon.size.height > 0 {
                            Image(uiImage: event.attendedIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .background(Color.clear)
                        } else {
                            // Show placeholder for empty icon (invisible but maintains spacing)
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .frame(height: 25)
                    
                    // SECOND ROW: Special notes and Event Type (separate sections)
                    HStack(alignment: .center, spacing: 0) {
                        // Special notes section
                        Text(event.notes.isEmpty ? " " : event.notes)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Event Type Section (separate from notes, text first, then icon)
                        if !event.eventType.isEmpty && event.eventType != "Show" {
                            HStack(spacing: 4) {
                                // Event type text (first)
                                Text(event.eventType)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                
                                // Event type icon (second)
                                Image(uiImage: event.eventTypeIcon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    .frame(height: 25)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                // Combined Time Column (start time above end time)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(event.startTime)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 25)
                    
                    Text(event.endTime)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0x79/255.0, green: 0x7D/255.0, blue: 0x7F/255.0))
                        .frame(height: 25)
                }
                .frame(width: 65, alignment: .trailing)
                
                // Day Column (distinct grey background with Day at top, number at bottom)
                VStack(spacing: 0) {
                    Text("Day")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 25)
                    
                    Text(event.day)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 25)
                }
                .frame(width: 35, height: 50)
                .background(Color.gray.opacity(0.2))
            }
        }
        .frame(height: 50)
        .background(Color.black)
        .cornerRadius(6)
        .onTapGesture {
            viewModel.toggleAttendedStatus(for: event)
        }
    }
}

enum LinkIconType {
    case globe, metalArchives, wikipedia, youtube
}

struct LinkIconButton: View {
    let iconType: LinkIconType
    let url: String
    let viewModel: DetailViewModel
    
    var body: some View {
        Button(action: {
            viewModel.openExternalBrowser(url: url)
        }) {
            iconView
                .frame(width: 30, height: 30)
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch iconType {
        case .globe:
            Image(systemName: "globe")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        case .metalArchives:
            Image("icon-ma")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 23)
        case .wikipedia:
            Image("icon-wiki")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 16)
        case .youtube:
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .font(.system(size: 15, weight: .regular)) // Changed to regular weight
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// MARK: - Toast Overlay View

struct ToastOverlayView: View {
    @ObservedObject var toastManager: ToastManager
    
    var body: some View {
        ZStack {
            if toastManager.isShowing {
                let _ = print("DEBUG: ToastOverlayView - rendering toast with message: '\(toastManager.message)'")
                
                // Toast styled to match main interface - text only, centered
                VStack {
                    Spacer()
                    
                    Text(toastManager.message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gray.opacity(0.8))
                        )
                        .padding(.horizontal, 16)
                    
                    Spacer()
                        .frame(height: 100)  // Position above bottom
                }
                .transition(.opacity)
                .zIndex(9999)  // Very high z-index
                .allowsHitTesting(false)
                .onAppear {
                    print("DEBUG: Toast onAppear - scheduling dismissal")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        print("DEBUG: Dismissing toast after 3 seconds")
                        withAnimation(.easeOut(duration: 0.13)) {
                            toastManager.isShowing = false
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

}

// MARK: - Custom ViewModifiers

struct DetailNavigationModifier: ViewModifier {
    @ObservedObject var viewModel: DetailViewModel
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(viewModel.bandName)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailLifecycleModifiers: ViewModifier {
    @ObservedObject var viewModel: DetailViewModel
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                print("DEBUG: DetailView appeared for band: '\(viewModel.bandName)'")
                viewModel.loadBandData()
            }
            .onDisappear {
                print("DEBUG: DetailView disappeared for band: '\(viewModel.bandName)'")
                // Only save if we're actually leaving the detail view entirely
                // (not during swipe navigation which handles saving manually)
                viewModel.saveNotes()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                viewModel.handleOrientationChange()
            }
    }
}

#Preview {
    NavigationView {
        DetailView(bandName: "Sample Band")
    }
}

// MARK: - Hyperlink Text View
struct HyperlinkTextView: View {
    let text: String
    let fontSize: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(parseTextWithLinks(), id: \.id) { segment in
                if segment.isLink, let url = segment.url, let displayText = segment.displayText {
                    Button(action: {
                        openInExternalBrowser(url)
                    }) {
                        Text(displayText)
                            .font(.system(size: fontSize))
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(segment.text)
                        .font(.system(size: fontSize))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func parseTextWithLinks() -> [TextSegment] {
        let pattern = "(!!!!https://|https://)[^\\s]+"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, options: [], range: range)
            
            var segments: [TextSegment] = []
            var lastIndex = 0
            
            for match in matches {
                let matchRange = match.range
                
                // Add text before the link
                if lastIndex < matchRange.location {
                    let beforeRange = NSRange(location: lastIndex, length: matchRange.location - lastIndex)
                    if let beforeText = Range(beforeRange, in: text) {
                        let textContent = String(text[beforeText])
                        if !textContent.isEmpty {
                            segments.append(TextSegment(text: textContent, isLink: false))
                        }
                    }
                }
                
                // Add the link
                if let linkRange = Range(matchRange, in: text) {
                    let fullLink = String(text[linkRange])
                    
                    // Handle both !!!!https:// and regular https:// URLs
                    let cleanUrl: String
                    let displayText: String
                    
                    if fullLink.hasPrefix("!!!!https://") {
                        // Remove the !!!! prefix for the actual URL
                        cleanUrl = String(fullLink.dropFirst(4)) // Remove "!!!!"
                        displayText = cleanUrl // Show the clean URL as display text
                    } else {
                        // Regular https:// URL - use as is
                        cleanUrl = fullLink
                        displayText = fullLink
                    }
                    
                    segments.append(TextSegment(
                        text: displayText,
                        isLink: true,
                        url: cleanUrl,
                        displayText: displayText
                    ))
                }
                
                lastIndex = matchRange.location + matchRange.length
            }
            
            // Add remaining text after the last link
            if lastIndex < text.count {
                let remainingRange = NSRange(location: lastIndex, length: text.count - lastIndex)
                if let remainingTextRange = Range(remainingRange, in: text) {
                    let remainingText = String(text[remainingTextRange])
                    if !remainingText.isEmpty {
                        segments.append(TextSegment(text: remainingText, isLink: false))
                    }
                }
            }
            
            // If no links were found, return the original text as a single segment
            if segments.isEmpty {
                segments.append(TextSegment(text: text, isLink: false))
            }
            
            return segments
            
        } catch {
            print("ERROR: Failed to parse hyperlinks: \(error)")
            // Fallback to original text if regex fails
            return [TextSegment(text: text, isLink: false)]
        }
    }
    
    private func openInExternalBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("ERROR: Invalid URL: \(urlString)")
            return
        }
        
        print("Opening URL in external browser: \(urlString)")
        
        // Use UIApplication to open in external browser (Safari)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("Successfully opened URL in external browser")
                } else {
                    print("Failed to open URL in external browser")
                }
            }
        } else {
            print("Cannot open URL: \(urlString)")
        }
    }
}

// MARK: - Text Segment Model
struct TextSegment: Identifiable {
    let id = UUID()
    let text: String
    let isLink: Bool
    let url: String?
    let displayText: String?
    
    init(text: String, isLink: Bool, url: String? = nil, displayText: String? = nil) {
        self.text = text
        self.isLink = isLink
        self.url = url
        self.displayText = displayText
    }
}

