package com.Bands70k;

import android.graphics.drawable.Drawable;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.content.res.AppCompatResources;

/**
 * Handles view mode filtering logic and UI for the filter menu.
 * Manages Schedule vs Bands Only display modes.
 */
public class ViewModeFilterHandler {

    private PopupWindow popupWindow;

    /**
     * Constructs a ViewModeFilterHandler with the given popup window.
     * @param value The popup window instance.
     */
    public ViewModeFilterHandler(PopupWindow value){
        popupWindow = value;
    }

    /**
     * Sets up view mode filter listeners for the filter menu.
     * @param showBands The main activity instance.
     */
    public void setupViewModeListener(showBands showBands) {
        LinearLayout viewModeToggleAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.viewModeToggleAll);

        viewModeToggleAll.setOnClickListener(new LinearLayout.OnClickListener() {
            public void onClick(View context) {
                
                // Toggle the view mode (session-only, not saved to disk)
                boolean currentMode = staticVariables.preferences.getShowScheduleView();
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: Current mode before toggle: " + currentMode);
                staticVariables.preferences.setShowScheduleView(!currentMode);
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: New mode after toggle (session-only): " + staticVariables.preferences.getShowScheduleView());
                
                // AUTO SORT FIX: Automatically switch sort mode based on view mode
                // Bands Only → Sort Alphabetically, Schedule View → Sort by Time
                if (staticVariables.preferences.getShowScheduleView()) {
                    // Switching to Schedule View → Sort by Time
                    staticVariables.preferences.setSortByTime(true);
                    Log.d("VIEW_MODE_DEBUG", "🔄 AUTO SORT: Switched to Sort by Time for Schedule View");
                } else {
                    // Switching to Bands Only → Sort Alphabetically
                    staticVariables.preferences.setSortByTime(false);
                    Log.d("VIEW_MODE_DEBUG", "🔄 AUTO SORT: Switched to Sort Alphabetically for Bands Only View");
                }
                
                // Save sort preference (but NOT showScheduleView - it's session-only)
                staticVariables.preferences.saveData();
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: Sort preference saved to file (showScheduleView is session-only)");
                
                // Update the UI immediately
                setupViewModeFilters();
                
                // Refresh the main list
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: About to call refreshData()");
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: Final check - getShowScheduleView() = " + staticVariables.preferences.getShowScheduleView());
                showBands.refreshData();
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: refreshData() completed");
                Log.d("VIEW_MODE_DEBUG", "🔄 TOGGLE: After refresh - getShowScheduleView() = " + staticVariables.preferences.getShowScheduleView());
                
                // Close the popup
                popupWindow.dismiss();
                
                // Show confirmation message
                String message = !currentMode ? 
                    staticVariables.context.getResources().getString(R.string.show_schedule) : 
                    staticVariables.context.getResources().getString(R.string.show_bands_only);
                Toast.makeText(staticVariables.context, message, Toast.LENGTH_SHORT).show();
            }
        });
    }

    /**
     * Sets up the view mode filter display based on current settings.
     */
    public void setupViewModeFilters() {
        TextView viewModeText = (TextView) popupWindow.getContentView().findViewById(R.id.viewModeToggle);
        ImageView viewModeIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.viewModeToggleIcon);
        
        // Get appropriate drawables
        Drawable scheduleIcon = AppCompatResources.getDrawable(staticVariables.context, R.drawable.icon_sort_time);
        Drawable bandsIcon = AppCompatResources.getDrawable(staticVariables.context, R.drawable.icon_sort_az);
        
        if (staticVariables.preferences.getShowScheduleView()) {
            // Currently showing schedule, offer to switch to bands only
            viewModeIcon.setImageDrawable(bandsIcon);
            viewModeText.setText(R.string.show_bands_only);
        } else {
            // Currently showing bands only, offer to switch to schedule
            viewModeIcon.setImageDrawable(scheduleIcon);
            viewModeText.setText(R.string.show_schedule);
        }
    }

    /**
     * Shows or hides the view mode filter section based on whether scheduled events are present.
     * @param showSection True to show the section, false to hide it.
     */
    public void setViewModeSectionVisibility(boolean showSection) {
        int visibility = showSection ? View.VISIBLE : View.GONE;
        
        View viewModeHeader = popupWindow.getContentView().findViewById(R.id.viewModeHeader);
        View viewModeBrake = popupWindow.getContentView().findViewById(R.id.viewModeBrake);
        View viewModeToggleAll = popupWindow.getContentView().findViewById(R.id.viewModeToggleAll);
        View viewModeToggleBrake = popupWindow.getContentView().findViewById(R.id.viewModeToggleBrake);
        
        if (viewModeHeader != null) viewModeHeader.setVisibility(visibility);
        if (viewModeBrake != null) viewModeBrake.setVisibility(visibility);
        if (viewModeToggleAll != null) viewModeToggleAll.setVisibility(visibility);
        if (viewModeToggleBrake != null) viewModeToggleBrake.setVisibility(visibility);
    }
}
