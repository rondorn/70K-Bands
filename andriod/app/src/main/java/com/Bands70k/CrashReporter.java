package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Simple crash reporting system to catch edge cases during AsyncTask modernization.
 * Logs crashes to both device storage and system logs for debugging.
 */
public class CrashReporter implements Thread.UncaughtExceptionHandler {
    
    private static final String TAG = "CrashReporter";
    private static final String CRASH_LOG_FILE = "crash_reports.log";
    private static final String PREF_CRASH_COUNT = "crash_count";
    private static final String PREF_LAST_CRASH = "last_crash_time";
    
    private final Thread.UncaughtExceptionHandler defaultHandler;
    private final Context context;
    private static CrashReporter instance;
    
    private CrashReporter(Context context) {
        this.context = context.getApplicationContext();
        this.defaultHandler = Thread.getDefaultUncaughtExceptionHandler();
    }
    
    /**
     * Initializes the crash reporter. Call this from Application.onCreate().
     * @param context Application context
     */
    public static void initialize(Context context) {
        if (instance == null) {
            instance = new CrashReporter(context);
            Thread.setDefaultUncaughtExceptionHandler(instance);
            Log.d(TAG, "CrashReporter initialized - monitoring for threading issues");
        }
    }
    
    /**
     * Gets crash statistics for debugging.
     * @return String with crash stats
     */
    public static String getCrashStats() {
        if (instance == null) return "CrashReporter not initialized";
        
        SharedPreferences prefs = instance.context.getSharedPreferences("crash_reporter", Context.MODE_PRIVATE);
        int crashCount = prefs.getInt(PREF_CRASH_COUNT, 0);
        long lastCrash = prefs.getLong(PREF_LAST_CRASH, 0);
        
        if (crashCount == 0) {
            return "No crashes reported since modernization";
        } else {
            Date lastCrashDate = new Date(lastCrash);
            return String.format("Crashes since modernization: %d, Last: %s", 
                               crashCount, lastCrashDate.toString());
        }
    }
    
    @Override
    public void uncaughtException(Thread thread, Throwable throwable) {
        try {
            // Log crash details
            logCrash(thread, throwable);
            
            // Check if this looks like a threading-related issue
            if (isThreadingIssue(throwable)) {
                Log.e(TAG, "⚠️  THREADING ISSUE DETECTED - This might be related to AsyncTask modernization!");
                logThreadingAnalysis(throwable);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error in crash reporting", e);
        }
        
        // Let the default handler take over
        if (defaultHandler != null) {
            defaultHandler.uncaughtException(thread, throwable);
        }
    }
    
    private void logCrash(Thread thread, Throwable throwable) {
        try {
            // Update crash statistics
            updateCrashStats();
            
            // Create detailed crash report
            String crashReport = buildCrashReport(thread, throwable);
            
            // Log to system
            Log.e(TAG, "💥 CRASH DETECTED:\n" + crashReport);
            
            // Save to file
            saveCrashToFile(crashReport);
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to log crash", e);
        }
    }
    
    private String buildCrashReport(Thread thread, Throwable throwable) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        
        // Header
        pw.println("=== CRASH REPORT ===");
        pw.println("Time: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(new Date()));
        pw.println("App Version: " + getAppVersion());
        pw.println("Android Version: " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")");
        pw.println("Device: " + Build.MANUFACTURER + " " + Build.MODEL);
        pw.println("Thread: " + thread.getName());
        pw.println();
        
        // Exception details
        pw.println("=== EXCEPTION ===");
        throwable.printStackTrace(pw);
        pw.println();
        
        // Threading context
        pw.println("=== THREADING CONTEXT ===");
        pw.println("Is Main Thread: " + (thread == android.os.Looper.getMainLooper().getThread()));
        pw.println("Thread Count: " + Thread.activeCount());
        pw.println("ThreadManager Status: " + getThreadManagerStatus());
        pw.println();
        
        // App state
        pw.println("=== APP STATE ===");
        pw.println("Loading Bands: " + staticVariables.loadingBands);
        pw.println("Loading Notes: " + staticVariables.loadingNotes);
        pw.println("App in Background: " + Bands70k.isAppInBackground());
        
        return sw.toString();
    }
    
    private boolean isThreadingIssue(Throwable throwable) {
        String message = throwable.getMessage();
        String stackTrace = getStackTraceString(throwable);
        
        // Check for common threading issues
        return stackTrace.contains("ThreadManager") ||
               stackTrace.contains("ExecutorService") ||
               stackTrace.contains("AsyncTask") ||
               (message != null && (
                   message.contains("thread") ||
                   message.contains("concurrent") ||
                   message.contains("synchroniz") ||
                   message.contains("deadlock")
               ));
    }
    
    private void logThreadingAnalysis(Throwable throwable) {
        Log.w(TAG, "🔍 THREADING ANALYSIS:");
        Log.w(TAG, "- Check if this crash is related to the AsyncTask modernization");
        Log.w(TAG, "- Look for ExecutorService or ThreadManager in the stack trace");
        Log.w(TAG, "- Verify that SynchronizationManager is working correctly");
        Log.w(TAG, "- Check for race conditions in loading flags");
        
        String stackTrace = getStackTraceString(throwable);
        if (stackTrace.contains("SynchronizationManager")) {
            Log.w(TAG, "⚠️  SynchronizationManager detected in stack - check CountDownLatch usage");
        }
        if (stackTrace.contains("ThreadManager")) {
            Log.w(TAG, "⚠️  ThreadManager detected in stack - check ExecutorService usage");
        }
    }
    
    private void updateCrashStats() {
        SharedPreferences prefs = context.getSharedPreferences("crash_reporter", Context.MODE_PRIVATE);
        int currentCount = prefs.getInt(PREF_CRASH_COUNT, 0);
        
        prefs.edit()
             .putInt(PREF_CRASH_COUNT, currentCount + 1)
             .putLong(PREF_LAST_CRASH, System.currentTimeMillis())
             .apply();
    }
    
    private void saveCrashToFile(String crashReport) {
        try {
            File logFile = new File(context.getFilesDir(), CRASH_LOG_FILE);
            FileWriter writer = new FileWriter(logFile, true); // Append mode
            writer.write(crashReport + "\n\n");
            writer.flush();
            writer.close();
            
            Log.d(TAG, "Crash report saved to: " + logFile.getAbsolutePath());
        } catch (IOException e) {
            Log.e(TAG, "Failed to save crash report to file", e);
        }
    }
    
    private String getStackTraceString(Throwable throwable) {
        StringWriter sw = new StringWriter();
        throwable.printStackTrace(new PrintWriter(sw));
        return sw.toString();
    }
    
    private String getAppVersion() {
        try {
            return context.getPackageManager()
                         .getPackageInfo(context.getPackageName(), 0)
                         .versionName;
        } catch (Exception e) {
            return "Unknown";
        }
    }
    
    private String getThreadManagerStatus() {
        try {
            // Basic status check
            return "Initialized"; // ThreadManager doesn't expose internal state
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }
    
    /**
     * Manually report a non-fatal issue for monitoring.
     * @param tag Log tag
     * @param message Issue description
     * @param throwable Optional exception
     */
    public static void reportIssue(String tag, String message, Throwable throwable) {
        if (instance == null) {
            Log.w(tag, message, throwable);
            return;
        }
        
        String report = String.format("[NON-FATAL] %s: %s\nTime: %s\n", 
                                    tag, message, 
                                    new SimpleDateFormat("HH:mm:ss", Locale.US).format(new Date()));
        
        if (throwable != null) {
            report += "Exception: " + instance.getStackTraceString(throwable);
        }
        
        Log.w(TAG, report);
        
        try {
            instance.saveCrashToFile(report);
        } catch (Exception e) {
            Log.e(TAG, "Failed to save issue report", e);
        }
    }
}


