package com.Bands70k;

import android.content.Context;
import android.graphics.Color;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;
import androidx.appcompat.content.res.AppCompatResources;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Common filter menu builder for both portrait and calendar views.
 * Creates a consistent filter menu UI that can be customized for different view types.
 */
public class CommonFilterMenuBuilder {
    
    private static final String TAG = "CommonFilterMenuBuilder";
    
    public enum MenuType {
        PORTRAIT,  // Portrait view: includes Show Expired Events and Sort By Time
        CALENDAR   // Calendar view: no Show Expired Events, no Sort By Time
    }
    
    /**
     * Interface for handling filter menu callbacks
     */
    public interface FilterMenuCallbacks {
        void onFilterChanged();
        void onClearAllFilters();
        void onDismiss();
    }
    
    /**
     * Builds a filter menu dialog for the specified menu type.
     * 
     * @param context The context
     * @param menuType PORTRAIT or CALENDAR
     * @param callbacks Callbacks for filter actions
     * @return A Dialog containing the filter menu
     */
    public static android.app.Dialog buildFilterMenu(Context context, MenuType menuType, FilterMenuCallbacks callbacks) {
        int screenWidth = context.getResources().getDisplayMetrics().widthPixels;
        int screenHeight = context.getResources().getDisplayMetrics().heightPixels;
        
        android.app.Dialog dialog = new android.app.Dialog(context, android.R.style.Theme_DeviceDefault_Dialog);
        dialog.setCancelable(true);
        dialog.setCanceledOnTouchOutside(true);
        dialog.requestWindowFeature(android.view.Window.FEATURE_NO_TITLE);
        
        LinearLayout root = new LinearLayout(context);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#FF1C1C1E"));
        root.setPadding(0, 0, dpToPx(context, 24), 0);
        
        // Track switches for disabling when Show Flagged Events Only is enabled
        final List<Switch> allFilterSwitches = new ArrayList<>();
        final Switch[] flaggedSwitchRef = new Switch[1];
        final Switch[] expiredSwitchRef = new Switch[1]; // Excluded from Clear All (preference, not filter)
        final TextView[] clearAllButtonRef = new TextView[1];
        
        // Get venue names for location filters
        final List<String> allVenueNames = staticVariables.getVenueNamesInUseForList();
        
        // Check if Show Flagged Events Only is enabled
        boolean isFlaggedFilterEnabled = staticVariables.preferences.getShowWillAttend();
        
        // Create a wrapper callback that updates clearAll button state
        FilterMenuCallbacks wrapperCallbacks = new FilterMenuCallbacks() {
            @Override
            public void onFilterChanged() {
                if (clearAllButtonRef[0] != null) {
                    updateClearAllButtonState(clearAllButtonRef[0], allVenueNames, allFilterSwitches, flaggedSwitchRef[0], expiredSwitchRef[0]);
                }
                callbacks.onFilterChanged();
            }
            
            @Override
            public void onClearAllFilters() {
                callbacks.onClearAllFilters();
            }
            
            @Override
            public void onDismiss() {
                callbacks.onDismiss();
            }
        };
        
        // Toolbar: [Clear All Filters] [Filters] [Done]
        int toolbarHeight = dpToPx(context, 56);
        int horizontalPadding = dpToPx(context, 16);
        LinearLayout toolbarRow = createToolbar(context, horizontalPadding, toolbarHeight, wrapperCallbacks, clearAllButtonRef);
        root.addView(toolbarRow);
        
        // ScrollView for filter sections
        ScrollView scroll = new ScrollView(context);
        scroll.setPadding(horizontalPadding, 0, horizontalPadding, 0);
        LinearLayout filterList = new LinearLayout(context);
        filterList.setOrientation(LinearLayout.VERTICAL);
        filterList.setBackgroundColor(Color.parseColor("#FF2C2C2E"));
        filterList.setPadding(0, dpToPx(context, 4), 0, dpToPx(context, 4));
        
        // Build menu sections based on menu type
        // When Hide Expired Events is ON and no unexpired events: hide event-related sections (Locations, Event Type, Sort By, Show Flagged)
        // Event sections container is refreshed when Hide Expired toggle changes
        final View[] eventSectionsContainerRef = new View[1];
        boolean showEventSections = shouldShowEventRelatedSections(context);
        if (menuType == MenuType.PORTRAIT) {
            // Portrait order: Clear Filters -> Show Expired Events -> Band Ranking -> Show Flagged Events Only -> Sort By Time -> Event Types -> Locations
            buildShowExpiredEventsSection(context, filterList, allFilterSwitches, expiredSwitchRef, isFlaggedFilterEnabled, wrapperCallbacks, eventSectionsContainerRef);
            buildBandRankingSection(context, filterList, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
            LinearLayout eventSectionsContainer = new LinearLayout(context);
            eventSectionsContainer.setOrientation(LinearLayout.VERTICAL);
            eventSectionsContainer.setVisibility(showEventSections ? View.VISIBLE : View.GONE);
            buildShowFlaggedEventsSection(context, eventSectionsContainer, flaggedSwitchRef, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
            buildSortByTimeSection(context, eventSectionsContainer, wrapperCallbacks);
            buildEventTypeSection(context, eventSectionsContainer, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
            buildLocationSection(context, eventSectionsContainer, allVenueNames, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
            filterList.addView(eventSectionsContainer);
            eventSectionsContainerRef[0] = eventSectionsContainer;
        } else {
            // Calendar order (consistent with List): Band Rankings -> Flagged Only -> Event Type -> Locations (no Hide Expired, no Sort By)
            buildBandRankingSection(context, filterList, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
            if (showEventSections) {
                buildShowFlaggedEventsSection(context, filterList, flaggedSwitchRef, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
                buildEventTypeSection(context, filterList, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
                buildLocationSection(context, filterList, allVenueNames, allFilterSwitches, isFlaggedFilterEnabled, wrapperCallbacks);
            }
        }
        
        scroll.addView(filterList, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        scroll.setVerticalScrollBarEnabled(true);
        scroll.setFillViewport(false);
        LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        root.addView(scroll, scrollParams);
        
        // Set initial state of Clear All button
        if (clearAllButtonRef[0] != null) {
            updateClearAllButtonState(clearAllButtonRef[0], allVenueNames, allFilterSwitches, flaggedSwitchRef[0], expiredSwitchRef[0]);
        }
        
        dialog.setContentView(root);
        if (dialog.getWindow() != null) {
            android.view.WindowManager.LayoutParams wlp = dialog.getWindow().getAttributes();
            wlp.width = (int) (screenWidth * 0.92);
            wlp.height = (int) (screenHeight * 0.88);
            dialog.getWindow().setAttributes(wlp);
        }
        
        return dialog;
    }
    
    private static LinearLayout createToolbar(Context context, int horizontalPadding, int toolbarHeight, FilterMenuCallbacks callbacks, TextView[] clearAllButtonRef) {
        LinearLayout toolbarRow = new LinearLayout(context);
        toolbarRow.setOrientation(LinearLayout.HORIZONTAL);
        toolbarRow.setGravity(Gravity.CENTER_VERTICAL);
        toolbarRow.setLayoutParams(new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toolbarHeight));
        toolbarRow.setPadding(horizontalPadding, 0, horizontalPadding, 0);
        toolbarRow.setBackgroundColor(Color.parseColor("#FF1C1C1E"));
        
        final TextView clearAll = new TextView(context);
        clearAll.setText(context.getString(R.string.clear_all_filters));
        clearAll.setTextSize(17);
        clearAll.setTextColor(Color.WHITE);
        clearAll.setPadding(0, dpToPx(context, 8), 0, dpToPx(context, 8));
        clearAll.setClickable(true);
        clearAll.setFocusable(true);
        clearAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (clearAll.getAlpha() < 0.5f) return; // disabled
                callbacks.onClearAllFilters();
            }
        });
        clearAllButtonRef[0] = clearAll;
        toolbarRow.addView(clearAll, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        
        // Spacer to push Done button to the right (no "Filters" title in menu)
        View spacer = new View(context);
        toolbarRow.addView(spacer, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        
        TextView done = new TextView(context);
        done.setText(context.getString(R.string.venue_filter_done));
        done.setTextSize(17);
        done.setTypeface(null, android.graphics.Typeface.BOLD);
        done.setTextColor(Color.WHITE);
        done.setPadding(dpToPx(context, 8), dpToPx(context, 8), 0, dpToPx(context, 8));
        done.setClickable(true);
        done.setFocusable(true);
        done.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                callbacks.onDismiss();
            }
        });
        toolbarRow.addView(done, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        
        return toolbarRow;
    }
    
    private static void buildShowExpiredEventsSection(Context context, LinearLayout parent, List<Switch> allSwitches,
                                                     Switch[] expiredSwitchRef, boolean isFlaggedEnabled, FilterMenuCallbacks callbacks,
                                                     View[] eventSectionsContainerRef) {
        // Check if we have expired events
        if (!hasExpiredEvents(context)) {
            return;
        }
        
        int horizontalPadding = dpToPx(context, 16);
        
        TextView header = new TextView(context);
        header.setText(context.getString(R.string.expired_events));
        header.setTextSize(13);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setTextColor(Color.parseColor("#FF8E8E93"));
        header.setPadding(horizontalPadding, dpToPx(context, 16), horizontalPadding, dpToPx(context, 8));
        parent.addView(header);
        
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dpToPx(context, 16), dpToPx(context, 12), dpToPx(context, 16), dpToPx(context, 12));
        row.setBackgroundColor(Color.TRANSPARENT);
        
        ImageView icon = new ImageView(context);
        icon.setImageDrawable(AppCompatResources.getDrawable(context, R.drawable.icon_sort_time));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dpToPx(context, 24), dpToPx(context, 24));
        iconParams.setMargins(0, 0, dpToPx(context, 12), 0);
        icon.setLayoutParams(iconParams);
        
        TextView text = new TextView(context);
        boolean hideExpired = staticVariables.preferences.getHideExpiredEvents();
        text.setText(context.getString(R.string.hide_expired_events)); // Always same text; checkbox indicates status
        text.setTextSize(17);
        text.setTextColor(Color.WHITE);
        text.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        
        Switch sw = new Switch(context);
        sw.setChecked(hideExpired); // Switch ON = Hide Expired Events ON = expired events are hidden
        sw.setEnabled(!isFlaggedEnabled);
        allSwitches.add(sw);
        if (expiredSwitchRef != null) {
            expiredSwitchRef[0] = sw;
        }
        sw.setOnCheckedChangeListener(new android.widget.CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(android.widget.CompoundButton buttonView, boolean isChecked) {
                staticVariables.preferences.setHideExpiredEvents(isChecked);
                staticVariables.preferences.saveData();
                // Refresh menu to show/hide event-related sections
                if (eventSectionsContainerRef != null && eventSectionsContainerRef[0] != null) {
                    eventSectionsContainerRef[0].setVisibility(shouldShowEventRelatedSections(context) ? View.VISIBLE : View.GONE);
                }
                callbacks.onFilterChanged();
            }
        });
        
        row.addView(icon);
        row.addView(text);
        row.addView(sw);
        parent.addView(row);
    }
    
    private static void buildShowFlaggedEventsSection(Context context, LinearLayout parent, Switch[] flaggedSwitchRef,
                                                     List<Switch> allSwitches, boolean isFlaggedEnabled, FilterMenuCallbacks callbacks) {
        if (!hasFlaggedEvents(context)) {
            return;
        }
        
        int horizontalPadding = dpToPx(context, 16);
        
        TextView header = new TextView(context);
        header.setText(context.getString(R.string.show_only_flagged_as_attended));
        header.setTextSize(13);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setTextColor(Color.parseColor("#FF8E8E93"));
        header.setPadding(horizontalPadding, dpToPx(context, 16), horizontalPadding, dpToPx(context, 8));
        parent.addView(header);
        
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dpToPx(context, 16), dpToPx(context, 12), dpToPx(context, 16), dpToPx(context, 12));
        row.setBackgroundColor(Color.TRANSPARENT);
        
        ImageView icon = new ImageView(context);
        icon.setImageDrawable(AppCompatResources.getDrawable(context, 
            isFlaggedEnabled ? R.drawable.icon_seen : R.drawable.icon_seen_alt));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dpToPx(context, 24), dpToPx(context, 24));
        iconParams.setMargins(0, 0, dpToPx(context, 12), 0);
        icon.setLayoutParams(iconParams);
        
        TextView text = new TextView(context);
        text.setText(isFlaggedEnabled ? context.getString(R.string.show_all_events) : context.getString(R.string.show_flaged_events_only));
        text.setTextSize(17);
        text.setTextColor(Color.WHITE);
        text.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        
        Switch sw = new Switch(context);
        sw.setChecked(isFlaggedEnabled);
        flaggedSwitchRef[0] = sw;
        sw.setOnCheckedChangeListener(new android.widget.CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(android.widget.CompoundButton buttonView, boolean isChecked) {
                staticVariables.preferences.setShowWillAttend(isChecked);
                staticVariables.preferences.saveData();
                icon.setImageDrawable(AppCompatResources.getDrawable(context, 
                    isChecked ? R.drawable.icon_seen : R.drawable.icon_seen_alt));
                text.setText(isChecked ? context.getString(R.string.show_all_events) : context.getString(R.string.show_flaged_events_only));
                // Enable/disable other filters
                boolean shouldDisable = isChecked;
                for (Switch s : allSwitches) {
                    s.setEnabled(!shouldDisable);
                }
                callbacks.onFilterChanged();
            }
        });
        
        row.addView(icon);
        row.addView(text);
        row.addView(sw);
        parent.addView(row);
    }
    
    private static void buildSortByTimeSection(Context context, LinearLayout parent, FilterMenuCallbacks callbacks) {
        int horizontalPadding = dpToPx(context, 16);
        
        TextView header = new TextView(context);
        header.setText(context.getString(R.string.sort_by_name));
        header.setTextSize(13);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setTextColor(Color.parseColor("#FF8E8E93"));
        header.setPadding(horizontalPadding, dpToPx(context, 16), horizontalPadding, dpToPx(context, 8));
        parent.addView(header);
        
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dpToPx(context, 16), dpToPx(context, 12), dpToPx(context, 16), dpToPx(context, 12));
        row.setBackgroundColor(Color.TRANSPARENT);
        
        ImageView icon = new ImageView(context);
        boolean sortByTime = staticVariables.preferences.getSortByTime();
        icon.setImageDrawable(AppCompatResources.getDrawable(context, 
            sortByTime ? R.drawable.icon_sort_time : R.drawable.icon_sort_az));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dpToPx(context, 24), dpToPx(context, 24));
        iconParams.setMargins(0, 0, dpToPx(context, 12), 0);
        icon.setLayoutParams(iconParams);
        
        TextView text = new TextView(context);
        text.setText(sortByTime ? context.getString(R.string.sort_by_name) : context.getString(R.string.sort_by_time));
        text.setTextSize(17);
        text.setTextColor(Color.WHITE);
        text.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        
        row.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                boolean newValue = !staticVariables.preferences.getSortByTime();
                staticVariables.preferences.setSortByTime(newValue);
                staticVariables.preferences.saveData();
                icon.setImageDrawable(AppCompatResources.getDrawable(context, 
                    newValue ? R.drawable.icon_sort_time : R.drawable.icon_sort_az));
                text.setText(newValue ? context.getString(R.string.sort_by_name) : context.getString(R.string.sort_by_time));
                callbacks.onFilterChanged();
            }
        });
        
        row.addView(icon);
        row.addView(text);
        parent.addView(row);
    }
    
    private static void buildBandRankingSection(Context context, LinearLayout parent, List<Switch> allSwitches,
                                                boolean isFlaggedEnabled, FilterMenuCallbacks callbacks) {
        if (!hasRankedBands(context)) {
            return;
        }
        
        int horizontalPadding = dpToPx(context, 16);
        
        TextView header = new TextView(context);
        header.setText(context.getString(R.string.band_ranking_filters));
        header.setTextSize(13);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setTextColor(Color.parseColor("#FF8E8E93"));
        header.setPadding(horizontalPadding, dpToPx(context, 16), horizontalPadding, dpToPx(context, 8));
        parent.addView(header);
        
        // Must See
        createFilterRow(context, parent, 
            R.drawable.icon_going_yes, R.drawable.icon_going_yes_alt,
            R.string.hide_must_see_items, R.string.show_must_see_items,
            staticVariables.preferences.getShowMust(),
            new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    boolean newValue = !staticVariables.preferences.getShowMust();
                    staticVariables.preferences.setshowMust(newValue);
                    staticVariables.preferences.saveData();
                    callbacks.onFilterChanged();
                }
            },
            allSwitches, isFlaggedEnabled);
        
        // Might See
        createFilterRow(context, parent,
            R.drawable.icon_going_maybe, R.drawable.icon_going_maybe_alt,
            R.string.hide_might_see_items, R.string.show_might_see_items,
            staticVariables.preferences.getShowMight(),
            new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    boolean newValue = !staticVariables.preferences.getShowMight();
                    staticVariables.preferences.setshowMight(newValue);
                    staticVariables.preferences.saveData();
                    callbacks.onFilterChanged();
                }
            },
            allSwitches, isFlaggedEnabled);
        
        // Wont See
        createFilterRow(context, parent,
            R.drawable.icon_going_no, R.drawable.icon_going_no_alt,
            R.string.hide_wont_see_items, R.string.show_wont_see_items,
            staticVariables.preferences.getShowWont(),
            new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    boolean newValue = !staticVariables.preferences.getShowWont();
                    staticVariables.preferences.setshowWont(newValue);
                    staticVariables.preferences.saveData();
                    callbacks.onFilterChanged();
                }
            },
            allSwitches, isFlaggedEnabled);
        
        // Unknown
        createFilterRow(context, parent,
            R.drawable.icon_unknown, R.drawable.icon_unknown_alt,
            R.string.hide_unknown_items, R.string.show_unknown_items,
            staticVariables.preferences.getShowUnknown(),
            new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    boolean newValue = !staticVariables.preferences.getShowUnknown();
                    staticVariables.preferences.setshowUnknown(newValue);
                    staticVariables.preferences.saveData();
                    callbacks.onFilterChanged();
                }
            },
            allSwitches, isFlaggedEnabled);
    }
    
    private static void buildEventTypeSection(Context context, LinearLayout parent, List<Switch> allSwitches,
                                             boolean isFlaggedEnabled, FilterMenuCallbacks callbacks) {
        if (!hasFilterableEventTypes(context)) {
            return;
        }
        
        int horizontalPadding = dpToPx(context, 16);
        
        TextView header = new TextView(context);
        header.setText(context.getString(R.string.event_type_filters));
        header.setTextSize(13);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setTextColor(Color.parseColor("#FF8E8E93"));
        header.setPadding(horizontalPadding, dpToPx(context, 16), horizontalPadding, dpToPx(context, 8));
        parent.addView(header);
        
        // Meet and Greet
        if (staticVariables.preferences.getMeetAndGreetsEnabled()) {
            createFilterRow(context, parent,
                R.drawable.icon_meet_and_greet, R.drawable.icon_meet_and_greet_alt,
                R.string.hide_meet_and_greet_events, R.string.show_meet_and_greet_events,
                staticVariables.preferences.getShowMeetAndGreet(),
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        boolean newValue = !staticVariables.preferences.getShowMeetAndGreet();
                        staticVariables.preferences.setShowMeetAndGreet(newValue);
                        staticVariables.preferences.saveData();
                        callbacks.onFilterChanged();
                    }
                },
                allSwitches, isFlaggedEnabled);
        }
        
        // Special Events
        if (staticVariables.preferences.getSpecialEventsEnabled()) {
            createFilterRow(context, parent,
                R.drawable.icon_all_star_jam, R.drawable.icon_all_star_jam_alt,
                R.string.hide_special_other_events, R.string.show_special_other_events,
                staticVariables.preferences.getShowSpecialEvents(),
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        boolean newValue = !staticVariables.preferences.getShowSpecialEvents();
                        staticVariables.preferences.setShowSpecialEvents(newValue);
                        staticVariables.preferences.saveData();
                        callbacks.onFilterChanged();
                    }
                },
                allSwitches, isFlaggedEnabled);
        }
        
        // Unofficial Events
        if (staticVariables.preferences.getUnofficalEventsEnabled()) {
            createFilterRow(context, parent,
                R.drawable.icon_unoffical_event, R.drawable.icon_unoffical_event_alt,
                R.string.hide_unofficial_events, R.string.show_unofficial_events,
                staticVariables.preferences.getShowUnofficalEvents(),
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        boolean newValue = !staticVariables.preferences.getShowUnofficalEvents();
                        staticVariables.preferences.setShowUnofficalEvents(newValue);
                        staticVariables.preferences.saveData();
                        callbacks.onFilterChanged();
                    }
                },
                allSwitches, isFlaggedEnabled);
        }
    }
    
    private static void buildLocationSection(Context context, LinearLayout parent, List<String> venueNames,
                                           List<Switch> allSwitches, boolean isFlaggedEnabled, FilterMenuCallbacks callbacks) {
        int horizontalPadding = dpToPx(context, 16);
        
        TextView header = new TextView(context);
        header.setText(context.getString(R.string.venue_filters));
        header.setTextSize(13);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setTextColor(Color.parseColor("#FF8E8E93"));
        header.setPadding(horizontalPadding, dpToPx(context, 16), horizontalPadding, dpToPx(context, 8));
        parent.addView(header);
        
        for (final String venueName : venueNames) {
            boolean isVenueEnabled = staticVariables.preferences.getShowVenueEvents(venueName);
            LinearLayout row = new LinearLayout(context);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(dpToPx(context, 16), dpToPx(context, 12), dpToPx(context, 16), dpToPx(context, 12));
            row.setBackgroundColor(Color.TRANSPARENT);
            
            ImageView venueIcon = new ImageView(context);
            venueIcon.setImageDrawable(getVenueIconDrawable(context, venueName, isVenueEnabled));
            LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dpToPx(context, 24), dpToPx(context, 24));
            iconParams.setMargins(0, 0, dpToPx(context, 12), 0);
            venueIcon.setLayoutParams(iconParams);
            
            TextView nameText = new TextView(context);
            nameText.setText(venueName != null ? staticVariables.venueDisplayName(venueName) : "");
            nameText.setTextSize(17);
            nameText.setTextColor(Color.WHITE);
            nameText.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
            
            Switch sw = new Switch(context);
            sw.setChecked(isVenueEnabled);
            sw.setEnabled(!isFlaggedEnabled);
            allSwitches.add(sw);
            sw.setOnCheckedChangeListener(new android.widget.CompoundButton.OnCheckedChangeListener() {
                @Override
                public void onCheckedChanged(android.widget.CompoundButton buttonView, boolean isChecked) {
                    if (!isChecked && FilterButtonHandler.blockTurningAllFiltersOn()) {
                        sw.setChecked(true);
                        android.widget.Toast.makeText(context, context.getString(R.string.can_not_hide_all_venues), android.widget.Toast.LENGTH_SHORT).show();
                        return;
                    }
                    staticVariables.preferences.setShowVenueEvents(venueName, isChecked);
                    staticVariables.preferences.saveData();
                    venueIcon.setImageDrawable(getVenueIconDrawable(context, venueName, isChecked));
                    callbacks.onFilterChanged();
                }
            });
            
            row.addView(venueIcon);
            row.addView(nameText);
            row.addView(sw);
            parent.addView(row);
        }
    }
    
    private static LinearLayout createFilterRow(Context context, LinearLayout parent,
                                               int iconResId, int iconAltResId,
                                               int textOnResId, int textOffResId,
                                               boolean isChecked,
                                               View.OnClickListener clickListener,
                                               List<Switch> allSwitches,
                                               boolean disabled) {
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dpToPx(context, 16), dpToPx(context, 12), dpToPx(context, 16), dpToPx(context, 12));
        row.setBackgroundColor(Color.TRANSPARENT);
        
        ImageView icon = new ImageView(context);
        icon.setImageDrawable(AppCompatResources.getDrawable(context, isChecked ? iconResId : iconAltResId));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dpToPx(context, 24), dpToPx(context, 24));
        iconParams.setMargins(0, 0, dpToPx(context, 12), 0);
        icon.setLayoutParams(iconParams);
        
        TextView text = new TextView(context);
        text.setText(context.getString(textOffResId));
        text.setTextSize(17);
        text.setTextColor(Color.WHITE);
        text.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        
        Switch sw = new Switch(context);
        sw.setChecked(isChecked);
        sw.setEnabled(!disabled);
        allSwitches.add(sw);
        sw.setOnCheckedChangeListener(new android.widget.CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(android.widget.CompoundButton buttonView, boolean checked) {
                icon.setImageDrawable(AppCompatResources.getDrawable(context, checked ? iconResId : iconAltResId));
                text.setText(context.getString(textOffResId));
                clickListener.onClick(row);
            }
        });
        
        row.addView(icon);
        row.addView(text);
        row.addView(sw);
        parent.addView(row);
        return row;
    }
    
    private static android.graphics.drawable.Drawable getVenueIconDrawable(Context context, String venueName, boolean isEnabled) {
        FestivalConfig config = FestivalConfig.getInstance();
        String iconName = isEnabled ?
            config.getVenueGoingIcon(venueName) :
            config.getVenueNotGoingIcon(venueName);
        
        if (iconName == null || iconName.toLowerCase().contains("unknown")) {
            return AppCompatResources.getDrawable(context,
                isEnabled ? R.drawable.icon_location_generic : R.drawable.icon_location_generic_alt);
        }
        
        int resourceId = context.getResources().getIdentifier(iconName, "drawable", context.getPackageName());
        if (resourceId != 0) {
            return AppCompatResources.getDrawable(context, resourceId);
        }
        
        // Fall back to hardcoded venue icons
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
                    isEnabled ? R.drawable.icon_location_generic : R.drawable.icon_location_generic_alt);
        }
    }
    
    private static void updateClearAllButtonState(TextView clearAllButton, List<String> venueNames,
                                                 List<Switch> allSwitches, Switch flaggedSwitch, Switch expiredSwitch) {
        boolean anyHidden = false;
        
        if (flaggedSwitch != null && flaggedSwitch.isChecked()) {
            anyHidden = true;
        }
        
        for (Switch sw : allSwitches) {
            if (sw == expiredSwitch) continue; // Hide Expired Events is a preference, not a filter
            if (!sw.isChecked()) {
                anyHidden = true;
                break;
            }
        }
        
        clearAllButton.setClickable(anyHidden);
        clearAllButton.setAlpha(anyHidden ? 1f : 0.4f);
    }
    
    // Helper methods to check if sections should be shown
    private static boolean hasExpiredEvents(Context context) {
        if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
            return false;
        }
        long currentTime = System.currentTimeMillis();
        for (String bandName : BandInfo.scheduleRecords.keySet()) {
            scheduleTimeTracker tracker = BandInfo.scheduleRecords.get(bandName);
            if (tracker != null && tracker.scheduleByTime != null) {
                for (Long timeIndex : tracker.scheduleByTime.keySet()) {
                    scheduleHandler event = tracker.scheduleByTime.get(timeIndex);
                    if (event != null && event.getEpochEnd() != null) {
                        if (event.getEpochEnd() < currentTime) {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }
    
    /**
     * When Hide Expired Events is ON, event-related filters (Locations, Event Type, Sort By, Show Flagged)
     * are only relevant if there are unexpired events to display.
     */
    private static boolean shouldShowEventRelatedSections(Context context) {
        if (!staticVariables.preferences.getHideExpiredEvents()) {
            return true; // Showing all events; filters are always relevant
        }
        return hasUnexpiredEvents(context);
    }
    
    private static boolean hasUnexpiredEvents(Context context) {
        if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
            return false;
        }
        long currentTime = System.currentTimeMillis();
        for (String bandName : BandInfo.scheduleRecords.keySet()) {
            scheduleTimeTracker tracker = BandInfo.scheduleRecords.get(bandName);
            if (tracker != null && tracker.scheduleByTime != null) {
                for (Long timeIndex : tracker.scheduleByTime.keySet()) {
                    scheduleHandler event = tracker.scheduleByTime.get(timeIndex);
                    if (event != null && event.getEpochEnd() != null && event.getEpochEnd() >= currentTime) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    private static boolean hasFlaggedEvents(Context context) {
        return staticVariables.showsIwillAttend > 0;
    }
    
    private static boolean hasRankedBands(Context context) {
        if (BandInfo.scheduleRecords == null) return false;
        for (String bandName : BandInfo.scheduleRecords.keySet()) {
            String rankIcon = rankStore.getRankForBand(bandName);
            if (rankIcon != null && !rankIcon.isEmpty() &&
                (rankIcon.equals(staticVariables.mustSeeIcon) ||
                 rankIcon.equals(staticVariables.mightSeeIcon) ||
                 rankIcon.equals(staticVariables.wontSeeIcon) ||
                 rankIcon.equals(staticVariables.unknownIcon))) {
                return true;
            }
        }
        return false;
    }
    
    private static boolean hasFilterableEventTypes(Context context) {
        if (BandInfo.scheduleRecords == null) return false;
        for (scheduleTimeTracker tracker : BandInfo.scheduleRecords.values()) {
            if (tracker == null || tracker.scheduleByTime == null) continue;
            for (scheduleHandler scheduleHandle : tracker.scheduleByTime.values()) {
                if (scheduleHandle == null) continue;
                String eventType = scheduleHandle.getShowType();
                if (eventType != null &&
                    (eventType.equals("Meet and Greet") ||
                     eventType.equals("Special Event") ||
                     eventType.equals(staticVariables.unofficalEvent) ||
                     eventType.equals(staticVariables.unofficalEventOld))) {
                    return true;
                }
            }
        }
        return false;
    }
    
    private static int dpToPx(Context context, int dp) {
        return (int) (dp * context.getResources().getDisplayMetrics().density);
    }
}
