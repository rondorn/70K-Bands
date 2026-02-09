package com.Bands70k;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.Toast;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.FileOutputStream;
import java.net.URI;

/**
 * Activity for displaying HTML reports in a WebView, with caching and background refresh support.
 */
public class WebViewActivity extends Activity {
    
    private WebView webView;
    private View waitingMessage;
    
    /**
     * Called when the activity is created. Sets up the WebView and loads the report.
     * @param savedInstanceState The saved instance state bundle.
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.webview_activity);
        
        webView = findViewById(R.id.webView);
        waitingMessage = findViewById(R.id.waitingMessage);
        
        // Configure WebView settings
        WebSettings webSettings = webView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setLoadWithOverviewMode(true);
        webSettings.setUseWideViewPort(true);
        webSettings.setBuiltInZoomControls(true);
        webSettings.setDisplayZoomControls(false);
        
        // Performance optimizations
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT);
        
        // SECURITY FIX: Restrict file access to prevent cross-app scripting
        webSettings.setAllowFileAccess(false);  // Disable file:// URL access
        webSettings.setAllowContentAccess(true);  // Keep content:// access for legitimate content
        
        // SECURITY FIX: Prevent universal file access (API 16+)
        if (android.os.Build.VERSION.SDK_INT >= 16) {
            webSettings.setAllowUniversalAccessFromFileURLs(false);
            webSettings.setAllowFileAccessFromFileURLs(false);
        }
        
        // Enable hardware acceleration for better performance
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
        
        // Set up WebViewClient to handle loading
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                // SECURITY FIX: Validate URL before loading - inline validation
                boolean urlSafe = false;
                if (url != null && !url.trim().isEmpty()) {
                    try {
                        java.net.URI uri = java.net.URI.create(url.trim());
                        String scheme = uri.getScheme();
                        if (scheme != null) {
                            scheme = scheme.toLowerCase();
                            if (scheme.equals("http") || scheme.equals("https")) {
                                String lowerUrl = url.toLowerCase();
                                if (!lowerUrl.contains("javascript:") && 
                                    !lowerUrl.contains("data:") && 
                                    !lowerUrl.contains("file:") &&
                                    !lowerUrl.contains("content:") &&
                                    !lowerUrl.contains("android_asset:") &&
                                    !lowerUrl.contains("android_res:")) {
                                    String host = uri.getHost();
                                    if (host != null && !host.trim().isEmpty() &&
                                        !host.equals("localhost") && 
                                        !host.equals("127.0.0.1") && 
                                        !host.startsWith("192.168.") && 
                                        !host.startsWith("10.") && 
                                        !host.startsWith("172.")) {
                                        urlSafe = true;
                                    }
                                }
                            }
                        }
                    } catch (Exception e) {
                        Log.w("WebViewActivity", "URL validation failed: " + e.getMessage());
                    }
                }
                
                if (urlSafe) {
                    view.loadUrl(url);
                    return true;
                } else {
                    Log.w("WebViewActivity", "Blocked potentially unsafe URL: " + url);
                    Toast.makeText(WebViewActivity.this, "URL blocked for security reasons", Toast.LENGTH_SHORT).show();
                    return true; // Block the navigation
                }
            }
            
            @Override
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                Log.e("WebViewActivity", "Error loading page: " + description);
                Toast.makeText(WebViewActivity.this, "Error loading report: " + description, Toast.LENGTH_LONG).show();
            }
        });
        
        // Get the report URL and handle all loading logic internally
        String reportUrl = getIntent().getStringExtra("reportUrl");
        
        if (reportUrl != null && !reportUrl.isEmpty()) {
            // SECURITY FIX: Validate URL from intent before using - inline validation
            boolean urlSafe = false;
            try {
                java.net.URI uri = java.net.URI.create(reportUrl.trim());
                String scheme = uri.getScheme();
                if (scheme != null) {
                    scheme = scheme.toLowerCase();
                    if (scheme.equals("http") || scheme.equals("https")) {
                        String lowerUrl = reportUrl.toLowerCase();
                        if (!lowerUrl.contains("javascript:") && 
                            !lowerUrl.contains("data:") && 
                            !lowerUrl.contains("file:") &&
                            !lowerUrl.contains("content:") &&
                            !lowerUrl.contains("android_asset:") &&
                            !lowerUrl.contains("android_res:")) {
                            String host = uri.getHost();
                            if (host != null && !host.trim().isEmpty() &&
                                !host.equals("localhost") && 
                                !host.equals("127.0.0.1") && 
                                !host.startsWith("192.168.") && 
                                !host.startsWith("10.") && 
                                !host.startsWith("172.")) {
                                urlSafe = true;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                Log.w("WebViewActivity", "URL validation failed: " + e.getMessage());
            }
            
            if (urlSafe) {
                Log.d("WebViewActivity", "Starting internal loading for URL: " + reportUrl);
                loadReportWithCaching(reportUrl);
            } else {
                Log.w("WebViewActivity", "Blocked unsafe URL from intent: " + reportUrl);
                Toast.makeText(this, "URL blocked for security reasons", Toast.LENGTH_SHORT).show();
                finish();
            }
        } else {
            // For stats page, get URL in background and load cached content immediately
            boolean isStatsPage = getIntent().getBooleanExtra("isStatsPage", false);
            if (isStatsPage) {
                Log.d("WebViewActivity", "Loading stats page with cached content first");
                loadStatsPageWithCaching();
            } else {
                // Fallback: Check for legacy intent extras
                String htmlContent = getIntent().getStringExtra("htmlContent");
                String directUrl = getIntent().getStringExtra("directUrl");
                
                if (htmlContent != null && !htmlContent.isEmpty()) {
                    Log.d("WebViewActivity", "Loading provided HTML content");
                    webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null);
                } else if (directUrl != null && !directUrl.isEmpty()) {
                    Log.d("WebViewActivity", "Loading URL directly: " + directUrl);
                    // SECURITY FIX: Validate URL from intent before loading - inline validation
                    boolean urlSafe = false;
                    try {
                        java.net.URI uri = java.net.URI.create(directUrl.trim());
                        String scheme = uri.getScheme();
                        if (scheme != null) {
                            scheme = scheme.toLowerCase();
                            if (scheme.equals("http") || scheme.equals("https")) {
                                String lowerUrl = directUrl.toLowerCase();
                                if (!lowerUrl.contains("javascript:") && 
                                    !lowerUrl.contains("data:") && 
                                    !lowerUrl.contains("file:") &&
                                    !lowerUrl.contains("content:") &&
                                    !lowerUrl.contains("android_asset:") &&
                                    !lowerUrl.contains("android_res:")) {
                                    String host = uri.getHost();
                                    if (host != null && !host.trim().isEmpty() &&
                                        !host.equals("localhost") && 
                                        !host.equals("127.0.0.1") && 
                                        !host.startsWith("192.168.") && 
                                        !host.startsWith("10.") && 
                                        !host.startsWith("172.")) {
                                        urlSafe = true;
                                    }
                                }
                            }
                        }
                    } catch (Exception e) {
                        Log.w("WebViewActivity", "URL validation failed: " + e.getMessage());
                    }
                    
                    if (urlSafe) {
                        webView.loadUrl(directUrl);
                    } else {
                        Log.w("WebViewActivity", "Blocked unsafe URL from intent: " + directUrl);
                        Toast.makeText(this, "URL blocked for security reasons", Toast.LENGTH_SHORT).show();
                        finish();
                    }
                } else {
                    Log.e("WebViewActivity", "No content or URL provided");
                    Toast.makeText(this, "Unable to load report", Toast.LENGTH_SHORT).show();
                    finish();
                }
            }
        }
    }
    
    /**
     * Handles the back button press, navigating WebView history if possible.
     */
    @Override
    public void onBackPressed() {
        boolean isStatsPage = getIntent().getBooleanExtra("isStatsPage", false);
        if (isStatsPage) {
            finish();
        } else {
            if (webView.canGoBack()) {
                webView.goBack();
            } else {
                super.onBackPressed();
            }
        }
    }
    
    /**
     * Loads the report with caching and background refresh.
     * @param url The URL of the report to load.
     */
    private void loadReportWithCaching(String url) {
        ReportDownloader downloader = new ReportDownloader(this);
        
        // First, check if we have cached content and display it immediately
        String cachedFilePath = downloader.getCachedReportPath();
        File cachedFile = new File(cachedFilePath);
        
        if (cachedFile.exists()) {
            // Load cached content immediately
            Log.d("WebViewActivity", "Loading cached content immediately");
            try {
                String cachedContent = readCachedFileContent(cachedFilePath);
                webView.loadDataWithBaseURL(null, cachedContent, "text/html", "UTF-8", null);
                webView.setVisibility(View.VISIBLE);
                waitingMessage.setVisibility(View.GONE);
                // Start background refresh for fresh content
                startBackgroundRefresh(url);
                return;
            } catch (Exception e) {
                Log.e("WebViewActivity", "Error reading cached file: " + e.getMessage());
                // Continue to download fresh content
            }
        }
        
        // No cached content available, download fresh content
        Log.d("WebViewActivity", "No cached content, downloading fresh content");
        webView.setVisibility(View.GONE);
        waitingMessage.setVisibility(View.VISIBLE);
        downloader.downloadReport(url, new ReportDownloader.DownloadCallback() {
            @Override
            public void onDownloadComplete(String filePath, String htmlContent) {
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null);
                        webView.setVisibility(View.VISIBLE);
                        waitingMessage.setVisibility(View.GONE);
                    }
                });
            }
            
            @Override
            public void onDownloadError(String error) {
                Log.e("WebViewActivity", "Download failed: " + error);
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        // Fallback: Load URL directly
                        webView.loadUrl(url);
                        webView.setVisibility(View.VISIBLE);
                        waitingMessage.setVisibility(View.GONE);
                    }
                });
            }
        });
    }
    
    /**
     * Starts a background refresh of the report content.
     * @param url The URL to refresh from.
     */
    private void startBackgroundRefresh(String url) {
        Log.d("WebViewActivity", "Starting background refresh for URL: " + url);
        
        ReportDownloader downloader = new ReportDownloader(this);
        downloader.downloadReport(url, new ReportDownloader.DownloadCallback() {
            @Override
            public void onDownloadComplete(String filePath, String htmlContent) {
                // Update the WebView with fresh content
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        Log.d("WebViewActivity", "Refreshing WebView with new content");
                        webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null);
                        // Toast.makeText(WebViewActivity.this, "Report updated with fresh data", Toast.LENGTH_SHORT).show();
                    }
                });
            }
            
            @Override
            public void onDownloadError(String error) {
                Log.d("WebViewActivity", "Background refresh failed: " + error);
                // Silently fail for background refresh - user already has cached content
            }
        });
    }

    /**
     * Loads the stats page with caching, using a completely independent thread.
     * This ensures the stats page loads in parallel with other data loads.
     */
    private void loadStatsPageWithCaching() {
        // Use a dedicated thread for stats loading to ensure it runs in parallel
        new Thread(new Runnable() {
            @Override
            public void run() {
                loadStatsPageIndependent();
            }
        }).start();
    }
    
    /**
     * Independent stats page loader that doesn't interfere with other downloads.
     */
    private void loadStatsPageIndependent() {
        try {
            // Check for cached content first
            String cachedFilePath = getCacheDir().getAbsolutePath() + "/stats_report.html";
            File cachedFile = new File(cachedFilePath);
            
            if (cachedFile.exists()) {
                Log.d("WebViewActivity", "Loading stats page with cached content immediately");
                String cachedContent = readCachedFileContent(cachedFilePath);
                
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        webView.loadDataWithBaseURL(null, cachedContent, "text/html", "UTF-8", null);
                        webView.setVisibility(View.VISIBLE);
                        waitingMessage.setVisibility(View.GONE);
                    }
                });
                
                // Start background refresh for fresh content
                downloadFreshStatsInBackground();
            } else {
                Log.d("WebViewActivity", "No cached stats page, downloading fresh content");
                downloadFreshStatsInBackground();
            }
        } catch (Exception e) {
            Log.e("WebViewActivity", "Error in independent stats loader: " + e.getMessage());
            downloadFreshStatsInBackground();
        }
    }
    
    /**
     * Downloads fresh stats content using independent network calls.
     */
    private void downloadFreshStatsInBackground() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                webView.setVisibility(View.GONE);
                waitingMessage.setVisibility(View.VISIBLE);
            }
        });
        
        // Use a dedicated thread for network operations
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    // Get report URL independently
                    String reportUrl = getReportUrlIndependent();
                    if (reportUrl != null && !reportUrl.isEmpty()) {
                        downloadStatsContentIndependent(reportUrl);
                    } else {
                        Log.e("WebViewActivity", "Failed to get report URL");
                        showErrorOnUiThread("Failed to get report URL");
                    }
                } catch (Exception e) {
                    Log.e("WebViewActivity", "Error downloading stats: " + e.getMessage());
                    showErrorOnUiThread("Error downloading stats: " + e.getMessage());
                }
            }
        }).start();
    }
    
    /**
     * Gets the report URL independently without using shared resources.
     */
    private String getReportUrlIndependent() {
        try {
            // Try cached pointer data first
            String cachedUrl = staticVariables.getCachedPointerData("reportUrl");
            if (!cachedUrl.isEmpty()) {
                return cachedUrl;
            }
            
            // If no cached URL, make independent network call
            String pointerUrl = null;
            String customPointerUrl = staticVariables.preferences.getCustomPointerUrl();
            if (customPointerUrl != null && !customPointerUrl.trim().isEmpty()) {
                pointerUrl = customPointerUrl.trim();
            } else {
                pointerUrl = staticVariables.getDefaultUrls();
                if (staticVariables.preferences.getPointerUrl().equals("Testing")) {
                    pointerUrl = staticVariables.getDefaultUrlTest();
                }
            }
            
            // Make independent HTTP call
            URL url = new URL(pointerUrl);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            HttpConnectionHelper.applyTimeouts(connection);
            connection.setRequestMethod("GET");
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line).append("\n");
            }
            reader.close();
            connection.disconnect();
            
            // Parse response for reportUrl
            String[] lines = response.toString().split("\n");
            for (String line2 : lines) {
                if (line2.startsWith("reportUrl=")) {
                    return line2.substring("reportUrl=".length()).trim();
                }
            }
            
            return null;
        } catch (Exception e) {
            Log.e("WebViewActivity", "Error getting report URL: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Downloads stats content independently.
     */
    private void downloadStatsContentIndependent(String reportUrl) {
        try {
            URL url = new URL(reportUrl);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            HttpConnectionHelper.applyTimeouts(connection);
            connection.setRequestMethod("GET");
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            StringBuilder content = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
            reader.close();
            connection.disconnect();
            
            // Save to cache
            String cachedFilePath = getCacheDir().getAbsolutePath() + "/stats_report.html";
            FileOutputStream fos = new FileOutputStream(cachedFilePath);
            fos.write(content.toString().getBytes("UTF-8"));
            fos.close();
            
            // Load in WebView
            final String htmlContent = content.toString();
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null);
                    webView.setVisibility(View.VISIBLE);
                    waitingMessage.setVisibility(View.GONE);
                }
            });
            
        } catch (Exception e) {
            Log.e("WebViewActivity", "Error downloading stats content: " + e.getMessage());
            showErrorOnUiThread("Error downloading stats content: " + e.getMessage());
        }
    }
    
    /**
     * Shows error on UI thread.
     */
    private void showErrorOnUiThread(final String error) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                webView.setVisibility(View.VISIBLE);
                waitingMessage.setVisibility(View.GONE);
                Toast.makeText(WebViewActivity.this, error, Toast.LENGTH_SHORT).show();
            }
        });
    }
    
    /**
     * Reads the content of a cached file as a string with optimized performance.
     * @param filePath The path to the cached file.
     * @return The file content as a string.
     * @throws IOException If reading fails.
     */
    private String readCachedFileContent(String filePath) throws IOException {
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
} 