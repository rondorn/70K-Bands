package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.content.Context;
import android.graphics.drawable.Drawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import androidx.appcompat.content.res.AppCompatResources;
import androidx.coordinatorlayout.widget.CoordinatorLayout;

import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.widget.Toast;
import android.util.Log;


//import com.google.android.material.snackbar.Snackbar;

import java.lang.reflect.Field;

/**
 * Handles the filter menu button and related UI logic for filtering bands.
 */
//public class FilterButtonHandler {
public class FilterButtonHandler  {
    public Button filterMenuButton;
    private PopupWindow popupWindow;
    private static View messageView;
    /**
     * Sets up the filter button and its click listener.
     * @param showBands The main activity instance.
     */
    public void setUpFiltersButton(showBands showBands){

        filterMenuButton = (Button) showBands.findViewById(R.id.FilerMenu);
        messageView = showBands.findViewById(R.id.showBandsView);

        filterMenuButton.setText(context.getResources().getString(R.string.Filters));

        filterMenuButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View context) {
                popupWindow = new PopupWindow(showBands);
                LayoutInflater inflater = (LayoutInflater) staticVariables.context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);

                View view = inflater.inflate(R.layout.filter_choices_menu_layout, null);

                popupWindow.setFocusable(true);
                popupWindow.setWidth(WindowManager.LayoutParams.WRAP_CONTENT);
                popupWindow.setHeight(WindowManager.LayoutParams.WRAP_CONTENT);
                popupWindow.setContentView(view);

                popupWindow.showAsDropDown(filterMenuButton, 0, 0);

                // View Mode Filter (Schedule/Bands Only) - show only when scheduled events are present
                boolean hasScheduledEvents = staticVariables.showEventButtons;
                boolean showScheduleFilters = staticVariables.preferences.getShowScheduleView();
                
                ViewModeFilterHandler viewModeFilterHandle = new ViewModeFilterHandler(popupWindow);
                viewModeFilterHandle.setVisibility(hasScheduledEvents);
                viewModeFilterHandle.setupViewModeFilters();
                viewModeFilterHandle.setupViewModeListener(showBands);

                MustMightFilterHandler mustMightHandle = new MustMightFilterHandler(popupWindow);
                mustMightHandle.setupMustMightFilters();
                mustMightHandle.setupMustMightListener(showBands);

                EventFilterHandler eventFilterHandle = new EventFilterHandler(popupWindow);
                eventFilterHandle.setupEventTypeFilters();
                eventFilterHandle.setupEventTypeListener(showBands);

                VenueFilterHandler venueFilterHandle = new VenueFilterHandler(popupWindow);
                venueFilterHandle.setupVenueFilters();
                venueFilterHandle.setupVenueListener(showBands);

                OtherFilterHandler otherFilterHandle = new OtherFilterHandler(popupWindow);
                otherFilterHandle.setupOtherFilters(showScheduleFilters);
                otherFilterHandle.setupEventTypeListener(showBands);

            }
        });
    }

    /**
     * Refreshes the filter UI and shows a message after a button click.
     * @param popupWindow The popup window containing the filters.
     * @param showBands The main activity instance.
     * @param message The message to display.
     */
    public static void refreshAfterButtonClick(PopupWindow popupWindow, showBands showBands, String message){

        //popupWindow.dismiss();
        if (message.isEmpty() == false) {
            HelpMessageHandler.showMessage(message, messageView);
        }
        // CRITICAL FIX: Clear the mainListHandler cache
        if (showBands.listHandler != null) {
            Log.d("VIEW_MODE_DEBUG", "🔄 REFRESH: Actually clearing mainListHandler cache");
            showBands.listHandler.clearCache();
        }
        
        showBands.refreshData();

        // View Mode Filter (Schedule/Bands Only) - show only when scheduled events are present
        boolean hasScheduledEvents = staticVariables.showEventButtons;
        boolean showScheduleFilters = staticVariables.preferences.getShowScheduleView();
        
        ViewModeFilterHandler viewModeFilterHandle = new ViewModeFilterHandler(popupWindow);
        viewModeFilterHandle.setVisibility(hasScheduledEvents);
        viewModeFilterHandle.setupViewModeFilters();

        MustMightFilterHandler mustMightHandle = new MustMightFilterHandler(popupWindow);
        mustMightHandle.setupMustMightFilters();

        EventFilterHandler eventFilterHandle = new EventFilterHandler(popupWindow);
        eventFilterHandle.setupEventTypeFilters();

        VenueFilterHandler venueFilterHandle = new VenueFilterHandler(popupWindow);
        venueFilterHandle.setupVenueFilters();

        OtherFilterHandler otherFilterHandle = new OtherFilterHandler(popupWindow);
        otherFilterHandle.setupOtherFilters(showScheduleFilters);

    }

    /**
     * Hides a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void hideMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if (sectionType == "TextView") {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.GONE);
        }
        if (sectionType == "LinearLayout") {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.GONE);
        }
    }

    /**
     * Disables a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void disableMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if (sectionType == "TextView") {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setEnabled(false);
        }
        if (sectionType == "LinearLayout") {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setEnabled(false);
        }
    }

    /**
     * Enables a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void enableMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if (sectionType == "TextView") {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setEnabled(true);
        }
        if (sectionType == "LinearLayout") {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setEnabled(true);
        }
    }

    /**
     * Shows a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void showMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if (sectionType == "TextView") {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.VISIBLE);
        }
        if (sectionType == "LinearLayout") {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.VISIBLE);
        }
    }

    /**
     * Checks if all venue or status filters are off and blocks the change if so, showing a message.
     * @return True if the change should be blocked, false otherwise.
     */
    public static Boolean blockTurningAllFiltersOn(){

        Boolean blockChange = false;
        
        // Check if all venues are hidden using dynamic venue system
        FestivalConfig festivalConfig = FestivalConfig.getInstance();
        java.util.List<String> configuredVenues = festivalConfig.getAllVenueNames();
        
        boolean anyVenueVisible = false;
        // Check all configured venues
        for (String venueName : configuredVenues) {
            if (staticVariables.preferences.getShowVenueEvents(venueName)) {
                anyVenueVisible = true;
                break;
            }
        }
        // Also check "Other" venues
        if (staticVariables.preferences.getShowVenueEvents("Other")) {
            anyVenueVisible = true;
        }
        
        if (!anyVenueVisible) {
            blockChange = true;
            HelpMessageHandler.showMessage(context.getResources().getString(R.string.can_not_hide_all_venues), messageView);
        }

        if (staticVariables.preferences.getShowMust() == false &&
                staticVariables.preferences.getShowMight() == false &&
                staticVariables.preferences.getShowWont() == false &&
                staticVariables.preferences.getShowUnknown() == false ){
            blockChange = true;
            HelpMessageHandler.showMessage(context.getResources().getString(R.string.can_not_hide_all_statuses), messageView);
        }

        return blockChange;
    }

}
