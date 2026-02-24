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
import android.os.Handler;
import android.os.Looper;


//import com.google.android.material.snackbar.Snackbar;

import java.lang.reflect.Field;

/**
 * Handles the filter menu button and related UI logic for filtering bands.
 */
//public class FilterButtonHandler {
public class FilterButtonHandler  {
    public Button filterMenuButton;
    private android.app.Dialog filterDialog;
    private static android.app.Dialog sCurrentDialog;
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
                // Dismiss any existing dialog
                if (sCurrentDialog != null && sCurrentDialog.isShowing()) {
                    sCurrentDialog.dismiss();
                }
                
                // Create filter menu using CommonFilterMenuBuilder
                filterDialog = CommonFilterMenuBuilder.buildFilterMenu(
                    showBands,
                    CommonFilterMenuBuilder.MenuType.PORTRAIT,
                    new CommonFilterMenuBuilder.FilterMenuCallbacks() {
                        @Override
                        public void onFilterChanged() {
                            String message = "";
                            refreshAfterButtonClick(null, showBands, message);
                        }
                        
                        @Override
                        public void onClearAllFilters() {
                            // Clear all filters
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
                            
                            // Reset all location filters
                            java.util.List<String> venuesInUse = staticVariables.getVenueNamesInUseForList();
                            staticVariables.preferences.setVenueFilters(venuesInUse, true);
                            
                            staticVariables.preferences.setShowWillAttend(false);
                            // Hide Expired Events is a preference, not a filter — preserve it
                            
                            staticVariables.preferences.saveData();
                            
                            String message = staticVariables.context.getResources().getString(R.string.clear_all_filters);
                            refreshAfterButtonClick(null, showBands, message);
                            filterDialog.dismiss();
                        }
                        
                        @Override
                        public void onDismiss() {
                            filterDialog.dismiss();
                        }
                    }
                );
                
                sCurrentDialog = filterDialog;
                filterDialog.show();
            }
        });
    }

    /**
     * Registers the current filter dialog (List or Calendar). Used so dismissFilterPopupIfShowing can close whichever is open.
     */
    public static void registerCurrentFilterDialog(android.app.Dialog dialog) {
        sCurrentDialog = dialog;
    }

    /**
     * Dismisses the filter dialog if it is showing (e.g. on rotation, view switch).
     */
    public static void dismissFilterPopupIfShowing() {
        if (sCurrentDialog != null && sCurrentDialog.isShowing()) {
            sCurrentDialog.dismiss();
        }
        sCurrentDialog = null;
    }

    /**
     * Refreshes the filter UI and shows a message after a button click.
     * @param popupWindow The popup window containing the filters (deprecated, kept for compatibility).
     * @param showBands The main activity instance.
     * @param message The message to display.
     */
    public static void refreshAfterButtonClick(PopupWindow popupWindow, showBands showBands, String message){

        if (message != null && !message.isEmpty()) {
            HelpMessageHandler.showMessage(message, messageView);
        }
        // CRITICAL FIX: Clear the mainListHandler cache
        if (showBands.listHandler != null) {
            Log.d("VIEW_MODE_DEBUG", "🔄 REFRESH: Actually clearing mainListHandler cache");
            showBands.listHandler.clearCache();
        }
        
        showBands.refreshData();

        // Re-evaluate list vs calendar in landscape after filter change (e.g. Hide Expired Events off → calendar should appear)
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                showBands.recheckLandscapeScheduleAfterFilterChange();
            }
        }, 500);

        // Note: Filter UI is now managed by CommonFilterMenuBuilder, so we don't need to refresh
        // individual filter handlers here anymore. The dialog will be rebuilt when reopened.
    }

    /**
     * Hides a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void hideMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if ("TextView".equals(sectionType)) {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setVisibility(View.GONE);
                Log.d("UNOFFICIAL_DEBUG", "🔧 HIDING TextView section: " + sectionName);
            } else {
                Log.w("UNOFFICIAL_DEBUG", "⚠️ TextView section not found: " + sectionName);
            }
        }
        if ("LinearLayout".equals(sectionType)) {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setVisibility(View.GONE);
                Log.d("UNOFFICIAL_DEBUG", "🔧 HIDING LinearLayout section: " + sectionName);
            } else {
                Log.w("UNOFFICIAL_DEBUG", "⚠️ LinearLayout section not found: " + sectionName);
            }
        }
    }

    /**
     * Disables a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void disableMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if ("TextView".equals(sectionType)) {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setEnabled(false);
            }
        }
        if ("LinearLayout".equals(sectionType)) {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setEnabled(false);
            }
        }
    }

    /**
     * Enables a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void enableMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if ("TextView".equals(sectionType)) {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setEnabled(true);
            }
        }
        if ("LinearLayout".equals(sectionType)) {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setEnabled(true);
            }
        }
    }

    /**
     * Shows a menu section by view type and ID.
     * @param sectionName The resource ID of the section.
     * @param sectionType The type of the section (TextView or LinearLayout).
     * @param popupWindow The popup window containing the section.
     */
    public static void showMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if ("TextView".equals(sectionType)) {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setVisibility(View.VISIBLE);
                Log.d("UNOFFICIAL_DEBUG", "🔧 SHOWING TextView section: " + sectionName);
            } else {
                Log.w("UNOFFICIAL_DEBUG", "⚠️ TextView section not found: " + sectionName);
            }
        }
        if ("LinearLayout".equals(sectionType)) {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            if (menuSection != null) {
                menuSection.setVisibility(View.VISIBLE);
                Log.d("UNOFFICIAL_DEBUG", "🔧 SHOWING LinearLayout section: " + sectionName);
            } else {
                Log.w("UNOFFICIAL_DEBUG", "⚠️ LinearLayout section not found: " + sectionName);
            }
        }
    }

    /**
     * Checks if all venue or status filters are off and blocks the change if so, showing a message.
     * @return True if the change should be blocked, false otherwise.
     */
    public static Boolean blockTurningAllFiltersOn(){

        Boolean blockChange = false;
        
        // Check if all venues in use (configured + discovered) would be hidden
        java.util.List<String> venuesInUse = staticVariables.getVenueNamesInUseForList();
        boolean anyVenueVisible = false;
        for (String venueName : venuesInUse) {
            if (staticVariables.preferences.getShowVenueEvents(venueName)) {
                anyVenueVisible = true;
                break;
            }
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
