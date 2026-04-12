//
//  CommonFilterSheetView.swift
//  70K Bands
//
//  Shared filter menu sheet component for both portrait and calendar views
//

import SwiftUI


enum FilterMenuOrder {
    case portrait   // List view: all sections
    case calendar   // Landscape: same order, omits portrait-only (Hide Expired, Sort By Name)
}

struct CommonFilterSheetView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @State private var showFlaggedOnly: Bool = getShowOnlyWillAttened()
    @State private var sortRefreshTrigger: Int = 0  // Force view refresh when sort changes
    @State private var filterChangeTrigger: Int = 0  // Force List refresh when section structure changes (e.g. Hide Expired)
    @State private var clearButtonActive: Bool = false  // Clear button enabled state; updated by toggles without rebuilding List (preserves scroll)
    @State private var scrollPosition: CGFloat? = nil  // Track scroll position to preserve it
    @State private var savedScrollPosition: CGFloat? = nil  // Saved position before refresh
    
    // Capture scroll position synchronously and return it
    @discardableResult
    private func captureScrollPositionSync() -> CGFloat {
        // Request immediate capture from ScrollPositionMonitor
        NotificationCenter.default.post(name: Notification.Name("CaptureScrollPosition"), object: nil)
        
        // Use current scrollPosition from monitor (updated continuously)
        let currentOffset = scrollPosition ?? 0.0
        
        // Also try to find UITableView directly as backup
        var foundOffset: CGFloat? = nil
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                if let tableView = findTableView(in: window) {
                    foundOffset = tableView.contentOffset.y
                    print("📍 [SCROLL] Found UITableView directly, offset: \(foundOffset!)")
                    break
                }
            }
        }
        
        // Use found offset if available, otherwise use current from monitor
        let finalOffset = foundOffset ?? currentOffset
        
        // Save to both scrollPosition and savedScrollPosition
        scrollPosition = finalOffset
        savedScrollPosition = finalOffset
        
        print("📍 [SCROLL] Captured scroll position: \(finalOffset) (from monitor: \(currentOffset), from direct search: \(foundOffset ?? -1))")
        return finalOffset
    }
    
    // Helper to restore scroll position by finding UITableView in view hierarchy
    private func restoreScrollPosition(offset: CGFloat) {
        print("📍 [SCROLL] Attempting to restore scroll position to: \(offset)")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("📍 [SCROLL] Failed to restore - no window scene")
            return
        }
        
        // Try all windows to find the UITableView
        var restored = false
        for window in windowScene.windows {
            if let tableView = findTableView(in: window) {
                print("📍 [SCROLL] Found UITableView, restoring offset: \(offset)")
                tableView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                restored = true
                
                // Verify it was set with multiple checks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let actualOffset = tableView.contentOffset.y
                    print("📍 [SCROLL] Verification 1 - Actual scroll position: \(actualOffset)")
                    if abs(actualOffset - offset) > 1 {
                        // Try again if it didn't work
                        tableView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let actualOffset = tableView.contentOffset.y
                    print("📍 [SCROLL] Verification 2 - Actual scroll position: \(actualOffset)")
                }
                break
            }
        }
        
        if !restored {
            print("📍 [SCROLL] Failed to restore - UITableView not found in any window")
        }
    }
    
    // Helper to find UITableView in view hierarchy (recursive search)
    // Specifically looks for UITableViews that are backing SwiftUI Lists
    private func findTableView(in view: UIView) -> UITableView? {
        // Check if this is a UITableView
        if let tableView = view as? UITableView {
            // Additional check: SwiftUI Lists typically have specific characteristics
            // Check if it's visible and has content
            if !tableView.isHidden && tableView.alpha > 0.01 && tableView.superview != nil {
                return tableView
            }
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            // Skip hidden views and views with zero alpha (they're likely not the active List)
            if subview.isHidden || subview.alpha < 0.01 {
                continue
            }
            
            if let tableView = findTableView(in: subview) {
                return tableView
            }
        }
        
        return nil
    }
    
    let menuOrder: FilterMenuOrder
    let dayData: DayScheduleData?  // nil for portrait, set for calendar
    let viewModel: LandscapeScheduleViewModel?  // nil for portrait, set for calendar
    @Binding var dayBeforeFilterChange: String?  // nil for portrait, set for calendar
    var onDismiss: (() -> Void)? = nil  // Optional dismiss closure for portrait view
    private var dismiss: () -> Void {
        if let onDismiss = onDismiss {
            return onDismiss
        } else {
            return { environmentDismiss() }
        }
    }
    
    // Determine if we should show schedule-related filters
    private var hasScheduledEvents: Bool {
        eventCount > 0 && eventCounterUnoffical != eventCount
    }
    
    private var showScheduleView: Bool {
        getShowScheduleView()
    }
    
    /// True when the year's schedule is **bands + unofficial-only** (no official cruise events yet).
    /// In this mode the filter sheet must stay narrow (rankings + unofficial toggle only), even when
    /// "Show Unofficial" is on — otherwise `hasScheduledEvents` flips and exposes sort / M&G / venues.
    private var scheduleIsUnofficialOnlyComposition: Bool {
        showScheduleView && scheduleCompositionIsUnofficialOnly(forYear: eventYear)
    }
    
    /// Full schedule filter UI (sort, flagged, meet & greet, special, locations). Not used for unofficial-only composition.
    private var showRichScheduleFilterSections: Bool {
        hasScheduledEvents && showScheduleView && !scheduleIsUnofficialOnlyComposition
    }
    
    private var isFlaggedFilterEnabled: Bool {
        // Only disable other filters when "Show Flagged Events Only" is enabled AND there are events to filter
        // If "Hide Expired Events" is on and there are no non-expired events, don't disable filters
        guard showFlaggedOnly else { return false }
        
        // If Hide Expired Events is enabled, check for non-expired events
        if getHideExpireScheduleData() {
            return hasNonExpiredEvents()
        }
        
        // Otherwise, check if there are any events at all
        return hasAnyEvents()
    }
    
    // Get venues - from dayData for calendar, from global list for portrait
    private var venues: [String] {
        if let dayData = dayData {
            return getUnfilteredVenuesForDay(dayData.dayLabel).map { $0.name }
        } else {
            return getVenueNamesInUseForList()
        }
    }
    
    // KISS: Consistent darker grey color for entire menu
    private let menuBackgroundColor = Color(uiColor: UIColor(white: 0.2, alpha: 1.0))
    
    var body: some View {
        ZStack {
            // Darker grey background - same color throughout
            menuBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header bar (replaces NavigationView to avoid opaque background)
                HStack {
                    Button(NSLocalizedString("Clear All Filters", comment: "")) {
                        clearAllFilters()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .disabled(!clearButtonActive)
                    .opacity(clearButtonActive ? 1.0 : 0.5)
                    
                    Spacer()
                    
                    Button(NSLocalizedString("Done", comment: "")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("qaFilterSheetDone")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(menuBackgroundColor)
                
                // List content with scroll position preservation
                // Use ScrollViewReader to preserve scroll position
                ScrollViewReader { proxy in
                    List {
                        unifiedFilterSections
                    }
                    .accessibilityIdentifier("qaFilterSheetList")
                    .id(filterChangeTrigger)  // Force refresh when filters change (e.g., Hide Expired Events)
                    .listStyle(.plain)
                    .modifier(DarkListBackgroundModifier())
                    .environment(\.defaultMinListRowHeight, menuOrder == .portrait ? 36 : 44)
                    .background(menuBackgroundColor)
                    .background(
                        // Monitor scroll position continuously
                        ScrollPositionMonitor(scrollPosition: $scrollPosition)
                    )
                    .onAppear {
                        if menuOrder == .portrait {
                            // Reduce spacing between sections for portrait view
                            UITableView.appearance().sectionHeaderHeight = 0
                            UITableView.appearance().estimatedSectionHeaderHeight = 0
                        }
                        clearButtonActive = hasAnyFiltersSet()
                    }
                .onChange(of: filterChangeTrigger) { newValue in
                    // Restore scroll position after List rebuilds
                    // Use savedScrollPosition if available (captured before change), otherwise use current scrollPosition
                    let offsetToRestore = savedScrollPosition ?? scrollPosition
                    if let savedOffset = offsetToRestore, savedOffset > 0 {
                        print("📍 [SCROLL] filterChangeTrigger changed to \(newValue), restoring offset: \(savedOffset) (savedScrollPosition: \(savedScrollPosition ?? -1), scrollPosition: \(scrollPosition ?? -1))")
                        // Use multiple attempts with increasing delays
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            restoreScrollPosition(offset: savedOffset)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            restoreScrollPosition(offset: savedOffset)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            restoreScrollPosition(offset: savedOffset)
                        }
                        // Clear saved position after restore attempts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            savedScrollPosition = nil
                        }
                    } else {
                        print("📍 [SCROLL] filterChangeTrigger changed but no valid scroll position to restore (savedScrollPosition: \(savedScrollPosition ?? -1), scrollPosition: \(scrollPosition ?? -1))")
                    }
                }
                }
            }
            .background(menuBackgroundColor)
            .overlay(
                Group {
                    if menuOrder == .portrait {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    }
                }
            )
            .preferredColorScheme(.dark)
        }
        // XCTest reads the SwiftUI accessibility tree, not UIKit identifiers on UIHostingController.view.
        // This root id lets UI tests find the sheet while children (.contain) still expose Done / toggles.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("qaCommonFilterSheetRoot")
    }
    
    // MARK: - Unified Filter Sections (exact same order for portrait and landscape)
    
    /// Single canonical order for both portrait and landscape.
    /// Portrait shows all applicable sections; landscape omits Hide Expired and Sort By Name.
    /// Order: AI Schedule (when enabled) -> Hide Expired -> Sort By Name -> Show Flagged -> Band Rankings -> Event Type -> Locations
    @ViewBuilder
    private var unifiedFilterSections: some View {
        let dayLabel = dayData?.dayLabel ?? ""
        
        // 0. Hide Expired Events (portrait/list only)
        if menuOrder == .portrait, hasAnyEvents() && hasExpiredEvents() {
            expiredEventsSection
        }
        
        // 2. Sort By Name (portrait/list only)
        if menuOrder == .portrait, showRichScheduleFilterSections {
            sortBySection
        }
        
        // 3. Show Flagged Events Only
        if menuOrder == .portrait ? (showRichScheduleFilterSections && attendingCount > 0) : hasFlaggedEvents(forDay: dayLabel) {
            flaggedEventsSection
        }
        
        // 4. Band Ranking Filters (mandatory in list view only; calendar only when ranked bands exist to avoid empty menu)
        if menuOrder == .portrait || hasRankedBands(forDay: dayLabel) {
            bandRankingSection
        }
        
        // 5. Event Type Filters
        if menuOrder == .portrait || hasFilterableEventTypes(forDay: dayLabel) {
            eventTypeSection
        }
        
        // 6. Location Filters
        if !scheduleIsUnofficialOnlyComposition,
           (menuOrder == .portrait && showRichScheduleFilterSections && !venues.isEmpty) || (menuOrder == .calendar && !venues.isEmpty) {
            locationSection
        }
    }
    
    // MARK: - Section Components
    
    @ViewBuilder
    private var expiredEventsSection: some View {
        Section(header: sectionHeader(NSLocalizedString("Expired Events", comment: ""))) {
            HStack(spacing: 12) {
                Image(uiImage: UIImage(named: scheduleIconSort) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Toggle(NSLocalizedString("Hide Expired Events", comment: ""), isOn: Binding(
                    get: { getHideExpireScheduleData() },
                    set: { newValue in
                        setHideExpireScheduleData(newValue)
                        writeFiltersFile()
                        filterChangeTrigger += 1
                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                        // Refresh menu after data redraw completes (delay to allow data refresh to finish)
                        // This ensures menu elements are added/removed after the underlying data has been refreshed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            filterChangeTrigger += 1
                        }
                    }
                ))
            }
            .listRowBackground(menuBackgroundColor)
            .foregroundColor(.white)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .foregroundColor(Color.gray)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if menuOrder == .portrait {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.top, 2)
            }
        }
        .padding(.top, menuOrder == .portrait ? 0 : 8)
        .padding(.bottom, menuOrder == .portrait ? 0 : 4)
    }
    
    @ViewBuilder
    private var flaggedEventsSection: some View {
        Section(header: sectionHeader(NSLocalizedString("Show Flagged Events Only", comment: ""))) {
            HStack(spacing: 12) {
                Image(uiImage: UIImage(named: showFlaggedOnly ? attendedShowIcon : attendedShowIconAlt) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Toggle(NSLocalizedString("Show Flagged Events Only", comment: ""), isOn: Binding(
                    get: { showFlaggedOnly },
                    set: { newValue in
                        showFlaggedOnly = newValue
                        setShowOnlyWillAttened(newValue)
                        writeFiltersFile()
                        clearButtonActive = hasAnyFiltersSet()
                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                    }
                ))
                .disabled(shouldDisableFlaggedFilter)
                .id("\(filterChangeTrigger)-\(getHideExpireScheduleData())")  // Force refresh when Hide Expired Events changes
            }
            .listRowBackground(menuBackgroundColor)
            .foregroundColor(.white)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: menuOrder == .portrait ? 0 : 2, trailing: 16))
        }
    }
    
    // Disable "Show Flagged Events Only" when "Hide Expired Events" is enabled AND there are no non-expired events to display
    private var shouldDisableFlaggedFilter: Bool {
        guard getHideExpireScheduleData() else { return false }
        // When Hide Expired Events is enabled, check if there are any non-expired events
        return !hasNonExpiredEvents()
    }
    
    // Check if there are any non-expired events (when Hide Expired Events filter is applied)
    private func hasNonExpiredEvents() -> Bool {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
        
        // Check if any event is NOT expired (endTimeIndex + 10 min buffer >= currentTime)
        return allEvents.contains { event in
            var endTimeIndex = event.endTimeIndex
            // Detect midnight crossing - add 24 hours if needed
            if event.timeIndex > endTimeIndex {
                endTimeIndex += 86400
            }
            // Add 10-minute buffer (600 seconds) before considering expired
            return endTimeIndex + 600 >= currentTime
        }
    }
    
    @ViewBuilder
    private var bandRankingSection: some View {
        Section(header: sectionHeader(NSLocalizedString("Band Ranking Filters", comment: ""))) {
            bandRankingRow(
                icon: getMustSeeOn() ? mustSeeIcon : mustSeeIconAlt,
                title: NSLocalizedString("Show Must See", comment: ""),
                toggleAccessibilityId: "qaFilterToggleMustSee",
                isOn: Binding(
                    get: { getMustSeeOn() },
                    set: { newValue in
                        setMustSeeOn(newValue)
                        writeFiltersFile()
                        clearButtonActive = hasAnyFiltersSet()
                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                    }
                )
            )
            bandRankingRow(
                icon: getMightSeeOn() ? mightSeeIcon : mightSeeIconAlt,
                title: NSLocalizedString("Show Might See", comment: ""),
                toggleAccessibilityId: "qaFilterToggleMightSee",
                isOn: Binding(
                    get: { getMightSeeOn() },
                    set: { newValue in
                        setMightSeeOn(newValue)
                        writeFiltersFile()
                        clearButtonActive = hasAnyFiltersSet()
                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                    }
                )
            )
            bandRankingRow(
                icon: getWontSeeOn() ? wontSeeIcon : wontSeeIconAlt,
                title: NSLocalizedString("Show Wont See", comment: ""),
                toggleAccessibilityId: "qaFilterToggleWontSee",
                isOn: Binding(
                    get: { getWontSeeOn() },
                    set: { newValue in
                        setWontSeeOn(newValue)
                        writeFiltersFile()
                        clearButtonActive = hasAnyFiltersSet()
                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                    }
                )
            )
            bandRankingRow(
                icon: getUnknownSeeOn() ? unknownIcon : unknownIconAlt,
                title: NSLocalizedString("Show Unknown", comment: ""),
                toggleAccessibilityId: "qaFilterToggleUnknownSee",
                isOn: Binding(
                    get: { getUnknownSeeOn() },
                    set: { newValue in
                        setUnknownSeeOn(newValue)
                        writeFiltersFile()
                        clearButtonActive = hasAnyFiltersSet()
                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                    }
                )
            )
        }
    }
    
    @ViewBuilder
    private func bandRankingRow(icon: String, title: String, toggleAccessibilityId: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: UIImage(named: icon) ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            Toggle(title, isOn: isOn)
                .accessibilityIdentifier(toggleAccessibilityId)
                .disabled(isFlaggedFilterEnabled)
                .id("\(filterChangeTrigger)-\(isFlaggedFilterEnabled)")  // Force refresh when disabled state changes
        }
        .listRowBackground(menuBackgroundColor)
        .foregroundColor(.white)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: menuOrder == .portrait ? 0 : 2, trailing: 16))
    }
    
    @ViewBuilder
    private var sortBySection: some View {
        Section(header: sectionHeader(NSLocalizedString("Sorting Options", comment: ""))) {
            HStack(spacing: 12) {
                let sortByTime = getSortedBy() == "time"
                Image(uiImage: UIImage(named: sortByTime ? scheduleIconSort : bandIconSort) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text(sortByTime ? NSLocalizedString("Sort By Name", comment: "") : NSLocalizedString("Sort By Time", comment: ""))
                    .foregroundColor(.white)
                Spacer()
            }
            .listRowBackground(menuBackgroundColor)
            .contentShape(Rectangle())
            .onTapGesture {
                let newSort = getSortedBy() == "name" ? "time" : "name"
                setSortedBy(newSort)
                writeFiltersFile()
                sortRefreshTrigger += 1  // Trigger view refresh
                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
            }
            .id(sortRefreshTrigger)  // Force refresh when trigger changes
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: menuOrder == .portrait ? 0 : 2, trailing: 16))
        }
    }
    
    @ViewBuilder
    private var eventTypeSection: some View {
        let showScheduledEventTypeFilters = showRichScheduleFilterSections && (getMeetAndGreetsEnabled() || getSpecialEventsEnabled())
        // Show Unofficial option only when schedule actually contains Unofficial or Cruiser Organized events
        let showUnofficalEventFilter = getUnofficalEventsEnabled() && showScheduleView && eventCounterUnoffical > 0
        
        if showScheduledEventTypeFilters || showUnofficalEventFilter {
            Section(header: sectionHeader(NSLocalizedString("Event Type Filters", comment: ""))) {
                if getMeetAndGreetsEnabled() && showRichScheduleFilterSections {
                    eventTypeRow(
                        icon: getShowMeetAndGreetEvents() ? meetAndGreetIcon : meetAndGreetIconAlt,
                        title: NSLocalizedString("Show Meet & Greet", comment: ""),
                        isOn: Binding(
                            get: { getShowMeetAndGreetEvents() },
                            set: { newValue in
                                setShowMeetAndGreetEvents(newValue)
                                writeFiltersFile()
                                clearButtonActive = hasAnyFiltersSet()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        )
                    )
                }
                if getSpecialEventsEnabled() && showRichScheduleFilterSections {
                    eventTypeRow(
                        icon: getShowSpecialEvents() ? specialEventTypeIcon : specialEventTypeIconAlt,
                        title: NSLocalizedString("Show Special/Other", comment: ""),
                        isOn: Binding(
                            get: { getShowSpecialEvents() },
                            set: { newValue in
                                setShowSpecialEvents(newValue)
                                writeFiltersFile()
                                clearButtonActive = hasAnyFiltersSet()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        )
                    )
                }
                if showUnofficalEventFilter {
                    eventTypeRow(
                        icon: getShowUnofficalEvents() ? unofficalEventTypeIcon : unofficalEventTypeIconAlt,
                        title: NSLocalizedString("Show Unofficial", comment: ""),
                        isOn: Binding(
                            get: { getShowUnofficalEvents() },
                            set: { newValue in
                                setShowUnofficalEvents(newValue)
                                writeFiltersFile()
                                clearButtonActive = hasAnyFiltersSet()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        )
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func eventTypeRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: UIImage(named: icon) ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            Toggle(title, isOn: isOn)
                .disabled(isFlaggedFilterEnabled)
                .id("\(filterChangeTrigger)-\(isFlaggedFilterEnabled)")  // Force refresh when disabled state changes
        }
        .listRowBackground(menuBackgroundColor)
        .foregroundColor(.white)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: menuOrder == .portrait ? 0 : 2, trailing: 16))
    }
    
    @ViewBuilder
    private var locationSection: some View {
        Section(header: sectionHeader(NSLocalizedString("Location Filters", comment: ""))) {
            ForEach(venues, id: \.self) { venueName in
                locationRow(venueName: venueName)
            }
        }
    }
    
    @ViewBuilder
    private func locationRow(venueName: String) -> some View {
        HStack(spacing: 12) {
            let venueConfig = FestivalConfig.current.getVenue(named: venueName)
            let hasEstablishedIcon = venueConfig.map { !$0.goingIcon.lowercased().contains("unknown") } ?? false
            let genericLocationIconShown = "Location-Generic-Going-wBox"
            let genericLocationIconHidden = "Location-Generic-NotGoing-wBox"
            let isVenueShown = getShowVenueEvents(venueName: venueName)
            let iconName = isVenueShown
                ? ((hasEstablishedIcon ? venueConfig?.goingIcon : nil) ?? genericLocationIconShown)
                : ((hasEstablishedIcon ? venueConfig?.notGoingIcon : nil) ?? genericLocationIconHidden)
            
            Image(uiImage: UIImage(named: iconName) ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            Toggle(venueDisplayName(for: venueName), isOn: Binding(
                get: { getShowVenueEvents(venueName: venueName) },
                set: { newValue in
                    setShowVenueEvents(venueName: venueName, show: newValue)
                    writeFiltersFile()
                    clearButtonActive = hasAnyFiltersSet()
                    NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                }
            ))
            .disabled(isFlaggedFilterEnabled)
            .id("\(filterChangeTrigger)-\(isFlaggedFilterEnabled)-\(venueName)")  // Force refresh when disabled state changes
        }
        .listRowBackground(menuBackgroundColor)
        .foregroundColor(.white)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: menuOrder == .portrait ? 0 : 2, trailing: 16))
    }
    
    // MARK: - Helper Methods
    
    private func clearAllFilters() {
        setVenueFilters(venueNames: getVenueNamesInUseForList(), show: true)
        setShowOnlyWillAttened(false)
        showFlaggedOnly = false
        setShowMeetAndGreetEvents(true)
        setShowSpecialEvents(true)
        setShowUnofficalEvents(true)
        setMustSeeOn(true)
        setMightSeeOn(true)
        setWontSeeOn(true)
        setUnknownSeeOn(true)
        // Note: Hide Expired Events is exempt from clearing - it's more of a preference than a filter
        // setHideExpireScheduleData(false) - intentionally not cleared
        writeFiltersFile()
        
        clearButtonActive = false
        // Trigger view refresh - force menu to redraw with updated filter states
        filterChangeTrigger += 1
        
        // Refresh calendar view if needed
        if let viewModel = viewModel {
            viewModel.refreshVenueVisibility()
            if let dayToRestore = dayBeforeFilterChange {
                viewModel.refreshData(restoreDay: dayToRestore)
            } else {
                viewModel.refreshData()
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
    }
    
    private func hasAnyFiltersSet() -> Bool {
        if getShowOnlyWillAttened() { return true }
        if !getMustSeeOn() || !getMightSeeOn() || !getWontSeeOn() || !getUnknownSeeOn() { return true }
        if !getShowMeetAndGreetEvents() || !getShowSpecialEvents() || !getShowUnofficalEvents() { return true }
        // Note: Hide Expired Events is exempt from filter clearing, so don't count it here
        // if getHideExpireScheduleData() { return true }
        if let viewModel = viewModel {
            if viewModel.hasHiddenVenues { return true }
        } else {
            for venueName in venues {
                if !getShowVenueEvents(venueName: venueName) {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Scroll Position Monitor

struct ScrollPositionMonitor: UIViewRepresentable {
    @Binding var scrollPosition: CGFloat?
    
    func makeUIView(context: Context) -> ScrollPositionMonitorView {
        let view = ScrollPositionMonitorView()
        view.onScrollPositionChanged = { offset in
            scrollPosition = offset
        }
        return view
    }
    
    func updateUIView(_ uiView: ScrollPositionMonitorView, context: Context) {
        // Update callback if binding changed
        uiView.onScrollPositionChanged = { offset in
            scrollPosition = offset
        }
    }
}

class ScrollPositionMonitorView: UIView {
    var onScrollPositionChanged: ((CGFloat) -> Void)?
    private var timer: Timer?
    private var lastKnownOffset: CGFloat = 0.0
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if superview != nil {
            // Start monitoring when added to view hierarchy
            startMonitoring()
            
            // Also listen for capture requests
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCaptureRequest),
                name: Notification.Name("CaptureScrollPosition"),
                object: nil
            )
        } else {
            // Stop monitoring when removed
            stopMonitoring()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    @objc private func handleCaptureRequest() {
        // When capture is requested, immediately read current position
        updateScrollPosition()
    }
    
    private func startMonitoring() {
        stopMonitoring() // Stop any existing timer
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateScrollPosition()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateScrollPosition() {
        // Find UITableView by traversing up the view hierarchy from this view
        var tableView: UITableView? = nil
        
        // Strategy 1: Search up the hierarchy from this view
        var currentView: UIView? = self.superview
        while let view = currentView {
            if let foundTableView = findTableView(in: view) {
                tableView = foundTableView
                break
            }
            currentView = view.superview
        }
        
        // Strategy 2: If not found, search down from superview (in case we're above the List)
        if tableView == nil, let superview = self.superview {
            tableView = findTableView(in: superview)
        }
        
        // Strategy 3: Search in all windows (fallback)
        if tableView == nil {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    if let foundTableView = findTableView(in: window) {
                        tableView = foundTableView
                        break
                    }
                }
            }
        }
        
        if let tableView = tableView {
            let offset = tableView.contentOffset.y
            lastKnownOffset = offset
            onScrollPositionChanged?(offset)
            // Debug logging (only occasionally to avoid spam)
            if Int.random(in: 0..<20) == 0 {  // Log ~5% of the time
                print("📍 [SCROLL_MONITOR] Updated scroll position: \(offset)")
            }
        } else {
            // If UITableView not found, use last known offset
            if lastKnownOffset > 0 {
                onScrollPositionChanged?(lastKnownOffset)
            } else if Int.random(in: 0..<100) == 0 {  // Log occasionally when not found
                print("📍 [SCROLL_MONITOR] UITableView not found, lastKnownOffset: \(lastKnownOffset)")
            }
        }
    }
    
    private func findTableView(in view: UIView) -> UITableView? {
        if let tableView = view as? UITableView {
            // Verify it's visible and likely the List's table view
            if !tableView.isHidden && tableView.alpha > 0.01 && tableView.superview != nil {
                return tableView
            }
        }
        for subview in view.subviews {
            if let tableView = findTableView(in: subview) {
                return tableView
            }
        }
        return nil
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Dark List Background Modifier

struct DarkListBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
        } else {
            content
                .onAppear {
                    // Set darker grey background for list (iOS 15 and earlier)
                    let darkerGrey = UIColor(white: 0.2, alpha: 1.0)
                    UITableView.appearance().backgroundColor = darkerGrey
                    UITableViewCell.appearance().backgroundColor = darkerGrey
                }
        }
    }
}
