package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.util.Log;

import androidx.appcompat.content.res.AppCompatResources;

import java.util.List;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

public class VenueFilterHandler {

    private PopupWindow popupWindow;
    private FestivalConfig festivalConfig;
    private LinearLayout dynamicVenueContainer;
    private Map<String, LinearLayout> venueLayouts = new HashMap<>();
    private Map<String, TextView> venueTextViews = new HashMap<>();
    private Map<String, ImageView> venueImageViews = new HashMap<>();

    public VenueFilterHandler(PopupWindow value){
        popupWindow = value;
        festivalConfig = FestivalConfig.getInstance();
        dynamicVenueContainer = (LinearLayout) popupWindow.getContentView().findViewById(R.id.dynamicVenueFiltersContainer);
    }
    
    public void setupVenueListener(showBands showBands){
        Log.d("VenueFilterHandler", "Setting up dynamic venue listeners for " + festivalConfig.getAllVenueNames());
        
        // Clear any existing venue sections
        if (dynamicVenueContainer != null) {
            dynamicVenueContainer.removeAllViews();
            venueLayouts.clear();
            venueTextViews.clear();
            venueImageViews.clear();
        }
        
        // Create venue filter sections dynamically based on FestivalConfig
        List<String> configuredVenues = festivalConfig.getAllVenueNames();
        
        for (String venueName : configuredVenues) {
            createVenueFilterSection(venueName, showBands);
        }
        
        // Always add "Other" section for venues not explicitly defined
        createVenueFilterSection("Other", showBands);
        
        // Populate all the venue sections with their initial text and icons
        setupVenueFilters();
    }
    
    private void createVenueFilterSection(String venueName, showBands showBands) {
        // Create separator line
        createSeparatorLine();
        
        // Create main container for venue filter
        LinearLayout venueContainer = new LinearLayout(context);
        LinearLayout.LayoutParams containerParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT);
        containerParams.setMargins(0, dpToPx(10), 0, dpToPx(10));
        venueContainer.setLayoutParams(containerParams);
        venueContainer.setOrientation(LinearLayout.HORIZONTAL);
        venueContainer.setBackgroundColor(0xFF323232); // #323232
        venueContainer.setClickable(true);
        
        // Create TextView for venue name
        TextView venueText = new TextView(context);
        LinearLayout.LayoutParams textParams = new LinearLayout.LayoutParams(
            dpToPx(220), LinearLayout.LayoutParams.WRAP_CONTENT);
        textParams.setMarginStart(dpToPx(20));
        venueText.setLayoutParams(textParams);
        // Set text colors explicitly - white when enabled, grey when disabled
        venueText.setTextColor(0xFFF5F5F5); // Start with white (#f5f5f5)
        venueText.setTextAppearance(android.R.style.TextAppearance_Medium);
        venueText.setTypeface(venueText.getTypeface(), android.graphics.Typeface.BOLD);
        venueText.setClickable(false);
        
        // Create ImageView for venue icon
        ImageView venueIcon = new ImageView(context);
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(
            dpToPx(30), dpToPx(30));
        iconParams.setMargins(0, dpToPx(10), 0, dpToPx(10));
        venueIcon.setLayoutParams(iconParams);
        venueIcon.setClickable(false);
        
        // Add views to container
        venueContainer.addView(venueText);
        venueContainer.addView(venueIcon);
        
        // Set up click listener
        venueContainer.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                boolean currentState = getVenueShowState(venueName);
                
                if (currentState) {
                    setVenueShowState(venueName, false);
                    if (FilterButtonHandler.blockTurningAllFiltersOn()) {
                        setVenueShowState(venueName, true);
                    } else {
                        message = getVenueFilterOnMessage(venueName);
                    }
                } else {
                    message = getVenueFilterOffMessage(venueName);
                    setVenueShowState(venueName, true);
                }
                
                staticVariables.preferences.saveData();
                setupVenueFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });
        
        // Store references
        venueLayouts.put(venueName, venueContainer);
        venueTextViews.put(venueName, venueText);
        venueImageViews.put(venueName, venueIcon);
        
        // Add to dynamic container
        dynamicVenueContainer.addView(venueContainer);
        
        Log.d("VenueFilterHandler", "Created venue filter section for: " + venueName);
    }
    
    private void createSeparatorLine() {
        TextView separator = new TextView(context);
        LinearLayout.LayoutParams separatorParams = new LinearLayout.LayoutParams(
            dpToPx(330), dpToPx(1));
        separator.setLayoutParams(separatorParams);
        separator.setBackgroundColor(context.getResources().getColor(android.R.color.darker_gray));
        dynamicVenueContainer.addView(separator);
    }
    
    private int dpToPx(int dp) {
        float density = context.getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }
    
    // Helper methods for venue state management
    private boolean getVenueShowState(String venueName) {
        return staticVariables.preferences.getShowVenueEvents(venueName);
    }
    
    private void setVenueShowState(String venueName, boolean show) {
        staticVariables.preferences.setShowVenueEvents(venueName, show);
    }
    
    private String getVenueFilterOnMessage(String venueName) {
        // Try to get venue-specific strings first
        int stringResId = getStringResourceByName("hide_" + venueName.toLowerCase() + "_venue_filter_on");
        if (stringResId != 0) {
            return staticVariables.context.getString(stringResId);
        }
        
        // Fall back to existing hardcoded strings
        switch (venueName) {
            case "Pool": return staticVariables.context.getString(R.string.pool_venue_filter_on);
            case "Lounge": return staticVariables.context.getString(R.string.lounge_venue_filter_on);
            case "Theater": return staticVariables.context.getString(R.string.theater_venue_filter_on);
            case "Rink": return staticVariables.context.getString(R.string.rink_venue_filter_on);
            case "Other": return staticVariables.context.getString(R.string.other_venue_filter_on);
            default: return venueName + " venue filter enabled";
        }
    }
    
    private String getVenueFilterOffMessage(String venueName) {
        // Try to get venue-specific strings first
        int stringResId = getStringResourceByName("hide_" + venueName.toLowerCase() + "_venue_filter_off");
        if (stringResId != 0) {
            return staticVariables.context.getString(stringResId);
        }
        
        // Fall back to existing hardcoded strings
        switch (venueName) {
            case "Pool": return staticVariables.context.getString(R.string.pool_venue_filter_off);
            case "Lounge": return staticVariables.context.getString(R.string.lounge_venue_filter_off);
            case "Theater": return staticVariables.context.getString(R.string.theater_venue_filter_off);
            case "Rink": return staticVariables.context.getString(R.string.rink_venue_filter_off);
            case "Other": return staticVariables.context.getString(R.string.other_venue_filter_off);
            default: return venueName + " venue filter disabled";
        }
    }

    public void setupVenueFilters(){
        Log.d("VenueFilterHandler", "Setting up venue filter UI for " + festivalConfig.getAllVenueNames());
        
        // If we don't have stored references (e.g., after Clear Filters), rebuild them by scanning the container
        if (venueTextViews.isEmpty() && dynamicVenueContainer != null) {
            rebuildVenueReferences();
        }
        
        // Update UI for each dynamically created venue section
        List<String> configuredVenues = festivalConfig.getAllVenueNames();
        
        for (String venueName : configuredVenues) {
            updateVenueFilterUI(venueName);
        }
        
        // Always update "Other" section
        updateVenueFilterUI("Other");
    }
    
    /**
     * Rebuilds the venue UI element references by scanning the container
     */
    private void rebuildVenueReferences() {
        if (dynamicVenueContainer == null) return;
        
        venueLayouts.clear();
        venueTextViews.clear();
        venueImageViews.clear();
        
        List<String> allVenueNames = new ArrayList<>(festivalConfig.getAllVenueNames());
        allVenueNames.add("Other");
        
        // Scan through child views to find venue sections
        for (int i = 0; i < dynamicVenueContainer.getChildCount(); i++) {
            View child = dynamicVenueContainer.getChildAt(i);
            if (child instanceof LinearLayout) {
                LinearLayout container = (LinearLayout) child;
                
                // Check if this container has the expected structure (TextView + ImageView)
                if (container.getChildCount() >= 2) {
                    View firstChild = container.getChildAt(0);
                    View secondChild = container.getChildAt(1);
                    
                    if (firstChild instanceof TextView && secondChild instanceof ImageView) {
                        TextView textView = (TextView) firstChild;
                        ImageView imageView = (ImageView) secondChild;
                        
                        // Try to match this UI element to a venue by checking the text content
                        String currentText = textView.getText().toString();
                        for (String venueName : allVenueNames) {
                            String hideText = getHideVenueText(venueName);
                            String showText = getShowVenueText(venueName);
                            
                            if (currentText.equals(hideText) || currentText.equals(showText)) {
                                venueLayouts.put(venueName, container);
                                venueTextViews.put(venueName, textView);
                                venueImageViews.put(venueName, imageView);
                                Log.d("VenueFilterHandler", "Rebuilt reference for venue: " + venueName);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    
    private void updateVenueFilterUI(String venueName) {
        TextView venueText = venueTextViews.get(venueName);
        ImageView venueIcon = venueImageViews.get(venueName);
        
        if (venueText == null || venueIcon == null) {
            Log.w("VenueFilterHandler", "Could not find UI elements for venue: " + venueName);
            return;
        }
        
        boolean isVenueEnabled = getVenueShowState(venueName);
        
        // Get drawables - try FestivalConfig first, fall back to hardcoded icons
        Drawable venueFilterYes = getVenueDrawable(venueName, true);
        Drawable venueFilterNo = getVenueDrawable(venueName, false);
        
        // Update icon, text, and colors based on current state
        if (isVenueEnabled) {
            venueIcon.setImageDrawable(venueFilterYes);
            venueText.setText(getHideVenueText(venueName));
            venueText.setTextColor(0xFFF5F5F5); // White text when venue is being shown (#f5f5f5)
        } else {
            venueIcon.setImageDrawable(venueFilterNo);
            venueText.setText(getShowVenueText(venueName));
            venueText.setTextColor(0xFF696969); // Grey text when venue is filtered out (darker_gray)
        }
    }
    
    private String getHideVenueText(String venueName) {
        // Try to get venue-specific strings first
        int stringResId = getStringResourceByName("hide_" + venueName.toLowerCase() + "_events");
        if (stringResId != 0) {
            return staticVariables.context.getString(stringResId);
        }
        
        // Fall back to existing hardcoded strings
        switch (venueName) {
            case "Pool": return staticVariables.context.getString(R.string.hide_pool_events);
            case "Lounge": return staticVariables.context.getString(R.string.hide_lounge_events);
            case "Theater": return staticVariables.context.getString(R.string.hide_theater_events);
            case "Rink": return staticVariables.context.getString(R.string.hide_rink_events);
            case "Other": return staticVariables.context.getString(R.string.hide_other_events);
            default: return "Hide " + venueName + " Events";
        }
    }
    
    private String getShowVenueText(String venueName) {
        // Try to get venue-specific strings first
        int stringResId = getStringResourceByName("show_" + venueName.toLowerCase() + "_events");
        if (stringResId != 0) {
            return staticVariables.context.getString(stringResId);
        }
        
        // Fall back to existing hardcoded strings
        switch (venueName) {
            case "Pool": return staticVariables.context.getString(R.string.show_pool_events);
            case "Lounge": return staticVariables.context.getString(R.string.show_lounge_events);
            case "Theater": return staticVariables.context.getString(R.string.show_theater_events);
            case "Rink": return staticVariables.context.getString(R.string.show_rink_events);
            case "Other": return staticVariables.context.getString(R.string.show_other_events);
            default: return "Show " + venueName + " Events";
        }
    }
    
    private Drawable getVenueDrawable(String venueName, boolean isEnabled) {
        // Try to get icon from FestivalConfig first
        String iconName = isEnabled ? 
            festivalConfig.getVenueGoingIcon(venueName) : 
            festivalConfig.getVenueNotGoingIcon(venueName);
            
        // Try to get resource by name from FestivalConfig
        int resourceId = getDrawableResourceByName(iconName);
        if (resourceId != 0) {
            return AppCompatResources.getDrawable(context, resourceId);
        }
        
        // Fall back to hardcoded icons
        return getHardcodedVenueDrawable(venueName, isEnabled);
    }
    
    private Drawable getHardcodedVenueDrawable(String venueName, boolean isEnabled) {
        switch (venueName) {
            case "Lounge":
                return AppCompatResources.getDrawable(context, 
                    isEnabled ? R.drawable.icon_lounge : R.drawable.icon_lounge_alt);
            case "Pool":
                return AppCompatResources.getDrawable(context,
                    isEnabled ? R.drawable.icon_pool : R.drawable.icon_pool_alt);
            case "Rink":
                return AppCompatResources.getDrawable(context,
                    isEnabled ? R.drawable.icon_rink : R.drawable.icon_rink_alt);
            case "Theater":
                return AppCompatResources.getDrawable(context,
                    isEnabled ? R.drawable.icon_theater : R.drawable.icon_theater_alt);
            case "Other":
            default:
                return AppCompatResources.getDrawable(context,
                    isEnabled ? R.drawable.icon_unknown : R.drawable.icon_unknown_alt);
        }
    }
    
    private int getDrawableResourceByName(String iconName) {
        try {
            return context.getResources().getIdentifier(iconName, "drawable", context.getPackageName());
        } catch (Exception e) {
            Log.w("VenueFilterHandler", "Could not find drawable resource: " + iconName, e);
            return 0;
        }
    }
    
    private int getStringResourceByName(String stringName) {
        try {
            return context.getResources().getIdentifier(stringName, "string", context.getPackageName());
        } catch (Exception e) {
            Log.w("VenueFilterHandler", "Could not find string resource: " + stringName, e);
            return 0;
        }
    }
}