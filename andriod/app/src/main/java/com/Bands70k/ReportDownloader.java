package com.Bands70k;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.util.Log;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Handles downloading and caching of the report dashboard HTML file for the app.
 */
public class ReportDownloader {
    
    private static final String TAG = "ReportDownloader";
    private static final String REPORT_FILENAME = "report_dashboard.html";
    private Context context;
    
    /**
     * Callback interface for download completion or error.
     */
    public interface DownloadCallback {
        /**
         * Called when the download is complete.
         * @param filePath The path to the downloaded or cached file.
         * @param htmlContent The HTML content of the report.
         */
        void onDownloadComplete(String filePath, String htmlContent);
        /**
         * Called when there is an error during download or reading cached file.
         * @param error The error message.
         */
        void onDownloadError(String error);
    }
    
    /**
     * Constructs a ReportDownloader with the given context.
     * @param context The application context.
     */
    public ReportDownloader(Context context) {
        this.context = context;
    }
    
    /**
     * Downloads the report from the given URL or loads from cache if offline.
     * @param url The URL to download the report from.
     * @param callback The callback to notify on completion or error.
     */
    public void downloadReport(String url, DownloadCallback callback) {
        if (isNetworkAvailable()) {
            executeDownloadTask(callback, url);
        } else {
            String cachedFile = getCachedReportPath();
            if (new File(cachedFile).exists()) {
                Log.d(TAG, "Using cached report file");
                try {
                    String content = readFileContentOptimized(cachedFile);
                    callback.onDownloadComplete(cachedFile, content);
                } catch (IOException e) {
                    callback.onDownloadError("Error reading cached file: " + e.getMessage());
                }
            } else {
                callback.onDownloadError("No internet connection and no cached file available");
            }
        }
    }
    
    /**
     * Gets the path to the cached report file.
     * @return The absolute path to the cached report file.
     */
    public String getCachedReportPath() {
        return context.getFilesDir().getAbsolutePath() + File.separator + REPORT_FILENAME;
    }
    
    /**
     * Gets the report URL from the cached file by parsing the HTML content.
     * @param filePath The path to the cached file.
     * @return The report URL if found, null otherwise.
     */
    public String getReportUrlFromCachedFile(String filePath) {
        try {
            String content = readFileContentOptimized(filePath);
            // Look for a meta tag or script tag that contains the report URL
            // This is a simple implementation - you might need to adjust based on your HTML structure
            if (content.contains("reportUrl")) {
                // Extract URL from content - this is a placeholder implementation
                // You'll need to implement proper URL extraction based on your HTML structure
                return staticVariables.getPointerUrlData("reportUrl");
            }
            return null;
        } catch (IOException e) {
            Log.e(TAG, "Error reading cached file for URL extraction: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Downloads the report URL in the background and caches it.
     * @param callback The callback to notify on completion or error.
     */
    public void downloadReportUrlInBackground(DownloadCallback callback) {
        if (isNetworkAvailable()) {
            executeDownloadUrlTask(callback);
        } else {
            callback.onDownloadError("No internet connection available");
        }
    }
    
    /**
     * Checks if network is available.
     * @return True if network is available, false otherwise.
     */
    private boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager = 
            (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }
    
    /**
     * Reads file content with optimized performance.
     * @param filePath The path to the file.
     * @return The file content as a string.
     * @throws IOException If reading fails.
     */
    private String readFileContentOptimized(String filePath) throws IOException {
        BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(filePath), "UTF-8"), 8192);
        StringBuilder content = new StringBuilder(8192);
        char[] buffer = new char[8192];
        int bytesRead;
        
        while ((bytesRead = reader.read(buffer)) != -1) {
            content.append(buffer, 0, bytesRead);
        }
        
        reader.close();
        return content.toString();
    }
    
    /**
     * Modern replacement for DownloadTask AsyncTask - executes download in background.
     * @param callback The callback to notify on completion or error.
     * @param url The URL to download from.
     */
    private void executeDownloadTask(DownloadCallback callback, String url) {
        ThreadManager.getInstance().executeNetworkWithCallbacks(
            () -> {
                try {
                    String filePath = downloadHtmlContent(url);
                    if (filePath != null) {
                        String content = readFileContentOptimized(filePath);
                        ThreadManager.getInstance().runOnUiThread(() -> 
                            callback.onDownloadComplete(filePath, content));
                    } else {
                        handleDownloadFailure(callback, "Download failed");
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Download failed: " + e.getMessage());
                    handleDownloadFailure(callback, e.getMessage());
                }
            },
            null, // no pre-execute needed
            null  // post-execute handled in background task
        );
    }
    
    /**
     * Handles download failure by trying cache or reporting error.
     * @param callback The callback to notify.
     * @param errorMessage The error message.
     */
    private void handleDownloadFailure(DownloadCallback callback, String errorMessage) {
        String cachedFile = getCachedReportPath();
        if (new File(cachedFile).exists()) {
            Log.d(TAG, "Download failed, using cached file");
            try {
                String content = readFileContentOptimized(cachedFile);
                ThreadManager.getInstance().runOnUiThread(() -> 
                    callback.onDownloadComplete(cachedFile, content));
            } catch (IOException e) {
                ThreadManager.getInstance().runOnUiThread(() -> 
                    callback.onDownloadError("Error reading cached file: " + e.getMessage()));
            }
        } else {
            ThreadManager.getInstance().runOnUiThread(() -> 
                callback.onDownloadError(errorMessage != null ? errorMessage : "Download failed"));
        }
    }
    
    /**
     * Downloads the HTML content from the given URL and saves it to cache.
     * @param urlString The URL to download from.
     * @return The file path to the saved HTML file.
     * @throws IOException If download or save fails.
     */
    private String downloadHtmlContent(String urlString) throws IOException {
            Log.d(TAG, "Downloading from URL: " + urlString);
            
            URL url = new URL(urlString);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            // Reduced timeouts for faster failure detection
            connection.setConnectTimeout(10000);  // 10 seconds instead of 30
            connection.setReadTimeout(15000);     // 15 seconds instead of 45
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:40.0)");
            
            try {
                int responseCode = connection.getResponseCode();
                Log.d(TAG, "HTTP Response Code: " + responseCode);
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    InputStream inputStream = connection.getInputStream();
                    String content = readStreamOptimized(inputStream);
                    
                    // Save to local file
                    String filePath = getCachedReportPath();
                    Log.d(TAG, "Saving to file path: " + filePath);
                    saveToFileOptimized(content, filePath);
                    
                    Log.d(TAG, "Report downloaded and saved to: " + filePath);
                    return filePath;
                } else {
                    String errorMessage = "HTTP error code: " + responseCode;
                    if (responseCode == 403) {
                        errorMessage += " (Access Forbidden - check URL permissions)";
                    }
                    Log.e(TAG, errorMessage);
                    throw new IOException(errorMessage);
                }
            } finally {
                connection.disconnect();
            }
    }
    
    /**
     * Reads an InputStream into a string with optimized performance.
     * @param inputStream The input stream to read.
     * @return The content as a string.
     * @throws IOException If reading fails.
     */
    private String readStreamOptimized(InputStream inputStream) throws IOException {
            BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream), 8192); // Larger buffer
            StringBuilder content = new StringBuilder(8192); // Pre-allocate buffer
            char[] buffer = new char[8192]; // Use char buffer for better performance
            int bytesRead;
            
            while ((bytesRead = reader.read(buffer)) != -1) {
                content.append(buffer, 0, bytesRead);
            }
            
            reader.close();
            return content.toString();
    }
    
    /**
     * Saves content to a file with optimized performance.
     * @param content The content to save.
     * @param filePath The file path to save to.
     * @throws IOException If writing fails.
     */
    private void saveToFileOptimized(String content, String filePath) throws IOException {
            try {
                File file = new File(filePath);
                File parentDir = file.getParentFile();
                if (parentDir != null && !parentDir.exists()) {
                    parentDir.mkdirs();
                }
                
                FileOutputStream fos = new FileOutputStream(file);
                byte[] bytes = content.getBytes("UTF-8");
                fos.write(bytes);
                fos.flush();
                fos.close();
                
                Log.d(TAG, "File saved successfully: " + filePath + " (size: " + bytes.length + " bytes)");
            } catch (IOException e) {
                Log.e(TAG, "Error saving file: " + e.getMessage());
                throw e;
        }
    }
    
    /**
     * Modern replacement for DownloadUrlTask AsyncTask - gets URL and executes download.
     * @param callback The callback to notify on completion or error.
     */
    private void executeDownloadUrlTask(DownloadCallback callback) {
        ThreadManager.getInstance().executeNetworkWithCallbacks(
            () -> {
                try {
                    // Get the report URL from pointer data
                    String reportUrl = staticVariables.getPointerUrlData("reportUrl");
                    Log.d(TAG, "Retrieved report URL: " + reportUrl);
                    
                    if (reportUrl != null && !reportUrl.isEmpty()) {
                        // Download the actual report content on UI thread
                        ThreadManager.getInstance().runOnUiThread(() -> 
                            executeDownloadTask(callback, reportUrl));
                    } else {
                        ThreadManager.getInstance().runOnUiThread(() -> 
                            callback.onDownloadError("Failed to get report URL"));
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Failed to get report URL: " + e.getMessage());
                    ThreadManager.getInstance().runOnUiThread(() -> 
                        callback.onDownloadError("Failed to get report URL: " + e.getMessage()));
                }
            },
            null, // no pre-execute needed
            null  // post-execute handled in background task
        );
    }
} 