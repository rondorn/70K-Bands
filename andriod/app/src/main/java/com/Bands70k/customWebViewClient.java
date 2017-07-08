package com.Bands70k;

/**
 * Created by rdorn on 7/31/15.
 */
//web view client implementation

import android.webkit.WebView;
import android.webkit.WebViewClient;

public class customWebViewClient extends WebViewClient {
    public boolean shouldOverrideUrlLoading(WebView view, String url)
    {
        //do whatever you want with the url that is clicked inside the webview.
        //for example tell the webview to load that url.
        view.loadUrl(url);
        //return true if this method handled the link event
        //or false otherwise
        return true;
    }
}