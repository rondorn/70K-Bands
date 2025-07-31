package com.Bands70k;

/**
 * Created by rdorn on 7/25/15.
 */

import android.app.Activity;

import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Color;

import android.net.Uri;
import android.os.Bundle;

import android.os.SystemClock;

import androidx.core.app.NavUtils;
import android.util.DisplayMetrics;
import android.util.Log;

import android.view.Display;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;

import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ProgressBar;

import static com.Bands70k.staticVariables.context;


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

    private Intent browserIntent = null;

    private String rankIconLocation = "";
    private int noteViewPercentage = 35;

    public void onCreate(Bundle savedInstanceState) {

        setTheme(R.style.AppTheme);

        super.onCreate(savedInstanceState);
        setContentView(R.layout.band_details);

        // Pause background loading when entering details screen
        CustomerDescriptionHandler.pauseBackgroundLoading();
        ImageHandler.pauseBackgroundLoading();

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
            bandNote = bandHandler.getBandNoteImmediate();

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

        Log.d("RotationChange", "'" + orientation + "'");

        if (inLink == false){
            recreate();
        }
    }

    private void changeBand(String currentBand, String direction){
        BandInfo.setSelectedBand(currentBand);
        Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
        startActivity(showDetails);
        finish();
        if (direction == "Next") {
            overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_right);
        } else {
            overridePendingTransition(R.anim.slide_in_left, R.anim.slide_out_left);
        }
    }


    private void nextRecord(String direction){

        String directionMessage = "";
        String currentBand = "";
        String oldBandValue = staticVariables.currentListForDetails.get(staticVariables.currentListPosition);

        if (staticVariables.currentListPosition == 0 && direction == "Previous"){
            HelpMessageHandler.showMessage(getResources().getString(R.string.AlreadyAtStart));
            return;

        } else if (staticVariables.currentListPosition == staticVariables.currentListForDetails.size() &&
                    direction == "Next") {
            HelpMessageHandler.showMessage(getResources().getString(R.string.EndofList));
            return;

        } else if (direction == "Next"){
            staticVariables.currentListPosition = staticVariables.currentListPosition + 1;
            directionMessage = getResources().getString(R.string.Next);

        } else {
            staticVariables.currentListPosition = staticVariables.currentListPosition - 1;
            directionMessage = getResources().getString(R.string.Previous);
        }

        //sometime the list is not as long as is advertised
        try {
            currentBand = staticVariables.currentListForDetails.get(staticVariables.currentListPosition);
            Log.d("NextRecord", "Old Record is " + oldBandValue + " new record is " + currentBand);
            if (oldBandValue.equals(currentBand)){
                nextRecord(direction);
                return;
            }
        } catch (Exception error){
            staticVariables.currentListPosition = staticVariables.currentListPosition - 1;
            HelpMessageHandler.showMessage(getResources().getString(R.string.EndofList));
            return;
        }

        HelpMessageHandler.showMessage(directionMessage + " " + currentBand);
        changeBand(currentBand, direction);

    }

    private void initializeWebContent (){

        Log.d("initializeWebContent", "Start");
        webProgressBar = (ProgressBar) findViewById(R.id.webProgressBar);

        mWebView = (WebView) findViewById(R.id.detailWebView);
        mWebView.setBackgroundColor(Color.argb(1, 0, 0, 0));
        mWebView.setWebViewClient(new customWebViewClient());
        mWebView.getSettings().setJavaScriptEnabled(true);
        Log.d("initializeWebContent", "setOnTouchListener");
        mWebView.setOnTouchListener(new OnSwipeTouchListener(context) {
            @Override
            public void onSwipeLeft() {
                nextRecord("Next");
            }

            @Override
            public void onSwipeRight() {
                nextRecord("Previous");
            }

        });

        WebSettings webSettings = mWebView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setAllowFileAccessFromFileURLs(true);
        webSettings.setAllowFileAccess(true);
        mWebView.setVerticalScrollBarEnabled(false);
        mWebView.setHorizontalScrollBarEnabled(false);
        Log.d("initializeWebContent", "writeNoteHtml");
        mWebView.addJavascriptInterface(new Object() {

            @JavascriptInterface
            public void performClick(String value) {
                Log.d("Variable is", "Variable is - '" + value + "'");
                if (value.equals("Notes")) {
                    Log.d("Variable is", "Variable is -  Lets run this code to edit notes");
                    staticVariables.writeNoteHtml = createEditNoteInterface(BandInfo.getSelectedBand());
                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();

                } else if (value.startsWith(bandName + ":")){

                    if (clickedOnEvent == false){
                        clickedOnEvent = true;
                        Log.d("showAttended", " Lets set this value of " + value);
                        String status = staticVariables.attendedHandler.addShowsAttended(value, "");
                        String message = staticVariables.attendedHandler.setShowsAttendedStatus(status);
                        HelpMessageHandler.showMessage(message);

                        Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                        startActivity(showDetails);
                        finish();
                    }

                }else if (value.startsWith("UserNoteSubmit:")) {

                    Log.d("saveNote", "Save note now");
                    staticVariables.writeNoteHtml = "";
                    //code to write note for band
                    value = value.replaceFirst("UserNoteSubmit:", "");
                    bandHandler.saveCustomBandNote(value);
                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();

                } else if (value.equals("webLink")){
                    Log.d("webLink", "Going to weblink! " + BandInfo.getOfficalWebLink(bandName));
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
        Log.d("initializeWebContent", "webLink");
        mWebView.addJavascriptInterface(new Object() {

            @JavascriptInterface
            public void webLinkClick(String value) {
                Log.d("webLink", "Going to weblinks kind of " + value);
                staticVariables.webHelpMessage = setWebHelpMessage(value);
                Log.d("webHelpMessage", staticVariables.webHelpMessage );
                inLink = true;

                String webUrl = getWebUrl(value);
                Log.d("webLink", "Going to weblinks Start " + webUrl);

                browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(webUrl));
                browserIntent.addCategory(Intent.CATEGORY_BROWSABLE);
                browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);

                startActivity(browserIntent);

            }

        }, "link");
        createDetailHTML();
        webProgressBar.setVisibility(View.GONE);
        Log.d("initializeWebContent", "Done");
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

    private String getWebUrl(String linkType){

        String urlString = "";

        if (linkType.equals("webPage")) {
            urlString = BandInfo.getOfficalWebLink(bandName);

        } else if (linkType.equals("wikipedia")) {
            urlString = BandInfo.getWikipediaWebLink (bandName);

        } else if (linkType.equals("youTube")) {
            urlString = BandInfo.getYouTubeWebLink(bandName);

        } else if (linkType.equals("metalArchives")) {
            urlString = BandInfo.getMetalArchivesWebLink(bandName);
        }

        urlString = urlString.replace("http://","https://");

        return urlString;
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

        Log.d("WebView", "Back button pressed");
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
    
    @Override
    protected void onDestroy() {
        // Resume background loading when leaving details screen
        CustomerDescriptionHandler.resumeBackgroundLoading();
        ImageHandler.resumeBackgroundLoading();
        super.onDestroy();
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

        Display display = ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay();
        int rotation = display.getRotation();

        boolean landscape = false;

        int width = Resources.getSystem().getDisplayMetrics().widthPixels;
        int height = Resources.getSystem().getDisplayMetrics().heightPixels;

        String fontSize = "4.5vm";

        if (width > 1700 && height > 1700) {
            //do nothing

        } else {
            if (rotation == 1 || rotation == 3) {
                landscape = true;
            }
        }

        Log.d("rotation", "rotation is " + rotation);

        SetButtonColors();

        DisplayMetrics metrics = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(metrics);
        int widthPixels = metrics.widthPixels;
        float densityDpi = metrics.density;
        float scaleDense = metrics.scaledDensity;
        float xdpi = metrics.xdpi;

        int displayWidth = (widthPixels/(int)scaleDense - 100);

        DetailHtmlGeneration htmlGen = new DetailHtmlGeneration(getApplicationContext());

        htmlText = htmlGen.setupTitleAndLogo(bandName);


        if (staticVariables.writeNoteHtml.isEmpty() == false) {
            Log.d("Variable is", "Adding HTML text of " + staticVariables.writeNoteHtml);
            htmlText += staticVariables.writeNoteHtml;

        } else {

            htmlText += htmlGen.displaySchedule(bandName, displayWidth);

            htmlText += htmlGen.displayLinks(bandName, orientation);

            if (landscape == false) {
                htmlText += htmlGen.displayExtraData(bandName);

                htmlText += htmlGen.displayNotes(bandNote);
            }

            htmlText += htmlGen.displayMustMightWont(rankIconLocation,
                    unknownButtonColor,
                    mustButtonColor,
                    mightButtonColor,
                    wontButtonColor);


        }

        Log.d("exportedHtml", htmlText);

        mWebView.loadDataWithBaseURL(null, htmlText, "text/html", "UTF-8", null);

    }

    public static String getAttendedImage(String attendIndex){

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

    public static String getEventTypeImage(String eventType, String eventName){

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


    private String createEditNoteInterface(String bandName){

        String html = "<br>";

        if (bandHandler.getNoteIsBlank() == true){
            bandNote = "";
        }

        bandNote = bandNote.replaceAll("<br>", "\n");
        html += "<br><div style='width:100%;height:90%;width=100%; left:0;right:0;'>";
        html += "<center><form><textarea name='userNotes' id='userNotes' style='text-align:left;width:95%;height:80%;background-color:black;color:white;border:none;padding:2%;font:14px/16px sans-serif;outline:1px solid blue;' autofocus>";
        html += bandNote;
        html += "</textarea>";
        html += "<br><br><button type=button value='UserNoteSubmit' onclick='ok.performClick(this.value + \":\" + this.form.userNotes.value);'>Save Note:</button></form></center><br></div>";

        return html;
    }

    private class customWebViewClient extends WebViewClient {

        @Override
        public void onPageFinished(WebView view, String url) {
            Log.d("WebView", "finished with webLink");
            // TODO Auto-generated method stub
            super.onPageFinished(view, url);
            webProgressBar.setVisibility(View.GONE);
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            // TODO Auto-generated method stub

            webProgressBar.setVisibility(View.VISIBLE);
            if (staticVariables.webHelpMessage.isEmpty() == false) {
                HelpMessageHandler.showMessage(staticVariables.webHelpMessage);
                staticVariables.webHelpMessage = "";
            }
            super.onPageStarted(view, url, favicon);
        }

        public boolean shouldOverrideUrlLoading(WebView view, String url) {

            view.loadUrl(url);
            return true;
        }
    }
}

/**
 * Detects left and right swipes across a view.
 */
class OnSwipeTouchListener implements View.OnTouchListener {

    private final GestureDetector gestureDetector;

    public OnSwipeTouchListener(Context context) {
        gestureDetector = new GestureDetector(context, new GestureListener());
    }

    public void onSwipeLeft() {
    }

    public void onSwipeRight() {
    }

    public boolean onTouch(View view, MotionEvent event) {

        return gestureDetector.onTouchEvent(event);
    }

    private final class GestureListener extends GestureDetector.SimpleOnGestureListener {

        private static final int SWIPE_DISTANCE_THRESHOLD = 100;
        private static final int SWIPE_VELOCITY_THRESHOLD = 100;

        @Override
        public boolean onDown(MotionEvent e) {
            return false;
        }

        @Override
        public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
            float distanceX = e2.getX() - e1.getX();
            float distanceY = e2.getY() - e1.getY();
            if (Math.abs(distanceX) > Math.abs(distanceY) && Math.abs(distanceX) > SWIPE_DISTANCE_THRESHOLD && Math.abs(velocityX) > SWIPE_VELOCITY_THRESHOLD) {
                if (distanceX > 0)
                    onSwipeRight();
                else
                    onSwipeLeft();
                return true;
            }
            return false;
        }
    }

}
