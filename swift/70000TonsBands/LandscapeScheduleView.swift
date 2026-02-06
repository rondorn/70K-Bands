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
    
    let onBandTapped: (String, String?) -> Void  // (bandName, currentDay)
    
    init(priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended, initialDay: String? = nil, hideExpiredEvents: Bool = false, onBandTapped: @escaping (String, String?) -> Void) {
        self._viewModel = StateObject(wrappedValue: LandscapeScheduleViewModel(
            priorityManager: priorityManager,
            attendedHandle: attendedHandle,
            initialDay: initialDay,
            hideExpiredEvents: hideExpiredEvents
        ))
        self.onBandTapped = onBandTapped
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
    }
    
    // MARK: - Schedule Grid View
    
    private func scheduleGridView(dayData: DayScheduleData) -> some View {
        VStack(spacing: 0) {
            // Header with day navigation - stays fixed
            headerView(dayData: dayData)
            
            // Sticky headers and scrollable content
            GeometryReader { geometry in
                StickyHeaderScrollView(dayData: dayData, onBandTapped: onBandTapped)
            }
        }
    }
    
    // MARK: - Sticky Header Scroll View
    
    private struct StickyHeaderScrollView: View {
        let dayData: DayScheduleData
        let onBandTapped: (String, String?) -> Void
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
                        .frame(width: 60, height: 30, alignment: .top)
                        .background(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
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
                    eventBlockView(event: event, dayData: dayData, columnWidth: columnWidth)
                }
            }
            .frame(width: columnWidth)
        }
        
        private func eventBlockView(event: ScheduleBlock, dayData: DayScheduleData, columnWidth: CGFloat) -> some View {
            let yOffset = calculateYOffset(for: event, in: dayData)
            let blockHeight = calculateBlockHeight(for: event)
            let onBandTapped = self.onBandTapped
            let currentDay = dayData.dayLabel
            
            return Button(action: {
                print("Tapped on \(event.bandName) on \(currentDay)")
                onBandTapped(event.bandName, currentDay)
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    // Band name
                    Text(event.bandName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(event.isExpired ? .white.opacity(0.4) : .white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    // Time range
                    Text(formatTimeRange(start: event.startTime, end: event.endTime))
                        .font(.system(size: 9))
                        .foregroundColor(event.isExpired ? .white.opacity(0.3) : .white.opacity(0.8))
                    
                    // Priority and Attended icons
                    HStack(spacing: 3) {
                        // Priority icon
                        if event.priority > 0 {
                            Image(getPriorityIconName(event.priority))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .opacity(event.isExpired ? 0.4 : 1.0)
                        }
                        
                        // Attended icon
                        if !event.attendedStatus.isEmpty && event.attendedStatus != "sawNone" {
                            Image(getAttendedIconName(event.attendedStatus))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .opacity(event.isExpired ? 0.4 : 1.0)
                        }
                    }
                }
                .frame(width: columnWidth - 6, height: max(blockHeight - 6, 35), alignment: .topLeading)
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
            return CGFloat(totalOffsetSeconds) * pixelsPerSecond
        }
        
        private func calculateBlockHeight(for event: ScheduleBlock) -> CGFloat {
            let durationSeconds = event.endTime.timeIntervalSince(event.startTime)
            // Each 15-minute slot is 30px tall, so 1 hour (4 slots) = 120px
            let pixelsPerSecond: CGFloat = 120.0 / 3600.0 // 120 pixels per hour
            return max(CGFloat(durationSeconds) * pixelsPerSecond, 30)
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
                Text("\(viewModel.currentDayEventCount) Events - \(dayData.dayLabel)")
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
        onBandTapped: { bandName, currentDay in
            print("Preview: Tapped \(bandName) on \(currentDay ?? "unknown")")
        }
    )
    .previewInterfaceOrientation(.landscapeLeft)
}
