package com.Bands70k.landscape;

import android.content.Context;
import android.graphics.Color;
import android.util.AttributeSet;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.ScrollView;
import android.widget.ImageView;
import android.widget.TextView;
import com.Bands70k.BandInfo;
import com.Bands70k.FestivalConfig;
import com.Bands70k.iconResolve;
import com.Bands70k.showsAttended;
import com.Bands70k.staticVariables;
import com.Bands70k.scheduleHandler;
import com.Bands70k.scheduleTimeTracker;
import com.Bands70k.scheduleInfo;
import com.Bands70k.rankStore;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Date;
import java.util.Locale;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * SIMPLIFIED landscape schedule view - basic views with simple click listeners
 */
public class LandscapeScheduleView extends LinearLayout {
    
    private static final String TAG = "LandscapeScheduleView";
    
    private Context context;
    private String initialDay;
    private boolean hideExpiredEvents;
    
    // Simple data storage
    private List<DayScheduleData> days = new ArrayList<>();
    private int currentDayIndex = 0;
    private OnBandTappedListener bandTappedListener;
    private showsAttended attendedHandle;
    
    // Simple UI components
    private LinearLayout headerLayout;
    private Button prevButton;
    private Button nextButton;
    private TextView dayLabel;
    private ScrollView contentScrollView;
    private LinearLayout contentLayout;
    
    public interface OnBandTappedListener {
        void onBandTapped(String bandName, String currentDay);
    }
    
    public LandscapeScheduleView(Context context) {
        super(context);
        this.context = context;
        init();
    }
    
    public LandscapeScheduleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.context = context;
        init();
    }
    
    public LandscapeScheduleView(Context context, String initialDay, boolean hideExpiredEvents, boolean isSplitViewCapable) {
        super(context);
        this.context = context;
        this.initialDay = initialDay;
        this.hideExpiredEvents = hideExpiredEvents;
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
    
    private void createHeader() {
        headerLayout = new LinearLayout(context);
        headerLayout.setOrientation(LinearLayout.HORIZONTAL);
        headerLayout.setGravity(Gravity.CENTER); // Center the nav group
        // Add extra top padding to avoid system UI, reduced horizontal padding to keep buttons close to center
        headerLayout.setPadding(dpToPx(16), dpToPx(48), dpToPx(16), dpToPx(16));
        headerLayout.setBackgroundColor(Color.BLACK);
        // Don't intercept touches - let buttons handle them
        headerLayout.setClickable(false);
        headerLayout.setFocusable(false);
        
        // Container to group buttons and label together so they stay close
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
        // CRITICAL: Ensure button is clickable
        prevButton.setClickable(true);
        prevButton.setFocusable(true);
        prevButton.setFocusableInTouchMode(true);
        prevButton.setEnabled(true);
        LinearLayout.LayoutParams prevParams = new LinearLayout.LayoutParams(
            dpToPx(32), dpToPx(32) // Smaller buttons like iOS (32dp)
        );
        prevParams.setMargins(0, 0, dpToPx(1), 0); // Minimal spacing from label (1dp)
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
        
        // Day label - wrap content, no weight so buttons stay close
        dayLabel = new TextView(context);
        dayLabel.setText("Loading...");
        dayLabel.setTextColor(Color.WHITE);
        dayLabel.setTextSize(20);
        dayLabel.setTypeface(null, android.graphics.Typeface.BOLD);
        dayLabel.setGravity(Gravity.CENTER);
        dayLabel.setClickable(false);
        dayLabel.setFocusable(false);
        LinearLayout.LayoutParams labelParams = new LinearLayout.LayoutParams(
            LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT // Wrap content, don't expand
        );
        labelParams.setMargins(dpToPx(1), 0, dpToPx(1), 0); // Minimal spacing from buttons (1dp)
        dayLabel.setLayoutParams(labelParams);
        
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
        // CRITICAL: Ensure button is clickable
        nextButton.setClickable(true);
        nextButton.setFocusable(true);
        nextButton.setFocusableInTouchMode(true);
        nextButton.setEnabled(true);
        LinearLayout.LayoutParams nextParams = new LinearLayout.LayoutParams(
            dpToPx(32), dpToPx(32) // Smaller buttons like iOS (32dp)
        );
        nextParams.setMargins(dpToPx(1), 0, 0, 0); // Minimal spacing from label (1dp)
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
        navGroup.addView(dayLabel);
        navGroup.addView(nextButton);
        
        // Add the nav group to header layout (centered as a single unit)
        headerLayout.addView(navGroup);
        
        addView(headerLayout);
        
        // Debug: Log button properties
        Log.d(TAG, "Header created - prevButton clickable=" + prevButton.isClickable() + 
              ", enabled=" + prevButton.isEnabled() + ", visibility=" + prevButton.getVisibility());
        Log.d(TAG, "Header created - nextButton clickable=" + nextButton.isClickable() + 
              ", enabled=" + nextButton.isEnabled() + ", visibility=" + nextButton.getVisibility());
    }
    
    private android.graphics.drawable.Drawable getRoundedBackground(int color) {
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
        drawable.setColor(color);
        drawable.setCornerRadius(dpToPx(6)); // 6dp corner radius like iOS
        return drawable;
    }
    
    private HorizontalScrollView venueHeaderScrollView; // Fixed header row container
    private LinearLayout venueHeaderRow; // Fixed header row for venue names
    
    private void createContentArea() {
        // Create fixed venue header row (outside scroll view, but can scroll horizontally)
        venueHeaderScrollView = new HorizontalScrollView(context);
        venueHeaderScrollView.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT
        ));
        venueHeaderScrollView.setHorizontalScrollBarEnabled(false);
        // Don't intercept touches - let scroll view handle them
        venueHeaderScrollView.setClickable(false);
        venueHeaderScrollView.setFocusable(false);
        // Ensure content doesn't get clipped
        venueHeaderScrollView.setClipChildren(false);
        venueHeaderScrollView.setClipToPadding(false);
        
        venueHeaderRow = new LinearLayout(context);
        venueHeaderRow.setOrientation(LinearLayout.HORIZONTAL);
        venueHeaderRow.setBackgroundColor(Color.BLACK);
        // Use WRAP_CONTENT to allow horizontal scrolling when needed
        LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(
            LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
        );
        venueHeaderRow.setLayoutParams(rowParams);
        // Enable clipping to ensure headers respect their height constraints
        venueHeaderRow.setClipChildren(true);
        venueHeaderRow.setClipToPadding(true);
        venueHeaderScrollView.addView(venueHeaderRow);
        
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
        
        // Ensure views are visible
        venueHeaderScrollView.setVisibility(View.VISIBLE);
        contentScrollView.setVisibility(View.VISIBLE);
        
        // Add venue header row first, then scroll view
        addView(venueHeaderScrollView);
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
                    
                    days = processEventsFromScheduleRecords();
                    
                    if (hideExpiredEvents) {
                        days = filterExpiredDays(days);
                    }
                    
                    if (initialDay != null) {
                        Log.d(TAG, "Looking for initial day: '" + initialDay + "'");
                        Log.d(TAG, "Available days: " + days.size());
                        for (int i = 0; i < days.size(); i++) {
                            String dayLabel = days.get(i).dayLabel;
                            Log.d(TAG, "  Day " + i + ": '" + dayLabel + "'");
                            // Compare with trimming to handle any whitespace differences
                            if (dayLabel != null && dayLabel.trim().equals(initialDay.trim())) {
                                currentDayIndex = i;
                                Log.d(TAG, "✅ Found matching day at index " + i);
                                break;
                            }
                        }
                        if (currentDayIndex == 0 && days.size() > 0) {
                            Log.w(TAG, "⚠️ Could not find matching day, defaulting to index 0 (day: '" + (days.isEmpty() ? "none" : days.get(0).dayLabel) + "')");
                        }
                    }
                    
                    post(new Runnable() {
                        @Override
                        public void run() {
                            updateDisplay();
                        }
                    });
                } catch (Exception e) {
                    Log.e(TAG, "Error loading schedule data", e);
                }
            }
        }).start();
    }
    
    private void updateDisplay() {
        Log.d(TAG, "updateDisplay: currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
        
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
        int screenWidth = getResources().getDisplayMetrics().widthPixels;
        int availableWidth = screenWidth - dpToPx(60); // Subtract time column width
        int columnWidth = currentDay.venues.isEmpty() ? availableWidth : availableWidth / currentDay.venues.size();
        
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
        
        // Create horizontal scroll container for venue columns
        HorizontalScrollView horizontalScroll = new HorizontalScrollView(context);
        horizontalScroll.setLayoutParams(new LinearLayout.LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT
        ));
        horizontalScroll.setHorizontalScrollBarEnabled(false);
        
        // Synchronize horizontal scrolling between header and content
        horizontalScroll.setOnScrollChangeListener(new View.OnScrollChangeListener() {
            @Override
            public void onScrollChange(View v, int scrollX, int scrollY, int oldScrollX, int oldScrollY) {
                venueHeaderScrollView.scrollTo(scrollX, 0);
            }
        });
        
        venueHeaderScrollView.setOnScrollChangeListener(new View.OnScrollChangeListener() {
            @Override
            public void onScrollChange(View v, int scrollX, int scrollY, int oldScrollX, int oldScrollY) {
                horizontalScroll.scrollTo(scrollX, 0);
            }
        });
        
        LinearLayout columnsContainer = new LinearLayout(context);
        columnsContainer.setOrientation(LinearLayout.HORIZONTAL);
        
        // Add time column first (without header) - pass header height for spacer
        LinearLayout timeColumn = createTimeColumn(currentDay, maxHeaderHeight);
        columnsContainer.addView(timeColumn);
        
        // Add venue columns (without headers) - pass header height for spacer
        for (VenueColumn venue : currentDay.venues) {
            LinearLayout venueColumn = createVenueColumn(venue, currentDay, columnWidth, maxHeaderHeight);
            columnsContainer.addView(venueColumn);
        }
        
        horizontalScroll.addView(columnsContainer);
        contentLayout.addView(horizontalScroll);
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
    
    private LinearLayout createVenueColumn(VenueColumn venue, DayScheduleData dayData, int columnWidth, int headerHeight) {
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
        
        // Add grid lines
        for (TimeSlot slot : dayData.timeSlots) {
            View gridLine = new View(context);
            gridLine.setBackgroundColor(Color.GRAY);
            RelativeLayout.LayoutParams gridParams = new RelativeLayout.LayoutParams(
                LayoutParams.MATCH_PARENT, 1
            );
            int yPos = calculateYPosition(slot.time, dayData);
            gridParams.topMargin = yPos;
            gridLine.setLayoutParams(gridParams);
            gridLine.setAlpha(0.2f);
            contentArea.addView(gridLine);
        }
        
        // Add event blocks
        for (ScheduleBlock event : venue.events) {
            View eventBlock = createEventBlock(event, columnWidth, dayData);
            contentArea.addView(eventBlock);
        }
        
        venueColumn.addView(contentArea);
        return venueColumn;
    }
    
    private View createEventBlock(ScheduleBlock event, int columnWidth, DayScheduleData dayData) {
        LinearLayout eventBlock = new LinearLayout(context);
        eventBlock.setOrientation(LinearLayout.VERTICAL);
        eventBlock.setPadding(dpToPx(4), dpToPx(4), dpToPx(4), dpToPx(4));
        eventBlock.setBackgroundColor(event.venueColor);
        eventBlock.setClickable(true);
        eventBlock.setFocusable(true);
        eventBlock.setFocusableInTouchMode(true);
        // Ensure event block can receive clicks
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
        // Use date-based positioning (normalized within the day)
        int yPosition = calculateYPosition(eventStartTime, dayData);
        
        RelativeLayout.LayoutParams params = new RelativeLayout.LayoutParams(
            columnWidth - dpToPx(4), blockHeight
        );
        params.leftMargin = dpToPx(2);
        // Position exactly at calculated Y position to align with time text
        params.topMargin = yPosition;
        eventBlock.setLayoutParams(params);
        
        // Line 1: Band name
        TextView bandName = new TextView(context);
        bandName.setText(event.bandName);
        bandName.setTextColor(event.isExpired ? Color.argb(102, 255, 255, 255) : Color.WHITE); // 40% opacity if expired
        bandName.setTextSize(11);
        bandName.setTypeface(null, android.graphics.Typeface.BOLD);
        bandName.setMaxLines(1);
        eventBlock.addView(bandName);
        
        // Line 2: Start time with label
        TextView startTimeText = new TextView(context);
        SimpleDateFormat timeFormat = new SimpleDateFormat("h:mma", Locale.US);
        if (event.startTime != null) {
            startTimeText.setText("Start: " + timeFormat.format(event.startTime).toLowerCase());
        }
        startTimeText.setTextColor(event.isExpired ? Color.argb(102, 255, 255, 255) : Color.WHITE);
        startTimeText.setTextSize(9);
        startTimeText.setMaxLines(1);
        eventBlock.addView(startTimeText);
        
        // Line 3: End time with label
        TextView endTimeText = new TextView(context);
        if (event.endTime != null) {
            endTimeText.setText("End: " + timeFormat.format(event.endTime).toLowerCase());
        }
        endTimeText.setTextColor(event.isExpired ? Color.argb(102, 255, 255, 255) : Color.WHITE);
        endTimeText.setTextSize(9);
        endTimeText.setMaxLines(1);
        eventBlock.addView(endTimeText);
        
        // Line 4: Priority and Attended icons in horizontal layout
        LinearLayout iconRow = new LinearLayout(context);
        iconRow.setOrientation(LinearLayout.HORIZONTAL);
        iconRow.setPadding(0, dpToPx(2), 0, 0);
        
        // Priority icon (Must/Might/Won't see)
        if (event.priority > 0) {
            ImageView priorityIcon = new ImageView(context);
            int priorityResId = 0;
            if (event.priority == 1) {
                priorityResId = staticVariables.graphicMustSee;
            } else if (event.priority == 2) {
                priorityResId = staticVariables.graphicMightSee;
            } else if (event.priority == 3) {
                priorityResId = staticVariables.graphicWontSee;
            }
            
            if (priorityResId != 0) {
                priorityIcon.setImageResource(priorityResId);
                priorityIcon.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(14), dpToPx(14)));
                priorityIcon.setAlpha(event.isExpired ? 0.4f : 1.0f);
                iconRow.addView(priorityIcon);
                
                // Add spacing between icons
                View spacer = new View(context);
                spacer.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(3), 1));
                iconRow.addView(spacer);
            }
        }
        
        // Attended icon
        if (event.attendedStatus != null && !event.attendedStatus.isEmpty() && 
            !event.attendedStatus.equals("sawNone")) {
            int attendedResId = iconResolve.getAttendedIcon(event.attendedStatus);
            Log.d(TAG, "Attended icon check: band=" + event.bandName + ", status=" + event.attendedStatus + ", resId=" + attendedResId);
            if (attendedResId != 0) {
                ImageView attendedIcon = new ImageView(context);
                attendedIcon.setImageResource(attendedResId);
                attendedIcon.setLayoutParams(new LinearLayout.LayoutParams(dpToPx(14), dpToPx(14)));
                attendedIcon.setAlpha(event.isExpired ? 0.4f : 1.0f);
                iconRow.addView(attendedIcon);
            } else {
                Log.d(TAG, "Attended icon not shown: resId is 0 for status=" + event.attendedStatus);
            }
        } else {
            Log.d(TAG, "Attended icon not shown: status=" + (event.attendedStatus != null ? event.attendedStatus : "null"));
        }
        
        eventBlock.addView(iconRow);
        
        // Simple click listener - NO complex touch handling
        final ScheduleBlock eventData = event;
        eventBlock.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "Event clicked: " + eventData.bandName);
                Log.d(TAG, "  bandTappedListener=" + (bandTappedListener != null ? "NOT NULL" : "NULL"));
                Log.d(TAG, "  currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
                
                if (bandTappedListener == null) {
                    Log.e(TAG, "ERROR: bandTappedListener is NULL - cannot open details!");
                    return;
                }
                
                if (currentDayIndex < 0 || currentDayIndex >= days.size()) {
                    Log.e(TAG, "ERROR: Invalid currentDayIndex=" + currentDayIndex + ", days.size()=" + days.size());
                    return;
                }
                
                DayScheduleData currentDay = days.get(currentDayIndex);
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
        
        return eventBlock;
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
            
            List<VenueColumn> venueColumns = new ArrayList<>();
            for (String venueName : venues) {
                List<ScheduleBlock> venueEvents = new ArrayList<>();
                for (ScheduleBlock block : dayEvents) {
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
            
            double timeIndexDouble = timeIndex != null ? timeIndex.doubleValue() : 0.0;
            
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
            
            // Calculate endTimeIndex for expiration checking
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
            
            boolean isExpired = hideExpiredEvents && endTimeIndex <= (System.currentTimeMillis() / 1000.0);
            
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
        
        SimpleDateFormat hourFormatter = new SimpleDateFormat("h:mma", Locale.US);
        SimpleDateFormat quarterFormatter = new SimpleDateFormat(":mm", Locale.US);
        
        int maxIterations = 1000;
        int iterations = 0;
        
        // Use adjustedEndTime for the loop
        while (!cal.getTime().after(adjustedEndTime) && iterations < maxIterations) {
            TimeSlot slot = new TimeSlot();
            slot.time = cal.getTime();
            
            int minute = cal.get(Calendar.MINUTE);
            if (minute == 0) {
                slot.label = hourFormatter.format(cal.getTime()).toLowerCase();
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
