package com.Bands70k;

/**
 * Created by rdorn on 7/25/15.
 */

import android.app.Activity;

import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.os.Bundle;

import android.os.SystemClock;
import android.support.v4.app.NavUtils;
import android.util.Log;

import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ProgressBar;


import java.util.Iterator;
import java.util.Map;


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
    private String orientation;
    private String bandNote;
    private String bandName;
    private BandNotes bandHandler;
    private Boolean clickedOnEvent = false;

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.band_details);

        View view = getWindow().getDecorView();
        int orientationNum = getResources().getConfiguration().orientation;
        if (Configuration.ORIENTATION_LANDSCAPE == orientationNum) {
            orientation = "landscape";
        } else {
            orientation = "portrait";
        }

        bandName = BandInfo.getSelectedBand();

        if (bandName == null) {
            onBackPressed();
        } else if (bandName.isEmpty() == false) {
            bandHandler = new BandNotes(bandName);
            bandNote = bandHandler.getBandNote();
            initializeWebContent();
        } else {
            onBackPressed();
        }
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);

        // Checks the orientation of the screen
        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            orientation = "landscape";
        } else if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
            orientation = "portrait";
        }
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
                Log.d("Variable is", "'" + value + "'");
                if (value.equals("Notes")) {
                    Log.d("Variable is", " Lets run this code");
                    staticVariables.writeNoteHtml = createEditNoteInterface(BandInfo.getSelectedBand());
                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();

                } else if (value.startsWith(bandName + ":")){

                    if (clickedOnEvent == false){
                        clickedOnEvent = true;
                        Log.d("showAttended", " Lets set this value of " + value);
                        String status = staticVariables.attendedHandler.addShowsAttended(value);
                        String message = staticVariables.attendedHandler.setShowsAttendedStatus(status);
                        HelpMessageHandler.showMessage(message);

                        Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                        startActivity(showDetails);
                        finish();
                    }

                }else if (value.startsWith("UserNoteSubmit:")){

                    staticVariables.writeNoteHtml = "";
                    //code to write note for band
                    value = value.replaceFirst("UserNoteSubmit:", "");
                    bandHandler.saveBandNote(value);
                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();

                } else {
                    rankStore.saveBandRanking(BandInfo.getSelectedBand(), resolveValue(value));

                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();
                }
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

        staticVariables.writeNoteHtml = "";
        if (inLink){
            mWebView.onPause();
            Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
            startActivity(showDetails);
            finish();

        } else {
            SystemClock.sleep(70);
            setResult(RESULT_OK, null);
            finish();
            NavUtils.navigateUpTo(this, new Intent(this,
                    showBands.class));

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
            newValue = "";

        } else {
            newValue = value;
        }

        return newValue;
    }

    public void createDetailHTML () {

        SetButtonColors();

        String scheduleText = "";
        String commentHeight;
        ImageHandler imageHandler = new ImageHandler(bandName);
        try {
            scheduleText = buildScheduleView();
        } catch (Exception error){
            //if this causes an exception, no worries..just don't display the schedule
        }

        if (scheduleText.contains("onclick") == false){
            commentHeight = "46%";
        } else {
            commentHeight = "20%";
        }
            htmlText =
                    "<html><div style='height:82%;font-size:130%;'>" +
                            "<center>" + bandName + "</center><br>" +
                            "<center><img style='max-height:15%;max-height:15vh' src='" + imageHandler.getImage() + "'</img>";

                if (staticVariables.writeNoteHtml.isEmpty() == false) {
                    Log.d("Variable is", "Adding HTML text of " + staticVariables.writeNoteHtml);
                    htmlText += staticVariables.writeNoteHtml;

                } else {
                    if (orientation == "portrait") {
                        htmlText += displayLinks(bandName);

                        if (BandInfo.getCountry(bandName) != "") {
                            htmlText += "<ul style='overflow:hidden;font-size:14px;font-size:4.0vw;list-style-type:none;text-align:left;margin-left:-20px;color:darkred'>";

                            htmlText += "<li style='float:left;display:inline;width:20%'>Country:</li>";
                            htmlText += "<li style='float:left;display:inline;width:80%'>" + BandInfo.getCountry(bandName) + "</li>";

                            htmlText += "<li style='float:left;display:inline;width:20%'>Genre:</li>";
                            htmlText += "<li style='float:left;display:inline;width:80%'>" + BandInfo.getGenre(bandName) + "</li>";

                            if (BandInfo.getNote(bandName) != "") {
                                htmlText += "<li style='float:left;display:inline;width:20%'>Misc:</li>";
                                htmlText += "<li style='float:left;display:inline;width:80%'>" + BandInfo.getNote(bandName) + "</li>";
                            }
                            htmlText += "</ul>";
                        }
                        if (bandNote != "" && imageHandler.getImage().toString() != staticVariables.logo70kUrl) {
                            htmlText += "<ul style='overflow:hidden;font-size:10px;font-size:4.0vw;list-style-type:none;text-align:left;margin-left:-25px;color:balck'>";
                            htmlText += "<li style='float:left;display:inline;width:20%'><button style='overflow:hidden;font-size:10px;font-size:4.0vw' type=button value=Notes onclick='ok.performClick(this.value);'>Notes:</button></li>";
                            htmlText += "<li style='float:left;display:inline;width:80%'><div style='width:100%;height:" + commentHeight + ";overflow:scroll;text-overflow:ellipsis;font-size:10px;font-size:4.0vw'>" + bandNote + "</div></li>";
                            htmlText += "</ul>";
                        }
                    } else {
                        htmlText += "<br><br>";
                    }


                    htmlText += scheduleText;

                    htmlText += "</div><div style='height:10vh;position:fixed;bottom:0;width:100vw;'><table width=100%><tr width=100%>" +
                            "<td><button style='background:" + mustButtonColor + "' type=button value=" + staticVariables.mustSeeKey + " onclick='ok.performClick(this.value);'>" + staticVariables.mustSeeIcon + " Must</button></td>" +
                            "<td><button style='background:" + mightButtonColor + "' type=button value=" + staticVariables.mightSeeKey + " onclick='ok.performClick(this.value);'>" + staticVariables.mightSeeIcon + " Might</button></td>" +
                            "<td><button style='background:" + wontButtonColor + "' type=button value=" + staticVariables.wontSeeKey + " onclick='ok.performClick(this.value);'>" + staticVariables.wontSeeIcon + " Wont</button></td>" +
                            "<td><button style='background:" + unknownButtonColor + "' type=button value=" + staticVariables.unknownKey + " onclick='ok.performClick(this.value);'>" + staticVariables.unknownIcon + " Unknown</button></td>" +
                            "</tr></table></div>" +
                            "</html>";
                }

            mWebView.loadDataWithBaseURL(null, htmlText, "text/html", "UTF-8", null);

    }

    private String buildScheduleView(){

        String htmlData;
        if (orientation == "portrait") {
            htmlData = "<ul style='font-size:12px;font-size:3vw;list-style-type:none;text-align:left;margin-left:-30px;margin-top:20px;face=\"sans-serif-thin\">";
        } else {
            htmlData = "<ul style='font-size:12px;font-size:3vw;list-style-type:none;text-align:left;margin-left:-30px;margin-top:20px;face=\"sans-serif-thin\">";
        }
        if (BandInfo.scheduleRecords.get(bandName) != null) {
            Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();

            while (entries.hasNext()) {
                Map.Entry thisEntry = (Map.Entry) entries.next();
                Object key = thisEntry.getKey();

                String location = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowLocation();
                String locationIcon = staticVariables.getVenuIcon(location);

                String startTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getStartTimeString();
                String eventType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType();

                String attendIndex = bandName + ":" + location + ":" + startTime + ":" + eventType;
                String color = staticVariables.attendedHandler.getShowAttendedColor(attendIndex);

                htmlData += "<li style='margin-top:5px;margin-top:5px;' onclick='ok.performClick(\"" + attendIndex + "\");'>";
                htmlData += "<font color='" + color + "' >";
                htmlData += staticVariables.attendedHandler.getShowAttendedIcon(attendIndex) + " ";
                htmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowDay() + " - ";
                htmlData += dateTimeFormatter.formatScheduleTime(startTime) + " - ";
                htmlData += dateTimeFormatter.formatScheduleTime(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getEndTimeString()) + " - ";
                htmlData += location + locationIcon + " - ";
                htmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType() + " ";
                htmlData += staticVariables.getEventTypeIcon(eventType);
                htmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowNotes();
                htmlData += "</font></li>";

                Log.d("htmlData is", "Adding HTML text of " + htmlData);
            }

            htmlData += "</ul>";
        }

        return htmlData;
    }

    private String displayLinks(String bandName){

        String html = "<br><br><br><br><br><br><br><br><br><br><br>";

        String disable;
        if (OnlineStatus.isOnline() == true) {
            disable = "";
        } else {
            //disable and gray out link if offline
            disable = "style='pointer-events:none;cursor:default;color:grey'";
        }
        if (BandInfo.getOfficalWebLink(bandName).equals("http://") == false) {

            Log.d("Officia;Link", "Link is " + BandInfo.getOfficalWebLink(bandName));
            html = "<center><ul style='font-size:15px;font-size:5.0vw;list-style-type:none;text-align:left;margin-left:60px'>" +
                    "<li><a " + disable + " href='" + BandInfo.getOfficalWebLink(bandName) + "' onclick='link.webLinkClick()'>Offical Link</a></li>" +
                    "<li><a " + disable + " href='" + BandInfo.getWikipediaWebLink(bandName) + "' onclick='link.webLinkClick()'>Wikipedia</a></li>" +
                    "<li><a " + disable + " href='" + BandInfo.getYouTubeWebLink(bandName) + "' onclick='link.webLinkClick()'>YouTube</a></li>" +
                    "<li><a " + disable + " href='" + BandInfo.getMetalArchivesWebLink(bandName) + "' onclick='link.webLinkClick()'>Metal Archives</a></li>" +
                    "</ul></center>";

        }

        return html;

    }

    private String createEditNoteInterface(String bandName){

        String html = "<br><br><br>";

        if (bandHandler.getNoteIsBlank() == true){
            bandNote = "";
        }

        bandNote = bandNote.replaceAll("<br>", "\n");
        html += "<form><textarea name='userNotes' id='userNotes' style='width:96%;height:70%;background-color:white;color:black;border:none;padding:2%;font:14px/16px sans-serif;outline:1px solid blue;' autofocus>";
        html += bandNote;
        html += "</textarea>";
        html += "<br><br><button type=button value='UserNoteSubmit' onclick='ok.performClick(this.value + \":\" + this.form.userNotes.value);'>Save Note:</button></form><br>";

        return html;
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

