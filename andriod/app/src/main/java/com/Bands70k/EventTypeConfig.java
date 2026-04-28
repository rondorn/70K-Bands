package com.Bands70k;

import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Canonical event type keys + localized festival display labels.
 */
public final class EventTypeConfig {
    public static final String SHOW = "Show";
    public static final String UNOFFICIAL_EVENT = "Unofficial Event";
    public static final String SPECIAL_EVENT = "Special Event";
    public static final String MEET_AND_GREET = "Meet and Greet";
    public static final String CLINIC = "Clinic";

    private static final List<String> DISPLAY_ORDER = Arrays.asList(
            SHOW, UNOFFICIAL_EVENT, SPECIAL_EVENT, MEET_AND_GREET, CLINIC
    );

    private EventTypeConfig() {}

    public static String normalize(String eventType) {
        if (eventType == null) return SHOW;
        String trimmed = eventType.trim();
        if (trimmed.isEmpty()) return SHOW;
        if (trimmed.equalsIgnoreCase(SHOW)) return SHOW;
        if (trimmed.equalsIgnoreCase(SPECIAL_EVENT)) return SPECIAL_EVENT;
        if (trimmed.equalsIgnoreCase(MEET_AND_GREET)) return MEET_AND_GREET;
        if (trimmed.equalsIgnoreCase(CLINIC)) return CLINIC;
        if (trimmed.equalsIgnoreCase("Cruiser Organized") || trimmed.equalsIgnoreCase(UNOFFICIAL_EVENT)) {
            return UNOFFICIAL_EVENT;
        }
        return trimmed;
    }

    public static boolean isShow(String eventType) {
        return SHOW.equals(normalize(eventType));
    }

    public static boolean isUnofficial(String eventType) {
        return UNOFFICIAL_EVENT.equals(normalize(eventType));
    }

    public static boolean isSpecial(String eventType) {
        return SPECIAL_EVENT.equals(normalize(eventType));
    }

    public static boolean isMeetAndGreet(String eventType) {
        return MEET_AND_GREET.equals(normalize(eventType));
    }

    public static boolean isClinic(String eventType) {
        return CLINIC.equals(normalize(eventType));
    }

    public static boolean isFilterableNonShow(String eventType) {
        String canonical = normalize(eventType);
        return UNOFFICIAL_EVENT.equals(canonical)
                || SPECIAL_EVENT.equals(canonical)
                || MEET_AND_GREET.equals(canonical)
                || CLINIC.equals(canonical);
    }

    public static String displayName(String eventType) {
        return FestivalConfig.getInstance().getEventTypeDisplayName(normalize(eventType), currentLanguageCode());
    }

    public static String currentLanguageCode() {
        String lang = Locale.getDefault().getLanguage();
        if (lang == null || lang.isEmpty()) return "en";
        String lower = lang.toLowerCase(Locale.ROOT);
        switch (lower) {
            case "de":
            case "es":
            case "fr":
            case "pt":
            case "da":
            case "fi":
            case "en":
                return lower;
            default:
                return "en";
        }
    }

    public static Set<String> getEventTypesInScheduleExcludingShow() {
        LinkedHashSet<String> used = new LinkedHashSet<>();
        if (BandInfo.scheduleRecords == null) return used;
        for (scheduleTimeTracker tracker : BandInfo.scheduleRecords.values()) {
            if (tracker == null || tracker.scheduleByTime == null) continue;
            for (scheduleHandler sh : tracker.scheduleByTime.values()) {
                if (sh == null) continue;
                String canonical = normalize(sh.getShowType());
                if (isFilterableNonShow(canonical)) used.add(canonical);
            }
        }

        // Keep deterministic menu order.
        LinkedHashSet<String> ordered = new LinkedHashSet<>();
        for (String canonical : DISPLAY_ORDER) {
            if (!SHOW.equals(canonical) && used.contains(canonical)) {
                ordered.add(canonical);
            }
        }
        return ordered;
    }

    public static String getFilterRowText(String canonicalEventType) {
        return FestivalConfig.getInstance().getEventTypeFilterDisplayName(
                normalize(canonicalEventType),
                currentLanguageCode()
        );
    }

    public static boolean isEventTypeVisibleByPreference(String eventType) {
        String canonical = normalize(eventType);
        if (SHOW.equals(canonical)) return true;
        if (MEET_AND_GREET.equals(canonical)) return staticVariables.preferences.getShowMeetAndGreet();
        if (SPECIAL_EVENT.equals(canonical)) return staticVariables.preferences.getShowSpecialEvents();
        if (CLINIC.equals(canonical)) return staticVariables.preferences.getShowClinicEvents();
        if (UNOFFICIAL_EVENT.equals(canonical)) return staticVariables.preferences.getShowUnofficalEvents();
        return true;
    }

    public static void setEventTypeVisibleByPreference(String eventType, boolean visible) {
        String canonical = normalize(eventType);
        if (MEET_AND_GREET.equals(canonical)) {
            staticVariables.preferences.setShowMeetAndGreet(visible);
        } else if (SPECIAL_EVENT.equals(canonical)) {
            staticVariables.preferences.setShowSpecialEvents(visible);
        } else if (CLINIC.equals(canonical)) {
            staticVariables.preferences.setShowClinicEvents(visible);
        } else if (UNOFFICIAL_EVENT.equals(canonical)) {
            staticVariables.preferences.setShowUnofficalEvents(visible);
        }
    }

    public static int getIconEnabledRes(String eventType, String eventName) {
        String canonical = normalize(eventType);
        if (UNOFFICIAL_EVENT.equals(canonical)) return R.drawable.icon_unoffical_event;
        if (MEET_AND_GREET.equals(canonical)) return R.drawable.icon_meet_and_greet;
        if (CLINIC.equals(canonical)) return R.drawable.icon_clinic;
        if (SPECIAL_EVENT.equals(canonical)) {
            if (eventName != null && eventName.equals("All Star Jam")) return R.drawable.icon_all_star_jam;
            if (eventName != null && eventName.contains("Karaoke")) return R.drawable.icon_karaoke;
            return R.drawable.icon_ship_event;
        }
        return 0;
    }

    public static int getIconDisabledRes(String eventType, String eventName) {
        String canonical = normalize(eventType);
        if (UNOFFICIAL_EVENT.equals(canonical)) return R.drawable.icon_unoffical_event_alt;
        if (MEET_AND_GREET.equals(canonical)) return R.drawable.icon_meet_and_greet_alt;
        if (CLINIC.equals(canonical)) return R.drawable.icon_clinic;
        if (SPECIAL_EVENT.equals(canonical)) {
            if (eventName != null && eventName.equals("All Star Jam")) return R.drawable.icon_all_star_jam_alt;
            if (eventName != null && eventName.contains("Karaoke")) return R.drawable.icon_karaoke;
            return R.drawable.icon_ship_event;
        }
        return 0;
    }
}
