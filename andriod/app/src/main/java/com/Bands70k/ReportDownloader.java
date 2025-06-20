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

public class ReportDownloader {
    
    private static final String TAG = "ReportDownloader";
    private static final String REPORT_FILENAME = "report_dashboard.html";
    private Context context;
    
    public interface DownloadCallback {
        void onDownloadComplete(String filePath, String htmlContent);
        void onDownloadError(String error);
    }
    
    public ReportDownloader(Context context) {
        this.context = context;
    }
    
    public void downloadReport(String url, DownloadCallback callback) {
        if (isNetworkAvailable()) {
            new DownloadTask(callback).execute(url);
        } else {
            String cachedFile = getCachedReportPath();
            if (new File(cachedFile).exists()) {
                Log.d(TAG, "Using cached report file");
                try {
                    String content = readFileContent(cachedFile);
                    callback.onDownloadComplete(cachedFile, content);
                } catch (IOException e) {
                    callback.onDownloadError("Error reading cached file: " + e.getMessage());
                }
            } else {
                callback.onDownloadError("No internet connection and no cached file available");
            }
        }
    }
    
    private String readFileContent(String filePath) throws IOException {
        StringBuilder content = new StringBuilder();
        BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(filePath), "UTF-8"));
        String line;
        while ((line = reader.readLine()) != null) {
            content.append(line).append("\n");
        }
        reader.close();
        return content.toString();
    }
    
    public String getCachedReportPath() {
        return context.getFilesDir().getAbsolutePath() + File.separator + REPORT_FILENAME;
    }
    
    private boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager = 
            (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }
    
    private class DownloadTask extends AsyncTask<String, Void, String> {
        private DownloadCallback callback;
        private String errorMessage;
        
        public DownloadTask(DownloadCallback callback) {
            this.callback = callback;
        }
        
        @Override
        protected String doInBackground(String... urls) {
            String url = urls[0];
            try {
                return downloadHtmlContent(url);
            } catch (Exception e) {
                errorMessage = e.getMessage();
                Log.e(TAG, "Download failed: " + e.getMessage());
                return null;
            }
        }
        
        @Override
        protected void onPostExecute(String result) {
            if (result != null) {
                // Read the content and pass both file path and content
                try {
                    String content = readFileContent(result);
                    callback.onDownloadComplete(result, content);
                } catch (IOException e) {
                    callback.onDownloadError("Error reading downloaded file: " + e.getMessage());
                }
            } else {
                // Try to use cached file if download failed
                String cachedFile = getCachedReportPath();
                if (new File(cachedFile).exists()) {
                    Log.d(TAG, "Download failed, using cached file");
                    try {
                        String content = readFileContent(cachedFile);
                        callback.onDownloadComplete(cachedFile, content);
                    } catch (IOException e) {
                        callback.onDownloadError("Error reading cached file: " + e.getMessage());
                    }
                } else {
                    callback.onDownloadError(errorMessage != null ? errorMessage : "Download failed");
                }
            }
        }
        
        private String downloadHtmlContent(String urlString) throws IOException {
            Log.d(TAG, "Downloading from URL: " + urlString);
            
            URL url = new URL(urlString);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(30000);
            connection.setReadTimeout(45000);
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:40.0)");
            
            try {
                int responseCode = connection.getResponseCode();
                Log.d(TAG, "HTTP Response Code: " + responseCode);
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    InputStream inputStream = connection.getInputStream();
                    String content = readStream(inputStream);
                    
                    // Save to local file
                    String filePath = getCachedReportPath();
                    Log.d(TAG, "Saving to file path: " + filePath);
                    saveToFile(content, filePath);
                    
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
        
        private String readStream(InputStream inputStream) throws IOException {
            BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
            StringBuilder content = new StringBuilder();
            String line;
            
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            
            reader.close();
            return content.toString();
        }
        
        private void saveToFile(String content, String filePath) throws IOException {
            try {
                File file = new File(filePath);
                File parentDir = file.getParentFile();
                if (parentDir != null && !parentDir.exists()) {
                    parentDir.mkdirs();
                }
                
                FileOutputStream fos = new FileOutputStream(file);
                fos.write(content.getBytes("UTF-8"));
                fos.flush();
                fos.close();
                
                Log.d(TAG, "File saved successfully: " + filePath + " (size: " + content.length() + " chars)");
            } catch (IOException e) {
                Log.e(TAG, "Error saving file: " + e.getMessage());
                throw e;
            }
        }
    }
} 