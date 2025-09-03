package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
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
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });
    }


    public void setupOtherFilters(){

        if (staticVariables.showEventButtons == true){
            FilterButtonHandler.showMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake6, "TextView", popupWindow);
            // Show dynamic venue filters container instead of individual hardcoded venue sections
            FilterButtonHandler.showMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);

            FilterButtonHandler.showMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake3, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);

            FilterButtonHandler.showMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake4, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);

        } else {
            FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake6, "TextView", popupWindow);
            // Hide dynamic venue filters container instead of individual hardcoded venue sections
            FilterButtonHandler.hideMenuSection(R.id.dynamicVenueFiltersContainer, "LinearLayout", popupWindow);

            FilterButtonHandler.hideMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake3, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);

            FilterButtonHandler.hideMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake4, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);
        }
        //if (staticVariables.showUnofficalEventButtons == true){
            FilterButtonHandler.showMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
        //} else {
            //FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            //FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            //FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
        //}

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
