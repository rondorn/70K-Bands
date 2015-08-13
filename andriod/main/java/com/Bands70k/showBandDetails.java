package com.Bands70k;

/**
 * Created by rdorn on 7/25/15.
 */

import android.app.Activity;

import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;

import android.util.Log;

import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ProgressBar;


public class showBandDetails extends Activity {
    /** Called when the activity is first created. */

    private WebView mWebView;
    private String htmlText;
    private String mustButtonColor;
    private String mightButtonColor;
    private String wontButtonColor;
    private String unknownButtonColor;
    private Boolean inLink = false;
    private ProgressBar webProgressBar;

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.band_details);

        initializeWebContent();
    }

    private void initializeWebContent (){

        webProgressBar = (ProgressBar) findViewById(R.id.webProgressBar);

        mWebView = (WebView) findViewById(R.id.detailWebView);
        mWebView.setWebViewClient(new customWebViewClient());

        WebSettings webSettings = mWebView.getSettings();
        webSettings.setJavaScriptEnabled(true);


        mWebView.addJavascriptInterface(new Object() {

            @JavascriptInterface
            public void performClick(String value) {
                Log.d("Variable is", value);
                rankStore.saveBandRanking(BandInfo.getSelectedBand(), resolveValue(value));

                Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                startActivity(showDetails);
            }

        }, "ok");

        mWebView.addJavascriptInterface(new Object() {

            @JavascriptInterface
            public void webLinkClick() {
                inLink = true;
            }

        }, "link");

        createDetailHTML();
        webProgressBar.setVisibility(View.GONE);
    }

    @Override
    protected void onPause() {
        super.onPause();
        mWebView.reload();
    }

    @Override
    public void onResume() {
        super.onResume();
        setContentView(R.layout.band_details);
        initializeWebContent();
        inLink = false;
    }

    @Override
    public void onBackPressed() {

        if (inLink){
            mWebView.onPause();
            Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
            startActivity(showDetails);

        } else {
            Intent showDetails = new Intent(showBandDetails.this, showBands.class);
            startActivity(showDetails);
        }
    }

    public void SetButtonColors() {

        rankStore.getBandRankings();

        if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.mustSeeIcon)){
            mustButtonColor = "Silver";
            mightButtonColor = "WhiteSmoke";
            wontButtonColor = "WhiteSmoke";
            unknownButtonColor = "WhiteSmoke";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.mightSeeIcon)){
            mustButtonColor = "WhiteSmoke";
            mightButtonColor = "Silver";
            wontButtonColor = "WhiteSmoke";
            unknownButtonColor = "WhiteSmoke";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.wontSeeIcon)){
            mustButtonColor = "WhiteSmoke";
            mightButtonColor = "WhiteSmoke";
            wontButtonColor = "Silver";
            unknownButtonColor = "WhiteSmoke";

        } else {
            mustButtonColor = "WhiteSmoke";
            mightButtonColor = "WhiteSmoke";
            wontButtonColor = "WhiteSmoke";
            unknownButtonColor = "Silver";
        }
    }

    private String resolveValue (String value){

        String newValue;

        if (value.equals(staticVariables.mustSeeKey)){
            newValue = staticVariables.mustSeeIcon;

        } else if (value.equals(staticVariables.mightSeeKey)){
            newValue = staticVariables.mightSeeIcon;

        } else if (value.equals(staticVariables.wontSeeKey)){
            newValue = staticVariables.wontSeeIcon;

        } else if (value.equals(staticVariables.unknownKey)){
            newValue = staticVariables.unknownIcon;

        } else {
            newValue = value;
        }

        return newValue;
    }

    public void createDetailHTML () {

        String bandName = BandInfo.getSelectedBand();

        SetButtonColors();

            htmlText =
                    "<html><div style='height:90vh;font-size:130%;'>" +
                            "<center>" + bandName + "</center><br>" +
                            "<center><img src='" + BandInfo.getImageUrl(bandName) + "'</img>" +
                            "<center><ul style='list-style-type:none;text-align:left;margin-left:60px'>" +
                            "<li><a href='" + BandInfo.getOfficalWebLink(bandName) + "' onclick='link.webLinkClick()'>Offical Link</a></li>" +
                            "<li><a href='" + BandInfo.getWikipediaWebLink(bandName) + "' onclick='link.webLinkClick()'>Wikipedia</a></li>" +
                            "<li><a href='" + BandInfo.getYouTubeWebLink(bandName) + "' onclick='link.webLinkClick()'>YouTube</a></li>" +
                            "<li><a href='" + BandInfo.getMetalArchivesWebLink(bandName) + "' onclick='link.webLinkClick()'>Metal Archives</a></li>" +
                            "</ul></center><br></div><div style='height:10vh;position:fixed;bottom:0;width:100vw;'><table width=100%><tr width=100%>" +
                            "<td><button style='background:" + unknownButtonColor + "' type=button value=" + staticVariables.unknownKey + " onclick='ok.performClick(this.value);'>" + staticVariables.unknownIcon + "</button></td>" +
                            "<td><button style='background:" + mustButtonColor + "' type=button value=" + staticVariables.mustSeeKey + " onclick='ok.performClick(this.value);'>" + staticVariables.mustSeeIcon + " " + getResources().getString(R.string.must) + "</button></td>" +
                            "<td><button style='background:" + mightButtonColor + "' type=button value=" + staticVariables.mightSeeKey + " onclick='ok.performClick(this.value);'>" + staticVariables.mightSeeIcon + " " + getResources().getString(R.string.might) + "</button></td>" +
                            "<td><button style='background:" + wontButtonColor + "' type=button value=" + staticVariables.wontSeeKey + " onclick='ok.performClick(this.value);'>" + staticVariables.wontSeeIcon + " " + getResources().getString(R.string.wont) + "</button></td>" +
                            "</tr></table></div>" +
                            "</html>";

            mWebView.loadDataWithBaseURL("", htmlText, "text/html", "UTF-8", "");

    }

    private class customWebViewClient extends WebViewClient {

        @Override
        public void onPageFinished(WebView view, String url) {
            // TODO Auto-generated method stub
            super.onPageFinished(view, url);

            webProgressBar.setVisibility(View.GONE);
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            // TODO Auto-generated method stub
            super.onPageStarted(view, url, favicon);
            webProgressBar.setVisibility(View.VISIBLE);
        }

        public boolean shouldOverrideUrlLoading(WebView view, String url){

            view.loadUrl(url);
            return true;
        }
    }
}

