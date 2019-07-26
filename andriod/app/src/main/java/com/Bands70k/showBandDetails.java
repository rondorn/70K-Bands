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

    private String rankIconLocation = "";

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

            Log.d("descriptionMapFileError",  "1 bandNote = " + bandNote);
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

    private void invertImageJavaScript(){
        /*
        function invert(){
            document.getElementById("theImage").style.filter="invert(100%)";
        }

         */
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
            rankIconLocation = "file:///android_res/drawable/icon_going_yes.png";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.mightSeeIcon)){
            mustButtonColor = "WhiteSmoke";
            mightButtonColor = "Silver";
            wontButtonColor = "WhiteSmoke";
            unknownButtonColor = "WhiteSmoke";
            rankIconLocation = "file:///android_res/drawable/icon_going_maybe.png";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.wontSeeIcon)){
            mustButtonColor = "WhiteSmoke";
            mightButtonColor = "WhiteSmoke";
            wontButtonColor = "Silver";
            unknownButtonColor = "WhiteSmoke";
            rankIconLocation = "file:///android_res/drawable/icon_going_no.png";

        } else {
            mustButtonColor = "WhiteSmoke";
            mightButtonColor = "WhiteSmoke";
            wontButtonColor = "WhiteSmoke";
            unknownButtonColor = "Silver";
            rankIconLocation = "";
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
        String startHeight;
        ImageHandler imageHandler = new ImageHandler(bandName);
        try {
            scheduleText = buildScheduleView();
        } catch (Exception error){
            //if this causes an exception, no worries..just don't display the schedule
        }

        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal") == false) {
            Log.d("descriptionMapFileError", "setting comment Higher 80 " + BandInfo.getOfficalWebLink(bandName));
            commentHeight = "62%";

        } else if (scheduleText.contains("onclick") == false ){
            Log.d("descriptionMapFileError",  "setting comment Higher 46 " + BandInfo.getOfficalWebLink(bandName));
            commentHeight = "53%";
        } else {
            Log.d("descriptionMapFileError",  "setting comment Higher 20 " + BandInfo.getOfficalWebLink(bandName));
            commentHeight = "45%";
        }
            htmlText =
                    "<html><head><script>function invert(){\n" +
                            "document.getElementById(\"bandLogo\").style.filter=\"invert(100%)\";\n" +
                            "}</script><body bgcolor=\"black\" style=\"color:white\"> <div style='height:82%;font-size:130%;'>" +
                            "<center>" + bandName + "</center><br>" +
                            "<center><img id=\"bandLogo\" style='max-height:15%;max-height:15vh' src='" + imageHandler.getImage() + "'</img>";

                if (staticVariables.writeNoteHtml.isEmpty() == false) {
                    Log.d("Variable is", "Adding HTML text of " + staticVariables.writeNoteHtml);
                    htmlText += staticVariables.writeNoteHtml;

                } else {
                    if (orientation == "portrait") {
                        htmlText += displayLinks(bandName);

                        if (BandInfo.getCountry(bandName) != "") {
                            htmlText += "<ul style='overflow:hidden;font-size:14px;font-size:4.0vw;list-style-type:none;text-align:left;margin-left:-20px;color:white'>";

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
                        if (bandNote != "") {
                            htmlText += "<ul style='overflow:hidden;font-size:10px;font-size:4.0vw;list-style-type:none;text-align:left;margin-left:-25px;color:balck'>";
                            htmlText += "<!--li style='float:left;display:inline;width:20%'><button style='overflow:hidden;font-size:10px;font-size:4.0vw' type=button value=Notes onclick='ok.performClick(this.value);'>Notes:</button></li -->";
                            htmlText += "<li style='float:left;display:inline;width:80%'><div style='width:98%;height:" + commentHeight + ";overflow:hidden;overflow-y:scroll;text-overflow:ellipsis;font-size:10px;font-size:4.0vw' ondblclick='ok.performClick(\"Notes\");'>" + bandNote + "</div></li>";
                            htmlText += "</ul>";
                        }
                    } else {
                        htmlText += "<br><br>";
                    }


                    htmlText += scheduleText;

                    htmlText += "</div><div style='height:10vh;position:fixed;bottom:0;width:100vw;'><table width=100%><tr width=100%>" +
                            "<td width=12%><img src=" + rankIconLocation + " height=32 width=32></td>" +
                            "<td width=22%><button style='width:100%;background:" + mustButtonColor + "' type=button value=" + staticVariables.mustSeeKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.must) + "</button></td>" +
                            "<td width=22%><button style='width:100%;background:" + mightButtonColor + "' type=button value=" + staticVariables.mightSeeKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.might) + "</button></td>" +
                            "<td width=22%><button style='width:100%;background:" + wontButtonColor + "' type=button value=" + staticVariables.wontSeeKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.wont) + "</button></td>" +
                            "<td width=22%><button style='width:100%;background:" + unknownButtonColor + "' type=button value=" + staticVariables.unknownKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.unknown) + "</button></td>" +
                            "</tr></table></div>" +
                            "</body></html>";
                }

            mWebView.loadDataWithBaseURL(null, htmlText, "text/html", "UTF-8", null);

    }

    private String buildScheduleView(){

        String htmlData;
        if (orientation == "portrait") {
            htmlData = "<ul width=100% style='font-size:12px;font-size:3vw;list-style-type:none;text-align:left;margin-left:-40px;margin-top:20px;face=\"sans-serif-thin\">";
        } else {
            htmlData = "<ul width=100% style='font-size:12px;font-size:3vw;list-style-type:none;text-align:left;margin-left:-40px;margin-top:20px;face=\"sans-serif-thin\">";
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

                String attendIndex = bandName + ":" + location + ":" + startTime + ":" + eventType + ":" + String.valueOf(staticVariables.eventYear);
                String color = staticVariables.attendedHandler.getShowAttendedColor(attendIndex);

                htmlData += "<li style='margin-top:5px;margin-top:5px;' onclick='ok.performClick(\"" + attendIndex + "\");'>";
                htmlData += "<img src=" + getAttendedImage(attendIndex) + " height=12 width=18>&nbsp;";
                htmlData += "<img src=" + getEventTypeImage(eventType) + " height=18 width=18>&nbsp;";
                htmlData += "<font color='" + color + "' >";
                htmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowDay() + " - ";
                htmlData += dateTimeFormatter.formatScheduleTime(startTime) + " - ";
                htmlData += dateTimeFormatter.formatScheduleTime(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getEndTimeString()) + " - ";
                htmlData += location + locationIcon + " - ";
                htmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType();
                htmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowNotes();
                htmlData += "</font></li>";

                Log.d("htmlData is", "Adding HTML text of " + htmlData);
            }

            htmlData += "</ul>";
        }

        return htmlData;
    }

    private String getAttendedImage(String attendIndex){

        String icon = staticVariables.attendedHandler.getShowAttendedIcon(attendIndex);
        String image = "";

        Log.d("setAttendedImage", "Link is " + icon + " compare to " + staticVariables.sawAllIcon);
        if (icon.equals(staticVariables.sawAllIcon)){
            image = "file:///android_res/drawable/icon_seen.png";

        } else if (icon.equals(staticVariables.sawSomeIcon)) {
            image = "file:///android_res/drawable/icon_partially_seen.png";

        }

        return image;
    }

    private String getEventTypeImage(String eventType){

        String image = "";

        if (eventType.equals(staticVariables.clinic)){
            image = "file:///android_res/drawable/icon_clinic.png";

        } else if (eventType.equals(staticVariables.meetAndGreet)){
            image = "file:///android_res/drawable/icon_meet_and_greet.png";

        } else if (eventType.equals(staticVariables.specialEvent)){
            image = "file:///android_res/drawable/icon_all_star_jam.png";

        } else if (eventType.equals(staticVariables.unofficalEvent)){
            image = "file:///android_res/drawable/icon_unspecified_event.png";
        }

        return image;
    }

    private String displayLinks(String bandName){

        String html = "<br><br><br>";

        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal") == true) {
            html = "<br><br><br><br><br><br><br><br><br><br><br>";

            String disable;
            if (OnlineStatus.isOnline() == true) {
                disable = "";
            } else {
                //disable and gray out link if offline
                disable = "style='pointer-events:none;cursor:default;color:grey'";
            }


            Log.d("Officia;Link", "Link is " + BandInfo.getOfficalWebLink(bandName));
            html = "<center><table width=100%><tr width=100% style='font-size:15px;font-size:5.0vw;list-style-type:none;text-align:left;margin-left:60px'>" +
                    "<td width=40%>Visit Band On: </td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getOfficalWebLink(bandName) + "' onclick='link.webLinkClick()'><img src=file:///android_res/drawable/icon_www.png height=32 width=32></a></td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getWikipediaWebLink(bandName) + "' onclick='link.webLinkClick()'><img src=file:///android_res/drawable/icon_wiki.png height=32 width=32></a></td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getYouTubeWebLink(bandName) + "' onclick='link.webLinkClick()'><img src=file:///android_res/drawable/icon_youtube.png height=32 width=32></a></td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getMetalArchivesWebLink(bandName) + "' onclick='link.webLinkClick()'><img src=file:///android_res/drawable/icon_ma.png height=32 width=32></a></td>" +
                    "</tr></table></center>";

        }

        return html;

    }

    private String createEditNoteInterface(String bandName){

        String html = "<br><br><br>";

        if (bandHandler.getNoteIsBlank() == true){
            bandNote = "";
        }

        bandNote = bandNote.replaceAll("<br>", "\n");
        html += "<form><textarea name='userNotes' id='userNotes' style='width:90%;height:80%;background-color:black;color:white;border:none;padding:2%;font:14px/16px sans-serif;outline:1px solid blue;' autofocus>";
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

