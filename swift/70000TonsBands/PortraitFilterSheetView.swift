//
//  PortraitFilterSheetView.swift
//  70K Bands
//
//  Portrait filter menu sheet - uses shared CommonFilterSheetView
//

import SwiftUI

struct PortraitFilterSheetView: View {
    @State private var dayBeforeFilterChange: String? = nil
    var onDismiss: (() -> Void)?
    
    var body: some View {
        CommonFilterSheetView(
            menuOrder: .portrait,
            dayData: nil,
            viewModel: nil,
            dayBeforeFilterChange: $dayBeforeFilterChange,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Legacy implementation (kept for reference, now uses CommonFilterSheetView)
/*
struct PortraitFilterSheetView_Legacy: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFlaggedOnly: Bool = getShowOnlyWillAttened()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                
                // ORDER: Match Android portrait menu order
                // 1. Hide Expired Events
                // 2. Band Rankings
                // 3. Show Flagged Events Only
                // 4. Sort By Name
                // 5. Event Types
                // 6. Event Locations
                
                // 1. Hide Expired Events
                // Only when events exist and at least one is expired
                if hasAnyEvents() && hasExpiredEvents() {
                    Section(header: Text(NSLocalizedString("Expired Events", comment: ""))) {
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
                                    NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                                }
                            ))
                            .disabled(isFlaggedFilterEnabled)
                        }
                    }
                }
                
                // 2. Band Ranking Filters
                // Always shown
                // Disabled when "Show Flagged Events Only" is enabled
                Section(header: Text(NSLocalizedString("Band Ranking Filters", comment: ""))) {
                    HStack(spacing: 12) {
                        Image(uiImage: UIImage(named: getMustSeeOn() ? mustSeeIcon : mustSeeIconAlt) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Toggle(NSLocalizedString("Show Must See Items", comment: ""), isOn: Binding(
                            get: { getMustSeeOn() },
                            set: { newValue in
                                setMustSeeOn(newValue)
                                writeFiltersFile()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        ))
                        .disabled(isFlaggedFilterEnabled)
                    }
                    HStack(spacing: 12) {
                        Image(uiImage: UIImage(named: getMightSeeOn() ? mightSeeIcon : mightSeeIconAlt) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Toggle(NSLocalizedString("Show Might See Items", comment: ""), isOn: Binding(
                            get: { getMightSeeOn() },
                            set: { newValue in
                                setMightSeeOn(newValue)
                                writeFiltersFile()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        ))
                        .disabled(isFlaggedFilterEnabled)
                    }
                    HStack(spacing: 12) {
                        Image(uiImage: UIImage(named: getWontSeeOn() ? wontSeeIcon : wontSeeIconAlt) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Toggle(NSLocalizedString("Show Wont See Items", comment: ""), isOn: Binding(
                            get: { getWontSeeOn() },
                            set: { newValue in
                                setWontSeeOn(newValue)
                                writeFiltersFile()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        ))
                        .disabled(isFlaggedFilterEnabled)
                    }
                    HStack(spacing: 12) {
                        Image(uiImage: UIImage(named: getUnknownSeeOn() ? unknownIcon : unknownIconAlt) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Toggle(NSLocalizedString("Show Unknown Items", comment: ""), isOn: Binding(
                            get: { getUnknownSeeOn() },
                            set: { newValue in
                                setUnknownSeeOn(newValue)
                                writeFiltersFile()
                                NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                            }
                        ))
                        .disabled(isFlaggedFilterEnabled)
                    }
                }
                
                // 3. Show Flagged Events Only
                // Only show if flagged events exist
                if showScheduleFilters && attendingCount > 0 {
                    Section(header: Text(NSLocalizedString("Show Flagged Events Only", comment: ""))) {
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
                                    NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                                }
                            ))
                        }
                    }
                }
                
                // 4. Sort By Name
                // Only show when in Schedule mode AND scheduled events exist
                if showScheduleFilters {
                    Section(header: Text(NSLocalizedString("Sorting Options", comment: ""))) {
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let newSort = getSortedBy() == "name" ? "time" : "name"
                            setSortedBy(newSort)
                            writeFiltersFile()
                            NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                        }
                    }
                }
                
                // 5. Event Type Filters
                // Only show if filterable event types exist
                // Disabled when "Show Flagged Events Only" is enabled
                let showScheduledEventTypeFilters = showScheduleFilters && (getMeetAndGreetsEnabled() || getSpecialEventsEnabled())
                let showUnofficalEventFilter = getUnofficalEventsEnabled() && showScheduleView
                
                if showScheduledEventTypeFilters || showUnofficalEventFilter {
                    Section(header: Text(NSLocalizedString("Event Type Filters", comment: ""))) {
                        if getMeetAndGreetsEnabled() && showScheduleFilters {
                            HStack(spacing: 12) {
                                Image(uiImage: UIImage(named: getShowMeetAndGreetEvents() ? meetAndGreetIcon : meetAndGreetIconAlt) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                Toggle(NSLocalizedString("Show Meet & Greet Events", comment: ""), isOn: Binding(
                                    get: { getShowMeetAndGreetEvents() },
                                    set: { newValue in
                                        setShowMeetAndGreetEvents(newValue)
                                        writeFiltersFile()
                                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                                    }
                                ))
                                .disabled(isFlaggedFilterEnabled)
                            }
                        }
                        if getSpecialEventsEnabled() && showScheduleFilters {
                            HStack(spacing: 12) {
                                Image(uiImage: UIImage(named: getShowSpecialEvents() ? specialEventTypeIcon : specialEventTypeIconAlt) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                Toggle(NSLocalizedString("Show Special/Other Events", comment: ""), isOn: Binding(
                                    get: { getShowSpecialEvents() },
                                    set: { newValue in
                                        setShowSpecialEvents(newValue)
                                        writeFiltersFile()
                                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                                    }
                                ))
                                .disabled(isFlaggedFilterEnabled)
                            }
                        }
                        if showUnofficalEventFilter {
                            HStack(spacing: 12) {
                                Image(uiImage: UIImage(named: getShowUnofficalEvents() ? unofficalEventTypeIcon : unofficalEventTypeIconAlt) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                Toggle(NSLocalizedString("Show Unofficial Events", comment: ""), isOn: Binding(
                                    get: { getShowUnofficalEvents() },
                                    set: { newValue in
                                        setShowUnofficalEvents(newValue)
                                        writeFiltersFile()
                                        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                                    }
                                ))
                                .disabled(isFlaggedFilterEnabled)
                            }
                        }
                    }
                }
                
                // 6. Location Filters
                // Only show if venues exist
                // Disabled when "Show Flagged Events Only" is enabled
                if showScheduleFilters {
                    let venuesInUse = getVenueNamesInUseForList()
                    if !venuesInUse.isEmpty {
                        Section(header: HStack(spacing: 12) {
                            Image(uiImage: UIImage(named: "Location-Generic-Going-wBox") ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            Text(NSLocalizedString("Location Filters", comment: ""))
                        }) {
                            ForEach(venuesInUse, id: \.self) { venueName in
                                HStack(spacing: 12) {
                                    // Use same icon logic as calendar view
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
                                            NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
                                        }
                                    ))
                                    .disabled(isFlaggedFilterEnabled)
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }
}
*/
