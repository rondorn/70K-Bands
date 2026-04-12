package com.Bands70k;

import android.os.Bundle;
import android.util.Log;

/**
 * QA UI instrumentation hooks (parity with iOS {@code UITESTING} / {@code UITEST_CUSTOM_POINTER_URL}).
 * Reads {@link androidx.test.platform.app.InstrumentationRegistry} via reflection so release APK stays free of test deps.
 */
public final class UiTestMarkers {

    private static final String TAG = "UiTestMarkers";
    private static volatile boolean enabled;

    private UiTestMarkers() {}

    public static boolean isEnabled() {
        return enabled;
    }

    /**
     * Call after {@link preferencesHandler#loadData()} so prefs exist; applies URL + defaults before network init.
     */
    public static void applyFromInstrumentation(preferencesHandler prefs) {
        Bundle args = tryGetInstrumentationArguments();
        if (args == null) {
            return;
        }
        String flag = args.getString("UITESTING");
        if (!"1".equals(flag)) {
            return;
        }
        enabled = true;
        String url = args.getString("UITEST_CUSTOM_POINTER_URL");
        if (url != null && !url.trim().isEmpty()) {
            prefs.setCustomPointerUrl(url.trim());
            Log.d(TAG, "UITEST_CUSTOM_POINTER_URL applied for UI test");
        }
        prefs.setAllLinksOpenInExternalBrowser(false);
        prefs.setOpenYouTubeApp(false);
        prefs.saveData();
    }

    private static Bundle tryGetInstrumentationArguments() {
        try {
            Class<?> reg = Class.forName("androidx.test.platform.app.InstrumentationRegistry");
            Object bundle = reg.getMethod("getArguments").invoke(null);
            return bundle instanceof Bundle ? (Bundle) bundle : null;
        } catch (Throwable t) {
            return null;
        }
    }

    /** English priority label for row priority icon (matches iOS AX label for {@code qaMasterCellPriorityIcon}). */
    public static String priorityEnglishLabel(String bandName) {
        if (bandName == null) {
            return "Unknown";
        }
        switch (rankStore.getPriorityForBand(bandName)) {
            case 1:
                return "Must";
            case 2:
                return "Might";
            case 3:
                return "Wont";
            default:
                return "Unknown";
        }
    }
}
