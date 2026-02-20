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
        List<String> venuesInUse = staticVariables.getVenueNamesInUseForList();
        Log.d("VenueFilterHandler", "Setting up dynamic venue listeners for venues in use: " + venuesInUse);
        
        // Clear any existing venue sections
        if (dynamicVenueContainer != null) {
            dynamicVenueContainer.removeAllViews();
            venueLayouts.clear();
            venueTextViews.clear();
            venueImageViews.clear();
        }
        
        for (String venueName : venuesInUse) {
            createVenueFilterSection(venueName, showBands);
        }
        
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
        List<String> venuesInUse = staticVariables.getVenueNamesInUseForList();
        Log.d("VenueFilterHandler", "Setting up venue filter UI for venues in use: " + venuesInUse);
        
        if (venueTextViews.isEmpty() && dynamicVenueContainer != null) {
            rebuildVenueReferences();
        }
        
        for (String venueName : venuesInUse) {
            updateVenueFilterUI(venueName);
        }
    }
    
    /**
     * Rebuilds the venue UI element references by scanning the container
     */
    private void rebuildVenueReferences() {
        if (dynamicVenueContainer == null) return;
        
        venueLayouts.clear();
        venueTextViews.clear();
        venueImageViews.clear();
        
        List<String> allVenueNames = new ArrayList<>(staticVariables.getVenueNamesInUseForList());
        
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
    
    /** Show/Hide Venue section: label is "Hide X" / "Show X" with no " Events" suffix. Uses localized format. */
    private String getHideVenueText(String venueName) {
        String displayName = staticVariables.venueDisplayName(venueName);
        return context.getResources().getString(R.string.hide_venue_format, displayName);
    }

    private String getShowVenueText(String venueName) {
        String displayName = staticVariables.venueDisplayName(venueName);
        return context.getResources().getString(R.string.show_venue_format, displayName);
    }
    
    /** Generic venue icons in portrait filter (same assets as iOS: Location-Generic-Going-wBox / NotGoing-wBox). */
    private static final int VENUE_FILTER_GENERIC_ICON = R.drawable.icon_location_generic;
    private static final int VENUE_FILTER_GENERIC_ICON_ALT = R.drawable.icon_location_generic_alt;

    private Drawable getVenueDrawable(String venueName, boolean isEnabled) {
        // Try to get icon from FestivalConfig first (uses exact/prefix match so Boleros Lounge ≠ Lounge)
        String iconName = isEnabled ?
            festivalConfig.getVenueGoingIcon(venueName) :
            festivalConfig.getVenueNotGoingIcon(venueName);
        // Generic unknown-venue: use same generic location icons as iOS (Going = colorful, NotGoing = muted)
        if (isGenericVenueIconName(iconName)) {
            return AppCompatResources.getDrawable(context,
                isEnabled ? VENUE_FILTER_GENERIC_ICON : VENUE_FILTER_GENERIC_ICON_ALT);
        }
        // Try to get resource by name from FestivalConfig
        int resourceId = getDrawableResourceByName(iconName);
        if (resourceId != 0) {
            return AppCompatResources.getDrawable(context, resourceId);
        }
        // Fall back to hardcoded icons (unknown venues get generic icon)
        return getHardcodedVenueDrawable(venueName, isEnabled);
    }

    private boolean isGenericVenueIconName(String iconName) {
        if (iconName == null) return true;
        String lower = iconName.toLowerCase();
        return "unknown-going-wbox".equals(lower) || "unknown-notgoing-wbox".equals(lower)
            || "icon_unknown".equals(lower) || "icon_unknown_alt".equals(lower);
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
                    isEnabled ? VENUE_FILTER_GENERIC_ICON : VENUE_FILTER_GENERIC_ICON_ALT);
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