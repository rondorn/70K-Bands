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
import java.io.File;

public class WebViewActivity extends Activity {
    
    private WebView webView;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.webview_activity);
        
        webView = findViewById(R.id.webView);
        
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
        
        // Check for HTML content first, then fall back to direct URL
        String htmlContent = getIntent().getStringExtra("htmlContent");
        String directUrl = getIntent().getStringExtra("directUrl");
        boolean isRefreshing = getIntent().getBooleanExtra("isRefreshing", false);
        String refreshUrl = getIntent().getStringExtra("refreshUrl");
        
        if (htmlContent != null && !htmlContent.isEmpty()) {
            Log.d("WebViewActivity", "Loading cached HTML content");
            // Load HTML content directly to avoid file:// security restrictions
            webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null);
            
            // If this is a refresh scenario, start background refresh
            if (isRefreshing && refreshUrl != null) {
                startBackgroundRefresh(refreshUrl);
            }
        } else if (directUrl != null && !directUrl.isEmpty()) {
            Log.d("WebViewActivity", "Loading URL directly: " + directUrl);
            // Fallback: Load URL directly
            webView.loadUrl(directUrl);
        } else {
            Log.e("WebViewActivity", "No content or URL provided");
            Toast.makeText(this, "Unable to load report", Toast.LENGTH_SHORT).show();
            finish();
        }
    }
    
    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
    
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
} 