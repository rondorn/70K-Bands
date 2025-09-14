package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.appcompat.content.res.AppCompatResources;

import java.util.ArrayList;
import java.util.List;

public class OtherFilterHandler {

    private PopupWindow popupWindow;

    public OtherFilterHandler(PopupWindow value){
        popupWindow = value;
    }
    public void setupEventTypeListener(showBands showBands){

        TextView clearFilter = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilter);
        clearFilter.setOnClickListener(new View.OnClickListener() {
             @Override
             public void onClick(View context) {

                 String message = staticVariables.context.getResources().getString(R.string.clear_all_filters);

                 staticVariables.preferences.setShowAlbumListen(true);
                 staticVariables.preferences.setShowClinicEvents(true);
                 staticVariables.preferences.setShowMeetAndGreet(true);
                 staticVariables.preferences.setShowSpecialEvents(true);
                 staticVariables.preferences.setShowUnofficalEvents(true);

                 staticVariables.preferences.setshowMust(true);
                 staticVariables.preferences.setshowMight(true);
                 staticVariables.preferences.setshowWont(true);
                 staticVariables.preferences.setshowUnknown(true);

                 // Reset hardcoded venue preferences (for 70K)
                 staticVariables.preferences.setShowLoungeShows(true);
                 staticVariables.preferences.setShowPoolShows(true);
                 staticVariables.preferences.setShowRinkShows(true);
                 staticVariables.preferences.setShowTheaterShows(true);
                 staticVariables.preferences.setShowOtherShows(true);
                 
                 // Reset all dynamic venue preferences (for MDF and other festivals)
                 FestivalConfig festivalConfig = FestivalConfig.getInstance();
                 java.util.List<String> configuredVenues = festivalConfig.getAllVenueNames();
                 for (String venueName : configuredVenues) {
                     staticVariables.preferences.setShowVenueEvents(venueName, true);
                 }

                 staticVariables.preferences.setShowWillAttend(false);

                 staticVariables.preferences.saveData();

                 setupOtherFilters();
                 FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);

             }
         });


        LinearLayout onlyShowAttendedAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.onlyShowAttendedAll);
        onlyShowAttendedAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowWillAttend() == true) {
                    message = staticVariables.context.getResources().getString(R.string.show_all_events);
                    staticVariables.preferences.setShowWillAttend(false);
                } else {
                    message = staticVariables.context.getResources().getString(R.string.show_flaged_events_only);
                    staticVariables.preferences.setShowWillAttend(true);
                }
                staticVariables.preferences.saveData();
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);

            }
        });
        if (staticVariables.showsIwillAttend == 0){
            onlyShowAttendedAll.setEnabled(false);
            TextView onlyShowAttendedFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.onlyShowAttended);
            onlyShowAttendedFilterText.setEnabled(false);
        }

        LinearLayout sortOptionAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.sortOptionAll);
        sortOptionAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getSortByTime() == true) {
                    staticVariables.preferences.setSortByTime(false);
                    message = staticVariables.context.getString(R.string.SortingAlphabetically);
                } else {
                    staticVariables.preferences.setSortByTime(true);
                    message = staticVariables.context.getString(R.string.SortingChronologically);
                }
                staticVariables.preferences.saveData();
                
                // CRITICAL FIX: Clear the cache when sort preference changes
                Log.d("VIEW_MODE_DEBUG", "🔄 SORT CHANGE: Sort preference changed, clearing mainListHandler cache");
                
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });
    }


    public void setupOtherFilters(){
        setupOtherFilters(true); // Default to showing all filters for backward compatibility
    }

    public void setupOtherFilters(boolean showScheduleFilters){
        
        Log.d("UNOFFICIAL_DEBUG", "🔧 setupOtherFilters called - showScheduleFilters=" + showScheduleFilters + ", showEventButtons=" + staticVariables.showEventButtons + ", showUnofficalEventButtons=" + staticVariables.showUnofficalEventButtons);

        if ((staticVariables.showEventButtons == true || staticVariables.showUnofficalEventButtons == true) && showScheduleFilters){
            // SCHEDULE MODE: Show schedule-related filters
            
            // Check if we have ONLY unofficial events (special case)
            boolean hasOnlyUnofficalEvents = staticVariables.showUnofficalEventButtons && !staticVariables.showEventButtons;
            
            // Check if any event type filters should be shown
            boolean showAnyEventTypeFilters = staticVariables.preferences.getMeetAndGreetsEnabled() ||
                                             staticVariables.preferences.getSpecialEventsEnabled() ||
                                             staticVariables.showUnofficalEventButtons;
            
            Log.d("UNOFFICIAL_DEBUG", "🔧 hasOnlyUnofficalEvents=" + hasOnlyUnofficalEvents + ", showAnyEventTypeFilters=" + showAnyEventTypeFilters);
            
            if (showAnyEventTypeFilters) {
                if (hasOnlyUnofficalEvents) {
                    // ONLY UNOFFICIAL EVENTS: Show only unofficial filter, hide header and others
                    Log.d("UNOFFICIAL_DEBUG", "🔧 ONLY unofficial events - hiding other filters and header");
                    FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow); // Hide header
                    FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow); // Hide break
                    FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
                    FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
                    FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
                } else {
                    // MIXED OR OFFICIAL EVENTS: Show header and filters based on festival settings and data
                    Log.d("UNOFFICIAL_DEBUG", "🔧 Mixed/official events - showing standard filters and header");
                    FilterButtonHandler.showMenuSection(R.id.eventTypeHeader, "TextView", popupWindow); // Show header
                    FilterButtonHandler.showMenuSection(R.id.Brake5, "TextView", popupWindow); // Show break
                    
                    if (staticVariables.preferences.getMeetAndGreetsEnabled()) {
                        FilterButtonHandler.showMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
                    } else {
                        FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
                    }
                    
                    if (staticVariables.preferences.getSpecialEventsEnabled()) {
                        FilterButtonHandler.showMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
                    } else {
                        FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
                    }
                    
                    if (staticVariables.showUnofficalEventButtons) {
                        Log.d("UNOFFICIAL_DEBUG", "🔧 Showing unofficial events filter");
                        FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
                    } else {
                        Log.d("UNOFFICIAL_DEBUG", "🔧 Hiding unofficial events filter");
                        FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
                    }
                }
            } else {
                // Hide event type filters section when all are disabled
                FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            }
            
            if (!hasOnlyUnofficalEvents) {
                // Show location/venue filters in Schedule mode (but not when only unofficial events)
                Log.d("UNOFFICIAL_DEBUG", "🔧 Showing location/venue, flagged, and sort sections");
                FilterButtonHandler.showMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.Brake6, "TextView", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);
                
                // Show flagged and sort sections in Schedule mode (but not when only unofficial events)
                FilterButtonHandler.showMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.Brake3, "TextView", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.Brake4, "TextView", popupWindow);
                FilterButtonHandler.showMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);
            } else {
                // Hide location/venue, flagged, and sort sections when only unofficial events
                Log.d("UNOFFICIAL_DEBUG", "🔧 ONLY unofficial events - hiding location/venue, flagged, and sort sections");
                FilterButtonHandler.hideMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.Brake6, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.Brake3, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.Brake4, "TextView", popupWindow);
                FilterButtonHandler.hideMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);
            }
            
        } else if (staticVariables.showEventButtons == true && !showScheduleFilters) {
            // BANDS ONLY MODE: Hide all schedule-related filters (event types, venues, flagged, sort)
            FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake6, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake3, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake4, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);
            
        } else {
            // NO EVENTS MODE: Hide ALL sections when showEventButtons is false
            FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake6, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake3, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake4, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);
        }

        TextView clearFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilter);

        if (staticVariables.filteringInPlace == true) {
            clearFilterText.setEnabled(true);

        } else {
            clearFilterText.setEnabled(false);
        }



        TextView onlyShowAttendedText = (TextView) popupWindow.getContentView().findViewById(R.id.onlyShowAttended);
        ImageView onlyShowAttendedIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.onlyShowAttendedIcon);
        Drawable onlyShowAttendedYes = AppCompatResources.getDrawable(context, R.drawable.icon_seen);
        Drawable onlyShowAttendedNo = AppCompatResources.getDrawable(context, R.drawable.icon_seen_alt);

        if (staticVariables.preferences.getShowWillAttend() == false && staticVariables.showEventButtons == true) {
            onlyShowAttendedIcon.setImageDrawable(onlyShowAttendedYes);
            onlyShowAttendedText.setText(R.string.show_flaged_events_only);

            FilterButtonHandler.enableMenuSection(R.id.mustSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.mightSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.wontSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.unknownSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.mustSeeFilter, "TextView", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.mightSeeFilter, "TextView", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.wontSeeFilter, "TextView", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.unknownSeeFilter, "TextView", popupWindow);

            FilterButtonHandler.enableMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.meetAndGreetFilter, "TextView", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.specialOtherEventFilter, "TextView", popupWindow);
            FilterButtonHandler.enableMenuSection(R.id.unofficalEventFilter, "TextView", popupWindow);

            // Enable dynamic venue filters container
            FilterButtonHandler.enableMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);

        } else if (staticVariables.showEventButtons == true){
            onlyShowAttendedIcon.setImageDrawable(onlyShowAttendedNo);
            onlyShowAttendedText.setText(R.string.show_all_events);

            FilterButtonHandler.disableMenuSection(R.id.mustSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.mightSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.wontSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.unknownSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.mustSeeFilter, "TextView", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.mightSeeFilter, "TextView", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.wontSeeFilter, "TextView", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.unknownSeeFilter, "TextView", popupWindow);

            FilterButtonHandler.disableMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.meetAndGreetFilter, "TextView", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.specialOtherEventFilter, "TextView", popupWindow);
            FilterButtonHandler.disableMenuSection(R.id.unofficalEventFilter, "TextView", popupWindow);

            // Disable dynamic venue filters container
            FilterButtonHandler.disableMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);

            ImageView mustSeeFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.mustSeeFilterIcon);
            ImageView mightSeeFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.mightSeeFilterIcon);
            ImageView wontSeeFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.wontSeeFilterIcon);
            ImageView unknownSeeFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.unknownSeeFilterIcon);

            ImageView meetAndGreetFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.meetAndGreetFilterIcon);
            ImageView specialOtherEventFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.specialOtherEventFilterIcon);
            ImageView unofficalEventFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.unofficalEventFilterIcon);

            // Venue filter icons are now managed dynamically by VenueFilterHandler
            // No need to manually set their states here

            mightSeeFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_going_yes_alt));
            mustSeeFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_going_maybe_alt));
            wontSeeFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_going_no_alt));
            unknownSeeFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_unknown_alt));

            meetAndGreetFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_meet_and_greet_alt));
            specialOtherEventFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_all_star_jam_alt));
            unofficalEventFilterIcon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_unoffical_event_alt));

            // Venue filter icon states are now handled by VenueFilterHandler.setupVenueFilters()

        }

        TextView sortOptionText = (TextView) popupWindow.getContentView().findViewById(R.id.sortOption);
        ImageView sortOptionIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.sortOptionIcon);
        Drawable sortOptionName = AppCompatResources.getDrawable(context, R.drawable.icon_sort_az);
        Drawable sortOptionTime = AppCompatResources.getDrawable(context, R.drawable.icon_sort_time);
        if (staticVariables.preferences.getSortByTime()== false) {
            sortOptionIcon.setImageDrawable(sortOptionTime);
            sortOptionText.setText(R.string.sort_by_time);
        } else {
            sortOptionIcon.setImageDrawable(sortOptionName);
            sortOptionText.setText(R.string.sort_by_name);
        }

    }
}
