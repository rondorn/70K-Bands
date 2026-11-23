package com.Bands70k;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Year menu order: "Current" first, then numeric years newest to oldest.
 * Pointer files are not consistent (70K is newest-first, MDF is not).
 */
public final class EventYearOrder {

    private EventYearOrder() {}

    public static List<String> newestFirst(List<String> years) {
        List<String> current = new ArrayList<>();
        List<Integer> numeric = new ArrayList<>();
        List<String> other = new ArrayList<>();
        if (years != null) {
            for (String year : years) {
                if (year == null) {
                    continue;
                }
                String trimmed = year.trim();
                if (trimmed.isEmpty()) {
                    continue;
                }
                if (trimmed.equalsIgnoreCase("Current")) {
                    if (current.isEmpty()) {
                        current.add("Current");
                    }
                    continue;
                }
                try {
                    int value = Integer.parseInt(trimmed);
                    if (!numeric.contains(value)) {
                        numeric.add(value);
                    }
                } catch (NumberFormatException ignored) {
                    if (!other.contains(trimmed)) {
                        other.add(trimmed);
                    }
                }
            }
        }
        Collections.sort(numeric, Collections.reverseOrder());
        List<String> ordered = new ArrayList<>();
        ordered.addAll(current);
        for (Integer year : numeric) {
            ordered.add(String.valueOf(year));
        }
        ordered.addAll(other);
        return ordered;
    }
}
