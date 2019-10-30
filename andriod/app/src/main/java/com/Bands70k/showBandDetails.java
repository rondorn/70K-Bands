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

    private Integer startLocationTitle = 0;
    private Integer startLocationLogo = 20;
    private Integer startLocationLinks= 100;
    private Integer startLocationExtraInfo= 100;
    private Integer startLocationNotes= 235;

    private Integer startLocationEvents = 40;
    private Integer startBelowEvents = 25;

    private String linkMessage = "";

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

        Log.d("detailsForBand",  "determining bandName");
        bandName = BandInfo.getSelectedBand();

        Log.d("detailsForBand",  "bandName is " + bandName);

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

                }else if (value.startsWith("UserNoteSubmit:")) {

                    staticVariables.writeNoteHtml = "";
                    //code to write note for band
                    value = value.replaceFirst("UserNoteSubmit:", "");
                    bandHandler.saveBandNote(value);
                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();

                } else if (value.equals("webLink")){
                    linkMessage = "It appeas that the " + value + " link was clicked on";
                    WebView htmlWebView = (WebView)findViewById(R.id.detailWebView);
                    htmlWebView.loadUrl(BandInfo.getOfficalWebLink(bandName));

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
            public void webLinkClick(String value) {
                staticVariables.webHelpMessage = setWebHelpMessage(value);
                Log.d("webHelpMessage", staticVariables.webHelpMessage );
                inLink = true;
            }

        }, "link");

        createDetailHTML();
        webProgressBar.setVisibility(View.GONE);

    }

    private String setWebHelpMessage(String linkType){

        String webHelpMessage = "";

        if (linkType.equals("webPage")) {
            webHelpMessage = getResources().getString(R.string.officialWebSiteLinkHelp);

        } else if (linkType.equals("wikipedia")) {
            webHelpMessage = getResources().getString(R.string.WikipediaLinkHelp);

        } else if (linkType.equals("youTube")) {
            webHelpMessage = getResources().getString(R.string.YouTubeLinkHelp);

        } else if (linkType.equals("metalArchives")) {
            webHelpMessage = getResources().getString(R.string.MetalArchiveLinkHelp);
        }

        return webHelpMessage;
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
            mightButtonColor = "Black";
            wontButtonColor = "Black";
            unknownButtonColor = "Black";
            rankIconLocation = "file:///android_res/drawable/icon_going_yes.png";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.mightSeeIcon)){
            mustButtonColor = "Black";
            mightButtonColor = "Silver";
            wontButtonColor = "Black";
            unknownButtonColor = "Black";
            rankIconLocation = "file:///android_res/drawable/icon_going_maybe.png";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.wontSeeIcon)){
            mustButtonColor = "Black";
            mightButtonColor = "Black";
            wontButtonColor = "Silver";
            unknownButtonColor = "Black";
            rankIconLocation = "file:///android_res/drawable/icon_going_no.png";

        } else {
            mustButtonColor = "Black";
            mightButtonColor = "Black";
            wontButtonColor = "Black";
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
            commentHeight = "65%";
        } else {
            Log.d("descriptionMapFileError",  "setting comment Higher 20 " + BandInfo.getOfficalWebLink(bandName));
            commentHeight = "50%";
        }
            htmlText =
                    "<html><head><script>function invert(){\n" +
                            "document.getElementById(\"bandLogo\").style.filter=\"invert(100%)\";\n" +
                            "}</script><body bgcolor=\"black\" style='color:white;height:100%'> <div style='position: fixed;height:20px;top:" + startLocationTitle + ";font-size:130%;left:0;right:0;'>" +
                            "<center>" + bandName + "</center>" + "</div><br><br>" +
                            "<div style='position: fixed;height:25px;top:" + startLocationLogo + ";width=100%;left:0;right:0;'>" +
                            "<center><img id=\"bandLogo\" style='max-height:100px;max-width:90%' src='" + imageHandler.getImage() + "'</img></div><br><br><br>";

                htmlText += displayLinks(bandName);

                if (staticVariables.writeNoteHtml.isEmpty() == false) {
                    Log.d("Variable is", "Adding HTML text of " + staticVariables.writeNoteHtml);
                    htmlText += staticVariables.writeNoteHtml;

                } else {

                    startLocationExtraInfo = startLocationLinks;

                    if (orientation == "portrait") {

                        if (BandInfo.getCountry(bandName) != "") {
                            startLocationExtraInfo = startLocationExtraInfo + 25;

                            htmlText += "<div style='position: fixed;height:35px;top:" + startLocationExtraInfo + ";width=100%; left:0;right:0;width=100%;'>" +
                                    "<ul style='overflow:hidden;font-size:14px;font-size:4.0vw;list-style-type:none;text-align:left;margin-left:-25px;color:white'>";

                            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:20%'>Country:</li>";
                            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:80%'>" + BandInfo.getCountry(bandName) + "</li>";

                            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:20%'>Genre:</li>";
                            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:80%'>" + BandInfo.getGenre(bandName) + "</li>";

                            if (BandInfo.getNote(bandName) != "") {
                                startLocationExtraInfo = startLocationExtraInfo + 25;
                                htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:20%'>Misc:</li>";
                                htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:80%'>" + BandInfo.getNote(bandName) + "</li>";
                            }
                            htmlText += "</ul></div>";

                        }


                        startLocationExtraInfo = startLocationExtraInfo + 70;

                        startLocationNotes = startLocationExtraInfo;
                        if (bandNote != "") {
                            htmlText += "</div><br><br><center><br><br>";
                            htmlText += "<div style='text-align:left;padding-bottom:20px;top:" + startLocationNotes + ";bottom:" + startLocationEvents + ";position: fixed;overflow:auto;width:98%;scroll;text-overflow:ellipsis;font-size:10px;font-size:4.0vw' ondblclick='ok.performClick(\"Notes\");'>" + bandNote + "</div></center>";
                        }
                    } else {
                        htmlText += "<br><br>";
                    }

                    htmlText += scheduleText;

                    htmlText += "</div><div style='font-size:3vw;height:20px;position:fixed;bottom:0;width:100%'><center><table style='font-size:3vw;height:20px;position:fixed;bottom:0;width:95%'><tr width=100%>";

                    if (rankIconLocation.isEmpty() == false) {
                        htmlText += "<td width=12%><img src=" + rankIconLocation + " height=28 width=28></td>";
                    }

                    htmlText += "<td width=22%><button style='color:white;width:100%;background:" + unknownButtonColor + "' type=button value=" + staticVariables.unknownKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.unknown) + "</button></td>" +
                            "<td width=22%><button style='color:white;width:100%;background:" + mustButtonColor + "' type=button value=" + staticVariables.mustSeeKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.must) + "</button></td>" +
                            "<td width=22%><button style='color:white;width:100%;background:" + mightButtonColor + "' type=button value=" + staticVariables.mightSeeKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.might) + "</button></td>" +
                            "<td width=22%><button style='color:white;width:100%;background:" + wontButtonColor + "' type=button value=" + staticVariables.wontSeeKey + " onclick='ok.performClick(this.value);'>" + getString(R.string.wont) + "</button></td>" +
                            "</tr></table></center></div>" +
                            "</body></html>";
                }

                Log.d("exportedHtml", htmlText);
            mWebView.loadDataWithBaseURL(null, htmlText, "text/html", "UTF-8", null);

    }

    private String buildScheduleView(){

        String scheduleHtml = "<br>";

        String scheduleHtmlData = "";

        if (BandInfo.scheduleRecords.get(bandName) != null) {
            Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();

            while (entries.hasNext()) {

                startLocationEvents = startLocationEvents + 13;

                Map.Entry thisEntry = (Map.Entry) entries.next();
                Object key = thisEntry.getKey();

                String location = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowLocation();
                String locationIcon = staticVariables.getVenuIcon(location);

                String startTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getStartTimeString();
                String eventType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType();

                String attendIndex = bandName + ":" + location + ":" + startTime + ":" + eventType + ":" + String.valueOf(staticVariables.eventYear);
                String color = staticVariables.attendedHandler.getShowAttendedColor(attendIndex);


                scheduleHtmlData = Utilities.monthDateRegionalFormatting(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowDay()) + " - ";
                scheduleHtmlData += dateTimeFormatter.formatScheduleTime(startTime) + " - ";
                scheduleHtmlData += dateTimeFormatter.formatScheduleTime(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getEndTimeString()) + " - ";
                scheduleHtmlData += "</font><font color='" + iconResolve.getLocationColor(location) + "'>" + location + "</font><font color='" + color + "'>- ";
                scheduleHtmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType() + " ";
                scheduleHtmlData += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowNotes();
                scheduleHtmlData += "</font></li>";

                String fontSize = setEventFontSize(scheduleHtmlData);

                scheduleHtml += "<li style='font-size:" + fontSize + ";margin-top:8px;margin-top:8px;' onclick='ok.performClick(\"" + attendIndex + "\");'>";
                scheduleHtml += "<img src=" + getAttendedImage(attendIndex) + " height=12 width=18>&nbsp;";
                scheduleHtml += "<img src=" + getEventTypeImage(eventType, bandName) + " height=16 width=16>&nbsp;";
                scheduleHtml += "<font style='vertical-align:top' color='" + color + "' >";
                scheduleHtml += scheduleHtmlData;


                Log.d("htmlData is", "Adding HTML text of " + scheduleHtml);
            }
        }

        Log.d("startLocationEvents", "startLocationEvents =" + String.valueOf(startLocationEvents));
        String htmlData = "<div style='position:fixed;bottom:" + startBelowEvents + "'>";
        if (orientation == "portrait") {
            htmlData += "<ul width=100% style='white-space:nowrap;list-style-type:none;text-align:left;margin-left:-40px;margin-top:20px;face=\"sans-serif-thin\">";
        } else {
            htmlData += "<ul width=100% style='white-space:nowrap;list-style-type:none;text-align:left;margin-left:-40px;margin-top:20px;face=\"sans-serif-thin\">";
        }

        htmlData += scheduleHtml + "</ul></div>";


        return htmlData;
    }

    private String setEventFontSize(String eventText){

        Integer textSize = eventText.length();
        String fontSize = "";

        if (textSize < 105){
            fontSize = "5vw";

        } else  if (textSize < 110) {
            fontSize = "4.7vw";

        } else  if (textSize < 115) {
            fontSize = "4.3vw";

        } else  if (textSize < 120) {
            fontSize = "3.8vw";

        } else  if (textSize < 130) {
            fontSize = "3.2vw";

        } else  {
            fontSize = "3.0vw";

        }

        Log.d("fontSize", "event text is " + eventText + " size of " + fontSize + " length " + String.valueOf(textSize));

        return fontSize;
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

    private String getEventTypeImage(String eventType, String eventName){

        String image = "";

        if (eventType.equals(staticVariables.clinic)){
            image = "file:///android_res/drawable/icon_clinic.png";

        } else if (eventType.equals(staticVariables.meetAndGreet)){
            image = "file:///android_res/drawable/icon_meet_and_greet.png";

        } else if (eventType.equals(staticVariables.specialEvent)){
            if (eventName.equals("All Star Jam")){
                image = "file:///android_res/drawable/icon_all_star_jam.png";

            } else if (eventName.contains("Karaoke")){
                image = "file:///android_res/drawable/icon_karaoke.png";

            } else {
                image = "file:///android_res/drawable/icon_ship_event.png";
            }

        } else if (eventType.equals(staticVariables.unofficalEvent)){
            image = "file:///android_res/drawable/icon_unspecified_event.png";
        }

        return image;
    }

    private String displayLinks(String bandName){

        String html = "";

        startLocationLinks = startLocationLogo + 100;

        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal") == true) {

            String disable;
            if (OnlineStatus.isOnline() == true) {
                disable = "";
            } else {
                //disable and gray out link if offline
                disable = "style='pointer-events:none;cursor:default;color:grey'";
            }

            if (orientation == "portrait") {

                Log.d("Officia;Link", "Link is " + BandInfo.getOfficalWebLink(bandName));
                html = "<br><div style='position: fixed;height:30px;top:" + startLocationLinks + ";width=100%; left:0;right:0;'>" +
                        "<center><table width=95%><tr width=100% style='font-size:15px;font-size:5.0vw;list-style-type:none;text-align:left;margin-left:60px'>" +
                        "<td  style='color:" + staticVariables.blueColor + "' + staticVariables.blueColor + \"' width=40%>Visit Band On: </td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getOfficalWebLink(bandName) + "' onclick='link.webLinkClick(\"webPage\")'><img src=file:///android_res/drawable/icon_www.png height=24 width=27></a></td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getMetalArchivesWebLink(bandName) + "' onclick='link.webLinkClick(\"metalArchives\")'><img src=file:///android_res/drawable/icon_ma.png height=21 width=27></a></td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getWikipediaWebLink(bandName) + "' onclick='link.webLinkClick(\"wikipedia\")'><img src=file:///android_res/drawable/icon_wiki.png height=17 width=27></a></td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getYouTubeWebLink(bandName) + "' onclick='link.webLinkClick(\"youTube\")'><img src=file:///android_res/drawable/icon_youtube.png height=19 width=27></a></td>" +
                        "</tr></table></center></div>";
            }
            startLocationLinks = startLocationLinks;

        }

        return html;

    }

    private String createEditNoteInterface(String bandName){

        String html = "<br>";

        if (bandHandler.getNoteIsBlank() == true){
            bandNote = "";
        }

        bandNote = bandNote.replaceAll("<br>", "\n");
        html += "<br><div style='width:100%;height:90%;position: fixed;top:" + startLocationLinks + ";width=100%; left:0;right:0;'>";
        html += "<center><form><textarea name='userNotes' id='userNotes' style='text-align:left;width:95%;height:80%;background-color:black;color:white;border:none;padding:2%;font:14px/16px sans-serif;outline:1px solid blue;' autofocus>";
        html += bandNote;
        html += "</textarea>";
        html += "<br><br><button type=button value='UserNoteSubmit' onclick='ok.performClick(this.value + \":\" + this.form.userNotes.value);'>Save Note:</button></form></center><br></div>";

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

            webProgressBar.setVisibility(View.VISIBLE);
            if (staticVariables.webHelpMessage .isEmpty() == false) {
                HelpMessageHandler.showMessage(staticVariables.webHelpMessage);
                staticVariables.webHelpMessage = "";
            }
            super.onPageStarted(view, url, favicon);
        }

        public boolean shouldOverrideUrlLoading(WebView view, String url){

            view.loadUrl(url);
            return true;
        }
    }
}

