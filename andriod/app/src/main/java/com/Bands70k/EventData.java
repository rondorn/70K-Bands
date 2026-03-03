package com.Bands70k;

/**
 * Flat event model for AI schedule builder. Mirrors Swift EventData.
 * Built from BandInfo.scheduleRecords; used for overlap and conflict resolution.
 */
public class EventData {
    public String bandName;
    public String location;
    /** Normalized calendar date (yyyy-MM-dd) for same-day overlap. */
    public String date;
    /** Day label from schedule (e.g. "Day 1"). */
    public String day;
    public String startTime;
    public String endTime;
    public String eventType;
    /** Short notes from schedule (e.g. clinic title). */
    public String notes;
    /** Start time in seconds (epoch or reference). */
    public double timeIndex;
    /** End time in seconds. */
    public double endTimeIndex;
    public int eventYear;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        EventData other = (EventData) o;
        return java.util.Objects.equals(bandName, other.bandName)
                && java.util.Objects.equals(location, other.location)
                && java.util.Objects.equals(startTime, other.startTime)
                && java.util.Objects.equals(eventType, other.eventType)
                && eventYear == other.eventYear;
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash(bandName, location, startTime, eventType, eventYear);
    }
}
