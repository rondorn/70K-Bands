package com.Bands70k;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Modern thread management replacing deprecated AsyncTask usage.
 * Provides centralized ExecutorService management with proper UI thread handling.
 */
public class ThreadManager {
    
    private static final String TAG = "ThreadManager";
    private static ThreadManager instance;
    
    // Different thread pools for different types of work
    private final ExecutorService networkExecutor;
    private final ExecutorService fileExecutor;
    private final ExecutorService generalExecutor;
    
    // UI thread handler for callbacks
    private final Handler uiHandler;
    
    private ThreadManager() {
        // Network operations - limited concurrency to avoid overwhelming servers
        networkExecutor = Executors.newFixedThreadPool(2, new NamedThreadFactory("Network"));
        
        // File I/O operations - single threaded to avoid conflicts
        fileExecutor = Executors.newSingleThreadExecutor(new NamedThreadFactory("FileIO"));
        
        // General background tasks
        generalExecutor = Executors.newFixedThreadPool(3, new NamedThreadFactory("General"));
        
        // Handler for UI thread callbacks
        uiHandler = new Handler(Looper.getMainLooper());
        
        Log.d(TAG, "ThreadManager initialized with modern ExecutorService");
    }
    
    /**
     * Gets the singleton instance of ThreadManager.
     * @return The singleton instance.
     */
    public static synchronized ThreadManager getInstance() {
        if (instance == null) {
            instance = new ThreadManager();
        }
        return instance;
    }
    
    /**
     * Executes a task on the network thread pool.
     * @param task The task to execute.
     * @return Future for the task.
     */
    public Future<?> executeNetwork(Runnable task) {
        Log.d(TAG, "Submitting network task");
        return networkExecutor.submit(task);
    }
    
    /**
     * Executes a task on the file I/O thread pool.
     * @param task The task to execute.
     * @return Future for the task.
     */
    public Future<?> executeFile(Runnable task) {
        Log.d(TAG, "Submitting file I/O task");
        return fileExecutor.submit(task);
    }
    
    /**
     * Executes a task on the general background thread pool.
     * @param task The task to execute.
     * @return Future for the task.
     */
    public Future<?> executeGeneral(Runnable task) {
        Log.d(TAG, "Submitting general background task");
        return generalExecutor.submit(task);
    }
    
    /**
     * Runs code on the UI thread.
     * @param task The task to run on UI thread.
     */
    public void runOnUiThread(Runnable task) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            // Already on UI thread
            task.run();
        } else {
            uiHandler.post(task);
        }
    }
    
    /**
     * Runs code on the UI thread after a delay.
     * @param task The task to run on UI thread.
     * @param delayMillis Delay in milliseconds.
     */
    public void runOnUiThreadDelayed(Runnable task, long delayMillis) {
        uiHandler.postDelayed(task, delayMillis);
    }
    
    /**
     * Executes a background task with UI thread callbacks.
     * Modern replacement for AsyncTask pattern.
     * 
     * @param backgroundTask The task to run in background.
     * @param onPreExecute Optional task to run on UI thread before background task.
     * @param onPostExecute Optional task to run on UI thread after background task completes.
     * @param executor The executor to use (network, file, or general).
     * @return Future for the background task.
     */
    public Future<?> executeWithCallbacks(
            Runnable backgroundTask, 
            Runnable onPreExecute, 
            Runnable onPostExecute,
            ExecutorService executor) {
        
        // Run pre-execute on UI thread
        if (onPreExecute != null) {
            runOnUiThread(onPreExecute);
        }
        
        // Submit background task
        return executor.submit(() -> {
            try {
                backgroundTask.run();
            } finally {
                // Run post-execute on UI thread
                if (onPostExecute != null) {
                    runOnUiThread(onPostExecute);
                }
            }
        });
    }
    
    /**
     * Convenience method for general background tasks with callbacks.
     */
    public Future<?> executeGeneralWithCallbacks(
            Runnable backgroundTask, 
            Runnable onPreExecute, 
            Runnable onPostExecute) {
        return executeWithCallbacks(backgroundTask, onPreExecute, onPostExecute, generalExecutor);
    }
    
    /**
     * Convenience method for network tasks with callbacks.
     */
    public Future<?> executeNetworkWithCallbacks(
            Runnable backgroundTask, 
            Runnable onPreExecute, 
            Runnable onPostExecute) {
        return executeWithCallbacks(backgroundTask, onPreExecute, onPostExecute, networkExecutor);
    }
    
    /**
     * Convenience method for file I/O tasks with callbacks.
     */
    public Future<?> executeFileWithCallbacks(
            Runnable backgroundTask, 
            Runnable onPreExecute, 
            Runnable onPostExecute) {
        return executeWithCallbacks(backgroundTask, onPreExecute, onPostExecute, fileExecutor);
    }
    
    /**
     * Shuts down all thread pools. Call this in application termination.
     */
    public void shutdown() {
        Log.d(TAG, "Shutting down ThreadManager");
        networkExecutor.shutdown();
        fileExecutor.shutdown();
        generalExecutor.shutdown();
    }
    
    /**
     * Named thread factory for better debugging.
     */
    private static class NamedThreadFactory implements ThreadFactory {
        private final String namePrefix;
        private final AtomicInteger threadNumber = new AtomicInteger(1);
        
        NamedThreadFactory(String namePrefix) {
            this.namePrefix = namePrefix;
        }
        
        @Override
        public Thread newThread(Runnable r) {
            Thread thread = new Thread(r, namePrefix + "-" + threadNumber.getAndIncrement());
            thread.setDaemon(true);
            return thread;
        }
    }
    
    /**
     * Interface for background tasks that return results.
     * Modern replacement for AsyncTask<Params, Progress, Result> pattern.
     */
    public interface BackgroundTask<T> {
        T doInBackground();
        default void onPreExecute() {}
        default void onPostExecute(T result) {}
        default void onError(Exception e) {
            Log.e(TAG, "Background task failed", e);
        }
    }
    
    /**
     * Executes a background task that returns a result.
     * Modern AsyncTask replacement with type safety.
     */
    public <T> Future<?> executeTask(BackgroundTask<T> task) {
        return executeTask(task, generalExecutor);
    }
    
    /**
     * Executes a background task that returns a result on specified executor.
     */
    public <T> Future<?> executeTask(BackgroundTask<T> task, ExecutorService executor) {
        // Run pre-execute on UI thread
        runOnUiThread(task::onPreExecute);
        
        return executor.submit(() -> {
            try {
                T result = task.doInBackground();
                runOnUiThread(() -> task.onPostExecute(result));
            } catch (Exception e) {
                Log.e(TAG, "Background task failed", e);
                CrashReporter.reportIssue("ThreadManager", 
                    "Background task execution failed: " + e.getMessage(), e);
                runOnUiThread(() -> task.onError(e));
            }
        });
    }
    
    /**
     * Reports a threading issue to crash monitoring.
     * @param operation Description of the operation that failed
     * @param error The error that occurred
     */
    public static void reportThreadingIssue(String operation, Throwable error) {
        Log.w(TAG, "Threading issue in operation: " + operation, error);
        CrashReporter.reportIssue("ThreadManager", operation, error);
    }
}
