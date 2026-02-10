//
//  LandscapeScheduleView.swift
//  70K Bands
//
//  Created by Cursor on 2/5/26.
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import SwiftUI

// MARK: - Trackable Scroll View

struct TrackableScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    @Binding var contentOffset: CGPoint
    let content: Content
    
    init(axes: Axis.Set = .vertical, showsIndicators: Bool = true, contentOffset: Binding<CGPoint>, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self._contentOffset = contentOffset
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).origin
                )
            }
            .frame(width: 0, height: 0)
            
            content
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            contentOffset = CGPoint(x: -value.x, y: -value.y)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - Models

struct DayScheduleData: Identifiable {
    let id = UUID()
    let dayLabel: String  // "Day 1", "1/27", etc.
    let venues: [VenueColumn]
    let timeSlots: [TimeSlot]
    let startTime: Date
    let endTime: Date
    let baseTimeIndex: TimeInterval  // The timeIndex of the first event (for calculating offsets)
}

struct VenueColumn: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let events: [ScheduleBlock]
}

struct ScheduleBlock: Identifiable {
    let id = UUID()
    let bandName: String
    let startTime: Date
    let endTime: Date
    let startTimeString: String  // Original time string (e.g., "17:30") for attendance tracking
    let eventType: String
    let location: String
    let day: String
    let timeIndex: TimeInterval
    let priority: Int  // 0=none, 1=must, 2=might, 3=wont
    let attendedStatus: String  // "" = not attended, "sawAll" = attended all, "sawSome" = attended some
    let isExpired: Bool  // true if the event has ended
}

struct TimeSlot: Identifiable {
    let id = UUID()
    let time: Date
    let label: String  // "7pm", "8pm", etc.
}

// MARK: - Landscape Schedule View

struct LandscapeScheduleView: View {
    @StateObject private var viewModel: LandscapeScheduleViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let priorityManager: SQLitePriorityManager
    let onBandTapped: (String, String?) -> Void  // (bandName, currentDay)
    let attendedHandle: ShowsAttended
    let isSplitViewCapable: Bool  // iPad or similar
    let onDismissRequested: (() -> Void)?  // iPad: callback to return to list view
    
    init(priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended, initialDay: String? = nil, hideExpiredEvents: Bool = false, isSplitViewCapable: Bool = false, onDismissRequested: (() -> Void)? = nil, onBandTapped: @escaping (String, String?) -> Void) {
        self.priorityManager = priorityManager
        self._viewModel = StateObject(wrappedValue: LandscapeScheduleViewModel(
            priorityManager: priorityManager,
            attendedHandle: attendedHandle,
            initialDay: initialDay,
            hideExpiredEvents: hideExpiredEvents
        ))
        self.onBandTapped = onBandTapped
        self.attendedHandle = attendedHandle
        self.isSplitViewCapable = isSplitViewCapable
        self.onDismissRequested = onDismissRequested
    }
    
    func getCurrentDay() -> String? {
        return viewModel.currentDayData?.dayLabel
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if viewModel.isLoading {
                loadingView
            } else if let dayData = viewModel.currentDayData {
                scheduleGridView(dayData: dayData)
            } else {
                noDataView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadScheduleData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DetailScreenDismissed"))) { notification in
            // Refresh the event that was just viewed in the detail screen
            if let bandName = notification.userInfo?["bandName"] as? String {
                print("🔄 [LANDSCAPE_SCHEDULE] Detail screen dismissed for \(bandName), refreshing event")
                viewModel.refreshEventData(bandName: bandName)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading schedule...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - No Data View
    
    private var noDataView: some View {
        ZStack {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("No Schedule Data Available")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Schedule information is not currently loaded")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // iPad: Add return to list view button
            if isSplitViewCapable, let onDismiss = onDismissRequested {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            print("📱 [IPAD_TOGGLE] Return to list from no data screen")
                            onDismiss()
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Schedule Grid View
    
    private func scheduleGridView(dayData: DayScheduleData) -> some View {
        VStack(spacing: 0) {
            // Header with day navigation - stays fixed
            headerView(dayData: dayData)
            
            // Sticky headers and scrollable content
            GeometryReader { geometry in
                StickyHeaderScrollView(
                    dayData: dayData,
                    onBandTapped: onBandTapped,
                    priorityManager: priorityManager,
                    onAttendanceUpdate: { bandName, location, startTime, eventType, status in
                        // Normalize event type for database operations
                        // Event data contains "Unofficial Event" but database keys use "Cruiser Organized"
                        let normalizedEventType = (eventType == "Unofficial Event") ? "Cruiser Organized" : eventType
                        
                        print("🔍 [LANDSCAPE_SCHEDULE] Event type for attendance: \(eventType) -> \(normalizedEventType)")
                        
                        // Update attendance in database
                        attendedHandle.addShowsAttendedWithStatus(
                            band: bandName,
                            location: location,
                            startTime: startTime,
                            eventType: normalizedEventType,
                            eventYearString: String(eventYear),
                            status: status
                        )
                        
                        // Update the view model's data in place (use original eventType for matching)
                        viewModel.updateAttendanceForEvent(bandName: bandName, location: location, startTime: startTime, eventType: eventType)
                        
                        print("✅ [LANDSCAPE_SCHEDULE] Attendance updated for \(bandName) (\(eventType))")
                    },
                    attendedHandle: attendedHandle
                )
            }
        }
    }
    
    // MARK: - Sticky Header Scroll View
    
    private struct StickyHeaderScrollView: View {
        let dayData: DayScheduleData
        let onBandTapped: (String, String?) -> Void
        let priorityManager: SQLitePriorityManager
        let onAttendanceUpdate: (String, String, String, String, String) -> Void
        let attendedHandle: ShowsAttended
        @State private var scrollOffset: CGPoint = .zero
        
        var body: some View {
            GeometryReader { geometry in
                let availableWidth = geometry.size.width - 60 // Subtract time column width
                let columnWidth = availableWidth / CGFloat(dayData.venues.count)
                
                ZStack(alignment: .topLeading) {
                    // Main scrollable content (vertical only)
                    TrackableScrollView(axes: .vertical, showsIndicators: true, contentOffset: $scrollOffset) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Spacer for headers
                            Color.clear.frame(height: 44)
                            
                            // Content
                            HStack(alignment: .top, spacing: 0) {
                                // Time column content
                                timeColumnContentView(dayData: dayData)
                                
                                // Venue columns
                                ForEach(dayData.venues) { venue in
                                    venueColumnContentView(venue: venue, dayData: dayData, columnWidth: columnWidth)
                                }
                            }
                        }
                    }
                    
                    // Fixed headers overlay
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // Time header
                            Text("Time")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 44)
                                .background(Color.gray.opacity(0.3))
                            
                            // Venue headers (no horizontal scrolling needed)
                            ForEach(dayData.venues) { venue in
                                venueHeaderViewSticky(venue: venue, columnWidth: columnWidth)
                            }
                        }
                        .background(Color.black)
                        
                        Spacer()
                    }
                    .allowsHitTesting(false) // Let touches pass through to scroll view
                }
            }
        }
        
        private func timeColumnContentView(dayData: DayScheduleData) -> some View {
            VStack(spacing: 0) {
                ForEach(dayData.timeSlots) { slot in
                    let isHourMark = slot.label.contains("m") // Full time like "6:00pm"
                    Text(slot.label)
                        .font(.system(size: 12))
                        .foregroundColor(isHourMark ? .white : .gray)
                        .frame(width: 60, height: 30, alignment: .leading)
                        .padding(.leading, 4)
                        .background(Color.black.opacity(0.95))
                        .overlay(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
            .frame(width: 60)
        }
        
        private func venueHeaderViewSticky(venue: VenueColumn, columnWidth: CGFloat) -> some View {
            VStack(spacing: 2) {
                Text(venue.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: columnWidth, height: 44)
            .background(venue.color)
        }
        
        private func venueColumnContentView(venue: VenueColumn, dayData: DayScheduleData, columnWidth: CGFloat) -> some View {
            ZStack(alignment: .topLeading) {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(dayData.timeSlots) { slot in
                        Rectangle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            .frame(width: columnWidth, height: 30)
                    }
                }
                
                // Event blocks
                ForEach(venue.events) { event in
                    eventBlockView(event: event, dayData: dayData, columnWidth: columnWidth, priorityManager: priorityManager, onAttendanceUpdate: onAttendanceUpdate, attendedHandle: attendedHandle)
                }
            }
            .frame(width: columnWidth)
        }
        
        private func eventBlockView(event: ScheduleBlock, dayData: DayScheduleData, columnWidth: CGFloat, priorityManager: SQLitePriorityManager, onAttendanceUpdate: @escaping (String, String, String, String, String) -> Void, attendedHandle: ShowsAttended) -> some View {
            let yOffset = calculateYOffset(for: event, in: dayData)
            let blockHeight = calculateBlockHeight(for: event)
            let onBandTapped = self.onBandTapped
            let currentDay = dayData.dayLabel
            
            // Check if this is a combined event and get individual bands
            let isCombinedEvent = event.bandName.contains("/")
            let individualBands: [String] = {
                if isCombinedEvent {
                    // Use combinedEventsMap if available, otherwise split the band name
                    if let mappedBands = combinedEventsMap[event.bandName] {
                        return mappedBands
                    } else {
                        return event.bandName.components(separatedBy: "/")
                    }
                } else {
                    return []
                }
            }()
            
            return Button(action: {
                print("Tapped on \(event.bandName) on \(currentDay)")
                onBandTapped(event.bandName, currentDay)
            }) {
                VStack(alignment: .leading, spacing: 1) {
                    // Check if this is a combined event (format: "band1/band2")
                    if event.bandName.contains("/") {
                        let bandComponents = event.bandName.components(separatedBy: "/")
                        if bandComponents.count == 2 {
                            // Line 1: First band name with "/"
                            Text("\(bandComponents[0])/")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            // Line 2: Second band name
                            Text(bandComponents[1])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            // Fallback: show combined name as-is if format is unexpected
                            Text(event.bandName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                    } else {
                        // Line 1: Single band name
                        Text(event.bandName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    // Line 2 (or 3 for combined): Start time with label
                    Text("Start: \(formatTime(event.startTime))")
                        .font(.system(size: 9))
                        .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                    
                    // Line 3 (or 4 for combined): End time with label
                    Text("End: \(formatTime(event.endTime))")
                        .font(.system(size: 9))
                        .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                    
                    if isCombinedEvent && individualBands.count == 2 {
                        // Combined event layout
                        let band1 = individualBands[0]
                        let band2 = individualBands[1]
                        
                        // Get priorities for each band
                        let priority1 = priorityManager.getPriority(for: band1, eventYear: eventYear)
                        let priority2 = priorityManager.getPriority(for: band2, eventYear: eventYear)
                        
                        // Get attended status for each band
                        let attended1 = attendedHandle.getShowAttendedStatus(
                            band: band1,
                            location: event.location,
                            startTime: event.startTimeString,
                            eventType: event.eventType,
                            eventYearString: String(eventYear)
                        )
                        let attended2 = attendedHandle.getShowAttendedStatus(
                            band: band2,
                            location: event.location,
                            startTime: event.startTimeString,
                            eventType: event.eventType,
                            eventYearString: String(eventYear)
                        )
                        
                        // Check if values are populated
                        let hasPriority1 = priority1 == 1 || priority1 == 2 || priority1 == 3
                        let hasPriority2 = priority2 == 1 || priority2 == 2 || priority2 == 3
                        let hasAttended1 = !attended1.isEmpty && attended1 != "sawNone"
                        let hasAttended2 = !attended2.isEmpty && attended2 != "sawNone"
                        
                        // Line 4: Priority icons only
                        // Only show if at least one has a priority
                        if hasPriority1 || hasPriority2 {
                            HStack(spacing: 2) {
                                // First band priority
                                if hasPriority1 {
                                    ZStack {
                                        Circle()
                                            .fill(priority1 == 3 ? Color(white: 0.75) : Color(white: 0.2))
                                            .frame(width: 18, height: 18)
                                            .shadow(color: Color.black.opacity(0.2), radius: 1.5, x: 0, y: 0.5)
                                        
                                        Image(getPriorityIconName(priority1))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 14, height: 14)
                                            .opacity(event.isExpired ? 0.4 : 1.0)
                                    }
                                }
                                
                                // Slash separator (only show if exactly one is populated)
                                if (hasPriority1 && !hasPriority2) || (!hasPriority1 && hasPriority2) {
                                    Text("/")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white.opacity(0.7))
                                        .frame(width: 8)
                                }
                                
                                // Second band priority
                                if hasPriority2 {
                                    ZStack {
                                        Circle()
                                            .fill(priority2 == 3 ? Color(white: 0.75) : Color(white: 0.2))
                                            .frame(width: 18, height: 18)
                                            .shadow(color: Color.black.opacity(0.2), radius: 1.5, x: 0, y: 0.5)
                                        
                                        Image(getPriorityIconName(priority2))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 14, height: 14)
                                            .opacity(event.isExpired ? 0.4 : 1.0)
                                    }
                                }
                            }
                        }
                        
                        // Line 5: Attended icons on their own line
                        // Only show if at least one has an attended status
                        if hasAttended1 || hasAttended2 {
                            HStack(spacing: 2) {
                                // First band attended
                                if hasAttended1 {
                                    Image(getAttendedIconName(attended1))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 14, height: 14)
                                        .opacity(event.isExpired ? 0.4 : 1.0)
                                }
                                
                                // Slash separator (only show if exactly one is populated)
                                if (hasAttended1 && !hasAttended2) || (!hasAttended1 && hasAttended2) {
                                    Text("/")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white.opacity(0.7))
                                        .frame(width: 8)
                                }
                                
                                // Second band attended
                                if hasAttended2 {
                                    Image(getAttendedIconName(attended2))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 14, height: 14)
                                        .opacity(event.isExpired ? 0.4 : 1.0)
                                }
                            }
                        }
                        
                        // Line 6: Event type (moved down one line for combined events)
                        if !event.eventType.isEmpty {
                            HStack(spacing: 3) {
                                Text(localizeEventType(event.eventType))
                                    .font(.system(size: 8))
                                    .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                                    .lineLimit(1)
                                
                                Image(uiImage: getEventTypeIcon(eventType: event.eventType, eventName: event.bandName))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                    .opacity(event.isExpired ? 0.4 : 1.0)
                            }
                        }
                    } else {
                        // Single event: Show normal priority and attended icons on same line
                        // Line 4: Priority and Attended icons
                        HStack(spacing: 3) {
                            // Priority icon - apply circle background to all priority levels (1=must, 2=might, 3=wont)
                            if event.priority == 1 || event.priority == 2 || event.priority == 3 {
                                // Use different circle background colors: very dark grey for must/might, lighter grey for wont
                                ZStack {
                                    // Circle background extending 2px beyond icon
                                    // Use light grey for "won't" (priority 3) to better contrast with red "no" symbol
                                    Circle()
                                        .fill(event.priority == 3 ? Color(white: 0.75) : Color(white: 0.2))
                                        .frame(width: 18, height: 18)
                                        .shadow(color: Color.black.opacity(0.2), radius: 1.5, x: 0, y: 0.5)
                                    
                                    // Icon on top
                                    Image(getPriorityIconName(event.priority))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 14, height: 14)
                                        .opacity(event.isExpired ? 0.4 : 1.0)
                                }
                            }
                            
                            // Attended icon
                            if !event.attendedStatus.isEmpty && event.attendedStatus != "sawNone" {
                                Image(getAttendedIconName(event.attendedStatus))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                    .opacity(event.isExpired ? 0.4 : 1.0)
                            }
                        }
                        
                        // Line 5: Event type
                        // For single events, only show if not "Show"
                        if !event.eventType.isEmpty && event.eventType != "Show" {
                            HStack(spacing: 3) {
                                Text(localizeEventType(event.eventType))
                                    .font(.system(size: 8))
                                    .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                                    .lineLimit(1)
                                
                                Image(uiImage: getEventTypeIcon(eventType: event.eventType, eventName: event.bandName))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                    .opacity(event.isExpired ? 0.4 : 1.0)
                            }
                        }
                    }
                }
                .frame(width: columnWidth - 6, height: max(blockHeight - 6, 50), alignment: .topLeading)
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FestivalConfig.current.getVenueSwiftUIColor(for: event.location).opacity(event.isExpired ? 0.3 : 0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(event.isExpired ? 0.15 : 0.3), lineWidth: 1)
                )
            }
            .contextMenu {
                // Check if this is a combined event
                if isCombinedEvent && individualBands.count == 2 {
                    // Combined event: Show band selection menu items
                    ForEach(individualBands, id: \.self) { bandName in
                        Menu(bandName) {
                            // Get current status for this specific band
                            let currentStatus = attendedHandle.getShowAttendedStatus(
                                band: bandName,
                                location: event.location,
                                startTime: event.startTimeString,
                                eventType: event.eventType,
                                eventYearString: String(eventYear)
                            )
                            
                            // Show "All Of Event" if not already selected
                            if currentStatus != "sawAll" {
                                Button(action: {
                                    onAttendanceUpdate(bandName, event.location, event.startTimeString, event.eventType, sawAllStatus)
                                }) {
                                    Text(NSLocalizedString("All Of Event", comment: ""))
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            
                            // Show "Part Of Event" if not already selected AND event type is "Show"
                            if currentStatus != "sawSome" && event.eventType == "Show" {
                                Button(action: {
                                    onAttendanceUpdate(bandName, event.location, event.startTimeString, event.eventType, sawSomeStatus)
                                }) {
                                    Text(NSLocalizedString("Part Of Event", comment: ""))
                                    Image(systemName: "checkmark.circle")
                                }
                            }
                            
                            // Show "None Of Event" if not already selected
                            if currentStatus != "sawNone" && currentStatus != "" {
                                Button(action: {
                                    onAttendanceUpdate(bandName, event.location, event.startTimeString, event.eventType, sawNoneStatus)
                                }) {
                                    Text(NSLocalizedString("None Of Event", comment: ""))
                                    Image(systemName: "xmark.circle")
                                }
                            }
                        }
                    }
                } else {
                    // Single event: Show normal attendance options
                    let currentStatus = event.attendedStatus
                    
                    // Show "All Of Event" if not already selected
                    if currentStatus != "sawAll" {
                        Button(action: {
                            onAttendanceUpdate(event.bandName, event.location, event.startTimeString, event.eventType, sawAllStatus)
                        }) {
                            Text(NSLocalizedString("All Of Event", comment: ""))
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    
                    // Show "Part Of Event" if not already selected AND event type is "Show"
                    if currentStatus != "sawSome" && event.eventType == "Show" {
                        Button(action: {
                            onAttendanceUpdate(event.bandName, event.location, event.startTimeString, event.eventType, sawSomeStatus)
                        }) {
                            Text(NSLocalizedString("Part Of Event", comment: ""))
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    
                    // Show "None Of Event" if not already selected
                    if currentStatus != "sawNone" && currentStatus != "" {
                        Button(action: {
                            onAttendanceUpdate(event.bandName, event.location, event.startTimeString, event.eventType, sawNoneStatus)
                        }) {
                            Text(NSLocalizedString("None Of Event", comment: ""))
                            Image(systemName: "xmark.circle")
                        }
                    }
                }
            }
            .offset(x: 2, y: yOffset)
        }
        
        private func calculateYOffset(for event: ScheduleBlock, in dayData: DayScheduleData) -> CGFloat {
            // Calculate offset using actual timeIndex (preserves chronological order across days)
            // The timeline grid starts at the first event's timeIndex
            guard let firstTimeSlot = dayData.timeSlots.first else { return 0 }
            
            // Calculate seconds from the grid start using timeIndex
            let gridStartSeconds = dayData.startTime.timeIntervalSince(firstTimeSlot.time)
            let eventStartOffsetFromBase = event.timeIndex - dayData.baseTimeIndex
            let totalOffsetSeconds = eventStartOffsetFromBase + gridStartSeconds
            
            // Each 15-minute slot is 30px tall, so 1 hour (4 slots) = 120px
            let pixelsPerSecond: CGFloat = 120.0 / 3600.0 // 120 pixels per hour (4 slots)
            let baseOffset = CGFloat(totalOffsetSeconds) * pixelsPerSecond
            
            // Move down by 1/2 slot (7.5 minutes = 15 pixels)
            return baseOffset + 15.0
        }
        
        private func calculateBlockHeight(for event: ScheduleBlock) -> CGFloat {
            let durationSeconds = event.endTime.timeIntervalSince(event.startTime)
            // Each 15-minute slot is 30px tall, so 1 hour (4 slots) = 120px
            let pixelsPerSecond: CGFloat = 120.0 / 3600.0 // 120 pixels per hour
            return max(CGFloat(durationSeconds) * pixelsPerSecond, 30)
        }
        
        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mma"
            return formatter.string(from: date).lowercased()
        }
        
        private func formatTimeRange(start: Date, end: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mma"
            let startStr = formatter.string(from: start).lowercased()
            let endStr = formatter.string(from: end).lowercased()
            return "\(startStr)-\(endStr)"
        }
        
        private func getPriorityIconName(_ priority: Int) -> String {
            switch priority {
            case 1: return "icon-going-yes"     // Must see
            case 2: return "icon-going-maybe"   // Might see
            case 3: return "icon-going-no"      // Won't see
            default: return ""
            }
        }
        
        private func getAttendedIconName(_ status: String) -> String {
            switch status {
            case "sawAll": return "icon-seen"
            case "sawSome": return "icon-seen-partial"
            default: return ""
            }
        }
        
        private func localizeEventType(_ eventType: String) -> String {
            // Map database event type to display name via localization
            if eventType == "Unofficial Event" {
                return NSLocalizedString("Unofficial Events", comment: "")
            }
            return eventType
        }
    }
    
    // MARK: - Header View
    
    private func headerView(dayData: DayScheduleData) -> some View {
        HStack {
            Spacer()
            
            // Previous day button - only show if functional
            if viewModel.canNavigateToPreviousDay {
                Button(action: {
                    viewModel.navigateToPreviousDay()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                .padding(.trailing, 8)
            }
            
            // Day label and event count
            VStack(spacing: 2) {
                Text("\(dayData.dayLabel) - \(viewModel.currentDayEventCount) Events")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(minWidth: 200)
            
            // Next day button - only show if functional
            if viewModel.canNavigateToNextDay {
                Button(action: {
                    viewModel.navigateToNextDay()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(6)
                }
                .padding(.leading, 8)
            }
            
            Spacer()
            
            // iPad: List view toggle button (return to list view)
            if isSplitViewCapable, let onDismiss = onDismissRequested {
                Button(action: {
                    print("📱 [IPAD_TOGGLE] List button tapped in calendar view")
                    onDismiss()
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.trailing, 16)
            }
        }
        .frame(height: 60)
        .background(Color.black)
    }
    
}

// MARK: - Preview

#Preview {
    LandscapeScheduleView(
        priorityManager: SQLitePriorityManager.shared,
        attendedHandle: ShowsAttended(),
        isSplitViewCapable: true,
        onDismissRequested: {
            print("Preview: Dismiss requested")
        },
        onBandTapped: { bandName, currentDay in
            print("Preview: Tapped \(bandName) on \(currentDay ?? "unknown")")
        }
    )
    .previewInterfaceOrientation(.landscapeLeft)
}
