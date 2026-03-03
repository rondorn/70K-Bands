package com.Bands70k;

import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Builds a flat List&lt;EventData&gt; from BandInfo.scheduleRecords for the AI schedule builder.
 */
public class AIScheduleEventLoader {

    private static final String TAG = "AIScheduleEventLoader";

    /**
     * Builds event list for the given year. Uses timeIndex in seconds (epoch/1000).
     * date is normalized as yyyy-MM-dd from the handler's start Date.
     */
    public static List<EventData> buildEventListForYear(int eventYear) {
        List<EventData> out = new ArrayList<>();
        if (BandInfo.scheduleRecords == null) return out;

        SimpleDateFormat dayFormat = new SimpleDateFormat("yyyy-MM-dd", Locale.US);

        for (Map.Entry<String, scheduleTimeTracker> bandEntry : BandInfo.scheduleRecords.entrySet()) {
            String bandName = bandEntry.getKey();
            scheduleTimeTracker tracker = bandEntry.getValue();
            if (tracker == null || tracker.scheduleByTime == null) continue;

            for (Map.Entry<Long, scheduleHandler> timeEntry : tracker.scheduleByTime.entrySet()) {
                Long timeIndexMs = timeEntry.getKey();
                scheduleHandler h = timeEntry.getValue();
                if (h == null) continue;

                String location = h.getShowLocation();
                String startTimeStr = h.getStartTimeString();
                String endTimeStr = h.getEndTimeString();
                String eventType = h.getShowType();
                String day = h.getShowDay();
                String notes = h.getShowNotes();
                if (location == null || startTimeStr == null) continue;

                double timeIndexSec = timeIndexMs != null ? timeIndexMs / 1000.0 : 0;
                java.util.Date startDate = h.getStartTime();
                java.util.Date endDate = h.getEndTime();
                double endTimeIndexSec = timeIndexSec;
                if (startDate != null && endDate != null) {
                    long durationSec = (endDate.getTime() - startDate.getTime()) / 1000;
                    endTimeIndexSec = timeIndexSec + durationSec;
                }

                String dateNorm = null;
                if (startDate != null) {
                    try {
                        dateNorm = dayFormat.format(startDate);
                    } catch (Exception e) {
                        Log.w(TAG, "Date format failed for " + bandName + ": " + e.getMessage());
                    }
                }
                if (dateNorm == null) dateNorm = day != null ? day : "";

                EventData e = new EventData();
                e.bandName = bandName;
                e.location = location;
                e.date = dateNorm;
                e.day = day;
                e.startTime = startTimeStr;
                e.endTime = endTimeStr;
                e.eventType = eventType != null ? eventType : staticVariables.show;
                e.notes = (notes != null && !notes.isEmpty()) ? notes : null;
                e.timeIndex = timeIndexSec;
                e.endTimeIndex = endTimeIndexSec;
                e.eventYear = eventYear;
                out.add(e);
            }
        }

        out.sort((a, b) -> Double.compare(a.timeIndex, b.timeIndex));
        return out;
    }
}
