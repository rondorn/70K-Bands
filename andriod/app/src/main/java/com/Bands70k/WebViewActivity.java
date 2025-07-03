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
        
        // Set up WebViewClient to handle loading
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                view.loadUrl(url);
                return true;
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
            Log.d("WebViewActivity", "Starting internal loading for URL: " + reportUrl);
            loadReportWithCaching(reportUrl);
        } else {
            // Fallback: Check for legacy intent extras
            String htmlContent = getIntent().getStringExtra("htmlContent");
            String directUrl = getIntent().getStringExtra("directUrl");
            
            if (htmlContent != null && !htmlContent.isEmpty()) {
                Log.d("WebViewActivity", "Loading provided HTML content");
                webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null);
            } else if (directUrl != null && !directUrl.isEmpty()) {
                Log.d("WebViewActivity", "Loading URL directly: " + directUrl);
                webView.loadUrl(directUrl);
            } else {
                Log.e("WebViewActivity", "No content or URL provided");
                Toast.makeText(this, "Unable to load report", Toast.LENGTH_SHORT).show();
                finish();
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
     * Reads the content of a cached file as a string.
     * @param filePath The path to the cached file.
     * @return The file content as a string.
     * @throws IOException If reading fails.
     */
    private String readCachedFileContent(String filePath) throws IOException {
        StringBuilder content = new StringBuilder();
        BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(filePath), "UTF-8"));
        String line;
        while ((line = reader.readLine()) != null) {
            content.append(line).append("\n");
        }
        reader.close();
        return content.toString();
    }
} 