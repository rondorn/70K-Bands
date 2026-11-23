package com.Bands70k;

import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;

import static org.junit.Assert.assertEquals;

public class EventYearOrderTest {

    @Test
    public void currentThenNewestFirst() {
        assertEquals(
                Arrays.asList("Current", "2026", "2025"),
                EventYearOrder.newestFirst(Arrays.asList("Current", "2025", "2026"))
        );
    }

    @Test
    public void currentIsPulledToTheFront() {
        assertEquals(
                Arrays.asList("Current", "2026", "2025", "2024"),
                EventYearOrder.newestFirst(Arrays.asList("2025", "Current", "2024", "2026"))
        );
    }

    @Test
    public void alreadyNewestFirstStaysPut() {
        assertEquals(
                Arrays.asList("Current", "2025", "2024", "2023"),
                EventYearOrder.newestFirst(Arrays.asList("Current", "2025", "2024", "2023"))
        );
    }

    @Test
    public void duplicateAndBlankYearsAreDropped() {
        assertEquals(
                Arrays.asList("Current", "2026"),
                EventYearOrder.newestFirst(Arrays.asList("current", "2026", "2026", " ", null))
        );
    }

    @Test
    public void emptyListStaysEmpty() {
        assertEquals(Collections.emptyList(), EventYearOrder.newestFirst(Collections.emptyList()));
        assertEquals(Collections.emptyList(), EventYearOrder.newestFirst(null));
    }
}
