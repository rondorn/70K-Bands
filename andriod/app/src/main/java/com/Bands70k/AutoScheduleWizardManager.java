package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.drawable.ColorDrawable;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.TextView;

import androidx.appcompat.app.AlertDialog;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.TreeMap;

/**
 * When the pointer file has Current::AutoScheduleFlag = Yes and a schedule name,
 * offers to run the Plan Your Schedule wizard (once per Current::AutoScheduleName).
 * Current::AutoScheduleFlagRepeat = Yes uses the "rerun" message; otherwise "create" message.
 * Prompt is driven only by pointer file; no other app config gate.
 */
public final class AutoScheduleWizardManager {

    private static final String TAG = "AUTO_SCHEDULE";

    private static final String PREFS_NAME = "AutoScheduleWizard";
    private static final String KEY_LAST_RUN_SCHEDULE_NAME = "AutoScheduleWizardLastRunScheduleName";

    private static final String POINTER_FLAG = "AutoScheduleFlag";
    private static final String POINTER_REPEAT = "AutoScheduleFlagRepeat";
    private static final String POINTER_NAME = "AutoScheduleName";
    private static final String POINTER_EVENT_YEAR = "eventYear";

    /** Dark grey for dialog background (matches iOS 0.10 white). */
    private static final int DARK_BG_COLOR = 0xFF1A1A1A;

    private AutoScheduleWizardManager() {}

    /**
     * Checks pointer file; if AutoScheduleFlag=Yes and schedule not yet run for current AutoScheduleName,
     * shows a dark-styled dialog with No/Yes. On Yes starts the wizard; on No saves the name so we don't prompt again.
     * When the prompt is not shown (or after user dismisses with No), runs whenNotShownOrDismissed.
     */
    public static void checkAndShowIfNeeded(Activity activity, Runnable whenNotShownOrDismissed) {
        if (activity == null || activity.isFinishing()) {
            if (whenNotShownOrDismissed != null) whenNotShownOrDismissed.run();
            return;
        }
        String flag = readPointerCurrentValue(POINTER_FLAG);
        if (flag == null || !"Yes".equals(flag.trim())) {
            Log.d(TAG, "AutoScheduleFlag != Yes or missing, skipping");
            if (whenNotShownOrDismissed != null) whenNotShownOrDismissed.run();
            return;
        }

        int eventYearInt = resolveEventYear();
        String scheduleName = readPointerCurrentValue(POINTER_NAME);
        if (scheduleName == null || scheduleName.trim().isEmpty()) {
            scheduleName = "Schedule-" + eventYearInt;
        } else {
            scheduleName = scheduleName.trim();
        }
        final String scheduleNameFinal = scheduleName;

        SharedPreferences prefs = activity.getSharedPreferences(PREFS_NAME, Activity.MODE_PRIVATE);
        String lastRun = prefs.getString(KEY_LAST_RUN_SCHEDULE_NAME, "");
        if (lastRun != null && lastRun.equals(scheduleNameFinal)) {
            Log.d(TAG, "Already ran wizard for '" + scheduleNameFinal + "', skipping");
            if (whenNotShownOrDismissed != null) whenNotShownOrDismissed.run();
            return;
        }

        boolean isRepeat = "yes".equalsIgnoreCase(trimOrEmpty(readPointerCurrentValue(POINTER_REPEAT)));
        String message = activity.getString(isRepeat ? R.string.auto_schedule_released_rerun_prompt : R.string.auto_schedule_released_create_prompt);

        String title = activity.getString(R.string.plan_your_schedule);
        String noStr = activity.getString(R.string.No);
        String yesStr = activity.getString(R.string.Yes);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.setNegativeButton(noStr, (dialog, which) -> {
            prefs.edit().putString(KEY_LAST_RUN_SCHEDULE_NAME, scheduleNameFinal).apply();
            if (whenNotShownOrDismissed != null) whenNotShownOrDismissed.run();
        });
        builder.setPositiveButton(yesStr, (dialog, which) -> {
            prefs.edit().putString(KEY_LAST_RUN_SCHEDULE_NAME, scheduleNameFinal).apply();
            Intent wizard = new Intent(activity, AutoChooseAttendanceWizardActivity.class);
            wizard.putExtra("eventYear", eventYearInt);
            activity.startActivity(wizard);
            if (whenNotShownOrDismissed != null) whenNotShownOrDismissed.run();
        });
        builder.setOnCancelListener(dialog -> {
            if (whenNotShownOrDismissed != null) whenNotShownOrDismissed.run();
        });

        AlertDialog dialog = builder.show();
        applyDarkDialogStyle(dialog, activity);
    }

    /**
     * Reads a key from the cached pointer file. Checks "Current", then event year, then "Default".
     */
    private static String readPointerCurrentValue(String key) {
        File file = FileHandler70k.pointerCacheFile;
        if (file == null || !file.exists()) return null;
        try {
            String content = FileHandler70k.loadData(file);
            if (content == null || content.trim().isEmpty()) return null;
            Map<String, Map<String, String>> bySection = new TreeMap<>();
            for (String rawLine : content.split("\\n")) {
                String line = rawLine.trim();
                if (line.isEmpty()) continue;
                String[] parts = line.split("::", -1);
                if (parts.length < 3) continue;
                String section = parts[0].trim();
                String k = parts[1].trim();
                String v = parts[2].trim();
                bySection.computeIfAbsent(section, s -> new HashMap<>()).put(k, v);
            }
            String eventYearStr = null;
            if (bySection.containsKey("Current")) eventYearStr = bySection.get("Current").get(POINTER_EVENT_YEAR);
            if ((eventYearStr == null || eventYearStr.isEmpty()) && bySection.containsKey("Default")) {
                eventYearStr = bySection.get("Default").get(POINTER_EVENT_YEAR);
            }
            for (String section : new String[]{"Current", eventYearStr, "Default"}) {
                if (section == null || section.isEmpty()) continue;
                Map<String, String> map = bySection.get(section);
                if (map != null && map.containsKey(key)) {
                    String val = map.get(key);
                    if (val != null && !val.isEmpty()) return val;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed reading cached pointer file: " + e.getMessage());
        }
        return null;
    }

    private static int resolveEventYear() {
        String y = readPointerCurrentValue(POINTER_EVENT_YEAR);
        if (y != null && !y.isEmpty()) {
            try {
                int i = Integer.parseInt(y.trim());
                if (i > 2000) return i;
            } catch (NumberFormatException ignored) {}
        }
        String fromCache = staticVariables.getPointerUrlData(POINTER_EVENT_YEAR);
        if (fromCache != null && !fromCache.isEmpty()) {
            try {
                int i = Integer.parseInt(fromCache.trim());
                if (i > 2000) return i;
            } catch (NumberFormatException ignored) {}
        }
        return staticVariables.eventYear != null ? staticVariables.eventYear : java.util.Calendar.getInstance().get(java.util.Calendar.YEAR);
    }

    private static String trimOrEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    private static final int WHITE = 0xFFFFFFFF;

    /**
     * Applies dark background, white text (including buttons), and optionally larger width.
     */
    public static void applyDarkDialogStyle(AlertDialog dialog, Context context) {
        if (dialog == null || dialog.getWindow() == null) return;
        dialog.getWindow().setBackgroundDrawable(new ColorDrawable(DARK_BG_COLOR));
        try {
            View decor = dialog.getWindow().getDecorView();
            setAllTextViewsWhite(decor);
            Button negative = dialog.getButton(AlertDialog.BUTTON_NEGATIVE);
            if (negative != null) negative.setTextColor(WHITE);
            Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
            if (positive != null) positive.setTextColor(WHITE);
        } catch (Exception e) {
            Log.w(TAG, "Could not set dialog text color: " + e.getMessage());
        }
        if (context != null) {
            try {
                WindowManager wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
                if (wm != null && wm.getDefaultDisplay() != null) {
                    android.graphics.Point size = new android.graphics.Point();
                    wm.getDefaultDisplay().getSize(size);
                    int width = (int) (size.x * 0.9);
                    int paddingPx = (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 24, context.getResources().getDisplayMetrics());
                    dialog.getWindow().setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT);
                    View content = dialog.findViewById(android.R.id.content);
                    if (content != null) {
                        content.setPadding(paddingPx, paddingPx, paddingPx, paddingPx);
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "Could not set dialog size: " + e.getMessage());
            }
        }
    }

    /** Recursively set all TextViews in the view hierarchy to white so body and title are readable. */
    private static void setAllTextViewsWhite(View view) {
        if (view instanceof TextView) {
            ((TextView) view).setTextColor(WHITE);
        }
        if (view instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) view;
            for (int i = 0; i < g.getChildCount(); i++) {
                setAllTextViewsWhite(g.getChildAt(i));
            }
        }
    }
}
