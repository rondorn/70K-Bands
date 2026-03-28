package com.Bands70k;

import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;
import android.widget.ImageButton;

import java.util.List;

/**
 * Landscape schedule calendar flow extracted from {@link showBands}: orientation checks,
 * tablet calendar button, presenting {@link com.Bands70k.landscape.LandscapeScheduleActivity},
 * and list day sync. State that only this feature needs lives here.
 */
public final class ShowBandsLandscapeCoordinator {

    public static final int REQUEST_CODE_LANDSCAPE_SCHEDULE = 2001;

    private final showBands host;

    private boolean isShowingLandscapeSchedule = false;
    private String currentViewingDay = null;
    private boolean isManualCalendarView = false;

    public ShowBandsLandscapeCoordinator(showBands host) {
        this.host = host;
    }

    public boolean isShowingLandscapeSchedule() {
        return isShowingLandscapeSchedule;
    }

    public void setShowingLandscapeSchedule(boolean showing) {
        isShowingLandscapeSchedule = showing;
    }

    public String getCurrentViewingDay() {
        return currentViewingDay;
    }

    public void setCurrentViewingDay(String day) {
        currentViewingDay = day;
    }

    public boolean isManualCalendarView() {
        return isManualCalendarView;
    }

    public void setManualCalendarView(boolean manual) {
        isManualCalendarView = manual;
    }

    public boolean isSplitViewCapable() {
        return DeviceSizeManager.getInstance(host).isLargeDisplay();
    }

    private boolean isRotationViewOffered() {
        if (!staticVariables.preferences.getShowScheduleView()) {
            return false;
        }
        if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
            return false;
        }
        boolean hideExpired = staticVariables.preferences.getHideExpiredEvents();
        return !hideExpired || !areAllEventsExpired();
    }

    public void updateCalendarButtonVisibility() {
        ImageButton calendarViewButton = (ImageButton) host.findViewById(R.id.calendarViewButton);
        if (calendarViewButton == null) return;
        if (isSplitViewCapable()) {
            calendarViewButton.setVisibility(View.VISIBLE);
            boolean rotationOffered = isRotationViewOffered();
            calendarViewButton.setEnabled(rotationOffered);
            calendarViewButton.setAlpha(rotationOffered ? 1.0f : 0.4f);
            calendarViewButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (!isRotationViewOffered()) return;
                    Log.d("LANDSCAPE_SCHEDULE", "📱 [TABLET_TOGGLE] Calendar button tapped in list view");
                    presentLandscapeScheduleView();
                }
            });
        } else {
            calendarViewButton.setVisibility(View.GONE);
        }
    }

    public void recheckLandscapeScheduleAfterFilterChange() {
        checkOrientationAndShowLandscapeIfNeeded(true);
    }

    public void checkOrientationAndShowLandscapeIfNeeded() {
        checkOrientationAndShowLandscapeIfNeeded(false);
    }

    public void checkOrientationAndShowLandscapeIfNeeded(boolean fromFilterChange) {
        if (!fromFilterChange && !host.hasWindowFocus()) {
            Log.d("LANDSCAPE_SCHEDULE", "checkOrientationAndShowLandscapeIfNeeded - no window focus, skipping (detail screen likely showing)");
            return;
        }

        boolean isScheduleView = staticVariables.preferences.getShowScheduleView();

        boolean isTablet = isSplitViewCapable();
        Log.d("LANDSCAPE_SCHEDULE", "Device check - isTablet: " + isTablet + ", Schedule View: " + isScheduleView + ", Manual Calendar View: " + isManualCalendarView);

        if (isTablet) {
            Log.d("LANDSCAPE_SCHEDULE", "[TABLET_TOGGLE] Tablet detected - manual toggle behavior");
            return;
        }

        Log.d("LANDSCAPE_SCHEDULE", "[PHONE_MODE] Phone detected - using orientation-based switching");

        int orientation = host.getResources().getConfiguration().orientation;
        boolean isLandscape = orientation == Configuration.ORIENTATION_LANDSCAPE;

        DisplayMetrics displayMetrics = host.getResources().getDisplayMetrics();
        int displayWidth = displayMetrics.widthPixels;
        int displayHeight = displayMetrics.heightPixels;

        android.view.View decorView = host.getWindow().getDecorView();
        int windowWidth = decorView.getWidth();
        int windowHeight = decorView.getHeight();

        int width = (windowWidth > 0) ? windowWidth : displayWidth;
        int height = (windowHeight > 0) ? windowHeight : displayHeight;
        boolean isLandscapeBySize = width > height;

        Log.d("LANDSCAPE_SCHEDULE", "Orientation check - config orientation: " + orientation + " (" + (orientation == Configuration.ORIENTATION_LANDSCAPE ? "LANDSCAPE" : "PORTRAIT") +
                "), display metrics: " + displayWidth + "x" + displayHeight +
                ", window size: " + windowWidth + "x" + windowHeight +
                ", using: " + width + "x" + height +
                ", size-based landscape: " + isLandscapeBySize);

        isLandscape = isLandscape || isLandscapeBySize;

        boolean hasRenderableScheduleEvents = false;
        if (host.listHandler != null && host.listHandler.numberOfEvents > 0) {
            hasRenderableScheduleEvents = true;
        } else if (host.scheduleSortedBandNames != null && !host.scheduleSortedBandNames.isEmpty()) {
            for (String item : host.scheduleSortedBandNames) {
                Long t = host.getTimeIndexFromIndex(item);
                if (t != null && t > 0) {
                    hasRenderableScheduleEvents = true;
                    break;
                }
            }
        }

        boolean hideExpired = staticVariables.preferences.getHideExpiredEvents();
        boolean showCalendarInLandscape = isLandscape && isScheduleView && hasRenderableScheduleEvents;

        Log.d("LANDSCAPE_SCHEDULE", "Check orientation - Landscape: " + isLandscape + ", Schedule View: " + isScheduleView + ", HideExpired: " + hideExpired + ", HasRenderableScheduleEvents: " + hasRenderableScheduleEvents + ", listHandler.numberOfEvents: " + (host.listHandler != null ? host.listHandler.numberOfEvents : "null") + ", Bands Count: " + (host.bandNames != null ? host.bandNames.size() : 0));

        if (host.bandNames != null && !host.bandNames.isEmpty()) {
            int sampleSize = Math.min(5, host.bandNames.size());
            for (int i = 0; i < sampleSize; i++) {
                Log.d("LANDSCAPE_SCHEDULE", "Band entry " + i + ": " + host.bandNames.get(i));
            }
        }

        if (showCalendarInLandscape) {
            Log.d("LANDSCAPE_SCHEDULE", "✅ Conditions met - launching landscape schedule view (Landscape: " + isLandscape + ", ScheduleView: " + isScheduleView + ", HideExpired: " + hideExpired + ", hasEvents: " + hasRenderableScheduleEvents + ")");
            updateCurrentViewingDayFromVisibleCells();
            presentLandscapeScheduleView(fromFilterChange, false);
        } else {
            Log.d("LANDSCAPE_SCHEDULE", "❌ Conditions NOT met - Landscape: " + isLandscape + ", ScheduleView: " + isScheduleView + ", HideExpired: " + hideExpired + ", HasRenderableScheduleEvents: " + hasRenderableScheduleEvents);
            isShowingLandscapeSchedule = false;
        }
    }

    public void updateCurrentViewingDayFromVisibleCells() {
        if (host.bandNamesList == null) {
            Log.w("LANDSCAPE_SCHEDULE", "Cannot update day - bandNamesList is null");
            return;
        }

        if (host.adapter == null || !(host.adapter instanceof bandListView)) {
            Log.w("LANDSCAPE_SCHEDULE", "Cannot update day - adapter is null or not bandListView, it's: " + (host.adapter != null ? host.adapter.getClass().getName() : "null"));
            return;
        }
        bandListView bandAdapter = host.adapter;

        int adapterCount = bandAdapter.getCount();
        int firstVisiblePosition = host.bandNamesList.getFirstVisiblePosition();
        int lastVisiblePosition = host.bandNamesList.getLastVisiblePosition();

        Log.d("LANDSCAPE_SCHEDULE", "Updating day from visible cells - firstVisible: " + firstVisiblePosition + ", lastVisible: " + lastVisiblePosition + ", adapterCount: " + adapterCount + ", currentViewingDay: " + currentViewingDay);

        if (firstVisiblePosition >= 0 && firstVisiblePosition < adapterCount) {
            String expectedDay = currentViewingDay;
            boolean hasExpectedDay = (expectedDay != null && !expectedDay.isEmpty());

            if (hasExpectedDay) {
                int maxForward = Math.min(50, adapterCount - firstVisiblePosition);
                Log.d("LANDSCAPE_SCHEDULE", "currentViewingDay is set to '" + expectedDay + "', searching forward " + maxForward + " positions from " + firstVisiblePosition + " to find expected day");
                for (int i = 0; i < maxForward; i++) {
                    int position = firstVisiblePosition + i;
                    try {
                        bandListItem item = bandAdapter.getItem(position);
                        String rawDay = extractRawDayFromBandListItem(item);
                        if (rawDay != null && !rawDay.isEmpty()) {
                            if (rawDay.trim().equals(expectedDay.trim())) {
                                currentViewingDay = rawDay;
                                Log.d("LANDSCAPE_SCHEDULE", "✅ Found expected day '" + rawDay + "' at position " + position + " (was at boundary)");
                                return;
                            }
                        }
                    } catch (Exception e) {
                        // Continue searching
                    }
                }
                Log.d("LANDSCAPE_SCHEDULE", "Expected day '" + expectedDay + "' not found forward, using normal detection logic");
            }

            try {
                bandListItem item = bandAdapter.getItem(firstVisiblePosition);
                String rawDay = extractRawDayFromBandListItem(item);
                if (rawDay != null && !rawDay.isEmpty()) {
                    currentViewingDay = rawDay;
                    Log.d("LANDSCAPE_SCHEDULE", "✅ Updated viewing day from TOPMOST visible entry at position " + firstVisiblePosition + ": '" + currentViewingDay + "'");
                    return;
                }
            } catch (Exception e) {
                Log.d("LANDSCAPE_SCHEDULE", "Error getting topmost item at position " + firstVisiblePosition + ": " + e.getMessage());
            }

            int maxForward = Math.min(50, adapterCount - firstVisiblePosition);
            Log.d("LANDSCAPE_SCHEDULE", "Topmost entry has no day, searching forward " + maxForward + " positions from " + firstVisiblePosition);
            for (int i = 1; i < maxForward; i++) {
                int position = firstVisiblePosition + i;
                try {
                    bandListItem item = bandAdapter.getItem(position);
                    String rawDay = extractRawDayFromBandListItem(item);
                    if (rawDay != null && !rawDay.isEmpty()) {
                        currentViewingDay = rawDay;
                        Log.d("LANDSCAPE_SCHEDULE", "✅ Updated viewing day from forward search at position " + position + ": '" + currentViewingDay + "' (topmost was at " + firstVisiblePosition + ")");
                        return;
                    }
                } catch (Exception e) {
                    // Continue searching
                }
            }

            int maxBackward = Math.min(100, firstVisiblePosition);
            Log.d("LANDSCAPE_SCHEDULE", "Forward search failed, searching backwards " + maxBackward + " positions from " + firstVisiblePosition);
            for (int i = 1; i <= maxBackward; i++) {
                int position = firstVisiblePosition - i;
                if (position >= 0) {
                    try {
                        bandListItem item = bandAdapter.getItem(position);
                        String rawDay = extractRawDayFromBandListItem(item);
                        if (rawDay != null && !rawDay.isEmpty()) {
                            currentViewingDay = rawDay;
                            Log.d("LANDSCAPE_SCHEDULE", "✅ Updated viewing day from backward search at position " + position + ": '" + currentViewingDay + "' (topmost was at " + firstVisiblePosition + ")");
                            return;
                        }
                    } catch (Exception e) {
                        // Continue searching
                    }
                }
            }
        }

        Log.d("LANDSCAPE_SCHEDULE", "Fallback: searching backwards from end");
        int searchEnd = Math.max(0, adapterCount - 100);
        for (int position = adapterCount - 1; position >= searchEnd; position--) {
            try {
                bandListItem item = bandAdapter.getItem(position);
                String rawDay = extractRawDayFromBandListItem(item);
                if (rawDay != null && !rawDay.isEmpty()) {
                    currentViewingDay = rawDay;
                    Log.d("LANDSCAPE_SCHEDULE", "✅ Updated viewing day from end search at position " + position + ": '" + currentViewingDay + "'");
                    return;
                }
            } catch (Exception e) {
                // Continue searching
            }
        }

        Log.w("LANDSCAPE_SCHEDULE", "❌ Could not determine day from adapter after exhaustive search");
    }

    public void scrollListToDayIfNeeded(final String day) {
        Log.d("LANDSCAPE_SCHEDULE", "═══════════════════════════════════════════════════════");
        Log.d("LANDSCAPE_SCHEDULE", "scrollListToDayIfNeeded() called with day: '" + day + "' (length=" + (day != null ? day.length() : 0) + ")");
        try {
            if (day == null || day.isEmpty()) {
                Log.w("LANDSCAPE_SCHEDULE", "❌ scrollListToDayIfNeeded: day is null or empty");
                return;
            }
            if (host.bandNamesList == null) {
                Log.w("LANDSCAPE_SCHEDULE", "❌ scrollListToDayIfNeeded: bandNamesList is null");
                return;
            }
            if (host.adapter == null || !(host.adapter instanceof bandListView)) {
                Log.w("LANDSCAPE_SCHEDULE", "❌ scrollListToDayIfNeeded: adapter is null or not bandListView, it's: " + (host.adapter != null ? host.adapter.getClass().getName() : "null"));
                return;
            }
            final bandListView bandAdapter = host.adapter;
            int count = bandAdapter.getCount();
            Log.d("LANDSCAPE_SCHEDULE", "✅ Searching through " + count + " items for day '" + day + "'");
            if (count == 0) {
                Log.w("LANDSCAPE_SCHEDULE", "❌ scrollListToDayIfNeeded: adapter count is 0");
                return;
            }

            int foundPosition = -1;
            for (int position = 0; position < count; position++) {
                try {
                    bandListItem item = bandAdapter.getItem(position);
                    String rawDay = extractRawDayFromBandListItem(item);

                    if (position < 5 || (rawDay != null && rawDay.trim().equalsIgnoreCase(day.trim()))) {
                        Log.d("LANDSCAPE_SCHEDULE", "  Position " + position + ": rawDay='" + rawDay + "' (searching for '" + day + "') - match=" + (rawDay != null && rawDay.trim().equals(day.trim())));
                    }

                    if (rawDay != null && rawDay.trim().equals(day.trim())) {
                        foundPosition = position;
                        Log.d("LANDSCAPE_SCHEDULE", "✅ FOUND MATCHING DAY at position " + position + " - rawDay='" + rawDay + "' matches day='" + day + "'");
                        break;
                    }
                } catch (Exception e) {
                    Log.w("LANDSCAPE_SCHEDULE", "Error checking position " + position + ": " + e.getMessage());
                }
            }

            if (foundPosition >= 0) {
                final int scrollPosition = foundPosition;
                Log.d("LANDSCAPE_SCHEDULE", "✅ Scheduling scroll to position " + scrollPosition + " for day '" + day + "'");
                host.bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            Log.d("LANDSCAPE_SCHEDULE", "🔄 Executing scroll runnable - scrollPosition=" + scrollPosition + ", adapterCount=" + (bandAdapter != null ? bandAdapter.getCount() : "N/A"));
                            if (host.bandNamesList != null && scrollPosition < bandAdapter.getCount()) {
                                host.bandNamesList.setSelectionFromTop(scrollPosition, 0);
                                Log.d("LANDSCAPE_SCHEDULE", "✅✅✅ List scrolled to day '" + day + "' (position " + scrollPosition + ")");
                                currentViewingDay = day;
                                Log.d("LANDSCAPE_SCHEDULE", "✅ Set currentViewingDay to '" + day + "' after scroll");
                                SharedPreferences prefs = host.getSharedPreferences("landscape_schedule", android.content.Context.MODE_PRIVATE);
                                prefs.edit().remove("pending_day_result").apply();
                                host.bandNamesList.postDelayed(new Runnable() {
                                    @Override
                                    public void run() {
                                        host.returningFromLandscapeSchedule = false;
                                        Log.d("LANDSCAPE_SCHEDULE", "Reset returningFromLandscapeSchedule flag to FALSE after scroll animation completed");
                                    }
                                }, 300);
                            } else {
                                Log.w("LANDSCAPE_SCHEDULE", "❌ Cannot scroll: bandNamesList=" + (host.bandNamesList != null ? "not null" : "null") + ", scrollPosition=" + scrollPosition + ", adapterCount=" + (bandAdapter != null ? bandAdapter.getCount() : "N/A"));
                                host.returningFromLandscapeSchedule = false;
                            }
                        } catch (Exception e) {
                            Log.e("LANDSCAPE_SCHEDULE", "❌ EXCEPTION in scroll runnable", e);
                            host.returningFromLandscapeSchedule = false;
                        }
                    }
                });
                Log.d("LANDSCAPE_SCHEDULE", "═══════════════════════════════════════════════════════");
                return;
            }

            Log.w("LANDSCAPE_SCHEDULE", "❌ No list position found for day: '" + day + "' after searching " + count + " items");
            Log.d("LANDSCAPE_SCHEDULE", "Sample of days in list (first 10):");
            for (int i = 0; i < Math.min(10, count); i++) {
                try {
                    bandListItem item = bandAdapter.getItem(i);
                    String rawDay = extractRawDayFromBandListItem(item);
                    Log.d("LANDSCAPE_SCHEDULE", "  [" + i + "] rawDay='" + rawDay + "'");
                } catch (Exception e) {
                    Log.d("LANDSCAPE_SCHEDULE", "  [" + i + "] Error: " + e.getMessage());
                }
            }
            host.returningFromLandscapeSchedule = false;
            Log.d("LANDSCAPE_SCHEDULE", "Reset returningFromLandscapeSchedule flag to FALSE (day not found in list)");
            Log.d("LANDSCAPE_SCHEDULE", "═══════════════════════════════════════════════════════");
        } catch (Exception e) {
            Log.e("LANDSCAPE_SCHEDULE", "❌ EXCEPTION in scrollListToDayIfNeeded", e);
            host.returningFromLandscapeSchedule = false;
            Log.d("LANDSCAPE_SCHEDULE", "═══════════════════════════════════════════════════════");
        }
    }

    private String extractRawDayFromBandListItem(bandListItem item) {
        if (item == null) {
            return null;
        }
        return item.getRawDay();
    }

    @SuppressWarnings("unused")
    private String extractDayFromPosition(int position) {
        List<String> sourceList = (host.scheduleSortedBandNames != null && !host.scheduleSortedBandNames.isEmpty())
                ? host.scheduleSortedBandNames
                : host.bandNames;

        if (sourceList == null || position < 0 || position >= sourceList.size()) {
            Log.d("LANDSCAPE_SCHEDULE", "Position " + position + " out of bounds (size: " + (sourceList != null ? sourceList.size() : 0) + ")");
            return null;
        }

        String bandEntry = sourceList.get(position);
        Log.d("LANDSCAPE_SCHEDULE", "Checking position " + position + ": '" + bandEntry + "' (from " + (sourceList == host.scheduleSortedBandNames ? "scheduleSortedBandNames" : "bandNames") + ")");

        if (bandEntry != null && bandEntry.contains(":")) {
            String[] parts = bandEntry.split(":");
            if (parts.length >= 2) {
                try {
                    double timeIndexDouble = Double.parseDouble(parts[0]);
                    Long timeIndex = (long) timeIndexDouble;
                    String bandName = parts[1];

                    Log.d("LANDSCAPE_SCHEDULE", "  Parsed - bandName: '" + bandName + "', timeIndex: " + timeIndex);

                    if (BandInfo.scheduleRecords != null && BandInfo.scheduleRecords.containsKey(bandName)) {
                        scheduleTimeTracker tracker = BandInfo.scheduleRecords.get(bandName);
                        if (tracker != null && tracker.scheduleByTime != null && tracker.scheduleByTime.containsKey(timeIndex)) {
                            scheduleHandler scheduleHandle = tracker.scheduleByTime.get(timeIndex);
                            if (scheduleHandle != null) {
                                String d = scheduleHandle.getShowDay();
                                Log.d("LANDSCAPE_SCHEDULE", "  Found day: '" + d + "'");
                                if (d != null && !d.isEmpty()) {
                                    return d;
                                }
                            }
                        }
                    }
                } catch (NumberFormatException e) {
                    Log.d("LANDSCAPE_SCHEDULE", "  Not a timeIndex entry: " + e.getMessage());
                }
            }
        }
        return null;
    }

    /**
     * Opens calendar from an explicit user action (toolbar or header button). Window focus can be
     * briefly false during overlays, downloads progress, or transitions — we still launch so taps are not lost.
     */
    public void presentLandscapeScheduleView() {
        presentLandscapeScheduleView(false, true);
    }

    /**
     * @param fromFilterChange when true, skip window-focus check (filter sheet may hold focus)
     * @param userInitiated      when true, user tapped calendar — skip window-focus check; when false, auto phone landscape launch
     */
    public void presentLandscapeScheduleView(boolean fromFilterChange, boolean userInitiated) {
        FilterButtonHandler.dismissFilterPopupIfShowing();
        if (isShowingLandscapeSchedule) {
            Log.d("LANDSCAPE_SCHEDULE", "Already showing landscape schedule view");
            return;
        }

        if (!fromFilterChange && !userInitiated && !host.hasWindowFocus()) {
            Log.d("LANDSCAPE_SCHEDULE", "No window focus — skipping auto landscape launch (overlay, transition, or another activity)");
            return;
        }

        Log.d("LANDSCAPE_SCHEDULE", "Presenting landscape schedule view");

        if (currentViewingDay == null || currentViewingDay.isEmpty()) {
            Log.d("LANDSCAPE_SCHEDULE", "currentViewingDay is not set, updating from visible cells");
            updateCurrentViewingDayFromVisibleCells();
        } else {
            Log.d("LANDSCAPE_SCHEDULE", "Preserving existing currentViewingDay: '" + currentViewingDay + "' (not updating from visible cells)");
        }

        boolean hideExpiredEvents = staticVariables.preferences.getHideExpiredEvents();
        Log.d("LANDSCAPE_SCHEDULE", "hideExpiredEvents: " + hideExpiredEvents);

        if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
            Log.w("LANDSCAPE_SCHEDULE", "No scheduled events found - not showing calendar view");
            return;
        }

        if (hideExpiredEvents) {
            if (areAllEventsExpired()) {
                Log.w("LANDSCAPE_SCHEDULE", "Hide Expired Events is ON and ALL events are expired - not showing calendar view");
                return;
            }
        }

        String initialDay = currentViewingDay;
        if (initialDay != null) {
            Log.d("LANDSCAPE_SCHEDULE", "🚀 Starting landscape view on day: '" + initialDay + "'");
        } else {
            Log.w("LANDSCAPE_SCHEDULE", "⚠️ No tracked day found, will start on first day");
        }

        try {
            Class<?> activityClass = Class.forName("com.Bands70k.landscape.LandscapeScheduleActivity");
            Log.d("LANDSCAPE_SCHEDULE", "✅ LandscapeScheduleActivity class found: " + activityClass.getName());

            Intent intent = new Intent(host, activityClass);
            intent.putExtra(com.Bands70k.landscape.LandscapeScheduleActivity.EXTRA_INITIAL_DAY, initialDay);
            intent.putExtra(com.Bands70k.landscape.LandscapeScheduleActivity.EXTRA_HIDE_EXPIRED_EVENTS, hideExpiredEvents);
            intent.putExtra(com.Bands70k.landscape.LandscapeScheduleActivity.EXTRA_IS_SPLIT_VIEW_CAPABLE, isSplitViewCapable());

            Log.d("LANDSCAPE_SCHEDULE", "🚀 Launching LandscapeScheduleActivity with extras - initialDay: " + initialDay + ", hideExpired: " + hideExpiredEvents);

            isShowingLandscapeSchedule = true;
            host.startActivityForResult(intent, REQUEST_CODE_LANDSCAPE_SCHEDULE);
            Log.d("LANDSCAPE_SCHEDULE", "✅ Activity launch initiated - startActivityForResult called");
        } catch (ClassNotFoundException e) {
            Log.e("LANDSCAPE_SCHEDULE", "❌ LandscapeScheduleActivity class not found!", e);
            isShowingLandscapeSchedule = false;
        } catch (Exception e) {
            Log.e("LANDSCAPE_SCHEDULE", "❌ Error launching landscape schedule activity", e);
            e.printStackTrace();
            isShowingLandscapeSchedule = false;
        }
    }

    private boolean areAllEventsExpired() {
        if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
            return false;
        }

        long currentTimeMillis = System.currentTimeMillis();
        double currentTimeSeconds = currentTimeMillis / 1000.0;

        boolean foundAnyNonExpired = false;
        int totalEvents = 0;
        int expiredEvents = 0;

        for (java.util.Map.Entry<String, scheduleTimeTracker> bandEntry : BandInfo.scheduleRecords.entrySet()) {
            scheduleTimeTracker tracker = bandEntry.getValue();
            if (tracker == null || tracker.scheduleByTime == null) {
                continue;
            }

            for (java.util.Map.Entry<Long, scheduleHandler> timeEntry : tracker.scheduleByTime.entrySet()) {
                Long timeIndex = timeEntry.getKey();
                scheduleHandler scheduleHandle = timeEntry.getValue();

                if (scheduleHandle == null) {
                    continue;
                }

                totalEvents++;

                double timeIndexSeconds = timeIndex.doubleValue() / 1000.0;
                double endTimeIndex = timeIndexSeconds;

                java.util.Date startDate = scheduleHandle.getStartTime();
                java.util.Date endDate = scheduleHandle.getEndTime();

                if (startDate != null && endDate != null) {
                    long durationSeconds = (endDate.getTime() - startDate.getTime()) / 1000;
                    endTimeIndex = timeIndexSeconds + durationSeconds;
                } else {
                    endTimeIndex = timeIndexSeconds + 3600;
                }

                boolean isExpired = endTimeIndex <= currentTimeSeconds;

                if (isExpired) {
                    expiredEvents++;
                } else {
                    foundAnyNonExpired = true;
                    Log.d("LANDSCAPE_SCHEDULE", "Found non-expired event: " + bandEntry.getKey() +
                            " (endTimeIndex=" + endTimeIndex + ", currentTime=" + currentTimeSeconds + ")");
                    break;
                }
            }

            if (foundAnyNonExpired) {
                break;
            }
        }

        boolean allExpired = totalEvents > 0 && !foundAnyNonExpired;
        Log.d("LANDSCAPE_SCHEDULE", "areAllEventsExpired check: totalEvents=" + totalEvents +
                ", expiredEvents=" + expiredEvents + ", allExpired=" + allExpired);

        return allExpired;
    }
}
