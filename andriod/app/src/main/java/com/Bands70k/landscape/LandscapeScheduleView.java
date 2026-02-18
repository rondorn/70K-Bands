package com.Bands70k.landscape;

import android.content.Context;
import android.graphics.Color;
import android.text.format.DateFormat;
import android.util.AttributeSet;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.RelativeLayout;
import android.widget.ScrollView;
import android.widget.ImageView;
import android.widget.TextView;
import com.Bands70k.BandInfo;
import com.Bands70k.FestivalConfig;
import com.Bands70k.R;
import com.Bands70k.iconResolve;
import com.Bands70k.showsAttended;
import com.Bands70k.staticVariables;
import com.Bands70k.scheduleHandler;
import com.Bands70k.scheduleTimeTracker;
import com.Bands70k.scheduleInfo;
import com.Bands70k.rankStore;
import com.Bands70k.LongPressMenuHelper;
import com.Bands70k.Utilities;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Date;
import java.util.Locale;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * SIMPLIFIED landscape schedule view - basic views with simple click listeners
 */
public class LandscapeScheduleView extends LinearLayout {
    
    private static final String TAG = "LandscapeScheduleView";
    
    private Context context;
    private String initialDay;
    private boolean hideExpiredEvents;
    private boolean isSplitViewCapable; // True for tablets/master-detail view mode
    
    // Simple data storage
    private List<DayScheduleData> days = new ArrayList<>();
    private int currentDayIndex = 0;
    private OnBandTappedListener bandTappedListener;
    private OnDismissRequestedListener dismissRequestedListener;
    private showsAttended attendedHandle;
    private boolean shouldFinishActivity = false; // Flag to prevent display updates if we're finishing
    
    // Map to store combined events: combined band name -> list of individual band names
    private Map<String, List<String>> combinedEventsMap = new HashMap<>();

    /** Internal delimiter for combined (two-band) events. ASCII Record Separator - never in user-visible event names. */
    private static final String COMBINED_EVENT_DELIMITER = "\u001E";

    private static boolean isCombinedEventName(String bandName) {
        return bandName != null && bandName.contains(COMBINED_EVENT_DELIMITER);
    }

    /** Returns the two band names for a combined event, or null if not a combined event. */
    private static String[] getCombinedEventBandParts(String bandName) {
        if (bandName == null || !bandName.contains(COMBINED_EVENT_DELIMITER)) return null;
        String[] parts = bandName.split(Pattern.quote(COMBINED_EVENT_DELIMITER), -1);
        return (parts.length >= 2) ? parts : null;
    }
    
    // Simple UI components
    private ViewGroup headerLayout;
    private Button prevButton;
    private Button nextButton;
    private TextView dayLabel;
    private Button listViewButton; // Button to return to list view (tablets only)
    private ScrollView contentScrollView;
    private LinearLayout contentLayout;
    
    public interface OnBandTappedListener {
        void onBandTapped(String bandName, String currentDay);
    }
    
    public interface OnDismissRequestedListener {
        void onDismissRequested();
    }
    
    public LandscapeScheduleView(Context context) {
        super(context);
        this.context = context;
        this.isSplitViewCapable = false; // Default to phone mode
        init();
    }
    
    public LandscapeScheduleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.context = context;
        this.isSplitViewCapable = false; // Default to phone mode
        init();
    }
    
    public LandscapeScheduleView(Context context, String initialDay, boolean hideExpiredEvents, boolean isSplitViewCapable) {
        super(context);
        this.context = context;
        this.initialDay = initialDay;
        this.hideExpiredEvents = hideExpiredEvents;
        this.isSplitViewCapable = isSplitViewCapable;
        init();
    }
    
    private void init() {
        Log.d(TAG, "=== SIMPLIFIED init() START ===");
        
        setOrientation(LinearLayout.VERTICAL);
        setBackgroundColor(Color.BLACK);
        // Don't set gravity - let children layout naturally from top
        
        attendedHandle = staticVariables.attendedHandler != null ? 
                         staticVariables.attendedHandler : new showsAttended();
        
        // Create header with prev/next buttons
        createHeader();
        
        // Create content area
        createContentArea();
        
        // Load data
        loadScheduleData();
        
        Log.d(TAG, "=== SIMPLIFIED init() END ===");
    }
    
    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        // CRITICAL FIX: Recalculate layout when view size changes (handles rotation on foldable devices)
        // On Pixel Fold front display, rotation may not trigger onConfigurationChanged immediately
        if ((w != oldw || h != oldh) && oldw > 0 && oldh > 0) {
            Log.d(TAG, "View size changed: " + oldw + "x" + oldh + " -> " + w + "x" + h);
            // Only recalculate if we have data loaded and view is properly sized
            // Check if contentLayout exists and has children (content already displayed)
            if (w > 0 && h > 0 && contentLayout != null && contentLayout.getChildCount() > 0) {
                // Post to ensure layout is complete before recalculating
                post(new Runnable() {
                    @Override
                    public void run() {
                        // Double-check we still have content before updating
                        if (!days.isEmpty() && currentDayIndex >= 0 && currentDayIndex < days.size()) {
                            Log.d(TAG, "Recalculating layout after size change");
                            updateContent();
                        }
                    }
                });
            }
        }
    }
    
    private void createHeader() {
        // FrameLayout: nav stays centered; list icon positioned in top-right by gravity (no weights)
        headerLayout = new FrameLayout(context);
        headerLayout.setPadding(dpToPx(16), dpToPx(48), dpToPx(16), dpToPx(16));
        headerLayout.setBackgroundColor(Color.BLACK);
        headerLayout.setClickable(false);
        headerLayout.setFocusable(false);
        
        // Centered nav bar: horizontal row of prev, label, next
        LinearLayout navContainer = new LinearLayout(context);
        navContainer.setOrientation(LinearLayout.HORIZONTAL);
        navContainer.setGravity(Gravity.CENTER);
        navContainer.setLayoutParams(new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER));
        navContainer.setClickable(false);
        navContainer.setFocusable(false);
        
        LinearLayout navGroup = new LinearLayout(context);
        navGroup.setOrientation(LinearLayout.HORIZONTAL);
        navGroup.setGravity(Gravity.CENTER_VERTICAL);
        navGroup.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
        ));
        navGroup.setClickable(false);
        navGroup.setFocusable(false);
        
        // Prev button - Clean style: just icon with very subtle background for touch feedback
        prevButton = new Button(context);
        prevButton.setText("◀");
        prevButton.setTextColor(Color.WHITE);
        prevButton.setTextSize(14); // Smaller icon like iOS
        // Smaller buttons like iOS (32dp)
        prevButton.setMinWidth(dpToPx(32));
        prevButton.setMinHeight(dpToPx(32));
        prevButton.setPadding(dpToPx(6), dpToPx(6), dpToPx(6), dpToPx(6));
        // Very subtle background - almost transparent but provides touch feedback
        prevButton.setBackground(getRoundedBackground(Color.argb(30, 255, 255, 255))); // Very subtle white
        // CRITICAL: Ensure button is clickable; avoid focusableInTouchMode so first tap registers as click (not focus request)
        prevButton.setClickable(true);
        prevButton.setFocusable(false);
        prevButton.setFocusableInTouchMode(false);
        prevButton.setEnabled(true);
        LinearLayout.LayoutParams prevParams = new LinearLayout.LayoutParams(
            dpToPx(32), dpToPx(32) // Smaller buttons like iOS (32dp)
        );
        prevParams.setMargins(0, 0, dpToPx(10), 0);
        prevButton.setLayoutParams(prevParams);
        // Add touch listener to debug
        prevButton.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, android.view.MotionEvent event) {
                Log.d(TAG, "*** Prev button TOUCH *** action=" + event.getAction() + 
                      " (" + (event.getAction() == android.view.MotionEvent.ACTION_DOWN ? "DOWN" : 
                              event.getAction() == android.view.MotionEvent.ACTION_UP ? "UP" : "OTHER") + ")");
                return false; // Let onClick handle it
            }
        });
        prevButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "*** Prev button clicked *** currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
                if (currentDayIndex > 0) {
                    currentDayIndex--;
                    updateDisplay();
                } else {
                    Log.d(TAG, "Cannot go to previous day - already at index 0");
                }
            }
        });
        
        // Day label - fixed-width center slot so label can expand/contract (~20px) without moving prev/next
        dayLabel = new TextView(context);
        dayLabel.setText("Loading...");
        dayLabel.setTextColor(Color.WHITE);
        dayLabel.setTextSize(20);
        dayLabel.setTypeface(null, android.graphics.Typeface.BOLD);
        dayLabel.setGravity(Gravity.CENTER);
        dayLabel.setClickable(false);
        dayLabel.setFocusable(false);
        dayLabel.setSingleLine(true);
        dayLabel.setEllipsize(android.text.TextUtils.TruncateAt.END);
        FrameLayout labelSlot = new FrameLayout(context);
        labelSlot.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(160), LayoutParams.WRAP_CONTENT));
        labelSlot.setClickable(false);
        labelSlot.setFocusable(false);
        FrameLayout.LayoutParams labelParams = new FrameLayout.LayoutParams(
            LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.CENTER
        );
        dayLabel.setLayoutParams(labelParams);
        labelSlot.addView(dayLabel);
        
        // Next button - Clean style: just icon with very subtle background for touch feedback
        nextButton = new Button(context);
        nextButton.setText("▶");
        nextButton.setTextColor(Color.WHITE);
        nextButton.setTextSize(14); // Smaller icon like iOS
        // Smaller buttons like iOS (32dp)
        nextButton.setMinWidth(dpToPx(32));
        nextButton.setMinHeight(dpToPx(32));
        nextButton.setPadding(dpToPx(6), dpToPx(6), dpToPx(6), dpToPx(6));
        // Very subtle background - almost transparent but provides touch feedback
        nextButton.setBackground(getRoundedBackground(Color.argb(30, 255, 255, 255))); // Very subtle white
        // CRITICAL: Ensure button is clickable; avoid focusableInTouchMode so first tap registers as click (not focus request)
        nextButton.setClickable(true);
        nextButton.setFocusable(false);
        nextButton.setFocusableInTouchMode(false);
        nextButton.setEnabled(true);
        LinearLayout.LayoutParams nextParams = new LinearLayout.LayoutParams(
            dpToPx(32), dpToPx(32) // Smaller buttons like iOS (32dp)
        );
        nextParams.setMargins(dpToPx(10), 0, 0, 0);
        nextButton.setLayoutParams(nextParams);
        // Add touch listener to debug
        nextButton.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, android.view.MotionEvent event) {
                Log.d(TAG, "*** Next button TOUCH *** action=" + event.getAction() + 
                      " (" + (event.getAction() == android.view.MotionEvent.ACTION_DOWN ? "DOWN" : 
                              event.getAction() == android.view.MotionEvent.ACTION_UP ? "UP" : "OTHER") + ")");
                return false; // Let onClick handle it
            }
        });
        nextButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "*** Next button clicked *** currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
                if (currentDayIndex < days.size() - 1) {
                    currentDayIndex++;
                    updateDisplay();
                } else {
                    Log.d(TAG, "Cannot go to next day - already at last index " + (days.size() - 1));
                }
            }
        });
        
        // Add views to nav group: button, label, button (grouped together)
        navGroup.addView(prevButton);
        navGroup.addView(labelSlot);
        navGroup.addView(nextButton);
        
        navContainer.addView(navGroup);
        headerLayout.addView(navContainer);
        
        if (isSplitViewCapable) {
            createListViewButton();
        }
        
        addView(headerLayout);
        
        // Debug: Log button properties
        Log.d(TAG, "Header created - prevButton clickable=" + prevButton.isClickable() + 
              ", enabled=" + prevButton.isEnabled() + ", visibility=" + prevButton.getVisibility());
        Log.d(TAG, "Header created - nextButton clickable=" + nextButton.isClickable() + 
              ", enabled=" + nextButton.isEnabled() + ", visibility=" + nextButton.getVisibility());
        if (isSplitViewCapable) {
            Log.d(TAG, "Header created - listViewButton added for tablet mode");
        }
    }
    
    private android.graphics.drawable.Drawable getRoundedBackground(int color) {
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
        drawable.setColor(color);
        drawable.setCornerRadius(dpToPx(6)); // 6dp corner radius like iOS
        return drawable;
    }
    
    /**
     * Returns the fill color for an event block. Always uses venue color so cards match the venue;
     * Must/Might/Wont affect only the priority icon, not the card color.
     */
    private int getEventBlockFillColor(ScheduleBlock event) {
        return event.venueColor;
    }
    
    private android.graphics.drawable.Drawable getEventBlockBackground(int fillColor, boolean shouldDim) {
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
        
        // Darken the fill color for expired events (reduce brightness by ~60%) only if shouldDim is true
        int displayColor = shouldDim ? darkenColor(fillColor, 0.4f) : fillColor;
        drawable.setColor(displayColor);
        drawable.setCornerRadius(dpToPx(4)); // 4dp corner radius to match iOS
        // Darken border for expired events (use dark grey instead of white) only if shouldDim is true
        int borderColor = shouldDim ? Color.argb(102, 128, 128, 128) : Color.WHITE; // Dark grey border for expired
        drawable.setStroke(1, borderColor);
        return drawable;
    }
    
    /**
     * Darken a color by reducing its RGB values by a factor
     * @param color Original color
     * @param factor Factor to darken (0.0 = black, 1.0 = original color)
     * @return Darkened color
     */
    private int darkenColor(int color, float factor) {
        int alpha = Color.alpha(color);
        int red = (int)(Color.red(color) * factor);
        int green = (int)(Color.green(color) * factor);
        int blue = (int)(Color.blue(color) * factor);
        return Color.argb(alpha, red, green, blue);
    }
    
    private ViewGroup venueHeaderContainer; // Fixed header row container (no horizontal scroll - content fits width)
    private LinearLayout venueHeaderRow; // Fixed header row for venue names
    
    private void createContentArea() {
        // Venue header row container - no horizontal scroll; content shrinks to fit width
        venueHeaderContainer = new LinearLayout(context);
        venueHeaderContainer.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT
        ));
        venueHeaderContainer.setClickable(false);
        venueHeaderContainer.setFocusable(false);
        
        venueHeaderRow = new LinearLayout(context);
        venueHeaderRow.setOrientation(LinearLayout.HORIZONTAL);
        venueHeaderRow.setBackgroundColor(Color.BLACK);
        LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT
        );
        venueHeaderRow.setLayoutParams(rowParams);
        venueHeaderRow.setClipChildren(true);
        venueHeaderRow.setClipToPadding(true);
        venueHeaderContainer.addView(venueHeaderRow);
        
        contentScrollView = new ScrollView(context);
        LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, 0, 1.0f
        );
        contentScrollView.setLayoutParams(scrollParams);
        contentScrollView.setBackgroundColor(Color.BLACK);
        contentScrollView.setFillViewport(true);
        // Don't intercept touches - let child views handle them
        contentScrollView.setClickable(false);
        contentScrollView.setFocusable(false);
        
        contentLayout = new LinearLayout(context);
        contentLayout.setOrientation(LinearLayout.VERTICAL);
        contentLayout.setBackgroundColor(Color.BLACK);
        LinearLayout.LayoutParams contentParams = new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT
        );
        contentLayout.setLayoutParams(contentParams);
        // Don't intercept touches - let child views handle them
        contentLayout.setClickable(false);
        contentLayout.setFocusable(false);
        
        contentScrollView.addView(contentLayout);
        
        venueHeaderContainer.setVisibility(View.VISIBLE);
        contentScrollView.setVisibility(View.VISIBLE);
        
        addView(venueHeaderContainer);
        addView(contentScrollView);
    }
    
    private void loadScheduleData() {
        Log.d(TAG, "loadScheduleData: Starting background thread");
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
                        scheduleInfo scheduleParser = new scheduleInfo();
                        BandInfo.scheduleRecords = scheduleParser.ParseScheduleCSV();
                    }
                    
                    if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
                        post(new Runnable() {
                            @Override
                            public void run() {
                                updateDisplay();
                            }
                        });
                        return;
                    }
                    
                    // Preserve current day when reloading (e.g. returning from details) so position is not reset
                    String dayToRestore = null;
                    if (days != null && !days.isEmpty() && currentDayIndex >= 0 && currentDayIndex < days.size()) {
                        dayToRestore = days.get(currentDayIndex).dayLabel;
                        Log.d(TAG, "Preserving current day for restore: '" + dayToRestore + "' (index " + currentDayIndex + ")");
                    }
                    
                    days = processEventsFromScheduleRecords();
                    
                    // Apply visibility rules:
                    // Rule 1: If Hide Expired Events is ON and ALL events are expired → Don't show calendar view
                    // Rule 2: If Hide Expired Events is ON and ANY events are visible → Show calendar view, but only for days where events exist
                    // Rule 3: If Hide Expired Events is OFF and ANY scheduled events exist → Show calendar view for all days
                    // Rule 4: If there are NO scheduled events → Don't show calendar view
                    
                    // Check if there are any events at all (Rule 4)
                    if (days.isEmpty()) {
                        Log.w(TAG, "No scheduled events found - not showing calendar view");
                        post(new Runnable() {
                            @Override
                            public void run() {
                                updateDisplay();
                            }
                        });
                        return;
                    }
                    
                    // If hiding expired events, check if ALL events are expired (Rule 1)
                    if (hideExpiredEvents) {
                        boolean allEventsExpired = true;
                        long currentTimeMillis = System.currentTimeMillis();
                        
                        for (DayScheduleData day : days) {
                            for (VenueColumn venue : day.venues) {
                                for (ScheduleBlock event : venue.events) {
                                    // Check if event is expired independently of hideExpiredEvents setting
                                    // event.timeIndex is now in seconds (converted from milliseconds when block was created)
                                    boolean eventIsExpired = false;
                                    
                                    if (event.timeIndex > 0) {
                                        // Calculate endTimeIndex: timeIndex (start in seconds) + duration
                                        double endTimeIndex = event.timeIndex;
                                        if (event.startTime != null && event.endTime != null) {
                                            // Calculate duration in seconds
                                            long durationSeconds = (event.endTime.getTime() - event.startTime.getTime()) / 1000;
                                            endTimeIndex = event.timeIndex + durationSeconds;
                                        } else {
                                            // Default to 1 hour if we can't determine duration
                                            endTimeIndex = event.timeIndex + 3600;
                                        }
                                        
                                        // Compare endTimeIndex (in seconds) with current time (in seconds)
                                        double currentTimeSeconds = currentTimeMillis / 1000.0;
                                        eventIsExpired = endTimeIndex <= currentTimeSeconds;
                                    } else {
                                        // If we can't determine expiration, assume it's not expired to be safe
                                        eventIsExpired = false;
                                        Log.w(TAG, "Cannot determine expiration for event: " + event.bandName + 
                                              " (timeIndex=" + event.timeIndex + ")");
                                    }
                                    
                                    if (!eventIsExpired) {
                                        allEventsExpired = false;
                                        Log.d(TAG, "Found non-expired event: " + event.bandName + 
                                              " (endTime=" + (event.endTime != null ? event.endTime : "null") + 
                                              ", currentTime=" + new Date(currentTimeMillis) + ")");
                                        break;
                                    }
                                }
                                if (!allEventsExpired) break;
                            }
                            if (!allEventsExpired) break;
                        }
                        
                        if (allEventsExpired) {
                            Log.w(TAG, "Hide Expired Events is ON and ALL events are expired - not showing calendar view");
                            shouldFinishActivity = true;
                            post(new Runnable() {
                                @Override
                                public void run() {
                                    // Finish the activity if we're in one
                                    if (context instanceof android.app.Activity) {
                                        Log.d(TAG, "Finishing activity because all events are expired");
                                        ((android.app.Activity) context).finish();
                                    }
                                }
                            });
                            return;
                        }
                        
                        // Rule 2: Filter to only show days with non-expired events
                        days = filterExpiredDays(days);
                        
                        // If after filtering there are no days left, don't show calendar view
                        if (days.isEmpty()) {
                            Log.w(TAG, "After filtering expired events, no days remain - not showing calendar view");
                            shouldFinishActivity = true;
                            post(new Runnable() {
                                @Override
                                public void run() {
                                    // Finish the activity if we're in one
                                    if (context instanceof android.app.Activity) {
                                        Log.d(TAG, "Finishing activity because no days remain after filtering");
                                        ((android.app.Activity) context).finish();
                                    }
                                }
                            });
                            return;
                        }
                    }
                    
                    if (shouldFinishActivity) {
                        Log.d(TAG, "Skipping display update because activity should finish");
                        return;
                    }
                    
                    // Restore to the day we were on (e.g. after returning from details), else use initialDay from intent
                    boolean restored = false;
                    if (dayToRestore != null && !days.isEmpty()) {
                        // dayToRestore is already raw day from schedule data cache
                        Log.d(TAG, "Restoring day: '" + dayToRestore + "'");
                        for (int i = 0; i < days.size(); i++) {
                            String dayLabel = days.get(i).dayLabel;
                            if (dayLabel != null && dayLabel.trim().equals(dayToRestore.trim())) {
                                currentDayIndex = i;
                                restored = true;
                                Log.d(TAG, "✅ Restored calendar to day: '" + dayToRestore + "' (index " + i + ")");
                                break;
                            }
                        }
                    }
                    if (!restored && initialDay != null) {
                        // initialDay is already raw day from schedule data cache (via extractDayFromPosition)
                        Log.d(TAG, "Looking for initial day: '" + initialDay + "'");
                        for (int i = 0; i < days.size(); i++) {
                            String dayLabel = days.get(i).dayLabel;
                            if (dayLabel != null && dayLabel.trim().equals(initialDay.trim())) {
                                currentDayIndex = i;
                                Log.d(TAG, "✅ Found matching initial day at index " + i);
                                break;
                            }
                        }
                    }
                    if (currentDayIndex >= days.size()) {
                        currentDayIndex = 0;
                    }
                    
                    if (!shouldFinishActivity) {
                        post(new Runnable() {
                            @Override
                            public void run() {
                                if (!shouldFinishActivity) {
                                    updateDisplay();
                                }
                            }
                        });
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error loading schedule data", e);
                }
            }
        }).start();
    }
    
    private void updateDisplay() {
        Log.d(TAG, "updateDisplay: currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
        
        // Refresh attended statuses and priorities before updating the display
        refreshAttendedStatuses();
        refreshPriorities();
        
        // Update header
        if (days.isEmpty()) {
            dayLabel.setText("No Schedule Data");
            prevButton.setVisibility(View.GONE);
            nextButton.setVisibility(View.GONE);
        } else {
            if (currentDayIndex < 0 || currentDayIndex >= days.size()) {
                currentDayIndex = 0;
            }
            
            DayScheduleData currentDay = days.get(currentDayIndex);
            int eventCount = 0;
            for (VenueColumn venue : currentDay.venues) {
                eventCount += venue.events.size();
            }
            
            dayLabel.setText(currentDay.dayLabel + " - " + eventCount + " Events");
            
            // Show/hide buttons like iOS - only show when they can be used
            if (currentDayIndex > 0) {
                prevButton.setVisibility(View.VISIBLE);
                prevButton.setEnabled(true);
                Log.d(TAG, "updateDisplay: Prev button VISIBLE, enabled=true");
            } else {
                prevButton.setVisibility(View.GONE);
                Log.d(TAG, "updateDisplay: Prev button GONE (at first day)");
            }
            
            if (currentDayIndex < days.size() - 1) {
                nextButton.setVisibility(View.VISIBLE);
                nextButton.setEnabled(true);
                Log.d(TAG, "updateDisplay: Next button VISIBLE, enabled=true");
            } else {
                nextButton.setVisibility(View.GONE);
                Log.d(TAG, "updateDisplay: Next button GONE (at last day)");
            }
        }
        
        // Update content
        updateContent();
    }
    
    /**
     * Refresh the attended status for all events in the current day.
     * This ensures that when the UI is rebuilt, it shows the latest attended status.
     */
    private void refreshAttendedStatuses() {
        if (days.isEmpty() || currentDayIndex < 0 || currentDayIndex >= days.size()) {
            return;
        }
        
        DayScheduleData currentDay = days.get(currentDayIndex);
        if (staticVariables.eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
        }
        String eventYear = String.valueOf(staticVariables.eventYear);
        
        for (VenueColumn venue : currentDay.venues) {
            for (ScheduleBlock event : venue.events) {
                // Refresh the attended status from the current data
                String updatedStatus = attendedHandle.getShowAttendedStatus(
                    event.bandName,
                    event.location,
                    event.startTimeString,
                    event.eventType != null ? event.eventType : "Performance",
                    eventYear
                );
                event.attendedStatus = updatedStatus;
            }
        }
    }
    
    /**
     * Refresh priority for all events in the current day from rankStore.
     * Ensures calendar event blocks show the correct color after a priority change in the long-press menu.
     */
    private void refreshPriorities() {
        if (days.isEmpty() || currentDayIndex < 0 || currentDayIndex >= days.size()) {
            return;
        }
        DayScheduleData currentDay = days.get(currentDayIndex);
        for (VenueColumn venue : currentDay.venues) {
            for (ScheduleBlock event : venue.events) {
                String bandName = event.bandName;
                if (isCombinedEventName(bandName)) {
                    String[] parts = getCombinedEventBandParts(bandName);
                    if (parts != null) bandName = parts[0].trim();
                }
                String rankIcon = rankStore.getRankForBand(bandName);
                event.priority = getPriorityFromRankIcon(rankIcon);
            }
        }
    }
    
    private void updateContent() {
        contentLayout.removeAllViews();
        venueHeaderRow.removeAllViews();
        
        if (days.isEmpty() || currentDayIndex >= days.size()) {
            TextView noData = new TextView(context);
            noData.setText("No schedule data available");
            noData.setTextColor(Color.WHITE);
            noData.setGravity(Gravity.CENTER);
            noData.setPadding(0, dpToPx(50), 0, 0);
            contentLayout.addView(noData);
            return;
        }
        
        DayScheduleData currentDay = days.get(currentDayIndex);
        
        // Calculate column widths
        // CRITICAL FIX: Use actual view width instead of display metrics for foldable devices
        // On Pixel Fold front display, display metrics may be stale during rotation
        int screenWidth = getWidth() > 0 ? getWidth() : getResources().getDisplayMetrics().widthPixels;
        int availableWidth = screenWidth - dpToPx(60); // Subtract time column width
        Log.d(TAG, "Screen width calculation - view width: " + getWidth() + ", display metrics width: " + getResources().getDisplayMetrics().widthPixels + ", using: " + screenWidth);
        
        // Always divide width by venue count so content fits on screen (no horizontal scroll, no hidden content)
        int columnWidth = currentDay.venues.isEmpty() ? availableWidth : availableWidth / currentDay.venues.size();
        Log.d(TAG, "Column width (fit to screen): " + columnWidth + ", venues: " + currentDay.venues.size());
        
        // Venue headers - measure first to find max height, then recreate with fixed height
        int maxHeaderHeight = dpToPx(44); // Minimum height
        
        // Create a temporary parent layout for accurate measurement
        LinearLayout tempParent = new LinearLayout(context);
        tempParent.setOrientation(LinearLayout.HORIZONTAL);
        
        // First pass: measure all venue headers to find the maximum height needed
        java.util.List<String> venueNames = new java.util.ArrayList<>();
        java.util.List<Integer> venueColors = new java.util.ArrayList<>();
        for (VenueColumn venue : currentDay.venues) {
            TextView tempHeader = new TextView(context);
            tempHeader.setText(venue.name != null ? venue.name : "");
            tempHeader.setTextSize(12);
            tempHeader.setTypeface(null, android.graphics.Typeface.BOLD);
            tempHeader.setGravity(Gravity.CENTER);
            int padding = dpToPx(4);
            tempHeader.setPadding(padding, padding, padding, padding);
            tempHeader.setSingleLine(false);
            tempHeader.setMaxLines(2); // Limit to 2 lines
            tempHeader.setEllipsize(android.text.TextUtils.TruncateAt.END); // Ellipsize if text doesn't fit
            tempHeader.setIncludeFontPadding(false);
            
            // Enable auto-sizing text: max 12sp, min 8sp, shrink if needed
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                tempHeader.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE); // Disable default, use custom
                tempHeader.setAutoSizeTextTypeUniformWithConfiguration(
                    8,  // minTextSize in sp
                    12, // maxTextSize in sp (current size)
                    1,  // autoSizeStepGranularity in sp
                    android.util.TypedValue.COMPLEX_UNIT_SP
                );
            }
            
            // Measure with exact width constraint
            LinearLayout.LayoutParams measureParams = new LinearLayout.LayoutParams(
                columnWidth, ViewGroup.LayoutParams.WRAP_CONTENT
            );
            tempHeader.setLayoutParams(measureParams);
            tempParent.addView(tempHeader);
            
            // Force measurement
            int widthSpec = View.MeasureSpec.makeMeasureSpec(columnWidth, View.MeasureSpec.EXACTLY);
            int heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
            tempHeader.measure(widthSpec, heightSpec);
            
            int measuredHeight = tempHeader.getMeasuredHeight();
            Log.d(TAG, "Venue header measurement: " + venue.name + " -> height=" + measuredHeight + 
                  ", columnWidth=" + columnWidth);
            
            if (measuredHeight > maxHeaderHeight) {
                maxHeaderHeight = measuredHeight;
                Log.d(TAG, "New maxHeaderHeight: " + maxHeaderHeight + " for venue: " + venue.name);
            }
            
            // Store venue info for recreation
            venueNames.add(venue.name);
            venueColors.add(venue.color);
            
            // Clean up
            tempParent.removeView(tempHeader);
        }
        
        // Add some extra padding to ensure text doesn't get cut off
        maxHeaderHeight += dpToPx(2);
        Log.d(TAG, "Final maxHeaderHeight: " + maxHeaderHeight + "px (" + 
              (maxHeaderHeight / getResources().getDisplayMetrics().density) + "dp)");
        
        // Create fixed venue header row
        // Time header - use maxHeaderHeight so it matches venue headers
        TextView timeHeader = new TextView(context);
        timeHeader.setText("Time");
        timeHeader.setTextColor(Color.WHITE);
        timeHeader.setTextSize(12); // Match venue header size
        timeHeader.setTypeface(null, android.graphics.Typeface.BOLD);
        timeHeader.setGravity(Gravity.CENTER);
        timeHeader.setBackgroundColor(Color.GRAY);
        timeHeader.setIncludeFontPadding(false); // Match venue headers
        int timePadding = dpToPx(4);
        timeHeader.setPadding(timePadding, timePadding, timePadding, timePadding);
        LinearLayout.LayoutParams timeParams = new LinearLayout.LayoutParams(
            dpToPx(60), maxHeaderHeight
        );
        timeHeader.setLayoutParams(timeParams);
        timeHeader.setMinHeight(maxHeaderHeight);
        timeHeader.setMaxHeight(maxHeaderHeight);
        timeHeader.setHeight(maxHeaderHeight); // Explicitly set height
        venueHeaderRow.addView(timeHeader);
        
        Log.d(TAG, "Header height set to: " + maxHeaderHeight + "dp (" + (maxHeaderHeight / getResources().getDisplayMetrics().density) + "dp)");
        
        // Second pass: create all venue headers wrapped in FrameLayouts for strict height enforcement
        for (int i = 0; i < currentDay.venues.size(); i++) {
            VenueColumn venue = currentDay.venues.get(i);
            
            // Create FrameLayout wrapper to strictly enforce height and clip content
            FrameLayout headerWrapper = new FrameLayout(context);
            LinearLayout.LayoutParams wrapperParams = new LinearLayout.LayoutParams(
                columnWidth, maxHeaderHeight
            );
            headerWrapper.setLayoutParams(wrapperParams);
            headerWrapper.setClipChildren(true);
            headerWrapper.setClipToPadding(true);
            
            // Create TextView for the header text
            TextView venueHeader = new TextView(context);
            venueHeader.setText(venue.name != null ? venue.name : "");
            venueHeader.setTextColor(Color.WHITE);
            venueHeader.setTextSize(12);
            venueHeader.setTypeface(null, android.graphics.Typeface.BOLD);
            venueHeader.setGravity(Gravity.CENTER);
            venueHeader.setBackgroundColor(venue.color);
            int padding = dpToPx(4);
            venueHeader.setPadding(padding, padding, padding, padding);
            
            // TextView fills the wrapper but will be clipped if it exceeds
            FrameLayout.LayoutParams textParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            );
            venueHeader.setLayoutParams(textParams);
            
            // Enforce height constraints strictly
            venueHeader.setMinHeight(maxHeaderHeight);
            venueHeader.setMaxHeight(maxHeaderHeight);
            venueHeader.setHeight(maxHeaderHeight); // Explicitly set height
            
            // Allow text to wrap but limit to 2 lines with ellipsize
            venueHeader.setSingleLine(false);
            venueHeader.setMaxLines(2); // Limit to 2 lines to ensure consistent height
            venueHeader.setEllipsize(android.text.TextUtils.TruncateAt.END); // Show ellipsis if text doesn't fit
            venueHeader.setIncludeFontPadding(false);
            
            // Enable auto-sizing text: max 12sp (current size), min 8sp, shrink if needed to fit
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                venueHeader.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE); // Disable default, use custom
                venueHeader.setAutoSizeTextTypeUniformWithConfiguration(
                    8,  // minTextSize in sp
                    12, // maxTextSize in sp (current size)
                    1,  // autoSizeStepGranularity in sp
                    android.util.TypedValue.COMPLEX_UNIT_SP
                );
            }
            
            venueHeader.setVisibility(View.VISIBLE);
            venueHeader.setAlpha(1.0f);
            
            // Add TextView to wrapper, then wrapper to row
            headerWrapper.addView(venueHeader);
            
            Log.d(TAG, "Adding venue header: " + venue.name + ", height=" + maxHeaderHeight + 
                  ", columnWidth=" + columnWidth);
            venueHeaderRow.addView(headerWrapper);
        }
        
        // Columns container fits screen width (no horizontal scroll)
        LinearLayout columnsContainer = new LinearLayout(context);
        columnsContainer.setOrientation(LinearLayout.HORIZONTAL);
        columnsContainer.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT
        ));
        
        // Grid line color to match iOS: subtle light grey (horizontal and vertical)
        final int gridLineColor = Color.argb(100, 200, 200, 200);

        // Add time column first (without header) - pass header height for spacer
        LinearLayout timeColumn = createTimeColumn(currentDay, maxHeaderHeight);
        columnsContainer.addView(timeColumn);

        // Vertical grid lines between columns (match iOS: thin separators between Time and venues, and between each venue)
        for (VenueColumn venue : currentDay.venues) {
            columnsContainer.addView(createVerticalGridLine(gridLineColor));
            LinearLayout venueColumn = createVenueColumn(venue, currentDay, columnWidth, maxHeaderHeight, gridLineColor);
            columnsContainer.addView(venueColumn);
        }

        contentLayout.addView(columnsContainer);
    }
    
    private LinearLayout createTimeColumn(DayScheduleData dayData, int headerHeight) {
        LinearLayout timeColumn = new LinearLayout(context);
        timeColumn.setOrientation(LinearLayout.VERTICAL);
        timeColumn.setLayoutParams(new LinearLayout.LayoutParams(
            dpToPx(60), LayoutParams.WRAP_CONTENT
        ));
        timeColumn.setBackgroundColor(Color.BLACK);
        
        // Spacer for fixed header (same height as header)
        View headerSpacer = new View(context);
        headerSpacer.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, headerHeight
        ));
        headerSpacer.setBackgroundColor(Color.BLACK);
        timeColumn.addView(headerSpacer);
        
        // Time slots
        for (TimeSlot slot : dayData.timeSlots) {
            TextView timeText = new TextView(context);
            timeText.setText(slot.label);
            timeText.setTextSize(12);
            timeText.setTextColor(slot.label.contains("m") ? Color.WHITE : Color.GRAY);
            // Align text to top so events align with top of time text
            timeText.setGravity(Gravity.LEFT | Gravity.TOP);
            timeText.setPadding(dpToPx(4), 0, 0, 0);
            // Remove extra font padding to ensure text aligns at the very top
            timeText.setIncludeFontPadding(false);
            timeText.setLayoutParams(new LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT, dpToPx(30)
            ));
            timeText.setBackgroundColor(Color.BLACK);
            timeColumn.addView(timeText);
        }
        
        return timeColumn;
    }
    
    /** Creates a thin vertical divider for the grid (0.5px when possible, match iOS). */
    private View createVerticalGridLine(int gridLineColor) {
        View line = new View(context);
        line.setBackgroundColor(gridLineColor);
        line.setLayoutParams(new LinearLayout.LayoutParams(1, LayoutParams.MATCH_PARENT)); // 1px layout, draw at 0.5px
        line.setScaleX(0.5f);
        line.setPivotX(0.5f); // scale from center so 0.5px line is centered in 1px slot
        return line;
    }

    private LinearLayout createVenueColumn(VenueColumn venue, DayScheduleData dayData, int columnWidth, int headerHeight, int gridLineColor) {
        LinearLayout venueColumn = new LinearLayout(context);
        venueColumn.setOrientation(LinearLayout.VERTICAL);
        venueColumn.setLayoutParams(new LinearLayout.LayoutParams(
            columnWidth, LayoutParams.WRAP_CONTENT
        ));

        // Spacer for fixed header (same height as header)
        View headerSpacer = new View(context);
        headerSpacer.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, headerHeight
        ));
        headerSpacer.setBackgroundColor(Color.BLACK);
        venueColumn.addView(headerSpacer);

        // Content area with events positioned by time
        RelativeLayout contentArea = new RelativeLayout(context);
        int contentHeight = dayData.timeSlots.size() * dpToPx(30);
        contentArea.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, contentHeight
        ));

        // Horizontal grid lines at vertical center of each time row (match iOS: middle of "7:00pm" text)
        // Use 1px height so lines remain visible; 0.5px scaled lines disappear on many devices
        int halfSlotPx = dpToPx(15);
        for (TimeSlot slot : dayData.timeSlots) {
            View gridLine = new View(context);
            gridLine.setBackgroundColor(gridLineColor);
            RelativeLayout.LayoutParams gridParams = new RelativeLayout.LayoutParams(
                LayoutParams.MATCH_PARENT, 1
            );
            int yPos = calculateYPosition(slot.time, dayData) + halfSlotPx;
            gridParams.topMargin = yPos;
            gridLine.setLayoutParams(gridParams);
            contentArea.addView(gridLine);
        }
        
        // Check if there are any unexpired events in this day (for dimming logic)
        boolean hasUnexpiredEvents = hasUnexpiredEvents(dayData);
        
        // Add event blocks
        for (ScheduleBlock event : venue.events) {
            // Only dim expired events if: hideExpiredEvents is ON AND unexpired events exist
            // If all events are expired and hideExpiredEvents is OFF, don't dim
            boolean shouldDim = hideExpiredEvents && hasUnexpiredEvents && event.isExpired;
            View eventBlock = createEventBlock(event, columnWidth, dayData, shouldDim);
            contentArea.addView(eventBlock);
        }
        
        venueColumn.addView(contentArea);
        return venueColumn;
    }
    
    /**
     * Check if there are any unexpired events in the given day
     */
    private boolean hasUnexpiredEvents(DayScheduleData dayData) {
        for (VenueColumn venue : dayData.venues) {
            for (ScheduleBlock event : venue.events) {
                if (!event.isExpired) {
                    return true;
                }
            }
        }
        return false;
    }
    
    private View createEventBlock(ScheduleBlock event, int columnWidth, DayScheduleData dayData, boolean shouldDim) {
        LinearLayout eventBlock = new LinearLayout(context);
        eventBlock.setOrientation(LinearLayout.VERTICAL);
        eventBlock.setPadding(dpToPx(4), dpToPx(4), dpToPx(4), dpToPx(4));
        // Use drawable with white border instead of solid color, darken only if shouldDim is true
        int fillColor = getEventBlockFillColor(event);
        eventBlock.setBackground(getEventBlockBackground(fillColor, shouldDim));
        eventBlock.setClickable(true);
        eventBlock.setFocusable(false);
        eventBlock.setFocusableInTouchMode(false);
        eventBlock.setEnabled(true);
        
        // Calculate position and height
        Date eventStartTime = event.startTime;
        Date eventEndTime = event.endTime;
        
        if (eventEndTime != null && eventStartTime != null && eventEndTime.before(eventStartTime)) {
            Calendar cal = Calendar.getInstance();
            cal.setTime(eventEndTime);
            cal.add(Calendar.HOUR_OF_DAY, 24);
            eventEndTime = cal.getTime();
        }
        
        double durationSeconds = 3600; // Default 1 hour
        if (eventStartTime != null && eventEndTime != null) {
            durationSeconds = (eventEndTime.getTime() - eventStartTime.getTime()) / 1000.0;
            if (durationSeconds <= 0) {
                durationSeconds = 3600;
            }
        }
        
        double pixelsPerSecond = dpToPx(120) / 3600.0;
        int blockHeight = Math.max((int)(durationSeconds * pixelsPerSecond), dpToPx(30));
        // Use date-based positioning; add half-slot so event start aligns with grid line at center of time label
        int yPosition = calculateYPosition(eventStartTime, dayData) + dpToPx(15);
        
        RelativeLayout.LayoutParams params = new RelativeLayout.LayoutParams(
            columnWidth - dpToPx(4), blockHeight
        );
        params.leftMargin = dpToPx(2);
        params.topMargin = yPosition;
        eventBlock.setLayoutParams(params);
        
        // Line 1: Band name (handle combined events)
        boolean isCombinedEvent = isCombinedEventName(event.bandName);
        if (isCombinedEvent) {
            // Split combined name and display on separate lines (display still uses " / ")
            String[] bandParts = getCombinedEventBandParts(event.bandName);
            if (bandParts != null) {
                TextView bandName1 = new TextView(context);
                bandName1.setText(bandParts[0] + "/");
                bandName1.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                bandName1.setTextSize(11);
                bandName1.setTypeface(null, android.graphics.Typeface.BOLD);
                bandName1.setMaxLines(1);
                eventBlock.addView(bandName1);
                
                TextView bandName2 = new TextView(context);
                bandName2.setText(bandParts[1]);
                bandName2.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                bandName2.setTextSize(11);
                bandName2.setTypeface(null, android.graphics.Typeface.BOLD);
                bandName2.setMaxLines(1);
                eventBlock.addView(bandName2);
            } else {
                // Fallback: show as single line
                TextView bandName = new TextView(context);
                bandName.setText(event.bandName);
                bandName.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                bandName.setTextSize(11);
                bandName.setTypeface(null, android.graphics.Typeface.BOLD);
                bandName.setMaxLines(1);
                eventBlock.addView(bandName);
            }
        } else {
            // Single event: show normally
            TextView bandName = new TextView(context);
            bandName.setText(event.bandName);
            bandName.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
            bandName.setTextSize(11);
            bandName.setTypeface(null, android.graphics.Typeface.BOLD);
            bandName.setMaxLines(1);
            eventBlock.addView(bandName);
        }
        
        // Line 2: Start (localized): start time (respect OS 24-hour setting like list view)
        TextView startTimeText = new TextView(context);
        java.text.DateFormat timeFormat = DateFormat.getTimeFormat(context);
        if (event.startTime != null) {
            startTimeText.setText(context.getString(R.string.calendar_start) + ": " + timeFormat.format(event.startTime));
        }
        // Use darker grey for expired events only if shouldDim is true
        startTimeText.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
        startTimeText.setTextSize(9);
        startTimeText.setMaxLines(1);
        eventBlock.addView(startTimeText);
        
        // Line 3: End (localized): end time (respect OS 24-hour setting like list view)
        TextView endTimeText = new TextView(context);
        if (event.endTime != null) {
            endTimeText.setText(context.getString(R.string.calendar_end) + ": " + timeFormat.format(event.endTime));
        }
        // Use darker grey for expired events only if shouldDim is true
        endTimeText.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
        endTimeText.setTextSize(9);
        endTimeText.setMaxLines(1);
        eventBlock.addView(endTimeText);
        
        if (isCombinedEvent) {
            // Combined event: Show priority and attended on separate lines
            List<String> individualBands = combinedEventsMap.get(event.bandName);
            if (individualBands == null || individualBands.size() != 2) {
                // Fallback: split the name using internal delimiter
                String[] parts = getCombinedEventBandParts(event.bandName);
                if (parts != null) {
                    individualBands = new ArrayList<>();
                    individualBands.add(parts[0].trim());
                    individualBands.add(parts[1].trim());
                } else {
                    individualBands = null;
                }
            }
            
            if (individualBands != null && individualBands.size() == 2) {
                String band1 = individualBands.get(0);
                String band2 = individualBands.get(1);
                
                // Get priorities for each band
                String rankIcon1 = rankStore.getRankForBand(band1);
                String rankIcon2 = rankStore.getRankForBand(band2);
                int priority1 = getPriorityFromRankIcon(rankIcon1);
                int priority2 = getPriorityFromRankIcon(rankIcon2);
                
                // Get attended status for each band
                String attended1 = attendedHandle.getShowAttendedStatus(
                    band1, event.location, event.startTimeString,
                    event.eventType != null ? event.eventType : "Performance",
                    String.valueOf(staticVariables.eventYear)
                );
                String attended2 = attendedHandle.getShowAttendedStatus(
                    band2, event.location, event.startTimeString,
                    event.eventType != null ? event.eventType : "Performance",
                    String.valueOf(staticVariables.eventYear)
                );
                
                boolean hasPriority1 = priority1 > 0;
                boolean hasPriority2 = priority2 > 0;
                boolean hasAttended1 = attended1 != null && !attended1.isEmpty() && !attended1.equals("sawNone");
                boolean hasAttended2 = attended2 != null && !attended2.isEmpty() && !attended2.equals("sawNone");
                
                // Line 4: Priority icons only
                if (hasPriority1 || hasPriority2) {
                    LinearLayout priorityRow = new LinearLayout(context);
                    priorityRow.setOrientation(LinearLayout.HORIZONTAL);
                    priorityRow.setPadding(0, dpToPx(2), 0, 0);
                    
                    if (hasPriority1) {
                        addPriorityIcon(priorityRow, priority1, shouldDim);
                    }
                    
                    // Show slash only if exactly one has priority
                    if ((hasPriority1 && !hasPriority2) || (!hasPriority1 && hasPriority2)) {
                        TextView slash = new TextView(context);
                        slash.setText("/");
                        slash.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                        slash.setTextSize(10);
                        slash.setPadding(dpToPx(2), 0, dpToPx(2), 0);
                        priorityRow.addView(slash);
                    }
                    
                    if (hasPriority2) {
                        addPriorityIcon(priorityRow, priority2, shouldDim);
                    }
                    
                    eventBlock.addView(priorityRow);
                }
                
                // Line 5: Attended icons on their own line
                if (hasAttended1 || hasAttended2) {
                    LinearLayout attendedRow = new LinearLayout(context);
                    attendedRow.setOrientation(LinearLayout.HORIZONTAL);
                    attendedRow.setPadding(0, dpToPx(2), 0, 0);
                    
                    if (hasAttended1) {
                        addAttendedIcon(attendedRow, attended1, shouldDim);
                    }
                    
                    // Show slash only if exactly one has attended status
                    if ((hasAttended1 && !hasAttended2) || (!hasAttended1 && hasAttended2)) {
                        TextView slash = new TextView(context);
                        slash.setText("/");
                        slash.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                        slash.setTextSize(10);
                        slash.setPadding(dpToPx(2), 0, dpToPx(2), 0);
                        attendedRow.addView(slash);
                    }
                    
                    if (hasAttended2) {
                        addAttendedIcon(attendedRow, attended2, shouldDim);
                    }
                    
                    eventBlock.addView(attendedRow);
                }
                
                // Line 6: Event type (localized) + drawable icon after - only for non-Show types
                if (event.eventType != null && !event.eventType.isEmpty() && !event.eventType.equals(staticVariables.show)) {
                    LinearLayout eventTypeRow = new LinearLayout(context);
                    eventTypeRow.setOrientation(LinearLayout.HORIZONTAL);
                    eventTypeRow.setBaselineAligned(false);
                    TextView eventTypeText = new TextView(context);
                    eventTypeText.setText(Utilities.convertEventTypeToLocalLanguage(event.eventType));
                    eventTypeText.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                    eventTypeText.setTextSize(8);
                    eventTypeText.setMaxLines(1);
                    eventTypeRow.addView(eventTypeText);
                    int eventIconResId = iconResolve.getEventIcon(event.eventType, event.bandName);
                    if (eventIconResId != 0) {
                        ImageView eventTypeIcon = new ImageView(context);
                        eventTypeIcon.setImageResource(eventIconResId);
                        eventTypeIcon.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(14), dpToPx(14)));
                        eventTypeIcon.setAlpha(shouldDim ? 0.4f : 1.0f);
                        eventTypeIcon.setPadding(dpToPx(4), 0, 0, 0);
                        eventTypeRow.addView(eventTypeIcon);
                    }
                    eventBlock.addView(eventTypeRow);
                }
            } else {
                // Fallback: show normal layout
                addNormalIconRow(eventBlock, event, shouldDim);
            }
        } else {
            // Single event: Show normal priority and attended icons on same line
            addNormalIconRow(eventBlock, event, shouldDim);
            
            // Line 5: Event type (localized) + drawable icon after - only for non-Show types
            if (event.eventType != null && !event.eventType.isEmpty() && !event.eventType.equals(staticVariables.show)) {
                LinearLayout eventTypeRow = new LinearLayout(context);
                eventTypeRow.setOrientation(LinearLayout.HORIZONTAL);
                eventTypeRow.setBaselineAligned(false);
                TextView eventTypeText = new TextView(context);
                eventTypeText.setText(Utilities.convertEventTypeToLocalLanguage(event.eventType));
                eventTypeText.setTextColor(shouldDim ? Color.rgb(102, 102, 102) : Color.WHITE);
                eventTypeText.setTextSize(8);
                eventTypeText.setMaxLines(1);
                eventTypeRow.addView(eventTypeText);
                int eventIconResId = iconResolve.getEventIcon(event.eventType, event.bandName);
                if (eventIconResId != 0) {
                    ImageView eventTypeIcon = new ImageView(context);
                    eventTypeIcon.setImageResource(eventIconResId);
                    eventTypeIcon.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(14), dpToPx(14)));
                    eventTypeIcon.setAlpha(shouldDim ? 0.4f : 1.0f);
                    eventTypeIcon.setPadding(dpToPx(4), 0, 0, 0);
                    eventTypeRow.addView(eventTypeIcon);
                }
                eventBlock.addView(eventTypeRow);
            }
        }
        
        // Simple click listener - handle combined events
        final ScheduleBlock eventData = event;
        final boolean finalIsCombinedEvent = isCombinedEvent;
        eventBlock.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "Event clicked: " + eventData.bandName);
                
                if (bandTappedListener == null) {
                    Log.e(TAG, "ERROR: bandTappedListener is NULL - cannot open details!");
                    return;
                }
                
                if (currentDayIndex < 0 || currentDayIndex >= days.size()) {
                    Log.e(TAG, "ERROR: Invalid currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
                    return;
                }
                
                DayScheduleData currentDay = days.get(currentDayIndex);
                
                // If combined event, prompt for band selection
                if (finalIsCombinedEvent && isCombinedEventName(eventData.bandName)) {
                    List<String> individualBands = combinedEventsMap.get(eventData.bandName);
                    if (individualBands != null && individualBands.size() == 2) {
                        promptForBandSelection(eventData.bandName, individualBands, currentDay.dayLabel);
                        return;
                    } else {
                        // Fallback: split the name using internal delimiter
                        String[] parts = getCombinedEventBandParts(eventData.bandName);
                        if (parts != null) {
                            List<String> bands = new ArrayList<>();
                            bands.add(parts[0].trim());
                            bands.add(parts[1].trim());
                            promptForBandSelection(eventData.bandName, bands, currentDay.dayLabel);
                            return;
                        }
                    }
                }
                
                // Single event: proceed normally
                Log.d(TAG, "Calling onBandTapped with bandName=" + eventData.bandName + ", day=" + currentDay.dayLabel);
                try {
                    bandTappedListener.onBandTapped(eventData.bandName, currentDay.dayLabel);
                    Log.d(TAG, "onBandTapped called successfully");
                } catch (Exception e) {
                    Log.e(TAG, "ERROR calling onBandTapped", e);
                    e.printStackTrace();
                }
            }
        });
        
        // Long click listener for Priority + Attended menu (same as list view)
        eventBlock.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                showLongPressMenuForEvent(v, eventData, dayData);
                return true; // Consume the event
            }
        });
        
        return eventBlock;
    }
    
    /**
     * Prompt user to select which band they want to act on for a combined event
     */
    private void promptForBandSelection(String combinedBandName, List<String> bands, String currentDay) {
        if (bands == null || bands.size() != 2) {
            Log.e(TAG, "ERROR: Expected exactly 2 bands for combined event, got " + (bands != null ? bands.size() : 0));
            return;
        }
        
        final String band1 = bands.get(0);
        final String band2 = bands.get(1);
        final String finalCurrentDay = currentDay;
        
        Log.d(TAG, "Showing band selection dialog for click: " + combinedBandName + 
              ", band1=" + band1 + ", band2=" + band2);
        
        android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
        builder.setTitle(context.getString(R.string.SelectBand));
        
        // Create custom adapter with dark theme styling
        android.widget.ArrayAdapter<String> adapter = new android.widget.ArrayAdapter<String>(context, android.R.layout.simple_list_item_1, new String[]{band1, band2}) {
            @Override
            public View getView(int position, View convertView, ViewGroup parent) {
                View view = super.getView(position, convertView, parent);
                TextView textView = (TextView) view.findViewById(android.R.id.text1);
                if (textView != null) {
                    textView.setTextColor(Color.WHITE);
                    textView.setTextSize(16);
                }
                view.setBackgroundColor(Color.BLACK);
                return view;
            }
        };
        
        builder.setAdapter(adapter, new android.content.DialogInterface.OnClickListener() {
            @Override
            public void onClick(android.content.DialogInterface dialog, int which) {
                String selectedBand = (which == 0) ? band1 : band2;
                Log.d(TAG, "User selected band: " + selectedBand);
                dialog.dismiss();
                
                if (bandTappedListener != null) {
                    bandTappedListener.onBandTapped(selectedBand, finalCurrentDay);
                }
            }
        });
        
        builder.setNegativeButton("Cancel", new android.content.DialogInterface.OnClickListener() {
            @Override
            public void onClick(android.content.DialogInterface dialog, int which) {
                Log.d(TAG, "User cancelled band selection");
                dialog.dismiss();
            }
        });
        
        android.app.AlertDialog dialog = builder.create();
        // Style the dialog to match dark theme
        styleDialogForDarkTheme(dialog);
        dialog.show();
    }
    
    /**
     * Show long-press menu (Priority + Attended) for calendar event. Portrait = list, landscape = 2 columns.
     */
    private void showLongPressMenuForEvent(View anchor, ScheduleBlock event, DayScheduleData dayData) {
        boolean isCombinedEvent = isCombinedEventName(event.bandName);
        if (isCombinedEvent) {
            List<String> individualBands = combinedEventsMap.get(event.bandName);
            if (individualBands == null || individualBands.size() != 2) {
                String[] parts = getCombinedEventBandParts(event.bandName);
                if (parts != null) {
                    individualBands = new ArrayList<>();
                    individualBands.add(parts[0].trim());
                    individualBands.add(parts[1].trim());
                } else {
                    openLongPressMenuForBand(event, event.bandName);
                    return;
                }
            }
            if (individualBands == null || individualBands.size() != 2) {
                openLongPressMenuForBand(event, event.bandName);
                return;
            }
            final String band1 = individualBands.get(0);
            final String band2 = individualBands.get(1);
            final ScheduleBlock finalEvent = event;
            android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
            builder.setTitle(context.getString(R.string.SelectBand));
            android.widget.ArrayAdapter<String> adapter = new android.widget.ArrayAdapter<String>(context, android.R.layout.simple_list_item_1, new String[]{band1, band2}) {
                @Override
                public View getView(int position, View convertView, ViewGroup parent) {
                    View view = super.getView(position, convertView, parent);
                    TextView textView = (TextView) view.findViewById(android.R.id.text1);
                    if (textView != null) {
                        textView.setTextColor(Color.WHITE);
                        textView.setTextSize(16);
                    }
                    view.setBackgroundColor(Color.BLACK);
                    return view;
                }
            };
            builder.setAdapter(adapter, new android.content.DialogInterface.OnClickListener() {
                @Override
                public void onClick(android.content.DialogInterface dialog, int which) {
                    String selectedBand = (which == 0) ? band1 : band2;
                    dialog.dismiss();
                    openLongPressMenuForBand(finalEvent, selectedBand);
                }
            });
            builder.setNegativeButton("Cancel", null);
            android.app.AlertDialog dialog = builder.create();
            styleDialogForDarkTheme(dialog);
            dialog.show();
            return;
        }
        openLongPressMenuForBand(event, event.bandName);
    }

    private void openLongPressMenuForBand(ScheduleBlock event, String bandName) {
        String normalizedEventType = event.eventType != null ? event.eventType : "Performance";
        if ("Unofficial Event".equals(event.eventType)) {
            normalizedEventType = "Cruiser Organized";
        }
        String currentAttended = event.attendedStatus != null ? event.attendedStatus : "";
        if (!bandName.equals(event.bandName)) {
            currentAttended = attendedHandle.getShowAttendedStatus(bandName, event.location, event.startTimeString, normalizedEventType, String.valueOf(staticVariables.eventYear));
        }
        if (!(context instanceof android.app.Activity)) return;
        final Runnable onRefresh = new Runnable() { @Override public void run() { updateDisplay(); } };
        LongPressMenuHelper.show((android.app.Activity) context, bandName, currentAttended, event.location, event.startTimeString, normalizedEventType, onRefresh, null);
    }

    private void showAttendanceMenu(View anchor, ScheduleBlock event, DayScheduleData dayData) {
        // Check if this is a combined event
        boolean isCombinedEvent = isCombinedEventName(event.bandName);
        
        if (isCombinedEvent) {
            // For combined events, first ask which band
            List<String> individualBands = combinedEventsMap.get(event.bandName);
            if (individualBands == null || individualBands.size() != 2) {
                // Fallback: split the name using internal delimiter
                String[] parts = getCombinedEventBandParts(event.bandName);
                if (parts != null) {
                    individualBands = new ArrayList<>();
                    individualBands.add(parts[0].trim());
                    individualBands.add(parts[1].trim());
                } else {
                    // Can't determine bands, show normal menu
                    showAttendanceMenuForBand(anchor, event, dayData, event.bandName);
                    return;
                }
            }
            
            // Show band selection dialog first
            final List<String> finalBands = individualBands;
            final ScheduleBlock finalEvent = event;
            final DayScheduleData finalDayData = dayData;
            
            // Ensure we have exactly 2 bands
            if (finalBands == null || finalBands.size() != 2) {
                Log.e(TAG, "ERROR: Expected exactly 2 bands for combined event, got " + (finalBands != null ? finalBands.size() : 0));
                // Fallback: show normal menu
                showAttendanceMenuForBand(anchor, event, dayData, event.bandName);
                return;
            }
            
            String band1 = finalBands.get(0);
            String band2 = finalBands.get(1);
            
            Log.d(TAG, "Showing band selection dialog for combined event: " + event.bandName + 
                  ", band1=" + band1 + ", band2=" + band2);
            
            android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
            builder.setTitle(context.getString(R.string.SelectBand));
            
            // Create custom adapter with dark theme styling
            android.widget.ArrayAdapter<String> adapter = new android.widget.ArrayAdapter<String>(context, android.R.layout.simple_list_item_1, new String[]{band1, band2}) {
                @Override
                public View getView(int position, View convertView, ViewGroup parent) {
                    View view = super.getView(position, convertView, parent);
                    TextView textView = (TextView) view.findViewById(android.R.id.text1);
                    if (textView != null) {
                        textView.setTextColor(Color.WHITE);
                        textView.setTextSize(16);
                    }
                    view.setBackgroundColor(Color.BLACK);
                    return view;
                }
            };
            
            builder.setAdapter(adapter, new android.content.DialogInterface.OnClickListener() {
                @Override
                public void onClick(android.content.DialogInterface dialog, int which) {
                    String selectedBand = (which == 0) ? band1 : band2;
                    Log.d(TAG, "User selected band for attendance: " + selectedBand);
                    dialog.dismiss();
                    // Now show attendance menu for the selected band
                    showAttendanceMenuForBand(anchor, finalEvent, finalDayData, selectedBand);
                }
            });
            
            builder.setNegativeButton("Cancel", new android.content.DialogInterface.OnClickListener() {
                @Override
                public void onClick(android.content.DialogInterface dialog, int which) {
                    Log.d(TAG, "User cancelled band selection");
                    dialog.dismiss();
                }
            });
            
            android.app.AlertDialog dialog = builder.create();
            // Style the dialog to match dark theme
            styleDialogForDarkTheme(dialog);
            dialog.show();
            return;
        }
        
        // Single event: show normal menu
        showAttendanceMenuForBand(anchor, event, dayData, event.bandName);
    }
    
    private void showAttendanceMenuForBand(View anchor, ScheduleBlock event, DayScheduleData dayData, String bandName) {
        PopupMenu popupMenu = new PopupMenu(context, anchor);
        
        // Get current status for the specific band
        String currentStatus = "";
        if (bandName.equals(event.bandName)) {
            // Single event or combined event where we're checking the combined status
            currentStatus = event.attendedStatus != null ? event.attendedStatus : "";
        } else {
            // Combined event: get status for the specific individual band
            currentStatus = attendedHandle.getShowAttendedStatus(
                bandName,
                event.location,
                event.startTimeString,
                event.eventType != null ? event.eventType : "Performance",
                String.valueOf(staticVariables.eventYear)
            );
        }
        
        // Normalize event type for database operations (like iOS does)
        String normalizedEventType = event.eventType;
        if ("Unofficial Event".equals(event.eventType)) {
            normalizedEventType = "Cruiser Organized";
        }
        
        Log.d(TAG, "Showing attendance menu for " + bandName + 
              ", currentStatus=" + currentStatus + 
              ", eventType=" + event.eventType + 
              " -> normalizedEventType=" + normalizedEventType);
        
        // Define menu item IDs
        final int MENU_ID_ALL = 1;
        final int MENU_ID_SOME = 2;
        final int MENU_ID_NONE = 3;
        
        // Add menu items, excluding the currently active option
        if (!currentStatus.equals(staticVariables.sawAllStatus)) {
            popupMenu.getMenu().add(0, MENU_ID_ALL, 0, context.getString(R.string.AllOfEvent));
        }
        
        if (!currentStatus.equals(staticVariables.sawSomeStatus) && 
            event.eventType != null && event.eventType.equals(staticVariables.show)) {
            popupMenu.getMenu().add(0, MENU_ID_SOME, 0, context.getString(R.string.PartOfEvent));
        }
        
        if (!currentStatus.equals(staticVariables.sawNoneStatus) && !currentStatus.isEmpty()) {
            popupMenu.getMenu().add(0, MENU_ID_NONE, 0, context.getString(R.string.NoneOfEvent));
        }
        
        if (popupMenu.getMenu().size() == 0) {
            Log.w(TAG, "Attendance menu is empty - all options already selected?");
            return;
        }
        
        // Store event data in final variables for use in listener
        final ScheduleBlock finalEvent = event;
        final String finalNormalizedEventType = normalizedEventType;
        final String finalBandName = bandName;
        
        // Set click listener
        popupMenu.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
            @Override
            public boolean onMenuItemClick(android.view.MenuItem item) {
                String selectedStatus = null;
                
                switch (item.getItemId()) {
                    case MENU_ID_ALL:
                        selectedStatus = staticVariables.sawAllStatus;
                        break;
                    case MENU_ID_SOME:
                        selectedStatus = staticVariables.sawSomeStatus;
                        break;
                    case MENU_ID_NONE:
                        selectedStatus = staticVariables.sawNoneStatus;
                        break;
                }
                
                if (selectedStatus != null) {
                    if (staticVariables.eventYear == 0) {
                        staticVariables.ensureEventYearIsSet();
                    }
                    String eventYear = String.valueOf(staticVariables.eventYear);
                    
                    Log.d(TAG, "Updating attendance: band=" + finalBandName + 
                          ", location=" + finalEvent.location + 
                          ", startTime=" + finalEvent.startTimeString + 
                          ", eventType=" + finalNormalizedEventType + 
                          ", eventYear=" + eventYear + 
                          ", status=" + selectedStatus);
                    
                    attendedHandle.addShowsAttended(
                        finalBandName,
                        finalEvent.location,
                        finalEvent.startTimeString,
                        finalNormalizedEventType,
                        selectedStatus
                    );
                    
                    // Refresh the display
                    if (currentDayIndex >= 0 && currentDayIndex < days.size()) {
                        updateDisplay();
                    }
                    
                    Log.d(TAG, "Attendance updated successfully for " + finalBandName);
                }
                
                return true;
            }
        });
        
        popupMenu.show();
    }
    
    private int calculateYPositionFromTimeIndex(double eventTimeIndex, DayScheduleData dayData) {
        // Use date-based positioning instead of timeIndex to avoid huge values
        // This method is kept for compatibility but should use calculateYPosition with dates
        return 0;
    }
    
    private int calculateYPosition(Date eventTime, DayScheduleData dayData) {
        // Calculate position based on date difference from first time slot
        // Time slots start at the rounded-down hour, not the first event time
        if (dayData.timeSlots.isEmpty() || eventTime == null) {
            return 0;
        }
        
        // Get the first time slot's time (this is the rounded-down hour)
        Date firstSlotTime = dayData.timeSlots.get(0).time;
        if (firstSlotTime == null) {
            return 0;
        }
        
        // Calculate time difference from first time slot
        long timeDiff = eventTime.getTime() - firstSlotTime.getTime();
        
        // Handle midnight crossover: if eventTime is before firstSlotTime, it might be next day
        // Add 24 hours if the difference is negative and large
        if (timeDiff < 0) {
            // Check if it's likely the next day (more than 12 hours before)
            if (timeDiff < -(12 * 60 * 60 * 1000)) {
                timeDiff += (24 * 60 * 60 * 1000); // Add 24 hours
            } else {
                // Within same day, position at start
                return 0;
            }
        }
        
        // Cap at 24 hours maximum
        long maxDuration = 24 * 60 * 60 * 1000;
        if (timeDiff > maxDuration) {
            timeDiff = maxDuration;
        }
        
        // Convert to minutes and then to pixels (30px per 15-minute slot)
        long minutesDiff = timeDiff / (1000 * 60);
        return (int)(minutesDiff / 15.0 * dpToPx(30));
    }
    
    public void setBandTappedListener(OnBandTappedListener listener) {
        Log.d(TAG, "setBandTappedListener called: " + (listener != null ? "NOT NULL" : "NULL"));
        this.bandTappedListener = listener;
        Log.d(TAG, "bandTappedListener set to: " + (this.bandTappedListener != null ? "NOT NULL" : "NULL"));
    }
    
    public void setDismissRequestedListener(OnDismissRequestedListener listener) {
        Log.d(TAG, "setDismissRequestedListener called: " + (listener != null ? "NOT NULL" : "NULL"));
        this.dismissRequestedListener = listener;
    }
    
    /**
     * Update device size classification dynamically (handles foldable devices)
     * Shows/hides the list view button and updates behavior based on device size
     */
    public void updateSplitViewCapable(boolean newIsSplitViewCapable) {
        if (this.isSplitViewCapable == newIsSplitViewCapable) {
            Log.d(TAG, "Device size unchanged - isSplitViewCapable: " + newIsSplitViewCapable);
            return; // No change needed
        }
        
        boolean wasSplitViewCapable = this.isSplitViewCapable;
        this.isSplitViewCapable = newIsSplitViewCapable;
        
        Log.d(TAG, "Device size changed - isSplitViewCapable: " + wasSplitViewCapable + " -> " + newIsSplitViewCapable);
        
        // Update listViewButton visibility
        if (listViewButton != null) {
            if (newIsSplitViewCapable) {
                // Show button for tablet mode
                if (listViewButton.getParent() == null) {
                    // Button doesn't exist yet, create it
                    createListViewButton();
                } else {
                    listViewButton.setVisibility(View.VISIBLE);
                }
                Log.d(TAG, "List view button shown (tablet mode)");
            } else {
                // Hide button for phone mode
                if (listViewButton.getParent() != null) {
                    listViewButton.setVisibility(View.GONE);
                }
                Log.d(TAG, "List view button hidden (phone mode)");
            }
        } else if (newIsSplitViewCapable && headerLayout != null) {
            // Button doesn't exist but should be shown - create it
            createListViewButton();
        }
    }
    
    /**
     * Create and add the list view button to the header
     * Called during initialization and when device size changes (foldable devices)
     */
    private void createListViewButton() {
        if (headerLayout == null) {
            Log.w(TAG, "Cannot create list view button - headerLayout is null");
            return; // Header not initialized
        }
        
        if (listViewButton != null && listViewButton.getParent() != null) {
            Log.d(TAG, "List view button already exists and is added to parent");
            return; // Button already exists and is added
        }
        
        // Create button if it doesn't exist
        if (listViewButton == null) {
            listViewButton = new Button(context);
            listViewButton.setText("☰"); // List icon (hamburger/list symbol)
            listViewButton.setTextColor(Color.WHITE);
            listViewButton.setTextSize(18);
            listViewButton.setMinWidth(dpToPx(44));
            listViewButton.setMinHeight(dpToPx(44));
            listViewButton.setPadding(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8));
            listViewButton.setBackground(getRoundedBackground(Color.argb(204, 0, 122, 255))); // Blue background like iOS
            listViewButton.setClickable(true);
            listViewButton.setFocusable(false);
            listViewButton.setFocusableInTouchMode(false);
            listViewButton.setEnabled(true);
            FrameLayout.LayoutParams listButtonParams = new FrameLayout.LayoutParams(dpToPx(44), dpToPx(44));
            listButtonParams.gravity = Gravity.END | Gravity.TOP;
            listButtonParams.setMargins(0, 0, dpToPx(8), dpToPx(8)); // Small inset from top-right corner
            listViewButton.setLayoutParams(listButtonParams);
            listViewButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    Log.d(TAG, "📱 [TABLET_TOGGLE] List button tapped in calendar view");
                    if (dismissRequestedListener != null) {
                        dismissRequestedListener.onDismissRequested();
                    }
                }
            });
        }
        
        // Add to header if not already added
        if (listViewButton.getParent() == null) {
            headerLayout.addView(listViewButton);
            Log.d(TAG, "List view button created and added to header");
        } else {
            listViewButton.setVisibility(View.VISIBLE);
            Log.d(TAG, "List view button already in parent, made visible");
        }
    }
    
    public void refreshEventData(String bandName) {
        loadScheduleData();
    }
    
    private int dpToPx(int dp) {
        return (int) (dp * getResources().getDisplayMetrics().density);
    }
    
    // Data processing methods (keep existing logic)
    private List<DayScheduleData> processEventsFromScheduleRecords() {
        Map<String, List<ScheduleBlock>> dayGroups = new HashMap<>();
        
        if (BandInfo.scheduleRecords == null) {
            return new ArrayList<>();
        }
        
        int eventYear = staticVariables.eventYear;
        
        for (Map.Entry<String, scheduleTimeTracker> bandEntry : BandInfo.scheduleRecords.entrySet()) {
            String bandName = bandEntry.getKey();
            scheduleTimeTracker tracker = bandEntry.getValue();
            
            if (tracker == null || tracker.scheduleByTime == null) {
                continue;
            }
            
            for (Map.Entry<Long, scheduleHandler> timeEntry : tracker.scheduleByTime.entrySet()) {
                Long timeIndex = timeEntry.getKey();
                scheduleHandler scheduleHandle = timeEntry.getValue();
                
                if (scheduleHandle == null) {
                    continue;
                }
                
                String day = scheduleHandle.getShowDay();
                if (day == null) continue;
                
                ScheduleBlock block = createScheduleBlockFromHandler(bandName, timeIndex, scheduleHandle, eventYear);
                if (block != null) {
                    if (!dayGroups.containsKey(day)) {
                        dayGroups.put(day, new ArrayList<ScheduleBlock>());
                    }
                    dayGroups.get(day).add(block);
                }
            }
        }
        
        List<DayScheduleData> result = new ArrayList<>();
        FestivalConfig config = FestivalConfig.getInstance();
        
        for (Map.Entry<String, List<ScheduleBlock>> entry : dayGroups.entrySet()) {
            String dayLabel = entry.getKey();
            List<ScheduleBlock> dayEvents = entry.getValue();
            
            Collections.sort(dayEvents, (a, b) -> Double.compare(a.timeIndex, b.timeIndex));
            
            if (dayEvents.isEmpty()) continue;
            
            List<String> venues = getUniqueVenues(dayEvents);
            
            // Detect and combine duplicate events (same date, time, location, eventType, different bandName)
            combinedEventsMap.clear(); // Clear previous combined events
            Map<String, String> eventToCombinedName = new HashMap<>(); // "timeIndex:bandName" -> combined name (band1+delimiter+band2)
            Set<String> eventsToSkip = new HashSet<>(); // Events to skip (second event of a pair)
            
            // Group events by unique key (date|startTime|endTime|location|eventType)
            Map<String, List<ScheduleBlock>> eventGroups = new HashMap<>();
            for (ScheduleBlock event : dayEvents) {
                String eventKey = buildEventKey(event);
                if (!eventGroups.containsKey(eventKey)) {
                    eventGroups.put(eventKey, new ArrayList<>());
                }
                eventGroups.get(eventKey).add(event);
            }
            
            // Find groups with exactly 2 distinct bands
            for (Map.Entry<String, List<ScheduleBlock>> groupEntry : eventGroups.entrySet()) {
                List<ScheduleBlock> groupEvents = groupEntry.getValue();
                if (groupEvents.size() == 2) {
                    ScheduleBlock event1 = groupEvents.get(0);
                    ScheduleBlock event2 = groupEvents.get(1);
                    
                    // Check if bands are different
                    if (!event1.bandName.equals(event2.bandName)) {
                        // Create combined name
                        String combinedName = event1.bandName + COMBINED_EVENT_DELIMITER + event2.bandName;
                        
                        // Store mapping
                        List<String> individualBands = new ArrayList<>();
                        individualBands.add(event1.bandName);
                        individualBands.add(event2.bandName);
                        combinedEventsMap.put(combinedName, individualBands);
                        
                        // Mark events for combination
                        String key1 = event1.timeIndex + ":" + event1.bandName;
                        String key2 = event2.timeIndex + ":" + event2.bandName;
                        eventToCombinedName.put(key1, combinedName);
                        eventToCombinedName.put(key2, combinedName);
                        
                        // Mark second event to skip (we'll combine into first)
                        eventsToSkip.add(key2);
                        
                        // Update first event's bandName to combined name
                        event1.bandName = combinedName;
                    }
                }
            }
            
            List<VenueColumn> venueColumns = new ArrayList<>();
            for (String venueName : venues) {
                List<ScheduleBlock> venueEvents = new ArrayList<>();
                for (ScheduleBlock block : dayEvents) {
                    // Skip second event of combined pair
                    String eventKey = block.timeIndex + ":" + block.bandName;
                    if (eventsToSkip.contains(eventKey)) {
                        continue;
                    }
                    
                    if (block.location.equals(venueName)) {
                        venueEvents.add(block);
                    }
                }
                
                String venueColorHex = config.getVenueColor(venueName);
                int venueColor = parseColorFromHex(venueColorHex);
                
                VenueColumn venueColumn = new VenueColumn();
                venueColumn.name = venueName;
                venueColumn.color = venueColor;
                venueColumn.events = venueEvents;
                venueColumns.add(venueColumn);
            }
            
            // Sort events by timeIndex to find chronological order
            List<ScheduleBlock> sortedByTimeIndex = new ArrayList<>(dayEvents);
            Collections.sort(sortedByTimeIndex, (a, b) -> Double.compare(a.timeIndex, b.timeIndex));
            
            if (sortedByTimeIndex.isEmpty()) {
                continue;
            }
            
            // Use timeIndex to find chronologically first event
            ScheduleBlock firstEvent = sortedByTimeIndex.get(0);
            double firstEventTimeIndex = firstEvent.timeIndex;
            
            // Find the earliest calendar date in this day group (for normalization)
            Calendar earliestDate = null;
            for (ScheduleBlock event : sortedByTimeIndex) {
                if (event.startTime != null) {
                    Calendar eventCal = Calendar.getInstance();
                    eventCal.setTime(event.startTime);
                    if (earliestDate == null || eventCal.before(earliestDate)) {
                        earliestDate = (Calendar) eventCal.clone();
                    }
                }
            }
            
            if (earliestDate == null) {
                Log.w(TAG, "Day " + dayLabel + " no valid startTime found, skipping");
                continue;
            }
            
            // Normalize all events: extract time components and normalize relative to earliest date
            // Events on later calendar dates get +24 hours added
            Log.d(TAG, "Day " + dayLabel + " earliest date: " + 
                  earliestDate.get(Calendar.YEAR) + "-" + 
                  (earliestDate.get(Calendar.MONTH) + 1) + "-" + 
                  earliestDate.get(Calendar.DAY_OF_MONTH));
            
            for (ScheduleBlock event : sortedByTimeIndex) {
                if (event.startTime != null) {
                    Calendar eventCal = Calendar.getInstance();
                    eventCal.setTime(event.startTime);
                    
                    // Check if this event is on a later calendar date
                    boolean isNextDay = eventCal.get(Calendar.YEAR) > earliestDate.get(Calendar.YEAR) ||
                                       (eventCal.get(Calendar.YEAR) == earliestDate.get(Calendar.YEAR) &&
                                        eventCal.get(Calendar.DAY_OF_YEAR) > earliestDate.get(Calendar.DAY_OF_YEAR));
                    
                    int hour = eventCal.get(Calendar.HOUR_OF_DAY);
                    int minute = eventCal.get(Calendar.MINUTE);
                    
                    Calendar normCal = Calendar.getInstance();
                    normCal.set(2000, Calendar.JANUARY, 1, hour, minute, 0);
                    normCal.set(Calendar.MILLISECOND, 0);
                    
                    // If event is on next calendar day, add 24 hours to normalized time
                    if (isNextDay) {
                        normCal.add(Calendar.HOUR_OF_DAY, 24);
                        Log.d(TAG, "  Event " + event.bandName + " on next day: " + 
                              eventCal.get(Calendar.YEAR) + "-" + 
                              (eventCal.get(Calendar.MONTH) + 1) + "-" + 
                              eventCal.get(Calendar.DAY_OF_MONTH) + " " +
                              hour + ":" + minute + " -> normalized to " + normCal.getTime());
                    }
                    
                    event.startTime = normCal.getTime();
                }
                
                if (event.endTime != null) {
                    // Store original endTime before we modify startTime
                    Date originalEndTime = event.endTime;
                    Calendar eventCal = Calendar.getInstance();
                    eventCal.setTime(originalEndTime);
                    
                    // Check if endTime is on a later calendar date than the earliest date
                    boolean endIsNextDay = eventCal.get(Calendar.YEAR) > earliestDate.get(Calendar.YEAR) ||
                                         (eventCal.get(Calendar.YEAR) == earliestDate.get(Calendar.YEAR) &&
                                          eventCal.get(Calendar.DAY_OF_YEAR) > earliestDate.get(Calendar.DAY_OF_YEAR));
                    
                    int hour = eventCal.get(Calendar.HOUR_OF_DAY);
                    int minute = eventCal.get(Calendar.MINUTE);
                    
                    Calendar normCal = Calendar.getInstance();
                    normCal.set(2000, Calendar.JANUARY, 1, hour, minute, 0);
                    normCal.set(Calendar.MILLISECOND, 0);
                    
                    // If endTime is on next calendar day relative to earliest date, add 24 hours
                    if (endIsNextDay) {
                        normCal.add(Calendar.HOUR_OF_DAY, 24);
                    }
                    
                    Date normalizedEndTime = normCal.getTime();
                    
                    // Also ensure normalized endTime is after normalized startTime
                    // (event.startTime is now normalized from above)
                    if (event.startTime != null && normalizedEndTime.before(event.startTime)) {
                        normCal.setTime(normalizedEndTime);
                        normCal.add(Calendar.HOUR_OF_DAY, 24);
                        normalizedEndTime = normCal.getTime();
                    }
                    
                    event.endTime = normalizedEndTime;
                }
            }
            
            // Now use normalized first event's startTime as timeline start
            Date startTime = firstEvent.startTime;
            if (startTime == null) {
                Log.w(TAG, "Day " + dayLabel + " first event has null startTime after normalization, skipping");
                continue;
            }
            
            // Find latest normalized endTime
            Date endTime = null;
            
            for (ScheduleBlock event : sortedByTimeIndex) {
                if (event.startTime != null && event.endTime != null) {
                    Date eventEndTime = event.endTime;
                    
                    // Calculate end time relative to day's startTime
                    long endTimeOffsetFromStart = eventEndTime.getTime() - startTime.getTime();
                    
                    // If endTime is before startTime (shouldn't happen after normalization), add 24 hours
                    if (endTimeOffsetFromStart < 0) {
                        endTimeOffsetFromStart += (24 * 60 * 60 * 1000);
                    }
                    
                    // Calculate absolute end time
                    Calendar cal = Calendar.getInstance();
                    cal.setTime(startTime);
                    cal.add(Calendar.MILLISECOND, (int)endTimeOffsetFromStart);
                    Date calculatedEndTime = cal.getTime();
                    
                    // Cap at 24 hours from startTime
                    long calculatedDuration = calculatedEndTime.getTime() - startTime.getTime();
                    if (calculatedDuration > (24 * 60 * 60 * 1000)) {
                        cal.setTime(startTime);
                        cal.add(Calendar.HOUR_OF_DAY, 24);
                        calculatedEndTime = cal.getTime();
                    }
                    
                    // Find latest end time
                    if (endTime == null || calculatedEndTime.after(endTime)) {
                        endTime = calculatedEndTime;
                    }
                }
            }
            
            // Ensure endTime is within 24 hours of startTime
            if (endTime == null) {
                // Fallback: if no endTime found, use startTime + 1 hour
                Calendar cal = Calendar.getInstance();
                cal.setTime(startTime);
                cal.add(Calendar.HOUR_OF_DAY, 1);
                endTime = cal.getTime();
                Log.w(TAG, "Day " + dayLabel + " no endTime found, using startTime + 1 hour");
            } else {
                long totalDurationMs = endTime.getTime() - startTime.getTime();
                if (totalDurationMs > (24 * 60 * 60 * 1000)) {
                    Calendar cal = Calendar.getInstance();
                    cal.setTime(startTime);
                    cal.add(Calendar.HOUR_OF_DAY, 24);
                    endTime = cal.getTime();
                    Log.w(TAG, "Day " + dayLabel + " total duration exceeds 24 hours, capping at 24h");
                }
                
                // If endTime is before startTime (shouldn't happen after adjustments), add 24h
                if (endTime.before(startTime)) {
                    Calendar cal = Calendar.getInstance();
                    cal.setTime(endTime);
                    cal.add(Calendar.HOUR_OF_DAY, 24);
                    endTime = cal.getTime();
                }
            }
            
            Log.d(TAG, "Day " + dayLabel + " timeline: first event=" + firstEvent.bandName + 
                  " at timeIndex=" + firstEventTimeIndex + ", startTime=" + startTime + 
                  ", endTime=" + endTime + " (" + sortedByTimeIndex.size() + " events)");
            
            List<TimeSlot> timeSlots = generateTimeSlots(startTime, endTime);
            
            DayScheduleData dayData = new DayScheduleData();
            dayData.dayLabel = dayLabel;
            dayData.venues = venueColumns;
            dayData.timeSlots = timeSlots;
            dayData.startTime = startTime;
            dayData.endTime = endTime;
            // Store first event's timeIndex for sorting days chronologically
            dayData.baseTimeIndex = firstEventTimeIndex;
            
            result.add(dayData);
        }
        
        Collections.sort(result, (a, b) -> Double.compare(a.baseTimeIndex, b.baseTimeIndex));
        
        return result;
    }
    
    private ScheduleBlock createScheduleBlockFromHandler(String bandName, Long timeIndex, scheduleHandler scheduleHandle, int eventYear) {
        try {
            String location = scheduleHandle.getShowLocation();
            String startTimeStr = scheduleHandle.getStartTimeString();
            String endTimeStr = scheduleHandle.getEndTimeString();
            String eventType = scheduleHandle.getShowType();
            String day = scheduleHandle.getShowDay();
            
            if (bandName == null || location == null || startTimeStr == null) {
                return null;
            }
            
            // CRITICAL: timeIndex is stored in MILLISECONDS, convert to seconds for calculations
            double timeIndexDouble = timeIndex != null ? timeIndex.doubleValue() / 1000.0 : 0.0;
            
            // CRITICAL: Use the Date objects from scheduleHandler which include actual dates
            // These are set when the schedule is parsed and include both date and time
            Date startDate = scheduleHandle.getStartTime();
            Date endDate = scheduleHandle.getEndTime();
            
            // Fallback: if Date objects are null or invalid, parse from time strings
            if (startDate == null) {
                startDate = parseTimeToDate(startTimeStr);
            }
            if (endDate == null && endTimeStr != null && !endTimeStr.isEmpty()) {
                endDate = parseTimeToDate(endTimeStr);
                // If endDate is before startDate (crosses midnight), add 24 hours
                if (startDate != null && endDate.before(startDate)) {
                    Calendar cal = Calendar.getInstance();
                    cal.setTime(endDate);
                    cal.add(Calendar.HOUR_OF_DAY, 24);
                    endDate = cal.getTime();
                }
            }
            
            // Calculate endTimeIndex for expiration checking (timeIndexDouble is now in seconds)
            double endTimeIndex = timeIndexDouble;
            if (startDate != null && endDate != null) {
                long durationSeconds = (endDate.getTime() - startDate.getTime()) / 1000;
                endTimeIndex = timeIndexDouble + durationSeconds;
            }
            
            String rankIcon = rankStore.getRankForBand(bandName);
            int priority = getPriorityFromRankIcon(rankIcon);
            
            String attendedStatus = attendedHandle.getShowAttendedStatus(
                bandName, location, startTimeStr, 
                eventType != null ? eventType : "Performance",
                String.valueOf(eventYear)
            );
            
            // Always check if event is expired for styling purposes (darker colors)
            // hideExpiredEvents only controls filtering, not styling
            boolean isExpired = endTimeIndex <= (System.currentTimeMillis() / 1000.0);
            
            String venueColorHex = FestivalConfig.getInstance().getVenueColor(location);
            int venueColor = parseColorFromHex(venueColorHex);
            
            // Store the actual dates for later comparison - we'll normalize in processEventsFromScheduleRecords
            // after we know the earliest date in each day group
            Date normalizedStartDate = startDate;
            Date normalizedEndDate = endDate;
            
            ScheduleBlock block = new ScheduleBlock();
            block.bandName = bandName;
            // Store normalized times for positioning (all on same base date)
            block.startTime = normalizedStartDate;
            block.endTime = normalizedEndDate;
            block.startTimeString = startTimeStr;
            block.eventType = eventType != null ? eventType : "Performance";
            block.location = location;
            block.day = day;
            block.timeIndex = timeIndexDouble;
            block.priority = priority;
            block.attendedStatus = attendedStatus;
            block.isExpired = isExpired;
            block.venueColor = venueColor;
            
            return block;
        } catch (Exception e) {
            Log.e(TAG, "Error creating schedule block", e);
            return null;
        }
    }
    
    private List<String> getUniqueVenues(List<ScheduleBlock> events) {
        List<String> venues = new ArrayList<>();
        FestivalConfig config = FestivalConfig.getInstance();
        List<String> configuredVenues = config.getAllVenueNames();
        
        Map<String, Boolean> seen = new HashMap<>();
        List<String> configured = new ArrayList<>();
        List<String> unconfigured = new ArrayList<>();
        
        for (ScheduleBlock event : events) {
            if (!seen.containsKey(event.location)) {
                seen.put(event.location, true);
                if (configuredVenues.contains(event.location)) {
                    configured.add(event.location);
                } else {
                    unconfigured.add(event.location);
                }
            }
        }
        
        Collections.sort(configured, (a, b) -> {
            int indexA = configuredVenues.indexOf(a);
            int indexB = configuredVenues.indexOf(b);
            return Integer.compare(indexA, indexB);
        });
        
        Collections.sort(unconfigured);
        
        venues.addAll(configured);
        venues.addAll(unconfigured);
        
        return venues;
    }
    
    private List<TimeSlot> generateTimeSlots(Date startTime, Date endTime) {
        List<TimeSlot> slots = new ArrayList<>();
        
        if (startTime == null || endTime == null) {
            Log.w(TAG, "generateTimeSlots: startTime or endTime is null");
            return slots;
        }
        
        // Handle midnight crossover: if endTime is before startTime, it means it's the next day
        // In this case, endTime should already be adjusted (startTime + 24+ hours)
        // But if it's not, we need to check
        Date adjustedEndTime = endTime;
        if (endTime.before(startTime)) {
            Calendar cal = Calendar.getInstance();
            cal.setTime(endTime);
            cal.add(Calendar.HOUR_OF_DAY, 24);
            adjustedEndTime = cal.getTime();
            Log.d(TAG, "generateTimeSlots: endTime before startTime, adjusted endTime from " + 
                  endTime + " to " + adjustedEndTime);
        }
        
        if (startTime.after(adjustedEndTime)) {
            Log.w(TAG, "generateTimeSlots: startTime is still after adjustedEndTime - " + 
                  "startTime=" + startTime + ", adjustedEndTime=" + adjustedEndTime);
            return slots;
        }
        
        Calendar cal = Calendar.getInstance();
        cal.setTime(startTime);
        
        int currentHour = cal.get(Calendar.HOUR_OF_DAY);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        
        if (cal.getTime().after(startTime)) {
            cal.add(Calendar.HOUR_OF_DAY, -1);
        }
        
        // Respect OS 24-hour setting for time column labels (like list view)
        final SimpleDateFormat hourFormatter;
        if (DateFormat.is24HourFormat(context)) {
            hourFormatter = new SimpleDateFormat("H:mm", Locale.getDefault());
        } else {
            hourFormatter = new SimpleDateFormat("h:mma", Locale.getDefault());
        }
        SimpleDateFormat quarterFormatter = new SimpleDateFormat(":mm", Locale.getDefault());
        
        int maxIterations = 1000;
        int iterations = 0;
        
        // Use adjustedEndTime for the loop
        while (!cal.getTime().after(adjustedEndTime) && iterations < maxIterations) {
            TimeSlot slot = new TimeSlot();
            slot.time = cal.getTime();
            
            int minute = cal.get(Calendar.MINUTE);
            if (minute == 0) {
                String label = hourFormatter.format(cal.getTime());
                slot.label = DateFormat.is24HourFormat(context) ? label : label.toLowerCase();
            } else {
                slot.label = quarterFormatter.format(cal.getTime());
            }
            
            slots.add(slot);
            cal.add(Calendar.MINUTE, 15);
            iterations++;
        }
        
        return slots;
    }
    
    private Date parseTimeToDate(String timeStr) {
        // Legacy method - uses fixed base date (Jan 1, 2000)
        // Use parseTimeToDateWithBaseDate for date-aware parsing
        if (timeStr == null || timeStr.isEmpty()) {
            return null;
        }
        
        try {
            String[] parts = timeStr.split(":");
            if (parts.length == 0) {
                return null;
            }
            
            int hours = Integer.parseInt(parts[0]);
            int minutes = parts.length > 1 ? Integer.parseInt(parts[1]) : 0;
            
            Calendar cal = Calendar.getInstance();
            cal.set(2000, Calendar.JANUARY, 1, hours, minutes, 0);
            cal.set(Calendar.MILLISECOND, 0);
            return cal.getTime();
        } catch (Exception e) {
            Log.e(TAG, "parseTimeToDate: Error parsing " + timeStr, e);
            return null;
        }
    }
    
    /**
     * Parse time string using the actual date from timeIndex
     * This preserves both date and time information
     */
    private Date parseTimeToDateWithBaseDate(String timeStr, Calendar baseDate) {
        if (timeStr == null || timeStr.isEmpty()) {
            return null;
        }
        
        try {
            String[] parts = timeStr.split(":");
            if (parts.length == 0) {
                return null;
            }
            
            int hours = Integer.parseInt(parts[0]);
            int minutes = parts.length > 1 ? Integer.parseInt(parts[1]) : 0;
            
            // Use the actual date from timeIndex, but set the time from the time string
            Calendar cal = (Calendar) baseDate.clone();
            cal.set(Calendar.HOUR_OF_DAY, hours);
            cal.set(Calendar.MINUTE, minutes);
            cal.set(Calendar.SECOND, 0);
            cal.set(Calendar.MILLISECOND, 0);
            
            return cal.getTime();
        } catch (Exception e) {
            Log.e(TAG, "parseTimeToDateWithBaseDate: Error parsing " + timeStr, e);
            return null;
        }
    }
    
    private int parseColorFromHex(String hex) {
        try {
            String cleanHex = hex.replace("#", "");
            if (cleanHex.length() == 6) {
                return Color.parseColor("#" + cleanHex);
            } else {
                return Color.parseColor("#" + cleanHex);
            }
        } catch (Exception e) {
            return Color.GRAY;
        }
    }
    
    private int getPriorityFromRankIcon(String rankIcon) {
        if (rankIcon == null || rankIcon.isEmpty()) {
            return 0;
        } else if (rankIcon.equals(staticVariables.mustSeeIcon)) {
            return 1;
        } else if (rankIcon.equals(staticVariables.mightSeeIcon)) {
            return 2;
        } else if (rankIcon.equals(staticVariables.wontSeeIcon)) {
            return 3;
        } else {
            return 0;
        }
    }
    
    /**
     * Style an AlertDialog to match the dark theme of the app
     */
    private void styleDialogForDarkTheme(android.app.AlertDialog dialog) {
        // Set dark background
        dialog.getWindow().setBackgroundDrawableResource(android.R.color.black);
        
        // Style title
        int titleId = context.getResources().getIdentifier("alertTitle", "id", "android");
        if (titleId != 0) {
            TextView titleView = dialog.findViewById(titleId);
            if (titleView != null) {
                titleView.setTextColor(Color.WHITE);
            }
        }
        
        // Style list items (band names)
        android.widget.ListView listView = dialog.getListView();
        if (listView != null) {
            listView.setBackgroundColor(Color.BLACK);
            listView.setDivider(null); // Remove divider for cleaner look
            
            // Set text color for list items
            android.widget.Adapter adapter = listView.getAdapter();
            if (adapter != null) {
                // We'll need to set text color when items are created
                // For now, we'll use a custom adapter or style after creation
            }
        }
        
        // Style buttons
        dialog.setOnShowListener(new android.content.DialogInterface.OnShowListener() {
            @Override
            public void onShow(android.content.DialogInterface dialogInterface) {
                android.app.AlertDialog alertDialog = (android.app.AlertDialog) dialogInterface;
                
                // Style negative button (Cancel)
                android.widget.Button negativeButton = alertDialog.getButton(android.app.AlertDialog.BUTTON_NEGATIVE);
                if (negativeButton != null) {
                    negativeButton.setTextColor(Color.WHITE);
                    negativeButton.setBackgroundColor(Color.TRANSPARENT);
                }
                
                // Style list items text color
                android.widget.ListView listView = alertDialog.getListView();
                if (listView != null) {
                    for (int i = 0; i < listView.getChildCount(); i++) {
                        View child = listView.getChildAt(i);
                        if (child instanceof TextView) {
                            ((TextView) child).setTextColor(Color.WHITE);
                        } else if (child instanceof ViewGroup) {
                            // Find TextView inside the child view
                            TextView textView = findTextViewInViewGroup((ViewGroup) child);
                            if (textView != null) {
                                textView.setTextColor(Color.WHITE);
                            }
                        }
                    }
                }
            }
        });
    }
    
    /**
     * Helper method to find TextView in a ViewGroup recursively
     */
    private TextView findTextViewInViewGroup(ViewGroup viewGroup) {
        for (int i = 0; i < viewGroup.getChildCount(); i++) {
            View child = viewGroup.getChildAt(i);
            if (child instanceof TextView) {
                return (TextView) child;
            } else if (child instanceof ViewGroup) {
                TextView found = findTextViewInViewGroup((ViewGroup) child);
                if (found != null) {
                    return found;
                }
            }
        }
        return null;
    }
    
    /**
     * Build a unique key for an event based on date, startTime, endTime, location, and eventType
     * Used to identify duplicate events (same time/location/type, different band)
     */
    private String buildEventKey(ScheduleBlock event) {
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd", Locale.US);
        SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.US);
        
        String dateStr = event.startTime != null ? dateFormat.format(event.startTime) : "";
        String startTimeStr = event.startTime != null ? timeFormat.format(event.startTime) : "";
        String endTimeStr = event.endTime != null ? timeFormat.format(event.endTime) : "";
        String location = event.location != null ? event.location : "";
        String eventType = event.eventType != null ? event.eventType : "";
        
        return dateStr + "|" + startTimeStr + "|" + endTimeStr + "|" + location + "|" + eventType;
    }
    
    /**
     * Add a priority icon to a layout
     */
    private void addPriorityIcon(LinearLayout parent, int priority, boolean shouldDim) {
        if (priority <= 0) return;
        
        ImageView priorityIcon = new ImageView(context);
        int priorityResId = 0;
        if (priority == 1) {
            priorityResId = staticVariables.graphicMustSee;
        } else if (priority == 2) {
            priorityResId = staticVariables.graphicMightSee;
        } else if (priority == 3) {
            priorityResId = staticVariables.graphicWontSee;
        }
        
        if (priorityResId != 0) {
            priorityIcon.setImageResource(priorityResId);
            priorityIcon.setLayoutParams(new FrameLayout.LayoutParams(dpToPx(14), dpToPx(14), Gravity.CENTER));
            priorityIcon.setAlpha(shouldDim ? 0.4f : 1.0f);
            
            FrameLayout iconContainer = new FrameLayout(context);
            iconContainer.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(18), dpToPx(18)));
            
            float greyValue = (priority == 3) ? 0.75f : 0.2f;
            if (shouldDim) {
                greyValue *= 0.5f;
            }
            int greyColor = Color.rgb((int)(greyValue * 255), (int)(greyValue * 255), (int)(greyValue * 255));
            android.graphics.drawable.GradientDrawable circleBackground = new android.graphics.drawable.GradientDrawable();
            circleBackground.setShape(android.graphics.drawable.GradientDrawable.OVAL);
            circleBackground.setColor(greyColor);
            iconContainer.setBackground(circleBackground);
            iconContainer.setElevation(2f);
            
            iconContainer.addView(priorityIcon);
            parent.addView(iconContainer);
        }
    }
    
    /**
     * Add an attended icon to a layout
     */
    private void addAttendedIcon(LinearLayout parent, String attendedStatus, boolean shouldDim) {
        if (attendedStatus == null || attendedStatus.isEmpty() || attendedStatus.equals("sawNone")) {
            return;
        }
        
        int attendedResId = iconResolve.getAttendedIcon(attendedStatus);
        if (attendedResId != 0) {
            ImageView attendedIcon = new ImageView(context);
            attendedIcon.setImageResource(attendedResId);
            attendedIcon.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(14), dpToPx(14)));
            attendedIcon.setAlpha(shouldDim ? 0.4f : 1.0f);
            parent.addView(attendedIcon);
        }
    }
    
    /**
     * Add normal icon row (priority and attended on same line) for single events
     */
    private void addNormalIconRow(LinearLayout eventBlock, ScheduleBlock event, boolean shouldDim) {
        LinearLayout iconRow = new LinearLayout(context);
        iconRow.setOrientation(LinearLayout.HORIZONTAL);
        iconRow.setPadding(0, dpToPx(2), 0, 0);
        
        // Priority icon
        if (event.priority > 0) {
            addPriorityIcon(iconRow, event.priority, shouldDim);
            
            // Add spacing between icons
            View spacer = new View(context);
            spacer.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(3), 1));
            iconRow.addView(spacer);
        }
        
        // Attended icon
        addAttendedIcon(iconRow, event.attendedStatus, shouldDim);
        
        eventBlock.addView(iconRow);
    }
    
    private List<DayScheduleData> filterExpiredDays(List<DayScheduleData> days) {
        List<DayScheduleData> filtered = new ArrayList<>();
        for (DayScheduleData day : days) {
            boolean hasActiveEvent = false;
            for (VenueColumn venue : day.venues) {
                for (ScheduleBlock event : venue.events) {
                    if (!event.isExpired) {
                        hasActiveEvent = true;
                        break;
                    }
                }
                if (hasActiveEvent) break;
            }
            if (hasActiveEvent) {
                filtered.add(day);
            }
        }
        return filtered;
    }
    
    // Inner classes for data models
    static class DayScheduleData {
        String dayLabel;
        List<VenueColumn> venues;
        List<TimeSlot> timeSlots;
        Date startTime;
        Date endTime;
        double baseTimeIndex;
    }
    
    static class VenueColumn {
        String name;
        int color;
        List<ScheduleBlock> events;
    }
    
    static class ScheduleBlock {
        String bandName;
        Date startTime;
        Date endTime;
        String startTimeString;
        String eventType;
        String location;
        String day;
        double timeIndex;
        int priority;
        String attendedStatus;
        boolean isExpired;
        int venueColor;
    }
    
    static class TimeSlot {
        Date time;
        String label;
    }
}
