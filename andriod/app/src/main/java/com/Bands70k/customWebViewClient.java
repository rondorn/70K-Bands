package com.Bands70k;

/**
 * Created by rdorn on 7/31/15.
 */
//web view client implementation

import android.util.Log;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class customWebViewClient extends WebViewClient {

    private WebView thisView = null;

    public boolean shouldOverrideUrlLoading(WebView view, String url){
        //do whatever you want with the url that is clicked inside the webview.
        //for example tell the webview to load that url.
        Log.d("WebView", "Launching web view into " + url);
        
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
                Log.w("WebView", "URL validation failed: " + e.getMessage());
            }
        }
        
        if (urlSafe) {
            thisView = view;
            view.loadUrl(url);
            return true;
        } else {
            Log.w("WebView", "Blocked potentially unsafe URL: " + url);
            return true; // Block the navigation
        }
    }

}