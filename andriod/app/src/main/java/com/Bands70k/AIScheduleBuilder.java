package com.Bands70k;

import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Rule-based AI schedule builder. Uses Must/Might/Wont, Meet and Greet and Clinic options,
 * and resolves Must/Might conflicts. Port of Swift AIScheduleBuilder.
 */
public class AIScheduleBuilder {

    private static final String TAG = "AIScheduleBuilder";
    private static final double SHORT_OVERLAP_THRESHOLD_SECONDS = 900.0; // 15 min

    public static final int STEP_COMPLETED = 0;
    public static final int STEP_NEED_MUST_CONFLICT = 1;

    private final Integer latestShowCutoffHalfHours; // null = no cutoff, 0-11
    private final boolean markAllMustMeetAndGreets;
    private final boolean markAllMustClinics;
    private final int eventYear;
    private final String eventYearString;

    private List<EventData> allCandidates = new ArrayList<>();
    private Set<EventData> chosen = new HashSet<>();
    private Set<EventData> existingAttended = new HashSet<>();
    private Set<EventData> selectedClinicSet = new HashSet<>();
    private Set<EventData> selectedSpecialSet = new HashSet<>();
    private Set<EventData> selectedMeetAndGreetSet = new HashSet<>();
    private Set<EventData> selectedUnofficialSet = new HashSet<>();
    private int candidateIndex = 0;

    public AIScheduleBuilder(boolean markAllMustMeetAndGreets, boolean markAllMustClinics,
                             int eventYear, Integer latestShowCutoffHalfHours) {
        this.markAllMustMeetAndGreets = markAllMustMeetAndGreets;
        this.markAllMustClinics = markAllMustClinics;
        this.eventYear = eventYear;
        this.eventYearString = String.valueOf(eventYear);
        this.latestShowCutoffHalfHours = latestShowCutoffHalfHours != null
                ? Math.min(11, Math.max(0, latestShowCutoffHalfHours)) : null;
    }

    /**
     * Result of one builder step. type is STEP_COMPLETED or STEP_NEED_MUST_CONFLICT.
     * For COMPLETED, completedList is set. For NEED_MUST_CONFLICT, conflictEventA and conflictEventB are set.
     */
    public static class BuildStep {
        public final int type;
        public final List<EventData> completedList;
        public final EventData conflictEventA;
        public final EventData conflictEventB;

        public static BuildStep completed(List<EventData> list) {
            return new BuildStep(STEP_COMPLETED, list, null, null);
        }

        public static BuildStep needMustConflict(EventData a, EventData b) {
            return new BuildStep(STEP_NEED_MUST_CONFLICT, null, a, b);
        }

        private BuildStep(int type, List<EventData> completedList, EventData conflictEventA, EventData conflictEventB) {
            this.type = type;
            this.completedList = completedList;
            this.conflictEventA = conflictEventA;
            this.conflictEventB = conflictEventB;
        }
    }

    /**
     * Start or continue building. Pass null for resolution when no user choice is needed,
     * or pass the chosen event when resolving a Must conflict.
     * @param chooseBoth If true, add resolutionChosenEvent without removing the overlapping event (keep both).
     */
    public BuildStep nextStep(EventData resolutionChosenEvent, boolean chooseBoth) {
        if (resolutionChosenEvent != null) {
            if (chooseBoth) {
                chosen.add(resolutionChosenEvent);
                candidateIndex++;
            } else {
                // Resolve Must conflict: remove overlapping (except <=15 min), add chosen
                Set<EventData> newChosen = new HashSet<>();
                for (EventData e : chosen) {
                    if (e.equals(resolutionChosenEvent)) { newChosen.add(e); continue; }
                    if (!overlaps(resolutionChosenEvent, e)) { newChosen.add(e); continue; }
                    if (overlapDurationSeconds(resolutionChosenEvent, e) <= SHORT_OVERLAP_THRESHOLD_SECONDS) {
                        newChosen.add(e);
                    }
                }
                chosen = newChosen;
                chosen.add(resolutionChosenEvent);
                candidateIndex++;
            }
        }

        // Phase 1: walk candidates and resolve overlaps
        while (candidateIndex < allCandidates.size()) {
            EventData event = allCandidates.get(candidateIndex);
            if (chosen.contains(event)) {
                candidateIndex++;
                continue;
            }

            List<EventData> overlapping = new ArrayList<>();
            for (EventData c : chosen) {
                if (overlaps(event, c)) overlapping.add(c);
            }

            // Diagnostic: log every candidate decision (especially when overlapping or band name of interest)
            boolean logThis = overlapping.size() > 0 || (event.bandName != null && event.bandName.contains("T.H.E.M"));
            if (logThis) {
                Log.d(TAG, "CANDIDATE band=" + event.bandName + " location=" + event.location + " start=" + event.startTime
                        + " timeIndex=" + event.timeIndex + " endTimeIndex=" + event.endTimeIndex
                        + " overlapping=" + overlapping.size());
                for (EventData o : overlapping) {
                    double dur = overlapDurationSeconds(event, o);
                    Log.d(TAG, "  OVERLAP with " + o.bandName + " @ " + o.location + " " + o.startTime
                            + " o.timeIndex=" + o.timeIndex + " o.endTimeIndex=" + o.endTimeIndex + " overlapDurSec=" + dur);
                }
            }

            // 15-min grace: exactly one overlapping with overlap <= 15 min (end of earlier within 15 min of start of later) → allow both
            if (isShortOverlapException(event, overlapping)) {
                if (logThis) Log.d(TAG, "  -> ADD (short overlap exception)");
                chosen.add(event);
                candidateIndex++;
                continue;
            }

            // M&G vs M&G only: allow overlap without conflict (same as iOS). Show vs M&G or M&G vs Show go to Must/Might logic and may prompt.
            if (isMeetAndGreet(event)) {
                boolean allOverlappingAreMeetAndGreet = true;
                for (EventData o : overlapping) {
                    if (!isMeetAndGreet(o)) { allOverlappingAreMeetAndGreet = false; break; }
                }
                if (allOverlappingAreMeetAndGreet) {
                    if (logThis) Log.d(TAG, "  -> ADD (M&G vs M&G only)");
                    chosen.add(event);
                    candidateIndex++;
                    continue;
                }
            }

            // Conflicting with existing attended (overlap > 15 min): skip unless all M&G
            List<EventData> conflictingExisting = new ArrayList<>();
            for (EventData o : overlapping) {
                if (existingAttended.contains(o) && overlapDurationSeconds(event, o) > SHORT_OVERLAP_THRESHOLD_SECONDS)
                    conflictingExisting.add(o);
            }
            if (!conflictingExisting.isEmpty()) {
                boolean eventIsMAndG = isMeetAndGreet(event);
                boolean allMAndG = eventIsMAndG;
                for (EventData o : conflictingExisting) { if (!isMeetAndGreet(o)) allMAndG = false; }
                if (!allMAndG) {
                    Log.d(TAG, "Skip (conflicts existing): " + event.bandName + " @ " + event.location + " " + event.startTime);
                    candidateIndex++;
                    continue;
                }
                chosen.add(event);
                candidateIndex++;
                continue;
            }

            if (overlapping.isEmpty()) {
                if (logThis) Log.d(TAG, "  -> ADD (no overlap)");
                chosen.add(event);
                candidateIndex++;
                continue;
            }

            boolean eventMandatory = isMandatory(event);
            EventData overlappingMandatory = null;
            boolean overlappingAllMight = true;
            for (EventData o : overlapping) {
                if (isMandatory(o)) overlappingMandatory = o;
                if (!isMight(o)) overlappingAllMight = false;
            }
            if (logThis) Log.d(TAG, "  eventMandatory=" + eventMandatory + " overlappingMandatory=" + (overlappingMandatory != null ? overlappingMandatory.bandName : "null") + " overlappingAllMight=" + overlappingAllMight);

            if (!eventMandatory && overlappingMandatory != null) {
                Log.d(TAG, "Skip (Might vs Must): " + event.bandName + " @ " + event.location + " " + event.startTime + " loses to " + overlappingMandatory.bandName);
                candidateIndex++;
                continue;
            }
            if (eventMandatory && overlappingMandatory != null) {
                return BuildStep.needMustConflict(event, overlappingMandatory);
            }
            if (eventMandatory && overlappingAllMight) {
                chosen.removeAll(overlapping);
                chosen.add(event);
                candidateIndex++;
                continue;
            }
            if (!eventMandatory && overlappingAllMight && !overlapping.isEmpty()) {
                return BuildStep.needMustConflict(event, overlapping.get(0));
            }
            Log.d(TAG, "Skip (fallback): " + event.bandName + " @ " + event.location + " " + event.startTime + " overlapping=" + overlapping.size());
            candidateIndex++;
        }

        List<EventData> chosenList = new ArrayList<>(chosen);
        Log.d(TAG, "COMPLETED chosen.size()=" + chosenList.size());
        return BuildStep.completed(chosenList);
    }

    /**
     * Build candidate list and return first step. existingAttended = events already marked will-attend.
     * selectedClinicEvents, selectedSpecialEvents, selectedMeetAndGreetEvents, selectedUnofficialEvents are user-picked; they are added to candidates and participate in conflict resolution.
     */
    public BuildStep start(List<EventData> events, List<EventData> existingAttendedList,
                          List<EventData> selectedClinicEvents, List<EventData> selectedSpecialEvents,
                          List<EventData> selectedMeetAndGreetEvents, List<EventData> selectedUnofficialEvents) {
        existingAttended = new HashSet<>(existingAttendedList != null ? existingAttendedList : new ArrayList<>());
        selectedClinicSet = new HashSet<>(selectedClinicEvents != null ? selectedClinicEvents : new ArrayList<>());
        selectedSpecialSet = new HashSet<>(selectedSpecialEvents != null ? selectedSpecialEvents : new ArrayList<>());
        selectedMeetAndGreetSet = new HashSet<>(selectedMeetAndGreetEvents != null ? selectedMeetAndGreetEvents : new ArrayList<>());
        selectedUnofficialSet = new HashSet<>(selectedUnofficialEvents != null ? selectedUnofficialEvents : new ArrayList<>());
        List<EventData> candidates = new ArrayList<>();

        for (EventData event : events) {
            if (event.date == null || event.startTime == null || event.startTime.isEmpty()) continue;
            String eventType = event.eventType != null ? event.eventType : "";
            int priority = rankStore.getPriorityForBand(event.bandName);

            if (staticVariables.show.equals(eventType)) {
                if (priority == 1 || priority == 2) {
                    if (latestShowCutoffHalfHours != null && shouldExcludeShowByLatestCutoff(event.startTime, latestShowCutoffHalfHours))
                        continue;
                    candidates.add(event);
                } else if (priority == 0) {
                    Log.d(TAG, "Skip candidate (priority 0/unknown): " + event.bandName + " @ " + event.location + " " + event.startTime);
                }
                continue;
            }
            if (staticVariables.meetAndGreet.equals(eventType)) {
                if (priority == 1 && (markAllMustMeetAndGreets || selectedMeetAndGreetSet.contains(event))) candidates.add(event);
                continue;
            }
            if (staticVariables.clinic.equals(eventType)) {
                if (selectedClinicSet.contains(event)) candidates.add(event);
                continue;
            }
            if (staticVariables.specialEvent.equals(eventType)) {
                if (selectedSpecialSet.contains(event)) candidates.add(event);
                continue;
            }
            if (staticVariables.unofficalEvent.equals(eventType) || staticVariables.unofficalEventOld.equals(eventType)) {
                if (priority == 1 && selectedUnofficialSet.contains(event)) candidates.add(event);
                continue;
            }
        }

        candidates.sort((a, b) -> Double.compare(a.timeIndex, b.timeIndex));
        allCandidates = candidates;
        chosen = new HashSet<>(existingAttended);
        candidateIndex = 0;

        return nextStep(null, false);
    }

    /**
     * Midnight-wrap: if an event's end is earlier than its start on the same calendar day
     * (e.g. 23:15–00:00 or 23:45–01:30), treat end as next day (+24h) so overnight events overlap correctly.
     */
    private boolean overlaps(EventData a, EventData b) {
        String dayA = normalizedCalendarDay(a.date);
        String dayB = normalizedCalendarDay(b.date);
        if (dayA != null && dayB != null && !dayA.equals(dayB)) return false;
        double endA = a.endTimeIndex;
        if (a.timeIndex > endA) endA += 86400;
        double endB = b.endTimeIndex;
        if (b.timeIndex > endB) endB += 86400;
        return a.timeIndex < endB && b.timeIndex < endA;
    }

    /**
     * Overlap duration in seconds (0 if different days or no overlap).
     * Uses same logic as iOS: overlap = (end of earlier event) − (start of later event).
     * If overlap <= 15 min, both events can be booked (grace period). If > 15 min, hard conflict.
     */
    private double overlapDurationSeconds(EventData a, EventData b) {
        String dayA = normalizedCalendarDay(a.date);
        String dayB = normalizedCalendarDay(b.date);
        if (dayA != null && dayB != null && !dayA.equals(dayB)) return 0;
        EventData earlier = a.timeIndex <= b.timeIndex ? a : b;
        EventData later = a.timeIndex <= b.timeIndex ? b : a;
        double endOfEarlier = earlier.endTimeIndex;
        if (earlier.timeIndex > endOfEarlier) endOfEarlier += 86400;
        double startOfLater = later.timeIndex;
        if (earlier.timeIndex > startOfLater) startOfLater += 86400;
        return Math.max(0, endOfEarlier - startOfLater);
    }

    private boolean isShortOverlapException(EventData event, List<EventData> overlapping) {
        if (overlapping.size() != 1) return false;
        return overlapDurationSeconds(event, overlapping.get(0)) <= SHORT_OVERLAP_THRESHOLD_SECONDS;
    }

    private String normalizedCalendarDay(String dateString) {
        if (dateString == null || dateString.isEmpty()) return null;
        try {
            SimpleDateFormat in = new SimpleDateFormat("M/d/yyyy", Locale.US);
            java.util.Date d = in.parse(dateString);
            if (d == null) {
                in = new SimpleDateFormat("MM/dd/yyyy", Locale.US);
                d = in.parse(dateString);
            }
            if (d != null) {
                SimpleDateFormat out = new SimpleDateFormat("yyyy-MM-dd", Locale.US);
                return out.format(d);
            }
        } catch (Exception ignored) { }
        return dateString;
    }

    private boolean isMeetAndGreet(EventData event) {
        return staticVariables.meetAndGreet.equals(event.eventType != null ? event.eventType : "");
    }

    /** True if event is Must show, M&G, or in user-selected clinics/specials/unofficial. Used for conflict resolution. */
    private boolean isMandatory(EventData event) {
        if (event == null) return false;
        String type = event.eventType != null ? event.eventType : "";
        if (staticVariables.show.equals(type))
            return rankStore.getPriorityForBand(event.bandName) == 1;
        if (staticVariables.meetAndGreet.equals(type)) return true;
        if (staticVariables.unofficalEvent.equals(type) || staticVariables.unofficalEventOld.equals(type))
            return selectedUnofficialSet.contains(event);
        return selectedClinicSet.contains(event) || selectedSpecialSet.contains(event);
    }

    /** True if event is a Might show (priority 2). */
    private boolean isMight(EventData event) {
        if (event == null) return false;
        if (!staticVariables.show.equals(event.eventType != null ? event.eventType : "")) return false;
        return rankStore.getPriorityForBand(event.bandName) == 2;
    }

    private boolean shouldExcludeShowByLatestCutoff(String startTime, int cutoffHalfHours) {
        int[] hm = parseHourAndMinutesFromStartTime(startTime);
        if (hm == null) return false;
        int hour = hm[0], minutes = hm[1];
        if (hour < 0 || hour > 5) return false; // late night only (matches iOS)
        int cutoffHour = cutoffHalfHours / 2;
        int cutoffMinutes = (cutoffHalfHours % 2) * 30;
        if (hour > cutoffHour) return true;
        if (hour == cutoffHour) return minutes > cutoffMinutes;
        return false;
    }

    /** Returns { hour 0-23, minutes 0-59 } or null. */
    private int[] parseHourAndMinutesFromStartTime(String startTime) {
        if (startTime == null) return null;
        String trimmed = startTime.trim();
        String upper = trimmed.toUpperCase(Locale.US);
        boolean isPM = upper.contains("PM");
        boolean isAM = upper.contains("AM");
        if (isAM || isPM) {
            String numPart = trimmed.replaceAll("(?i)AM", "").replaceAll("(?i)PM", "").trim();
            String[] parts = numPart.split(":");
            if (parts.length < 1) return null;
            try {
                int first = Integer.parseInt(parts[0].trim());
                int minutes = 0;
                if (parts.length > 1) {
                    String m = parts[1].replaceAll("[^0-9]", "");
                    if (!m.isEmpty()) minutes = Math.min(59, Math.max(0, Integer.parseInt(m)));
                }
                if (isPM && first != 12) first += 12;
                if (isAM && first == 12) first = 0;
                return new int[]{Math.min(23, Math.max(0, first)), minutes};
            } catch (NumberFormatException e) {
                return null;
            }
        }
        String[] parts = trimmed.split(":");
        if (parts.length < 1) return null;
        try {
            int hour = Integer.parseInt(parts[0].trim());
            if (hour < 0 || hour > 23) return null;
            int minutes = 0;
            if (parts.length > 1) {
                String m = parts[1].replaceAll("[^0-9]", "");
                if (!m.isEmpty()) minutes = Math.min(59, Math.max(0, Integer.parseInt(m)));
            }
            return new int[]{hour, minutes};
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
