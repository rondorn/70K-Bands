package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Maps schedule location strings to generic color slots using CSV row order.
 * First unseen non-named location → generic slot 1, etc. Persisted per event year.
 */
public final class VenueColorAssignment {

    private static VenueColorAssignment instance;

    private final Map<String, Integer> slotIndexByLocation = new HashMap<>();
    private int loadedYear = -1;

    private VenueColorAssignment() {}

    public static synchronized VenueColorAssignment getInstance() {
        if (instance == null) {
            instance = new VenueColorAssignment();
        }
        return instance;
    }

    private String prefsKey(int year) {
        return "venueColorAssignments_" + year;
    }

    public synchronized void load(Context context, int year) {
        if (loadedYear == year && !slotIndexByLocation.isEmpty()) {
            return;
        }
        slotIndexByLocation.clear();
        loadedYear = year;
        if (context == null) {
            return;
        }
        SharedPreferences prefs = context.getSharedPreferences("VenueColorAssignment", Context.MODE_PRIVATE);
        String json = prefs.getString(prefsKey(year), null);
        if (json == null || json.isEmpty()) {
            return;
        }
        try {
            JSONObject obj = new JSONObject(json);
            Iterator<String> keys = obj.keys();
            while (keys.hasNext()) {
                String location = keys.next();
                slotIndexByLocation.put(location, obj.getInt(location));
            }
        } catch (Exception ignored) {
            slotIndexByLocation.clear();
        }
    }

    public synchronized void clear(Context context, int year) {
        slotIndexByLocation.clear();
        loadedYear = year;
        if (context != null) {
            context.getSharedPreferences("VenueColorAssignment", Context.MODE_PRIVATE)
                    .edit()
                    .remove(prefsKey(year))
                    .apply();
        }
    }

    /**
     * Rebuild from schedule CSV row order. Skips named venues (exact match). Persists per year.
     */
    public synchronized void updateFromCsvLocations(Context context, List<String> locationsInCSVOrder, int year) {
        FestivalConfig config = FestivalConfig.getInstance();
        Map<String, Integer> assignments = new HashMap<>();
        Set<String> seen = new HashSet<>();
        int nextSlot = 0;

        for (String location : locationsInCSVOrder) {
            if (location == null || location.isEmpty()) {
                continue;
            }
            if (config.hasNamedVenue(location)) {
                continue;
            }
            if (seen.contains(location)) {
                continue;
            }
            seen.add(location);
            if (nextSlot >= config.genericVenueSlots.size()) {
                continue;
            }
            assignments.put(location, nextSlot);
            nextSlot++;
        }

        slotIndexByLocation.clear();
        slotIndexByLocation.putAll(assignments);
        loadedYear = year;

        if (context != null) {
            try {
                JSONObject obj = new JSONObject();
                for (Map.Entry<String, Integer> entry : assignments.entrySet()) {
                    obj.put(entry.getKey(), entry.getValue());
                }
                context.getSharedPreferences("VenueColorAssignment", Context.MODE_PRIVATE)
                        .edit()
                        .putString(prefsKey(year), obj.toString())
                        .apply();
            } catch (Exception ignored) {
            }
        }
    }

    private synchronized Integer slotIndexFor(String location, Context context, int year) {
        if (loadedYear != year) {
            load(context, year);
        }
        return slotIndexByLocation.get(location);
    }

    public GenericVenueSlot resolveSlot(String location, Context context, int year) {
        Integer index = slotIndexFor(location, context, year);
        if (index == null) {
            return null;
        }
        List<GenericVenueSlot> slots = FestivalConfig.getInstance().genericVenueSlots;
        if (index < 0 || index >= slots.size()) {
            return null;
        }
        return slots.get(index);
    }
}
