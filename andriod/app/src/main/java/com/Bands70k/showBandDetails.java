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
import android.graphics.BitmapFactory;
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
import android.webkit.WebChromeClient;
import android.widget.ProgressBar;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Button;
import android.view.LayoutInflater;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ColorDrawable;
import android.app.AlertDialog;
import android.widget.EditText;
import android.content.DialogInterface;
import android.view.ViewGroup;

import java.util.Iterator;
import java.util.Map;
import java.io.File;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.style.ClickableSpan;
import android.text.style.ForegroundColorSpan;
import android.text.method.LinkMovementMethod;

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
    
    // Native view components
    private TextView bandNameText;
    private ImageView bandLogoImage;
    private LinearLayout scheduleSection;
    private LinearLayout linksSection;
    private LinearLayout linksIconContainer;
    private LinearLayout extraDataSection;
    private LinearLayout userNotesSection;
    private TextView userNotesText;
    private TextView linksLabel;
    private ImageView websiteLink, metalArchivesLink, wikipediaLink, youtubeLink;
    private TextView countryValue, genreValue, lastCruiseValue, noteValue;
    private LinearLayout countryRow, genreRow, lastCruiseRow, noteRow;
    private Button unknownButton, mustButton, mightButton, wontButton;
    private ImageView rankingIcon;
    private ProgressBar loadingProgressBar;
    private ScrollView contentScrollView;
    private LinearLayout contentContainer;
    private boolean useNativeView = true; // Toggle for native vs WebView
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
        
        if (useNativeView) {
            setContentView(R.layout.band_details_native);
        } else {
            setContentView(R.layout.band_details);
        }

        // Background loading continues while in details screen

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
            
            // Check if note is already cached - if so, use it immediately
            String cachedNote = bandHandler.getBandNoteFromFile();
            if (cachedNote != null && !cachedNote.trim().isEmpty()) {
                bandNote = bandHandler.getBandNote(); // Apply URL formatting
                Log.d("descriptionMapFileError", "Using cached note for " + bandName);
            } else {
                bandNote = "<div style='color: #888; font-style: italic; padding: 10px; text-align: center;'>" +
                          "<div style='margin-bottom: 5px;'>📝 Loading note...</div>" +
                          "<div style='font-size: 12px; color: #aaa;'>Please wait while we fetch the content</div>" +
                          "</div>";
                Log.d("descriptionMapFileError", "Using placeholder note for " + bandName);
            }
            
            if (useNativeView) {
                initializeNativeContent();
            } else {
                initializeWebContent();
            }
            
            // Load missing content asynchronously (image and note if not cached)
            loadContentAsync();
        } else {
            onBackPressed();
        }

    }

    /**
     * Loads band content (note and image) asynchronously and refreshes the UI when ready.
     */
    private void loadContentAsync() {
        // Load content in background thread to avoid blocking UI
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Log.d("AsyncContent", "Starting async content loading for " + bandName);
                    
                    // Load note - only if not already cached
                    String loadedNote = null;
                    boolean noteNeedsUpdate = false;
                    try {
                        // Check if note is already cached
                        String cachedNote = bandHandler.getBandNoteFromFile();
                        if (cachedNote != null && !cachedNote.trim().isEmpty()) {
                            // Note is already cached, no download needed
                            Log.d("AsyncContent", "Note already cached for " + bandName + ", skipping download");
                        } else {
                            // Download note immediately if not cached
                            Log.d("AsyncContent", "Note not cached, downloading for " + bandName);
                            loadedNote = bandHandler.getBandNoteImmediate();
                            noteNeedsUpdate = true;
                            if (loadedNote != null && !loadedNote.trim().isEmpty()) {
                                Log.d("AsyncContent", "Note downloaded successfully for " + bandName);
                            } else {
                                Log.d("AsyncContent", "Note download returned empty for " + bandName);
                                loadedNote = "<div style='color: #666;'>No note available for this band.</div>";
                            }
                        }
                    } catch (Exception e) {
                        Log.e("AsyncContent", "Error loading note for " + bandName, e);
                        loadedNote = "<div style='color: #cc6666;'>Note could not be loaded.</div>";
                        noteNeedsUpdate = true;
                    }
                    
                    // Load image only if not already cached
                    try {
                        ImageHandler bandImageHandler = new ImageHandler(bandName);
                        // Check if image is already cached  
                        java.net.URI existingImage = bandImageHandler.getImage();
                        if (existingImage != null) {
                            Log.d("AsyncContent", "Image already cached for " + bandName + ", skipping download");
                        } else {
                            Log.d("AsyncContent", "Image not cached, downloading for " + bandName);
                            bandImageHandler.getImageImmediate();
                            Log.d("AsyncContent", "Image download completed for " + bandName);
                        }
                    } catch (Exception e) {
                        Log.e("AsyncContent", "Error loading image for " + bandName, e);
                    }
                    
                    // Update UI on main thread only if content changed
                    final String finalNote = loadedNote;
                    final boolean needsUpdate = noteNeedsUpdate;
                    if (needsUpdate) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                if (finalNote != null) {
                                    bandNote = finalNote;
                                    Log.d("AsyncContent", "Refreshing UI with updated content for " + bandName);
                                    if (useNativeView) {
                                        refreshNativeContent();
                                    } else {
                                        refreshWebContent();
                                    }
                                } else {
                                    Log.d("AsyncContent", "No content update needed for " + bandName);
                                }
                            }
                        });
                    } else {
                        Log.d("AsyncContent", "No UI refresh needed for " + bandName + " - content already cached");
                    }
                    
                } catch (Exception e) {
                    Log.e("AsyncContent", "Error in async content loading for " + bandName, e);
                }
            }
        }).start();
    }
    
    /**
     * Refreshes the web view content with updated note and image data.
     */
    private void refreshWebContent() {
        if (mWebView != null) {
            Log.d("RefreshContent", "Refreshing web content for " + bandName);
            
            // Regenerate HTML with updated content
            DetailHtmlGeneration htmlGen = new DetailHtmlGeneration(getApplicationContext());
            
            DisplayMetrics metrics = new DisplayMetrics();
            getWindowManager().getDefaultDisplay().getMetrics(metrics);
            int widthPixels = metrics.widthPixels;
            float scaleDense = metrics.scaledDensity;
            int displayWidth = (widthPixels/(int)scaleDense - 100);
            
            SetButtonColors();
            
            String refreshedHtml = htmlGen.setupTitleAndLogo(bandName);
            
            if (staticVariables.writeNoteHtml.isEmpty() == false) {
                refreshedHtml += staticVariables.writeNoteHtml;
            } else {
                refreshedHtml += htmlGen.displaySchedule(bandName, displayWidth);
                refreshedHtml += htmlGen.displayLinks(bandName, orientation);
                
                if (!orientation.equals("landscape")) {
                    refreshedHtml += htmlGen.displayExtraData(bandName);
                    refreshedHtml += htmlGen.displayNotes(bandNote);
                }
                
                refreshedHtml += htmlGen.displayMustMightWont(rankIconLocation,
                        unknownButtonColor,
                        mustButtonColor,
                        mightButtonColor,
                        wontButtonColor);
            }
            
            mWebView.loadDataWithBaseURL(null, refreshedHtml, "text/html", "UTF-8", null);
            Log.d("RefreshContent", "Web content refreshed for " + bandName);
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
        } else {
            // If we're in WebView mode during rotation, exit back to details
            Log.d("WebView", "Configuration changed while in WebView, exiting to details");
            exitInAppWebView();
        }
    }

    private void changeBand(String currentBand, String direction){
        BandInfo.setSelectedBand(currentBand);
        
        if (useNativeView) {
            // For native view, update the band name and refresh content without animation
            bandName = currentBand;
            refreshNativeContent();
        } else {
            // For WebView mode, keep the original animation behavior
            Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
            startActivity(showDetails);
            finish();
            if (direction == "Next") {
                overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_right);
            } else {
                overridePendingTransition(R.anim.slide_in_left, R.anim.slide_out_left);
            }
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
    
    /**
     * Initializes the native Android view content instead of WebView
     */
    private void initializeNativeContent() {
        Log.d("initializeNativeContent", "Start"); 
        
        // Initialize all view references
        bandNameText = findViewById(R.id.band_name_text);
        bandLogoImage = findViewById(R.id.band_logo_image);
        scheduleSection = findViewById(R.id.schedule_section);
        linksSection = findViewById(R.id.links_section);
        linksIconContainer = findViewById(R.id.links_icon_container);
        extraDataSection = findViewById(R.id.extra_data_section);
        userNotesSection = findViewById(R.id.user_notes_section);
        userNotesText = findViewById(R.id.user_notes_text);
        linksLabel = findViewById(R.id.links_label);
        
        // Link buttons
        websiteLink = findViewById(R.id.website_link);
        metalArchivesLink = findViewById(R.id.metal_archives_link);
        wikipediaLink = findViewById(R.id.wikipedia_link);
        youtubeLink = findViewById(R.id.youtube_link);
        
        // Extra data views
        countryValue = findViewById(R.id.country_value);
        genreValue = findViewById(R.id.genre_value);
        lastCruiseValue = findViewById(R.id.last_cruise_value);
        noteValue = findViewById(R.id.note_value);
        countryRow = findViewById(R.id.country_row);
        genreRow = findViewById(R.id.genre_row);
        lastCruiseRow = findViewById(R.id.last_cruise_row);
        noteRow = findViewById(R.id.note_row);
        
        // Ranking buttons
        unknownButton = findViewById(R.id.unknown_button);
        mustButton = findViewById(R.id.must_button);
        mightButton = findViewById(R.id.might_button);
        wontButton = findViewById(R.id.wont_button);
        rankingIcon = findViewById(R.id.ranking_icon);
        
        // Other components
        loadingProgressBar = findViewById(R.id.loading_progress_bar);
        contentScrollView = findViewById(R.id.content_scroll_view);
        contentContainer = findViewById(R.id.content_container);
        
        // Set up touch listener for swipe gestures on the main container
        contentScrollView.setOnTouchListener(new OnSwipeTouchListener(context) {
            @Override
            public void onSwipeLeft() {
                nextRecord("Next");
            }

            @Override
            public void onSwipeRight() {
                nextRecord("Previous");
            }
        });
        
        // Set up click listeners
        setupNativeClickListeners();
        
        // Populate content
        populateNativeContent();
        
        loadingProgressBar.setVisibility(View.GONE);
        Log.d("initializeNativeContent", "Done");
    }
    
    /**
     * Sets up click listeners for native views
     */
    private void setupNativeClickListeners() {
        // Link click listeners
        websiteLink.setOnClickListener(v -> handleLinkClick("webPage"));
        metalArchivesLink.setOnClickListener(v -> handleLinkClick("metalArchives"));
        wikipediaLink.setOnClickListener(v -> handleLinkClick("wikipedia"));
        youtubeLink.setOnClickListener(v -> handleLinkClick("youTube"));
        
        // Ranking button click listeners
        unknownButton.setOnClickListener(v -> handleRankingClick(staticVariables.unknownKey));
        mustButton.setOnClickListener(v -> handleRankingClick(staticVariables.mustSeeKey));
        mightButton.setOnClickListener(v -> handleRankingClick(staticVariables.mightSeeKey));
        wontButton.setOnClickListener(v -> handleRankingClick(staticVariables.wontSeeKey));
        
        // Notes edit listener - make note content double-tap in native view
        if (useNativeView && noteValue != null) {
            setupNoteDoubleTapListener();
        } else {
            // Notes double-click listener for WebView mode (using long click as alternative)
            userNotesText.setOnLongClickListener(v -> {
                handleNotesEdit();
                return true;
            });
        }
        
        // Set online status for links
        boolean isOnline = OnlineStatus.isOnline();
        websiteLink.setEnabled(isOnline);
        metalArchivesLink.setEnabled(isOnline);
        wikipediaLink.setEnabled(isOnline);
        youtubeLink.setEnabled(isOnline);
        
        if (!isOnline) {
            websiteLink.setAlpha(0.5f);
            metalArchivesLink.setAlpha(0.5f);
            wikipediaLink.setAlpha(0.5f);
            youtubeLink.setAlpha(0.5f);
        }
    }
    
    /**
     * Handles link clicks for native views
     */
    private void handleLinkClick(String linkType) {
        Log.d("webLink", "Going to weblinks kind of " + linkType);
        staticVariables.webHelpMessage = setWebHelpMessage(linkType);
        Log.d("webHelpMessage", staticVariables.webHelpMessage);
        inLink = true;

        String webUrl = getWebUrl(linkType);
        Log.d("webLink", "Going to weblinks Start " + webUrl);

        // Show in-app WebView instead of external browser
        showInAppWebView(webUrl, linkType);
    }
    
    // WebView components
    private WebView inAppWebView;
    private ProgressBar webViewProgressBar;
    
    /**
     * Shows a web URL in an in-app WebView using the normal screen area
     */
    private void showInAppWebView(String url, String linkType) {
        Log.d("WebView", "showInAppWebView() called with URL: " + url);
        // Create container for WebView with progress bar
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setBackgroundColor(Color.BLACK); // Match app theme
        container.setLayoutParams(new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            ViewGroup.LayoutParams.MATCH_PARENT
        ));
        
        // Ensure container fits within system windows (respects status bar, navigation bar, etc.)
        container.setFitsSystemWindows(true);
        
        // Create progress bar
        webViewProgressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        webViewProgressBar.setLayoutParams(new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            8  // Fixed height for progress bar
        ));
        webViewProgressBar.setIndeterminate(false);
        webViewProgressBar.setMax(100);
        webViewProgressBar.setProgress(0);
        webViewProgressBar.setVisibility(View.VISIBLE);
        container.addView(webViewProgressBar);
        
        // Create WebView - takes remaining space in LinearLayout
        inAppWebView = new WebView(this);
        LinearLayout.LayoutParams webViewParams = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            0  // Height 0 with weight 1 = takes remaining space
        );
        webViewParams.weight = 1.0f;  // Takes all remaining vertical space
        inAppWebView.setLayoutParams(webViewParams);
        inAppWebView.getSettings().setJavaScriptEnabled(true);
        inAppWebView.getSettings().setLoadWithOverviewMode(true);
        inAppWebView.getSettings().setUseWideViewPort(true);
        inAppWebView.getSettings().setBuiltInZoomControls(true);
        inAppWebView.getSettings().setDisplayZoomControls(false);
        inAppWebView.getSettings().setDomStorageEnabled(true);
        inAppWebView.getSettings().setSupportZoom(true);
        
        // Enable history tracking for proper back navigation
        inAppWebView.getSettings().setCacheMode(WebSettings.LOAD_DEFAULT);
        
        // Enable navigation history
        inAppWebView.clearHistory(); // Start with clean history
        Log.d("WebView", "WebView history cleared, ready for navigation");
        
        // Set WebView client to handle page loading
        inAppWebView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                Log.d("WebView", "Page started: " + url + ", canGoBack: " + view.canGoBack());
                webViewProgressBar.setVisibility(View.VISIBLE);
                if (!staticVariables.webHelpMessage.isEmpty()) {
                    HelpMessageHandler.showMessage(staticVariables.webHelpMessage);
                    staticVariables.webHelpMessage = "";
                }
            }
            
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                Log.d("WebView", "Page finished: " + url + ", canGoBack: " + view.canGoBack());
                webViewProgressBar.setVisibility(View.GONE);
            }
            
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                Log.d("WebView", "Loading URL: " + url);
                // Allow the WebView to handle the URL normally for proper history tracking
                return false;
            }
        });
        
        // Set WebChrome client for progress updates
        inAppWebView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                webViewProgressBar.setProgress(newProgress);
                if (newProgress == 100) {
                    webViewProgressBar.setVisibility(View.GONE);
                }
            }
            
            @Override
            public void onReceivedTitle(WebView view, String title) {
                super.onReceivedTitle(view, title);
                // Update activity title with web page title
                if (title != null && !title.isEmpty()) {
                    setTitle(title);
                }
            }
        });
        
        container.addView(inAppWebView);
        
        // Replace current content with WebView (respects system UI)
        setContentView(container);
        
        // Load the URL
        Log.d("WebView", "Loading initial URL: " + url);
        inAppWebView.loadUrl(url);
        
        // Set flag that we're in web link mode
        inLink = true;
        Log.d("WebView", "inLink flag set to true");
    }
    
    /**
     * Debug method to log WebView history state
     */
    private void debugWebViewHistory() {
        if (inAppWebView != null) {
            try {
                boolean canGoBack = inAppWebView.canGoBack();
                boolean canGoForward = inAppWebView.canGoForward();
                String currentUrl = inAppWebView.getUrl();
                
                Log.d("WebView", "=== WebView History Debug ===");
                Log.d("WebView", "Current URL: " + currentUrl);
                Log.d("WebView", "Can go back: " + canGoBack);
                Log.d("WebView", "Can go forward: " + canGoForward);
                Log.d("WebView", "============================");
            } catch (Exception e) {
                Log.e("WebView", "Error debugging WebView history", e);
            }
        }
    }
    
    /**
     * Exits WebView and returns to band details content
     */
    private void exitInAppWebView() {
        Log.d("WebView", "exitInAppWebView() called");
        
        if (inAppWebView != null) {
            Log.d("WebView", "Destroying WebView");
            inAppWebView.destroy();
            inAppWebView = null;
        }
        
        if (webViewProgressBar != null) {
            webViewProgressBar = null;
        }
        
        // Reset link state first
        inLink = false;
        
        // Reset any window modifications
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
        
        // Restore original band details content
        Log.d("WebView", "Restoring band details content, useNativeView=" + useNativeView);
        if (useNativeView) {
            setContentView(R.layout.band_details_native);
            initializeNativeContent();
        } else {
            setContentView(R.layout.band_details);
            initializeWebContent();
        }
        
        // Reset activity title
        setTitle(bandName);
        
        Log.d("WebView", "exitInAppWebView() completed");
    }
    
    /**
     * Gets user-friendly title for link type
     */
    private String getLinkTypeTitle(String linkType) {
        switch (linkType) {
            case "webPage":
                return "Official Website";
            case "metalArchives":
                return "Metal Archives";
            case "wikipedia":
                return "Wikipedia";
            case "youTube":
                return "YouTube";
            default:
                return "Web Link";
        }
    }
    
    /**
     * Handles ranking button clicks
     */
    private void handleRankingClick(String rankingKey) {
        // Save the ranking
        rankStore.saveBandRanking(BandInfo.getSelectedBand(), resolveValue(rankingKey));
        
        // Update the button states immediately without restarting activity
        setupRankingButtons();
    }
    
    /**
     * Handles notes editing
     */
    private void handleNotesEdit() {
        Log.d("Variable is", "Variable is -  Lets run this code to edit notes");
        showEditNoteDialog(BandInfo.getSelectedBand());
    }
    
    /**
     * Shows dialog for editing notes
     */
    private void showEditNoteDialog(String bandName) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Edit Note for " + bandName);
        
        final EditText input = new EditText(this);
        input.setTextColor(getResources().getColor(android.R.color.white));
        input.setBackgroundColor(getResources().getColor(android.R.color.black));
        
        String currentNote = bandNote;
        if (bandHandler.getNoteIsBlank() == true) {
            currentNote = "";
        }
        currentNote = currentNote.replaceAll("<br>", "\n");
        currentNote = currentNote.replaceAll("<[^>]*>", ""); // Remove HTML tags
        input.setText(currentNote);
        
        builder.setView(input);
        
        builder.setPositiveButton("Save Note", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                String noteText = input.getText().toString().trim();
                
                // If note is empty or whitespace only, revert to original default content
                if (noteText.isEmpty()) {
                    // Get the original default note (not custom note) by checking the default note file directly
                    String originalDefaultNote = getOriginalDefaultNote(bandName);
                    
                    if (originalDefaultNote != null && !originalDefaultNote.trim().isEmpty() && 
                        !originalDefaultNote.contains("Comment text is not available yet")) {
                        // Use the original default comment
                        noteText = originalDefaultNote;
                    } else {
                        // Use the exact same waiting message as CustomerDescriptionHandler
                        noteText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";
                    }
                }
                
                bandHandler.saveCustomBandNote(noteText);
                
                // Update the note content and refresh display without restarting activity
                bandNote = noteText;
                if (useNativeView) {
                    refreshNativeContent();
                } else {
                    Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                    startActivity(showDetails);
                    finish();
                }
            }
        });
        
        builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                dialog.cancel();
            }
        });
        
        builder.show();
    }
    
    /**
     * Populates native content views with band data
     */
    private void populateNativeContent() {
        setupBandTitleAndLogo();
        setupScheduleSection();
        setupLinksSection();
        setupExtraDataSection();
        setupNotesSection();
        setupRankingButtons();
    }
    
    /**
     * Refreshes native content with updated data
     */
    private void refreshNativeContent() {
        if (bandNameText != null) {
            Log.d("RefreshContent", "Refreshing native content for " + bandName);
            populateNativeContent();
            Log.d("RefreshContent", "Native content refreshed for " + bandName);
        }
    }
    
    /**
     * Sets up double-tap listener for note editing
     */
    private void setupNoteDoubleTapListener() {
        GestureDetector gestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onDoubleTap(MotionEvent e) {
                handleNotesEdit();
                return true;
            }
        });
        
        noteValue.setOnTouchListener((v, event) -> {
            // Handle double-tap for editing
            boolean doubleTapHandled = gestureDetector.onTouchEvent(event);
            
            // If double-tap was handled, consume the event to prevent link clicks
            if (doubleTapHandled) {
                return true;
            }
            
            // For single taps on links, let the LinkMovementMethod handle it
            if (noteValue.getMovementMethod() != null) {
                return noteValue.getMovementMethod().onTouchEvent(noteValue, (Spannable) noteValue.getText(), event);
            }
            
            return false; // Allow other touch events to be processed
        });
    }
    
    /**
     * Gets the original default note (not custom note) by reading directly from the default note file
     */
    private String getOriginalDefaultNote(String bandName) {
        try {
            // Read directly from the .note_new file to get the original default note
            File defaultNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
            
            if (!defaultNoteFile.exists()) {
                Log.d("OriginalDefaultNote", "No default note file exists for " + bandName);
                return null;
            }
            
            // Read the note file (it's a serialized HashMap)
            Map<String, String> noteData = (Map<String, String>) FileHandler70k.readObject(defaultNoteFile);
            if (noteData != null && noteData.containsKey("defaultNote")) {
                String originalNote = noteData.get("defaultNote");
                Log.d("OriginalDefaultNote", "Found original default note for " + bandName + ": " + originalNote);
                return originalNote;
            } else {
                Log.d("OriginalDefaultNote", "No defaultNote key found in file for " + bandName);
                return null;
            }
            
        } catch (Exception e) {
            Log.e("OriginalDefaultNote", "Error reading original default note for " + bandName, e);
            return null;
        }
    }
    
    /**
     * Gets raw band note data without HTML conversion - directly from CustomerDescriptionHandler
     */
    private String getRawBandNote(String bandName) {
        try {
            // First check for custom note
            BandNotes bandHandler = new BandNotes(bandName);
            String customNote = bandHandler.getBandNoteFromFile();
            if (customNote != null && !customNote.trim().isEmpty() && 
                !customNote.contains("Comment text is not available yet")) {
                Log.d("RawBandNote", "Returning custom note for " + bandName);
                return customNote;
            }
            
            // Get default note directly without HTML conversion
            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
            // This calls the full getDescription but we'll strip HTML if present
            String note = descHandler.getDescription(bandName);
            Log.d("RawBandNote", "Got note from CustomerDescriptionHandler: " + note);
            return note;
            
        } catch (Exception e) {
            Log.e("RawBandNote", "Error getting raw band note for " + bandName, e);
            return "Comment text is not available yet. Please wait for Aaron to add his description.";
        }
    }
    
    /**
     * Converts text with URLs (both !!!! format and HTML <a> tags) to clickable spannable text for native TextView
     */
    private SpannableString makeUrlsClickable(String text) {
        Log.d("LinkProcessing", "Original text: " + text);
        String cleanText = text;
        
        // Handle already-converted HTML <a> tags from BandNotes.java
        // Pattern: <a target='_blank' style='color: lightblue' href=https://URL>DISPLAY_TEXT</a>
        // More flexible pattern to handle various href formats
        String beforeHtml = cleanText;
        cleanText = cleanText.replaceAll("<a[^>]*href=([^\\s>]+)[^>]*>([^<]+)</a>", "$1");
        Log.d("LinkProcessing", "After HTML processing: " + cleanText);
        
        // Handle original !!!! format URLs
        String beforeExclamation = cleanText;
        cleanText = cleanText.replaceAll("!!!!https://([^\\s]+)", "https://$1");
        Log.d("LinkProcessing", "After !!!! processing: " + cleanText);
        
        SpannableString spannableString = new SpannableString(cleanText);
        
        // Pattern to find all https:// URLs in the cleaned text
        Pattern urlPattern = Pattern.compile("https://[^\\s]+");
        Matcher matcher = urlPattern.matcher(cleanText);
        
        while (matcher.find()) {
            final String url = matcher.group(0); // Full URL with https://
            
            int start = matcher.start();
            int end = matcher.end();
            
            // Create clickable span that opens in in-app WebView
            ClickableSpan clickableSpan = new ClickableSpan() {
                @Override
                public void onClick(View widget) {
                    Log.d("ClickableLink", "Clicked URL: " + url);
                    // Open in the same in-app WebView as other links
                    showInAppWebView(url, "customLink");
                }
                
                @Override
                public void updateDrawState(android.text.TextPaint ds) {
                    super.updateDrawState(ds);
                    ds.setUnderlineText(false); // Remove underline to match original style
                }
            };
            
            // Apply clickable span
            spannableString.setSpan(clickableSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
            
            // Make the link light blue like the original HTML version
            ForegroundColorSpan colorSpan = new ForegroundColorSpan(Color.parseColor("#ADD8E6")); // Light blue
            spannableString.setSpan(colorSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        
        return spannableString;
    }
    
    /**
     * Sets up the band title and logo section
     */
    private void setupBandTitleAndLogo() {
        // Set band name
        bandNameText.setText(bandName);
        
        // Load and set band logo
        ImageHandler imageHandler = new ImageHandler(bandName);
        java.net.URI imageURI = imageHandler.getImage();
        
        if (imageURI != null) {
            try {
                // Load the image from the cached file
                java.io.File imageFile = new java.io.File(imageURI);
                if (imageFile.exists()) {
                    Bitmap bitmap = BitmapFactory.decodeFile(imageFile.getAbsolutePath());
                    if (bitmap != null) {
                        bandLogoImage.setImageBitmap(bitmap);
                        bandLogoImage.setVisibility(View.VISIBLE);
                        
                        // Set appropriate scaling based on aspect ratio
                        int width = bitmap.getWidth();
                        int height = bitmap.getHeight();
                        if (width > 0 && height > 0) {
                            int ratio = width / height;
                            if (ratio > 5) {
                                // Wide image - use width constraint
                                bandLogoImage.getLayoutParams().width = (int) (getResources().getDisplayMetrics().widthPixels * 0.7);
                                bandLogoImage.getLayoutParams().height = ViewGroup.LayoutParams.WRAP_CONTENT;
                            } else {
                                // Tall or square image - use height constraint  
                                bandLogoImage.getLayoutParams().width = ViewGroup.LayoutParams.WRAP_CONTENT;
                                bandLogoImage.getLayoutParams().height = (int) (getResources().getDisplayMetrics().heightPixels * 0.1);
                            }
                        }
                        Log.d("setupBandTitleAndLogo", "Image loaded for " + bandName);
                    }
                }
            } catch (Exception e) {
                Log.e("setupBandTitleAndLogo", "Error loading cached image for " + bandName, e);
                bandLogoImage.setVisibility(View.GONE);
            }
        } else {
            // Image not cached - will be loaded by background thread and screen will refresh
            bandLogoImage.setVisibility(View.GONE);
            Log.d("setupBandTitleAndLogo", "Image not cached for " + bandName + ", will load async");
        }
    }
    
    /**
     * Sets up the schedule section with show times and venues
     */
    private void setupScheduleSection() {
        // Clear existing schedule items
        scheduleSection.removeAllViews();
        
        try {
            if (BandInfo.scheduleRecords.get(bandName) != null) {
                Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();
                
                while (entries.hasNext()) {
                    Map.Entry thisEntry = (Map.Entry) entries.next();
                    Object key = thisEntry.getKey();
                    
                    // Create schedule item view
                    View scheduleItemView = LayoutInflater.from(this).inflate(R.layout.schedule_item, scheduleSection, false);
                    
                    // Get schedule data
                    String location = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowLocation();
                    String locationColor = staticVariables.getVenueColor(location);
                    String rawStartTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getStartTimeString();
                    String startTime = dateTimeFormatter.formatScheduleTime(rawStartTime);
                    String endTime = dateTimeFormatter.formatScheduleTime(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getEndTimeString());
                    String dayNumber = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowDay();
                    dayNumber = dayNumber.replaceFirst("Day ", "");
                    String eventType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType();
                    String eventNote = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowNotes();
                    
                    String attendIndex = bandName + ":" + location + ":" + rawStartTime + ":" + eventType + ":" + String.valueOf(staticVariables.eventYear);
                    String eventTypeImage = showBandDetails.getEventTypeImage(eventType, bandName);
                    String attendedImage = showBandDetails.getAttendedImage(attendIndex);
                    
                    // Don't display "show" as event type since it's default
                    if (eventType.equals(staticVariables.show)) {
                        eventType = "";
                    }
                    
                    if (staticVariables.venueLocation.get(location) != null) {
                        location = location + " " + staticVariables.venueLocation.get(location);
                    }
                    
                    // Set up the schedule item views
                    setupScheduleItemViews(scheduleItemView, location, locationColor, startTime, endTime, 
                                         dayNumber, eventType, eventNote, attendedImage, eventTypeImage, attendIndex);
                    
                    scheduleSection.addView(scheduleItemView);
                }
            }
        } catch (Exception error) {
            Log.e("setupScheduleSection", "Error setting up schedule", error);
        }
    }
    
    /**
     * Helper method to set up individual schedule item views
     */
    private void setupScheduleItemViews(View scheduleItemView, String location, String locationColor, 
                                      String startTime, String endTime, String dayNumber, String eventType, 
                                      String eventNote, String attendedImage, String eventTypeImage, String attendIndex) {
        
        // Set venue color bars
        View venueColorBar1 = scheduleItemView.findViewById(R.id.venue_color_bar);
        View venueColorBar2 = scheduleItemView.findViewById(R.id.venue_color_bar_2);
        int color = Color.parseColor(locationColor);
        venueColorBar1.setBackgroundColor(color);
        venueColorBar2.setBackgroundColor(color);
        
        // Set location text
        TextView locationText = scheduleItemView.findViewById(R.id.location_text);
        locationText.setText(location);
        
        // Set attended icon
        ImageView attendedIcon = scheduleItemView.findViewById(R.id.attended_icon);
        if (!attendedImage.isEmpty()) {
            setImageFromResource(attendedIcon, attendedImage);
            attendedIcon.setVisibility(View.VISIBLE);
        } else {
            attendedIcon.setVisibility(View.GONE);
        }
        
        // Set times
        TextView startTimeText = scheduleItemView.findViewById(R.id.start_time_text);
        TextView endTimeText = scheduleItemView.findViewById(R.id.end_time_text);
        startTimeText.setText(startTime);
        endTimeText.setText(endTime);
        
        // Set day number
        TextView dayNumberText = scheduleItemView.findViewById(R.id.day_number_text);
        dayNumberText.setText(dayNumber);
        
        // Set event type and notes
        TextView eventTypeText = scheduleItemView.findViewById(R.id.event_type_text);
        TextView eventNotesText = scheduleItemView.findViewById(R.id.event_notes_text);
        
        if (!eventType.isEmpty()) {
            eventTypeText.setText(Utilities.convertEventTypeToLocalLanguage(eventType));
            eventTypeText.setVisibility(View.VISIBLE);
        } else {
            eventTypeText.setVisibility(View.GONE);
        }
        eventNotesText.setText(eventNote);
        
        // Set event type icon
        ImageView eventTypeIcon = scheduleItemView.findViewById(R.id.event_type_icon);
        if (!eventTypeImage.isEmpty()) {
            setImageFromResource(eventTypeIcon, eventTypeImage);
            eventTypeIcon.setVisibility(View.VISIBLE);
        } else {
            eventTypeIcon.setVisibility(View.GONE);
        }
        
        // Set click listener for attendance tracking
        scheduleItemView.setOnClickListener(v -> handleScheduleItemClick(attendIndex));
    }
    
    /**
     * Helper method to set image from Android resource path
     */
    private void setImageFromResource(ImageView imageView, String resourcePath) {
        try {
            // Extract resource name from path like "file:///android_res/drawable/icon_seen.png"
            String resourceName = resourcePath.substring(resourcePath.lastIndexOf("/") + 1);
            resourceName = resourceName.substring(0, resourceName.lastIndexOf(".")); // Remove extension
            
            int resourceId = getResources().getIdentifier(resourceName, "drawable", getPackageName());
            if (resourceId != 0) {
                imageView.setImageResource(resourceId);
            }
        } catch (Exception e) {
            Log.e("setImageFromResource", "Error setting image from resource: " + resourcePath, e);
        }
    }
    
    /**
     * Handles schedule item clicks for attendance tracking
     */
    private void handleScheduleItemClick(String attendIndex) {
        if (clickedOnEvent == false) {
            clickedOnEvent = true;
            Log.d("showAttended", "Lets set this value of " + attendIndex);
            String status = staticVariables.attendedHandler.addShowsAttended(attendIndex, "");
            String message = staticVariables.attendedHandler.setShowsAttendedStatus(status);
            HelpMessageHandler.showMessage(message);

            // Refresh native content instead of restarting activity
            if (useNativeView) {
                refreshNativeContent();
                clickedOnEvent = false; // Reset flag for native refresh
            } else {
                // For WebView mode, still need to restart activity
                Intent showDetails = new Intent(showBandDetails.this, showBandDetails.class);
                startActivity(showDetails);
                finish();
            }
        }
    }
    
    /**
     * Sets up the links section for external websites with dynamic spacing
     */
    private void setupLinksSection() {
        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal")) {
            linksLabel.setText("Links:");
            linksSection.setVisibility(View.VISIBLE);
            
            // Set up dynamic spacing for link icons
            setupDynamicLinkSpacing();
        } else {
            linksSection.setVisibility(View.GONE);
        }
    }
    
    /**
     * Sets up dynamic spacing for link icons based on screen width
     */
    private void setupDynamicLinkSpacing() {
        // Get screen width
        android.util.DisplayMetrics displayMetrics = new android.util.DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        int screenWidth = displayMetrics.widthPixels;
        
        // Convert dp to pixels for calculations
        float density = getResources().getDisplayMetrics().density;
        int labelWidth = (int) (120 * density); // Links label width: 120dp
        int sectionMargins = (int) (32 * density); // Total left/right margins: 16dp each
        int iconWidth = (int) (43 * density); // Each icon width: 43dp
        int totalIconsWidth = iconWidth * 4; // 4 icons total
        
        // Calculate available space for spacing
        int availableSpace = screenWidth - labelWidth - sectionMargins - totalIconsWidth;
        
        // Calculate spacing between icons (distribute evenly, but make last icon closer to edge)
        int spacingBetweenIcons = Math.max((int) (12 * density), availableSpace / 4); // Minimum 12dp, or dynamic
        int lastIconMargin = Math.max((int) (8 * density), availableSpace / 6); // Less margin for last icon
        
        Log.d("DynamicSpacing", "Screen width: " + screenWidth + ", Available space: " + availableSpace + 
              ", Icon spacing: " + spacingBetweenIcons + ", Last margin: " + lastIconMargin);
        
        // Apply dynamic margins to icons
        setIconMargin(websiteLink, 0, spacingBetweenIcons);
        setIconMargin(metalArchivesLink, 0, spacingBetweenIcons);
        setIconMargin(wikipediaLink, 0, spacingBetweenIcons);
        setIconMargin(youtubeLink, 0, lastIconMargin); // Last icon has smaller right margin
    }
    
    /**
     * Helper method to set margins for an icon
     */
    private void setIconMargin(ImageView icon, int leftMargin, int rightMargin) {
        if (icon != null && icon.getLayoutParams() instanceof LinearLayout.LayoutParams) {
            LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) icon.getLayoutParams();
            params.setMargins(leftMargin, params.topMargin, rightMargin, params.bottomMargin);
            icon.setLayoutParams(params);
        }
    }
    
    /**
     * Helper method to process text and ensure proper line break handling
     */
    private String processLineBreaks(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        
        // Since we fixed the root cause in CustomerDescriptionHandler,
        // the text should now come with proper line breaks preserved
        String processed = text;
        
        // Handle any remaining HTML br tags (for backward compatibility)
        processed = processed.replace("<br><br>", "\n\n");
        processed = processed.replace("<br>", "\n");
        processed = processed.replace("<br/>", "\n");
        
        // Convert single line breaks to double line breaks for better paragraph separation
        processed = processed.replaceAll("\n", "\n\n");
        
        // Clean up any excessive spacing (max 2 consecutive newlines)
        processed = processed.replaceAll("\n{3,}", "\n\n");
        processed = processed.trim(); // Remove leading/trailing whitespace
        
        return processed;
    }
    
    /**
     * Clears cached note data to force refresh with new line break processing and updates display
     */
    private void clearCachedNoteData(String bandName) {
        try {
            Log.d("LineBreakDebug", "Clearing cached note data for " + bandName);
            
            // Delete cached note files to force refresh
            java.io.File bandNoteFile = new java.io.File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
            java.io.File bandCustNoteFile = new java.io.File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".custNote");
            
            if (bandNoteFile.exists()) {
                bandNoteFile.delete();
                Log.d("LineBreakDebug", "Deleted cached note file: " + bandNoteFile.getPath());
            }
            
            if (bandCustNoteFile.exists()) {
                bandCustNoteFile.delete();
                Log.d("LineBreakDebug", "Deleted cached custom note file: " + bandCustNoteFile.getPath());
            }
            
            // Force re-download of note data in background with UI refresh
            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
            new Thread(() -> {
                try {
                    Log.d("LineBreakDebug", "Re-downloading note data for " + bandName);
                    descHandler.loadNoteFromURL(bandName);
                    
                    // Wait a moment for the download to complete
                    Thread.sleep(2000);
                    
                    // Refresh the UI on the main thread
                    runOnUiThread(() -> {
                        Log.d("LineBreakDebug", "Refreshing display for " + bandName);
                        if (useNativeView) {
                            refreshNativeContent();
                        } else {
                            refreshWebContent();
                        }
                        Log.d("LineBreakDebug", "Display refreshed - line breaks should now be visible");
                    });
                } catch (Exception e) {
                    Log.e("LineBreakDebug", "Error during background refresh for " + bandName, e);
                }
            }).start();
            
            Log.d("LineBreakDebug", "Cache clearing and refresh initiated for " + bandName);
        } catch (Exception e) {
            Log.e("LineBreakDebug", "Error clearing cached note data for " + bandName, e);
        }
    }
    
    /**
     * Sets up the extra data section (country, genre, etc.)
     */
    private void setupExtraDataSection() {

        
        boolean hasExtraData = false;
        
        // Country
        if (!BandInfo.getCountry(bandName).isEmpty()) {
            countryValue.setText(BandInfo.getCountry(bandName));
            countryRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            countryRow.setVisibility(View.GONE);
        }
        
        // Genre
        if (!BandInfo.getGenre(bandName).isEmpty()) {
            genreValue.setText(BandInfo.getGenre(bandName));
            genreRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            genreRow.setVisibility(View.GONE);
        }
        
        // Last on cruise
        if (!BandInfo.getPriorYears(bandName).isEmpty()) {
            lastCruiseValue.setText(BandInfo.getPriorYears(bandName));
            lastCruiseRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            lastCruiseRow.setVisibility(View.GONE);
        }
        
        // Note - Get note data without HTML conversion for native TextView
        String rawNote = "";
        if (bandNote != null && !bandNote.trim().isEmpty()) {
            rawNote = bandNote;
        } else {
            // Get raw note data without HTML conversion by directly accessing BandNotes file
            rawNote = getRawBandNote(bandName);
        }
        
        if (!rawNote.isEmpty()) {
            // If the note still contains <br> tags, it's old cached data - force refresh
            if (rawNote.contains("<br>")) {
                clearCachedNoteData(bandName);
            }
            
            String noteText = processLineBreaks(rawNote);
            
            // Configure TextView for proper multiline display
            noteValue.setSingleLine(false);
            noteValue.setMaxLines(Integer.MAX_VALUE);
            noteValue.setHorizontallyScrolling(false);
            
            // Process URLs and make them clickable (handles both !!!! format and HTML <a> tags)
            if (noteText.contains("!!!!https://") || noteText.contains("<a ") || noteText.contains("https://")) {
                SpannableString clickableText = makeUrlsClickable(noteText);
                noteValue.setText(clickableText);
                noteValue.setMovementMethod(LinkMovementMethod.getInstance());
            } else {
                noteValue.setText(noteText);
            }
            
            noteRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            noteRow.setVisibility(View.GONE);
        }
        
        // Show/hide the entire extra data section
        if (hasExtraData && !orientation.equals("landscape")) {
            extraDataSection.setVisibility(View.VISIBLE);
        } else {
            extraDataSection.setVisibility(View.GONE);
        }
    }
    
    /**
     * Sets up the user notes section (personal user notes, not band descriptions)
     */
    private void setupNotesSection() {
        // Always hide user notes section to prevent duplication
        // User notes functionality can be re-enabled later if needed for personal notes
        userNotesSection.setVisibility(View.GONE);
    }
    
    /**
     * Sets up the ranking buttons at the bottom
     */
    private void setupRankingButtons() {
        SetButtonColors(); // This sets the color variables
        
        // Set button text from resources
        unknownButton.setText(getResources().getString(R.string.unknown));
        mustButton.setText(getResources().getString(R.string.must));
        mightButton.setText(getResources().getString(R.string.might));
        wontButton.setText(getResources().getString(R.string.wont));
        
        // Apply button colors (convert from HTML color names to Android colors)
        unknownButton.setBackgroundColor(getColorFromString(unknownButtonColor));
        mustButton.setBackgroundColor(getColorFromString(mustButtonColor));
        mightButton.setBackgroundColor(getColorFromString(mightButtonColor));
        wontButton.setBackgroundColor(getColorFromString(wontButtonColor));
        
        // Set ranking icon
        if (!rankIconLocation.isEmpty()) {
            setImageFromResource(rankingIcon, rankIconLocation);
            rankingIcon.setVisibility(View.VISIBLE);
        } else {
            rankingIcon.setVisibility(View.GONE);
        }
    }
    
    /**
     * Helper method to convert color string to Android color
     */
    private int getColorFromString(String colorString) {
        switch (colorString.toLowerCase()) {
            case "silver":
                return Color.parseColor("#808080"); // Darker grey instead of silver
            case "black":
            default:
                return Color.BLACK;
        }
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
                    // Handle ranking button clicks
                    rankStore.saveBandRanking(BandInfo.getSelectedBand(), resolveValue(value));
                    
                    // Refresh WebView content instead of restarting activity
                    refreshWebContent();
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

                // Show in-app WebView instead of external browser (consistent with native implementation)
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        showInAppWebView(webUrl, value);
                    }
                });
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
        
        // Only reload WebView if we're using WebView mode and it exists
        if (!useNativeView && mWebView != null) {
            mWebView.reload();
        }
        
        // Background loading is managed by main activity lifecycle only
    }

    @Override
    public void onResume() {
        super.onResume();
        if (useNativeView) {
            setContentView(R.layout.band_details_native);
            initializeNativeContent();
        } else {
            setContentView(R.layout.band_details);
            initializeWebContent();
        }
        inLink = false;
        
        // Background loading is managed by main activity lifecycle only
    }

    @Override
    public void onBackPressed() {

        Log.d("WebView", "Back button pressed - inLink=" + inLink + ", inAppWebView=" + (inAppWebView != null));
        
        // If we're in WebView mode, check history first
        if (inLink && inAppWebView != null) {
            // Debug WebView history state
            debugWebViewHistory();
            
            if (inAppWebView.canGoBack()) {
                Log.d("WebView", "Going back in WebView history");
                inAppWebView.goBack();
                return;
            } else {
                Log.d("WebView", "No WebView history, exiting to band details");
                exitInAppWebView();
                return;
            }
        }
        
        // Standard back navigation - return to main bands list
        staticVariables.writeNoteHtml = "";
        if (inLink){
            // Reset the link state
            inLink = false;
            if (mWebView != null) {
                mWebView.onPause();
            }
        }
        
        Log.d("WebView", "Standard back navigation to bands list");
        SystemClock.sleep(70);
        setResult(RESULT_OK, null);
        finish();
        NavUtils.navigateUpTo(this, new Intent(this, showBands.class));
    }
    
    @Override
    protected void onDestroy() {
        // Clean up in-app WebView if it exists
        if (inAppWebView != null) {
            inAppWebView.destroy();
            inAppWebView = null;
        }
        
        // Clean up other WebView references
        if (webViewProgressBar != null) {
            webViewProgressBar = null;
        }
        
        // Background loading is controlled by app lifecycle (onPause/onResume), not details screen
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
