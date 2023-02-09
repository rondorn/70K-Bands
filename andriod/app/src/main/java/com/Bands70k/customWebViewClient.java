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
        thisView = view;
        view.loadUrl(url);

        //return true if this method handled the link event
        //or false otherwise
        return true;
    }
}