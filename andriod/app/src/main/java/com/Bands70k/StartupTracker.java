package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.SystemClock;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * StartupTracker
 *
 * Lightweight, persistent breadcrumbs for diagnosing "stuck on splash" reports.
 * Stores only non-sensitive information (timestamps + simple step names).
 */
public final class StartupTracker {
    private static final String PREFS_MAIN = "startup_diagnostics_main";
    private static final String PREFS_DIAG = "startup_diagnostics_diag";

    private static final String KEY_STEPS = "steps";
    private static final String KEY_LAST_STEP = "last_step";
    private static final String KEY_LAST_STEP_TS = "last_step_ts";
    private static final String KEY_FIRST_FRAME_DRAWN = "first_frame_drawn";
    private static final String KEY_FIRST_FRAME_TS = "first_frame_ts";
    private static final String KEY_PROCESS_START_ELAPSED = "process_start_elapsed";
    private static final String KEY_LAST_ERROR = "last_error";
    private static final String KEY_LAST_ERROR_TS = "last_error_ts";

    // Keep this small; it's copied into logs/support emails.
    private static final int MAX_STEPS_CHARS = 4000;

    private StartupTracker() {}

    public static void initProcess(Context context) {
        if (!staticVariables.sendDebug) return;
        SharedPreferences prefs = getPrefsForCurrentProcess(context);
        if (!prefs.contains(KEY_PROCESS_START_ELAPSED)) {
            prefs.edit()
                    .putLong(KEY_PROCESS_START_ELAPSED, SystemClock.elapsedRealtime())
                    .apply();
        }
    }

    public static void markStep(Context context, String step) {
        if (!staticVariables.sendDebug) return;
        if (context == null) return;
        if (step == null) step = "unknown";

        SharedPreferences prefs = getPrefsForCurrentProcess(context);
        long now = System.currentTimeMillis();

        String entry = now + " " + step;
        String existing = prefs.getString(KEY_STEPS, "");
        String updated;
        if (existing == null || existing.isEmpty()) {
            updated = entry;
        } else {
            updated = existing + "\n" + entry;
        }

        // Trim from the front if it gets too big.
        if (updated.length() > MAX_STEPS_CHARS) {
            updated = updated.substring(updated.length() - MAX_STEPS_CHARS);
            int firstNewline = updated.indexOf('\n');
            if (firstNewline >= 0 && firstNewline + 1 < updated.length()) {
                updated = updated.substring(firstNewline + 1);
            }
        }

        prefs.edit()
                .putString(KEY_STEPS, updated)
                .putString(KEY_LAST_STEP, step)
                .putLong(KEY_LAST_STEP_TS, now)
                .apply();
    }

    public static void markFirstFrameDrawn(Context context) {
        if (!staticVariables.sendDebug) return;
        if (context == null) return;
        SharedPreferences prefs = getPrefsForCurrentProcess(context);
        prefs.edit()
                .putBoolean(KEY_FIRST_FRAME_DRAWN, true)
                .putLong(KEY_FIRST_FRAME_TS, System.currentTimeMillis())
                .apply();
    }

    /**
     * Records a non-fatal diagnostic detail that can be shared by the user.
     */
    public static void markError(Context context, String component, String message) {
        if (!staticVariables.sendDebug) return;
        if (context == null) return;
        if (component == null) component = "unknown";
        if (message == null) message = "";

        SharedPreferences prefs = getPrefsForCurrentProcess(context);
        long now = System.currentTimeMillis();
        String value = component + ": " + message;
        if (value.length() > 2000) {
            value = value.substring(0, 2000);
        }
        prefs.edit()
                .putString(KEY_LAST_ERROR, value)
                .putLong(KEY_LAST_ERROR_TS, now)
                .apply();
    }

    public static boolean isFirstFrameDrawn(Context context) {
        if (context == null) return false;
        return getPrefsForMainProcess(context).getBoolean(KEY_FIRST_FRAME_DRAWN, false);
    }

    public static String buildDiagnosticsReport(Context context) {
        if (!staticVariables.sendDebug) return "Startup diagnostics are disabled.";
        if (context == null) return "No context available.";
        SharedPreferences prefs = getPrefsForCurrentProcess(context);
        return buildReportFromPrefs(context, prefs, /* reportProcessLabel */ getProcessLabel(context));
    }

    /**
     * Builds a report for the main app process, even when called from the :diag process.
     */
    public static String buildMainDiagnosticsReport(Context context) {
        if (!staticVariables.sendDebug) return "Startup diagnostics are disabled.";
        if (context == null) return "No context available.";
        SharedPreferences prefs = getPrefsForMainProcess(context);
        return buildReportFromPrefs(context, prefs, /* reportProcessLabel */ "main");
    }

    private static String buildReportFromPrefs(Context context, SharedPreferences prefs, String reportProcessLabel) {
        if (prefs == null) return "No diagnostics available.";

        String lastStep = prefs.getString(KEY_LAST_STEP, "(none)");
        long lastStepTs = prefs.getLong(KEY_LAST_STEP_TS, 0L);
        boolean firstFrame = prefs.getBoolean(KEY_FIRST_FRAME_DRAWN, false);
        long firstFrameTs = prefs.getLong(KEY_FIRST_FRAME_TS, 0L);
        long processStartElapsed = prefs.getLong(KEY_PROCESS_START_ELAPSED, 0L);
        String lastError = prefs.getString(KEY_LAST_ERROR, "(none)");
        long lastErrorTs = prefs.getLong(KEY_LAST_ERROR_TS, 0L);
        String steps = prefs.getString(KEY_STEPS, "");

        SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US);
        String lastStepTime = lastStepTs > 0 ? fmt.format(new Date(lastStepTs)) : "(unknown)";
        String firstFrameTime = firstFrameTs > 0 ? fmt.format(new Date(firstFrameTs)) : "(not drawn)";

        long nowElapsed = SystemClock.elapsedRealtime();
        long sinceStartMs = (processStartElapsed > 0) ? (nowElapsed - processStartElapsed) : -1;

        String versionName = "(unknown)";
        long versionCode = -1;
        try {
            android.content.pm.PackageInfo pi =
                    context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            versionName = pi.versionName;
            if (android.os.Build.VERSION.SDK_INT >= 28) {
                versionCode = pi.getLongVersionCode();
            } else {
                //noinspection deprecation
                versionCode = pi.versionCode;
            }
        } catch (Exception ignored) {
        }

        StringBuilder sb = new StringBuilder(4096);
        sb.append("70K Bands startup diagnostics\n");
        sb.append("\n");
        sb.append("App version: ").append(versionName).append(" (").append(versionCode).append(")\n");
        sb.append("Package: ").append(context.getPackageName()).append("\n");
        sb.append("Process: ").append(reportProcessLabel).append("\n");
        sb.append("PID: ").append(android.os.Process.myPid()).append("\n");
        sb.append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n");
        sb.append("Android: ").append(Build.VERSION.RELEASE).append(" (SDK ").append(Build.VERSION.SDK_INT).append(")\n");
        sb.append("Uptime since process start: ").append(sinceStartMs).append(" ms\n");
        sb.append("\n");
        sb.append("First frame drawn: ").append(firstFrame).append("\n");
        sb.append("First frame time: ").append(firstFrameTime).append("\n");
        sb.append("Last startup step: ").append(lastStep).append("\n");
        sb.append("Last step time: ").append(lastStepTime).append("\n");
        if (lastErrorTs > 0) {
            sb.append("Last error: ").append(lastError).append("\n");
            sb.append("Last error time: ").append(fmt.format(new Date(lastErrorTs))).append("\n");
        } else {
            sb.append("Last error: ").append(lastError).append("\n");
        }
        sb.append("\n");
        sb.append("Startup steps:\n");
        sb.append(steps == null || steps.isEmpty() ? "(none)\n" : steps).append("\n");
        return sb.toString();
    }

    private static SharedPreferences getPrefsForCurrentProcess(Context context) {
        if (isDiagnosticsProcess(context)) {
            return context.getApplicationContext().getSharedPreferences(PREFS_DIAG, Context.MODE_PRIVATE);
        }
        return getPrefsForMainProcess(context);
    }

    private static SharedPreferences getPrefsForMainProcess(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS_MAIN, Context.MODE_PRIVATE);
    }

    private static String getProcessLabel(Context context) {
        return isDiagnosticsProcess(context) ? "diag" : "main";
    }

    private static boolean isDiagnosticsProcess(Context context) {
        try {
            if (android.os.Build.VERSION.SDK_INT >= 28) {
                String name = android.app.Application.getProcessName();
                return name != null && name.endsWith(":diag");
            }
        } catch (Exception ignored) {
        }
        try {
            android.app.ActivityManager am =
                    (android.app.ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (am == null) return false;
            int myPid = android.os.Process.myPid();
            for (android.app.ActivityManager.RunningAppProcessInfo p : am.getRunningAppProcesses()) {
                if (p != null && p.pid == myPid) {
                    return p.processName != null && p.processName.endsWith(":diag");
                }
            }
        } catch (Exception ignored) {
        }
        return false;
    }
}

