package com.Bands70k;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Handler;
import android.os.StrictMode;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Parcelable;
import android.os.SystemClock;
import android.preference.PreferenceManager;

import androidx.activity.ComponentActivity;
import androidx.activity.EdgeToEdge;
import androidx.appcompat.widget.SearchView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import androidx.core.content.res.ResourcesCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import android.util.DisplayMetrics;
import android.view.MenuItem;

import android.util.Log;
import android.view.ContextThemeWrapper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

import com.baoyz.swipemenulistview.SwipeMenu;
import com.baoyz.swipemenulistview.SwipeMenuCreator;
import com.baoyz.swipemenulistview.SwipeMenuItem;
import com.baoyz.swipemenulistview.SwipeMenuListView;

import com.google.firebase.messaging.FirebaseMessaging;

import java.io.BufferedReader;
import java.util.Collections;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static com.Bands70k.staticVariables.*;

import com.Bands70k.CombinedImageListHandler;

import android.view.Window;
import android.view.WindowManager;


public class showBands extends Activity implements MediaPlayer.OnPreparedListener {

    String notificationTag = "notificationTag";

    public static String newRootDir = Bands70k.getAppContext().getFilesDir().getPath();

    private ArrayList<String> bandNames;
    public List<String> scheduleSortedBandNames = new ArrayList<String>();

    private SwipeMenuListView bandNamesList;
    private SwipeRefreshLayout bandNamesPullRefresh;
    
    // Track scroll state to prevent accidental clicks when stopping scroll
    private int currentScrollState = AbsListView.OnScrollListener.SCROLL_STATE_IDLE;
    private long lastScrollTime = 0;
    private static final long SCROLL_STOP_DELAY_MS = 50; // Reduced delay - only block clicks during active scrolling, not after
    private static final long SCROLL_STATE_TIMEOUT_MS = 200; // If scroll state hasn't changed in this time, treat as IDLE
    private volatile boolean isRefreshing = false; // Track if a refresh is in progress
    private int refreshCounter = 0; // Track number of concurrent refreshes for debugging
    private long lastRefreshStartTime = 0; // Track when refresh started
    private long lastRefreshEndTime = 0; // Track when refresh ended
    private AbsListView.OnScrollListener scrollListener = null; // Store scroll listener to avoid replacing it

    private ArrayList<String> rankedBandNames;

    private BandInfo bandInfo;
    private CustomerDescriptionHandler bandNotes;
    public Button filterMenuButton;
    public Button willAttendFilterButton;

    // Background detection is now handled at Application level using ActivityLifecycleCallbacks
    public static Boolean appFullyInitialized = false;
    
    // Flag to track when returning from stats page to avoid blocking refresh
    private static Boolean returningFromStatsPage = false;
    
    // INTERMITTENT POSITION LOSS FIX: Flag to track when we're returning from details screen
    public static Boolean returningFromDetailsScreen = false;

    //private static final int PLAY_SERVICES_RESOLUTION_REQUEST = 9000;
    private static final String TAG = "MainActivity";

    private BroadcastReceiver mRegistrationBroadcastReceiver;
    private boolean isReceiverRegistered;

    public mainListHandler listHandler;
    private bandListView adapter;
    private ListView listView;

    public SearchView searchCriteriaObject;

    private static Boolean recievedPermAnswer = false;
    private Boolean loadOnceStopper = false;

    // Easter egg trigger state for search
    private boolean hasTriggeredCowbellEasterEgg = false;

    private Boolean sharedZipFile = false;
    private File zipFile;

    private Dialog dialog;
    
    // Data change detection to prevent unnecessary refreshes
    private static final String PREFS_DATA_TIMESTAMPS = "DataTimestamps";
    private SharedPreferences dataTimestampPrefs;

    // inside my class
    private static final String[] INITIAL_PERMS = {
            android.Manifest.permission.INTERNET,
            android.Manifest.permission.ACCESS_NETWORK_STATE,
            android.Manifest.permission.WAKE_LOCK,
            android.Manifest.permission.VIBRATE
    };
    private static final int REQUEST = 1337;


    @Override
    protected void onCreate(Bundle savedInstanceState) {

        // Use internal app storage - no permissions required
        Log.d("App Storage", "Using internal app storage: " + newRootDir);
        
        // Log crash statistics from AsyncTask modernization
        Log.i("AsyncTaskModernization", "📊 " + CrashReporter.getCrashStats());

        setTheme(R.style.AppTheme);
        super.onCreate(savedInstanceState);

        // DEBUG: Log current festival configuration
        ConfigDebugger.logCurrentConfig();

        if (staticVariables.preferences == null) {
            staticVariables.preferences = new preferencesHandler();
            staticVariables.preferences.loadData();
            Log.d("ShowWont", "Show Wont = " + staticVariables.preferences.getShowWont());
        }

        setContentView(R.layout.activity_show_bands);
        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        setContentView(R.layout.activity_show_bands);
        
        // Initialize data timestamp preferences for change detection
        dataTimestampPrefs = getSharedPreferences(PREFS_DATA_TIMESTAMPS, MODE_PRIVATE);
        mRegistrationBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                SharedPreferences sharedPreferences =
                        PreferenceManager.getDefaultSharedPreferences(context);
                boolean sentToken = sharedPreferences
                        .getBoolean(SENT_TOKEN_TO_SERVER, false);
            }
        };

        // Registering BroadcastReceiver
        registerReceiver();


        if (staticVariables.attendedHandler == null) {
            staticVariables.attendedHandler = new showsAttended();
        }

        Log.d("startup", "show init start - 1");

        staticVariablesInitialize();
        
        // Initialize sharing managers early
        Log.d("INIT", "🔧 Initializing sharing managers...");
        SQLiteProfileManager.getInstance();
        ProfileColorManager.getInstance();
        SharedPreferencesManager.getInstance();
        Log.d("INIT", "✅ Sharing managers initialized");
        
        // Handle incoming shared preference file (if opened from external source)
        handleIncomingIntent(getIntent());

        this.getCountry();
        Log.d("startup", "show init start - 2");
        bandInfo = new BandInfo();
        bandNotes = CustomerDescriptionHandler.getInstance();

        Log.d("startup", "show init start - 3");
        scheduleAlertHandler alertHandler = new scheduleAlertHandler();

        Log.d("startup", "show init start - 4");
        //alertHandler.sendLocalAlert("Testing after 10 seconds", 5);

        Log.d("prefsData", "Show Unknown 1  = " + staticVariables.preferences.getShowUnknown());

        TextView jumpToTop = (TextView) findViewById(R.id.headerBandCount);
        
        // Long click jumps to top (original behavior)
        jumpToTop.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                bandNamesList.setSelectionAfterHeaderView();
                return true;
            }
        });
        
        // Regular click shows profile picker (new behavior)
        jumpToTop.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                showProfilePicker();
            }
        });

        // CRASH FIX: Initialize bandNamesList
        bandNamesList = (SwipeMenuListView) findViewById(R.id.bandNames);
        Log.d("UI_INIT", "🔧 bandNamesList initialized: " + (bandNamesList != null ? "SUCCESS" : "FAILED"));
        
        // CLICK LISTENER FIX: Set up click listener immediately after initialization
        setupClickListener();
        
        // If adapter was prepared before UI was ready, set it now
        if (bandNamesList != null && adapter != null) {
            Log.d("UI_INIT", "🔧 Setting deferred adapter with " + adapter.getCount() + " items");
            bandNamesList.setAdapter(adapter);
        }

        handleSearch();

        bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
        bandNamesPullRefresh.setOnRefreshListener(
                new SwipeRefreshLayout.OnRefreshListener() {
                    @Override
                    public void onRefresh() {
                        checkForEasterEgg();
                        Log.i("AsyncList refresh", "onRefresh called from SwipeRefreshLayout");

                        //start spinner and stop after 5 seconds
                        bandNamesPullRefresh.setRefreshing(true);
                        bandInfo = new BandInfo();
                        staticVariables.loadingNotes = false;
                        SynchronizationManager.signalNotesLoadingComplete();

                        // Pull-to-refresh should download all major config files in the background (non-blocking UI):
                        // - bandInfo.csv
                        // - schedule.csv
                        // - descriptionMap.csv
                        // Then refresh the UI only after all downloads complete.
                        performPullToRefreshDownload();

                    }

                }

        );

        Log.d(TAG, "2 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());
        Log.d("startup", "show init start - 5");
        populateBandList();
        Log.d("startup", "show init start - 6");
        showNotification();

        Log.d(TAG, "3 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());

        Log.d("DisplayListData", "show init start - 9");

        BandInfo bandInfo = new BandInfo();
        bandInfo.DownloadBandFile();

        FirbaseAsyncUserWrite userDataWriteAsync = new FirbaseAsyncUserWrite();
        userDataWriteAsync.execute();

        setupButtons();
        checkForNotifcationPermMissions();
        Log.d("startup", "show init start - 10");

        setSearchBarWidth();
    }

    public void checkForEasterEgg(){
        if (lastRefreshCount > 0){

            if (lastRefreshCount == 9){
                triggerEasterEgg();
                lastRefreshCount = 0;
                lastRefreshEpicTime = (int)(System.currentTimeMillis()/1000);

           } else if ((int)(System.currentTimeMillis()/1000) > (lastRefreshEpicTime + 40)){
                Log.d("Easter Egg", "Easter Egg triggered after more then 40 seconds");
                lastRefreshCount = 1;
                lastRefreshEpicTime = (int)(System.currentTimeMillis()/1000);

            } else {
                lastRefreshCount = lastRefreshCount + 1;
                Log.d("Easter Egg", "Easter Egg incrementing counter, on " + lastRefreshCount.toString());

            }



        } else {
            lastRefreshCount = 1;
            Log.d("Easter Egg", "Easter Egg incrementing counter, on  " + lastRefreshCount.toString());
            lastRefreshEpicTime = (int)(System.currentTimeMillis()/1000);
        }
    }

    public void triggerEasterEgg(){
        Log.d("Easter Egg", "The easter egg has been triggered");

        dialog = new Dialog(this,android.R.style.Theme_Translucent_NoTitleBar);
        dialog.setContentView(R.layout.prompt_show_video);
        
        // Allow dialog to be dismissed by tapping outside or pressing back button
        dialog.setCancelable(true);
        dialog.setCanceledOnTouchOutside(true);


        VideoView mVideoView = (VideoView)dialog.findViewById(R.id.VideoView);

        // Construct proper URI for the raw resource
        // Try to get the resource ID - will use MP4 if available, fallback to MOV
        int videoResourceId = getVideoResourceId();
        Uri videoUri = Uri.parse("android.resource://" + getPackageName() + "/" + videoResourceId);
        Log.d("Easter Egg", "Video URI: " + videoUri.toString());
        
        mVideoView.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {
            @Override
            public void onPrepared(MediaPlayer mp) {
                Log.d("Easter Egg", "Video prepared and ready to play");
                mp.start();
            }
        });
        
        // Add error listener to catch playback issues
        mVideoView.setOnErrorListener(new MediaPlayer.OnErrorListener() {
            @Override
            public boolean onError(MediaPlayer mp, int what, int extra) {
                String errorMsg = "Video playback error - what: " + what + ", extra: " + extra;
                Log.e("Easter Egg", errorMsg);
                
                // Provide more specific error messages
                String userMessage = "Unable to play video";
                if (what == MediaPlayer.MEDIA_ERROR_UNKNOWN) {
                    userMessage = "Unknown media error";
                } else if (what == MediaPlayer.MEDIA_ERROR_SERVER_DIED) {
                    userMessage = "Media server error";
                }
                
                Toast.makeText(showBands.this, userMessage, Toast.LENGTH_LONG).show();
                if (dialog != null && dialog.isShowing()) {
                    dialog.dismiss();
                }
                return true;
            }
        });
        
        // Add click listener to VideoView to dismiss on tap
        mVideoView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d("Easter Egg", "Video tapped - dismissing dialog");
                if (dialog != null && dialog.isShowing()) {
                    dialog.dismiss();
                }
            }
        });
        
        // Also add touch listener to the entire dialog container (including background) for better UX
        View dialogContainer = dialog.findViewById(R.id.video_dialog_container);
        if (dialogContainer != null) {
            dialogContainer.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    Log.d("Easter Egg", "Dialog background tapped - dismissing dialog");
                    if (dialog != null && dialog.isShowing()) {
                        dialog.dismiss();
                    }
                }
            });
        }
        
        dialog.show();

        // Center the dialog on the screen
        Window window = dialog.getWindow();
        if (window != null) {
            WindowManager.LayoutParams layoutParams = new WindowManager.LayoutParams();
            layoutParams.copyFrom(window.getAttributes());
            layoutParams.gravity = Gravity.CENTER;
            window.setAttributes(layoutParams);
        }

        try {
            mVideoView.setVideoURI(videoUri);
            mVideoView.requestFocus();
        } catch (Exception e) {
            Log.e("Easter Egg", "Exception setting video URI: " + e.getMessage());
            Toast.makeText(this, "Error loading video", Toast.LENGTH_SHORT).show();
            dialog.dismiss();
        }
        
        mVideoView.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
            @Override
            public void onCompletion(MediaPlayer mediaPlayer) {
                Log.d("Easter Egg", "Video playback completed");
                dialog.dismiss();
            }
        });

    }
    
    private int getVideoResourceId() {
        // Try to get MP4 version first (better Android compatibility)
        int resourceId = getResources().getIdentifier("snl_more_cowbell", "raw", getPackageName());
        if (resourceId == 0) {
            Log.w("Easter Egg", "Could not find video resource, using R.raw.snl_more_cowbell");
            resourceId = R.raw.snl_more_cowbell;
        } else {
            Log.d("Easter Egg", "Found video resource with ID: " + resourceId);
        }
        return resourceId;
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        Log.d("orientation", "orientation DONE!");
        setSearchBarWidth();
    }

    /**
     * Pull-to-refresh behavior:
     * - Shows spinner briefly (2s max) without blocking UI
     * - Downloads ALL major config files in background:
     *   1) bandInfo.csv
     *   2) schedule.csv
     *   3) descriptionMap.csv
     * - Refreshes UI only after background downloads complete
     *
     * Uses existing enhanced connectivity detection via OnlineStatus.isOnline().
     */
    private void performPullToRefreshDownload() {
        // Spinner should be visible briefly but must not block UI.
        // Stop after 2 seconds regardless of download completion.
        try {
            new Handler().postDelayed(() -> {
                try {
                    if (bandNamesPullRefresh != null) {
                        bandNamesPullRefresh.setRefreshing(false);
                    }
                } catch (Exception e) {
                    Log.w("PullToRefresh", "Error stopping refresh spinner", e);
                }
            }, 2000);
        } catch (Exception e) {
            Log.w("PullToRefresh", "Unable to schedule spinner stop", e);
        }

        ThreadManager.getInstance().executeGeneralWithCallbacks(
                // Background task: download/update all config files
                () -> {
                    Log.d("PullToRefresh", "Starting background pull-to-refresh download (bandInfo, schedule, descriptionMap)");

                    // Ensure we don't overlap with other band loading work
                    if (!SynchronizationManager.waitForBandLoadingComplete(10)) {
                        Log.w("PullToRefresh", "Timeout waiting for existing band loading to complete");
                        return;
                    }

                    SynchronizationManager.signalBandLoadingStarted();
                    staticVariables.loadingBands = true;

                    try {
                        boolean online = OnlineStatus.isOnline(); // existing enhanced network detection
                        boolean hasCachedData = FileHandler70k.bandInfo.exists() && FileHandler70k.schedule.exists();

                        if (!online) {
                            Log.d("PullToRefresh", "Offline detected (enhanced check). Using cached data if present: " + hasCachedData);
                        }

                        // 1) bandInfo.csv + 2) schedule.csv (DownloadBandFile triggers schedule download)
                        try {
                            BandInfo bandInfo = new BandInfo();
                            bandInfo.DownloadBandFile();
                        } catch (Exception e) {
                            Log.e("PullToRefresh", "Error downloading band/schedule data", e);
                        }

                        // 3) descriptionMap.csv (hash-checked; only replaces file if content changed)
                        try {
                            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
                            descHandler.getDescriptionMapFile();
                        } catch (Exception e) {
                            Log.e("PullToRefresh", "Error downloading descriptionMap", e);
                        }
                    } finally {
                        staticVariables.loadingBands = false;
                        SynchronizationManager.signalBandLoadingComplete();
                        Log.d("PullToRefresh", "Background pull-to-refresh download finished");
                    }
                },
                // Pre-execute (UI thread): nothing extra; spinner already started in onRefresh
                null,
                // Post-execute (UI thread): refresh UI only after downloads complete
                () -> {
                    try {
                        Log.d("PullToRefresh", "Refreshing UI after pull-to-refresh downloads completed");
                        reloadData();
                        refreshData(true);

                        // Keep alerts consistent with refreshNewData()
                        scheduleAlertHandler alerts = new scheduleAlertHandler();
                        alerts.execute();
                    } catch (Exception e) {
                        Log.e("PullToRefresh", "Error refreshing UI after pull-to-refresh downloads", e);
                    }
                }
        );
    }

    private void setSearchBarWidth(){
        DisplayMetrics displayMetrics = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        int screenWidth = displayMetrics.widthPixels;

        // Set SearchView size based on screen width
        float widthPercentage = 0.62f;  // 70% of screen width
        int desiredWidth = (int) (screenWidth * widthPercentage);

        Log.d("orientation", "orientation DONE! " + String.valueOf(desiredWidth));
        // Find SearchView and update its layout params
        searchCriteriaObject = (SearchView)findViewById(R.id.searchCriteria);
        ViewGroup.LayoutParams layoutParams = searchCriteriaObject.getLayoutParams();
        layoutParams.width = desiredWidth;

        searchCriteriaObject.setLayoutParams(layoutParams);
    }

    private void handleSearch(){
        searchCriteriaObject = (SearchView)findViewById(R.id.searchCriteria);
        searchCriteriaObject.setQuery(searchCriteria, false); // Don't submit query to avoid auto-focus
        searchCriteria = searchCriteriaObject.getQuery().toString();
        
        // Ensure SearchView doesn't automatically get focus
        searchCriteriaObject.clearFocus();
        searchCriteriaObject.setFocusable(false);
        searchCriteriaObject.setFocusable(true);
        searchCriteriaObject.setFocusableInTouchMode(false);

        searchCriteriaObject.setOnQueryTextListener(

                new SearchView.OnQueryTextListener() {
                    @Override
                    public boolean onQueryTextSubmit(String query) {
                        Log.d("searchCriteria", "onQueryTextChange - 1 " + searchCriteria);
                        searchCriteria = searchCriteriaObject.getQuery().toString();
                        // Easter egg trigger for 'More Cow Bell'
                        if (searchCriteria.equalsIgnoreCase("More Cow Bell")) {
                            if (!hasTriggeredCowbellEasterEgg) {
                                triggerEasterEgg();
                                hasTriggeredCowbellEasterEgg = true;
                            }
                        } else {
                            hasTriggeredCowbellEasterEgg = false;
                        }
                        searchCriteriaObject.clearFocus();
                        listHandler.sortableBandNames = new ArrayList<String>();
                        listHandler.sortableBandNames = listHandler.getSortableBandNames();
                        refreshData();
                        return false;
                    }

                    @Override
                    public boolean onQueryTextChange(String newText) {
                        searchCriteria = searchCriteriaObject.getQuery().toString();
                        Log.d("searchCriteria", "onQueryTextChange - 2 " + searchCriteria);
                        // Easter egg trigger for 'More Cow Bell'
                        if (searchCriteria.equalsIgnoreCase("More Cow Bell")) {
                            if (!hasTriggeredCowbellEasterEgg) {
                                triggerEasterEgg();
                                hasTriggeredCowbellEasterEgg = true;
                            }
                        } else {
                            hasTriggeredCowbellEasterEgg = false;
                        }
                        listHandler.sortableBandNames = new ArrayList<String>();
                        listHandler.sortableBandNames = listHandler.getSortableBandNames();
                        refreshData();
                        return false;
                    }
                }

        );
    }

    private void checkForNotifcationPermMissions() {
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(staticVariables.context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.POST_NOTIFICATIONS},101);
            }
        }
    }

    private void getCountry() {

        Log.d("getCountry", "getCountry started");
        if (FileHandler70k.doesCountryFileExist() == false) {
            Log.d("getCountry", "getCountry prompting for file");
            sharedZipFile = false;
            TextView titleView = new TextView(context);

            titleView.setText(getString(R.string.verify_country));
            titleView.setPadding(20, 30, 20, 30);
            titleView.setTextSize(20F);
            titleView.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
            titleView.setGravity(Gravity.CENTER);
            titleView.setBackgroundColor(Color.parseColor("#505050"));
            titleView.setTextColor(Color.WHITE);

            // create an alert builder
            final AlertDialog.Builder builder = new AlertDialog.Builder(new ContextThemeWrapper(this, R.style.AlertDialog));
            builder.setCustomTitle(titleView);
            final View customLayout = getLayoutInflater().inflate(R.layout.ask_country, null);
            builder.setView(customLayout);
            builder.setCancelable(false);

            Button okButton = (Button) customLayout.findViewById(R.id.ok_button);
            TextView countryLabel = (TextView) customLayout.findViewById(R.id.CountryLabel);
            final AutoCompleteTextView countryChoice = (AutoCompleteTextView) customLayout.findViewById(R.id.CountryList);

            countryLabel.setText(getString(R.string.correct_if_needed));
            countryLabel.setEnabled(false);
            countryLabel.setTextSize(15F);
            countryLabel.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
            countryLabel.setGravity(Gravity.CENTER);
            countryLabel.setPadding(20, 30, 20, 30);

            Map<String, String> countryMap = CountryChoiceHandler.loadCountriesList();
            String defaultCountryText = Locale.getDefault().getCountry();

            defaultCountryText = countryMap.get(defaultCountryText);
            countryChoice.setText(defaultCountryText);

            String[] countries = countryMap.values().toArray(new String[0]);

            ArrayAdapter<String> adapter = new ArrayAdapter<String>(context,
                    android.R.layout.simple_dropdown_item_1line, countries);

            countryChoice.setAdapter(adapter);

            // create and show the alert dialog
            final AlertDialog dialog = builder.create();


            okButton.setOnClickListener(new View.OnClickListener() {
                public void onClick(View v) {
                    Map<String, String> countryMap = CountryChoiceHandler.loadCountriesList();
                    String country = String.valueOf(countryChoice.getText());
                    if (countryMap.values().contains(country) == false) {
                        String defaultCountry = countryMap.get(Locale.getDefault().getCountry());
                        countryChoice.setText(defaultCountry);
                        HelpMessageHandler.showMessage(getString(R.string.country_invalid), findViewById(R.id.showBandsView));
                    }
                    Map<String, String> countryMapRev = new HashMap<String, String>();
                    for (String countryCode : countryMap.keySet()) {
                        countryMapRev.put(countryMap.get(countryCode), countryCode);
                    }
                    if (countryMapRev.containsKey(country) == true) {

                        staticVariables.userCountry = countryMapRev.get(country);
                        FileHandler70k.saveData(staticVariables.userCountry, FileHandler70k.countryFile);
                        Log.d("getCountry", "getCountry is now set to " + staticVariables.userCountry);
                        dialog.dismiss();
                    } else {
                        String defaultCountry = countryMap.get(Locale.getDefault().getCountry());
                        countryChoice.setText(defaultCountry);
                        HelpMessageHandler.showMessage(getString(R.string.country_invalid), findViewById(R.id.showBandsView));
                    }
                }
            });

            dialog.show();

        } else {
            Log.d("getCountry", "getCountry loading from file");
            staticVariables.userCountry = FileHandler70k.loadData(FileHandler70k.countryFile);
            Log.d("getCountry", "getCountry is now set to " + staticVariables.userCountry);
            if (staticVariables.userCountry.isEmpty() == true) {
                FileHandler70k.countryFile.delete();
                this.getCountry();
            }
        }

    }

    /**
     * CLICK LISTENER FIX: Centralized method to ensure click listener is always set
     * This must be called after bandNamesList is initialized and whenever the list is refreshed
     */
    private void setupClickListener() {
        if (bandNamesList != null) {
            bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
                // argument position gives the index of item which is clicked
                public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {
                    long clickTime = System.currentTimeMillis();
                    try {
                        // SCROLL STATE STUCK FIX: If scroll state says we're scrolling but it's been a long time
                        // since the last scroll stop, the scroll state callback was likely missed. Treat as IDLE.
                        long timeSinceScrollStop = (lastScrollTime > 0) ? (clickTime - lastScrollTime) : -1;
                        boolean scrollStateStuck = (currentScrollState != AbsListView.OnScrollListener.SCROLL_STATE_IDLE) && 
                                                   (timeSinceScrollStop > SCROLL_STATE_TIMEOUT_MS);
                        boolean isScrolling = (currentScrollState != AbsListView.OnScrollListener.SCROLL_STATE_IDLE) && !scrollStateStuck;
                        
                        // If scroll state is stuck, force it back to IDLE
                        if (scrollStateStuck) {
                            Log.w("CLICK_DEBUG", "Scroll state stuck, forcing to IDLE (state: " + currentScrollState + ", timeSinceScrollStop: " + timeSinceScrollStop + "ms)");
                            currentScrollState = AbsListView.OnScrollListener.SCROLL_STATE_IDLE;
                            isScrolling = false;
                        }
                        
                        // Only block clicks if actively scrolling OR if refresh is in progress
                        if (isScrolling || isRefreshing) {
                            return;
                        }
                        
                        showClickChoices(position);
                    } catch (Exception error) {
                        Log.e("CLICK_DEBUG", "Error in onItemClick at position " + position + ": " + error.toString(), error);
                        System.exit(0);
                    }
                }
            });
        } else {
            Log.e("CLICK_DEBUG", "Cannot set OnItemClickListener - bandNamesList is null!");
        }
    }

    private void setupSwipeList() {

        List<String> sortedList = new ArrayList<>();

        if (scheduleSortedBandNames != null) {
            if (scheduleSortedBandNames.size() > 0) {
                sortedList = scheduleSortedBandNames;

            } else {
                sortedList = bandNames;
            }
        } else {
            sortedList = bandNames;
        }

        Integer screenWidth = Resources.getSystem().getDisplayMetrics().widthPixels;
        final Integer menuWidth = screenWidth / 6;

        SwipeMenuCreator creator = new SwipeMenuCreator() {

            @Override
            public void create(SwipeMenu menu) {
                //create an action that will be showed on swiping an item in the list
                SwipeMenuItem item1 = new SwipeMenuItem(
                        getApplicationContext());
                item1.setBackground(new ColorDrawable(Color.BLACK));
                item1.setWidth(menuWidth);
                item1.setIcon(staticVariables.graphicMustSeeSmall);
                item1.setTitleSize(25);
                item1.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item1);

                SwipeMenuItem item2 = new SwipeMenuItem(
                        getApplicationContext());
                item2.setBackground(new ColorDrawable(Color.BLACK));
                item2.setWidth(menuWidth);
                item2.setIcon(staticVariables.graphicMightSeeSmall);
                item2.setTitleSize(25);
                item2.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item2);

                SwipeMenuItem item3 = new SwipeMenuItem(
                        getApplicationContext());
                item3.setBackground(new ColorDrawable(Color.BLACK));
                item3.setWidth(menuWidth);
                item3.setIcon(staticVariables.graphicWontSeeSmall);
                item3.setTitleSize(25);
                item3.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item3);


                if (listHandler == null) {
                    listHandler = new mainListHandler(showBands.this);
                }
                if (listHandler.allUpcomingEvents >= 1) {

                    SwipeMenuItem item4 = new SwipeMenuItem(
                            getApplicationContext());
                    item4.setWidth(0);
                    item4.setTitleColor(Color.LTGRAY);
                    menu.addMenuItem(item4);

                    SwipeMenuItem item5 = new SwipeMenuItem(
                            getApplicationContext());
                    item5.setBackground(new ColorDrawable(Color.BLACK));
                    item5.setWidth(menuWidth);
                    item5.setIcon(staticVariables.graphicAttendedSmall);
                    item5.setTitleSize(25);
                    item5.setTitleColor(Color.LTGRAY);
                    menu.addMenuItem(item5);

                } else {
                    SwipeMenuItem item4 = new SwipeMenuItem(
                            getApplicationContext());
                    item4.setBackground(new ColorDrawable(Color.BLACK));
                    item4.setWidth(menuWidth);
                    item4.setIcon(staticVariables.graphicUnknownSeeSmall);
                    item4.setTitleSize(25);
                    item4.setTitleColor(Color.LTGRAY);
                    menu.addMenuItem(item4);
                }


            }
        };
        //set MenuCreator
        bandNamesList.setMenuCreator(creator);

        // SCROLL LISTENER FIX: Only create scroll listener once to prevent replacing it during scrolling
        // Replacing the listener while scrolling causes the IDLE callback to be missed, leaving state stuck
        if (scrollListener == null) {
            scrollListener = new AbsListView.OnScrollListener() {
                @Override
                public void onScrollStateChanged(AbsListView view, int scrollState) {
                    // CLICK FIX: Track scroll state to prevent accidental clicks when stopping scroll
                    currentScrollState = scrollState;
                    if (scrollState == AbsListView.OnScrollListener.SCROLL_STATE_IDLE) {
                        lastScrollTime = System.currentTimeMillis();
                    }
                }

                @Override
                public void onScroll(AbsListView view, int firstVisibleItem,
                                     int visibleItemCount, int totalItemCount) {

                    // ERRATIC JUMPING FIX: Only update position during normal user scrolling
                    // Don't interfere when returning from details screen or during restoration
                    if (firstVisibleItem > 0 && !returningFromDetailsScreen) {
                        // Only update if this seems like genuine user scrolling (not programmatic)
                        if (staticVariables.listPosition == 0 || Math.abs(firstVisibleItem - staticVariables.listPosition) <= 3) {
                            Log.d("Setting position", "Normal scroll - updating position to: " + firstVisibleItem);
                            staticVariables.listPosition = firstVisibleItem;
                            if (staticVariables.listPosition == 1) {
                                staticVariables.listPosition = 0;
                            }
                        }
                    }

                }
            };
        }
        
        // Always set the listener (reuse existing instance to avoid missing callbacks)
        bandNamesList.setOnScrollListener(scrollListener);

        // set SwipeListener
        bandNamesList.setOnSwipeListener(new SwipeMenuListView.OnSwipeListener() {

            @Override
            public void onSwipeStart(int position) {
                bandNamesList.smoothOpenMenu(position);
                // swipe start
            }

            @Override
            public void onSwipeEnd(int position) {
                //bandNamesList.smoothCloseMenu();
                // swipe end
            }
        });

        setupOnSwipeListener();
        
        // CLICK LISTENER FIX: Ensure click listener is set after swipe menu setup
        // The swipe menu can sometimes override or clear the click listener
        setupClickListener();

        /*
         * Sets up a SwipeRefreshLayout.OnRefreshListener that is invoked when the user
         * performs a swipe-to-refresh gesture.
         */

    }


    private void setupOnSwipeListener() {

        bandNamesList.setOnMenuItemClickListener(new SwipeMenuListView.OnMenuItemClickListener() {

            @Override
            public boolean onMenuItemClick(int position, SwipeMenu menu, int index) {

                String bandIndex = scheduleSortedBandNames.get(position);

                String bandName = getBandNameFromIndex(bandIndex);
                Long timeIndex = getTimeIndexFromIndex(bandIndex);

                listState = bandNamesList.onSaveInstanceState();

                Log.d("setupOnSwipeListener", "Index of " + index + " working on band = " + bandName + " and timeindex of " + String.valueOf(timeIndex));
                switch (index) {
                    case 0:
                        rankStore.saveBandRanking(bandName, mustSeeIcon);
                        break;

                    case 1:
                        rankStore.saveBandRanking(bandName, mightSeeIcon);
                        break;

                    case 2:
                        rankStore.saveBandRanking(bandName, wontSeeIcon);
                        break;

                    case 3:
                        rankStore.saveBandRanking(bandName, unknownIcon);
                        break;

                    case 4:

                        String message = "";
                        String attendedValue = listHandler.getAttendedListMap(position);
                        Log.d("attendedValue", "attendedValue = " + attendedValue);

                        if (timeIndex != 0) {
                            String location = listHandler.getLocation(bandName, timeIndex);
                            String rawStartTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getStartTimeString();
                            String eventType = listHandler.getEventType(bandName, timeIndex);

                            String status = attendedHandler.addShowsAttended(bandName, location, rawStartTime, eventType);
                            message = attendedHandler.setShowsAttendedStatus(status);
                        } else {
                            message = "No Show Is Associated With This Entry";
                        }
                        HelpMessageHandler.showMessage(message, findViewById(R.id.showBandsView));
                        break;
                }

                // SWIPE MENU FIX: Save position before refresh, it will be restored automatically
                saveScrollPosition();
                refreshData();

                return false;
            }
        });
    }

    /**
     * Shows profile picker dialog to switch between profiles
     */
    private void showProfilePicker() {
        Log.d("ProfilePicker", "🔍 [PICKER] Opening profile picker");
        
        SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
        List<String> profileKeys = sharingManager.getAvailablePreferenceSources();
        String activeProfile = sharingManager.getActivePreferenceSource();
        
        Log.d("ProfilePicker", "🔍 [PICKER] Found " + profileKeys.size() + " profiles");
        Log.d("ProfilePicker", "🔍 [PICKER] Active profile: " + activeProfile);
        Log.d("ProfilePicker", "🔍 [PICKER] Profile keys: " + profileKeys.toString());
        
        if (profileKeys.isEmpty()) {
            Log.e("ProfilePicker", "❌ No profiles available - this shouldn't happen!");
            Toast.makeText(this, "No profiles available", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Build display names list
        java.util.List<String> displayNames = new java.util.ArrayList<>();
        for (String profileKey : profileKeys) {
            displayNames.add(sharingManager.getDisplayName(profileKey));
        }
        
        // Create custom adapter with colored dots and checkmarks
        ProfileListAdapter adapter = new ProfileListAdapter(this, profileKeys, displayNames, activeProfile);
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(getString(R.string.select_profile));
        
        builder.setAdapter(adapter, (dialog, which) -> {
            String selectedProfileKey = profileKeys.get(which);
            String selectedDisplayName = sharingManager.getDisplayName(selectedProfileKey);
            
            if (!selectedProfileKey.equals(activeProfile)) {
                Log.d("ProfilePicker", "🔄 [PROFILE] Switching to profile: " + selectedDisplayName + " (" + selectedProfileKey + ")");
                sharingManager.setActivePreferenceSource(selectedProfileKey);
                
                // Reload profile-specific data
                rankStore.reloadForActiveProfile();
                staticVariables.attendedHandler.reloadForActiveProfile();
                Log.d("ProfilePicker", "✅ [PROFILE] Reloaded priority and attendance data for profile: " + selectedDisplayName);
                
                // Refresh the band list with new profile data
                refreshNewData();
                
                // Update header color immediately to reflect new profile
                updateHeaderColorForCurrentProfile();
                
                // Show toast message
                String nowViewingText = getString(R.string.now_viewing_profile);
                Toast.makeText(this, nowViewingText + " " + selectedDisplayName, Toast.LENGTH_SHORT).show();
            } else {
                Log.d("ProfilePicker", "🔄 [PROFILE] Profile already active");
            }
            
            dialog.dismiss();
        });
        
        builder.setNegativeButton(getString(R.string.Cancel), (dialog, which) -> dialog.cancel());
        
        AlertDialog dialog = builder.create();
        dialog.show();
        
        // Position dialog near the "51 Bands" header
        android.view.Window window = dialog.getWindow();
        if (window != null) {
            TextView headerBandCount = findViewById(R.id.headerBandCount);
            if (headerBandCount != null) {
                // Get the location of the header text
                int[] location = new int[2];
                headerBandCount.getLocationOnScreen(location);
                
                // Position dialog below the header
                android.view.WindowManager.LayoutParams params = window.getAttributes();
                params.gravity = android.view.Gravity.TOP | android.view.Gravity.START;
                params.x = location[0];
                params.y = location[1] + headerBandCount.getHeight();
                window.setAttributes(params);
            }
        }
        
        // Add long-press handler to profile items
        ListView listView = dialog.getListView();
        listView.setOnItemLongClickListener((parent, view, position, id) -> {
            String profileKey = profileKeys.get(position);
            showProfileActionMenu(profileKey);
            dialog.dismiss();
            return true;
        });
    }
    
    /**
     * Updates the header band count color to match the active profile
     */
    public void updateHeaderColorForCurrentProfile() {
        TextView bandCount = (TextView) findViewById(R.id.headerBandCount);
        if (bandCount != null) {
            SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
            String activeProfile = sharingManager.getActivePreferenceSource();
            int profileColor = ProfileColorManager.getInstance().getColorInt(activeProfile);
            bandCount.setTextColor(profileColor);
            
            String profileDisplayName = sharingManager.getDisplayName(activeProfile);
            Log.d("HeaderColor", "Updated header color for profile: " + activeProfile + " (" + profileDisplayName + "), color: " + String.format("#%06X", (0xFFFFFF & profileColor)));
        }
    }
    
    /**
     * Shows action menu for a profile (rename, change color, copy, delete)
     */
    private void showProfileActionMenu(String profileKey) {
        SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
        String displayName = sharingManager.getDisplayName(profileKey);
        boolean isDefault = "Default".equals(profileKey);
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(displayName);
        
        // Build action list based on profile type
        java.util.List<String> actions = new java.util.ArrayList<>();
        actions.add(getString(R.string.rename_entry));
        actions.add(getString(R.string.change_color));
        if (!isDefault) {
            actions.add(getString(R.string.make_settings_own));
            actions.add(getString(R.string.delete_entry));
        }
        
        // Use custom adapter to style the delete action in red (iOS style)
        ActionMenuAdapter adapter = new ActionMenuAdapter(this, actions, !isDefault);
        
        builder.setAdapter(adapter, (dialog, which) -> {
            if (which == 0) {
                // Rename
                showRenameDialog(profileKey);
            } else if (which == 1) {
                // Change Color
                showColorPicker(profileKey);
            } else if (!isDefault && which == 2) {
                // Make These Settings My Own
                confirmCopyToDefault(profileKey, displayName);
            } else if (!isDefault && which == 3) {
                // Delete
                confirmDeleteProfile(profileKey);
            }
        });
        
        builder.setNegativeButton(getString(R.string.Cancel), null);
        
        AlertDialog dialog = builder.create();
        dialog.show();
        
        // Position dialog near the "51 Bands" header for consistency
        android.view.Window window = dialog.getWindow();
        if (window != null) {
            TextView headerBandCount = findViewById(R.id.headerBandCount);
            if (headerBandCount != null) {
                // Get the location of the header text
                int[] location = new int[2];
                headerBandCount.getLocationOnScreen(location);
                
                // Position dialog below the header
                android.view.WindowManager.LayoutParams params = window.getAttributes();
                params.gravity = android.view.Gravity.TOP | android.view.Gravity.START;
                params.x = location[0];
                params.y = location[1] + headerBandCount.getHeight();
                window.setAttributes(params);
            }
        }
    }
    
    /**
     * Shows rename dialog for a profile
     */
    private void showRenameDialog(String profileKey) {
        SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
        String currentName = sharingManager.getDisplayName(profileKey);
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(getString(R.string.rename_profile));
        builder.setMessage(getString(R.string.rename_profile_message));
        
        final EditText input = new EditText(this);
        input.setText(currentName);
        input.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_CAP_WORDS);
        builder.setView(input);
        
        builder.setPositiveButton(getString(R.string.Save), (dialog, which) -> {
            String newName = input.getText().toString().trim();
            if (!newName.isEmpty()) {
                Log.d("ProfileAction", "✏️ [RENAME] Renaming '" + currentName + "' to '" + newName + "'");
                sharingManager.renameProfile(profileKey, newName);
                
                // Refresh if this is the active profile
                if (profileKey.equals(sharingManager.getActivePreferenceSource())) {
                    refreshNewData();
                }
                
                Toast.makeText(this, getString(R.string.profile_renamed), Toast.LENGTH_SHORT).show();
            }
        });
        
        builder.setNegativeButton(getString(R.string.Cancel), null);
        builder.show();
    }
    
    /**
     * Shows color picker for a profile
     */
    private void showColorPicker(String profileKey) {
        SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
        ProfileColorManager colorManager = ProfileColorManager.getInstance();
        String displayName = sharingManager.getDisplayName(profileKey);
        
        // Get available colors - matching iOS exactly
        // White is reserved for Default profile only
        String[] colorNames = {
            "Red", "Green", "Orange", "Pink", "Teal", "Yellow"
        };
        
        int[] colorValues = {
            0xFFFF3333, // Red - matches iOS #FF3333
            0xFF33E633, // Green - matches iOS #33E633
            0xFFFF9A1A, // Orange - matches iOS #FF9A1A
            0xFFFF4DB8, // Pink - matches iOS #FF4DB8
            0xFF1AE6E6, // Teal - matches iOS #1AE6E6
            0xFFFFE61A  // Yellow - matches iOS #FFE61A
        };
        
        // Create custom adapter with color sample dots
        ColorPickerAdapter adapter = new ColorPickerAdapter(this, colorNames, colorValues);
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(getString(R.string.change_profile_color));
        
        builder.setAdapter(adapter, (dialog, which) -> {
            String hexColor = String.format("#%06X", (0xFFFFFF & colorValues[which]));
            Log.d("ProfileAction", "🎨 [COLOR] Changing color of '" + displayName + "' to " + hexColor);
            colorManager.updateColor(profileKey, hexColor);
            
            // Refresh if this is the active profile
            if (profileKey.equals(sharingManager.getActivePreferenceSource())) {
                refreshNewData();
                updateHeaderColorForCurrentProfile();
            }
            
            Toast.makeText(this, getString(R.string.color_changed), Toast.LENGTH_SHORT).show();
        });
        
        builder.setNegativeButton(getString(R.string.Cancel), null);
        
        AlertDialog dialog = builder.create();
        dialog.show();
        
        // Position dialog near the "51 Bands" header for consistency
        android.view.Window window = dialog.getWindow();
        if (window != null) {
            TextView headerBandCount = findViewById(R.id.headerBandCount);
            if (headerBandCount != null) {
                // Get the location of the header text
                int[] location = new int[2];
                headerBandCount.getLocationOnScreen(location);
                
                // Position dialog below the header
                android.view.WindowManager.LayoutParams params = window.getAttributes();
                params.gravity = android.view.Gravity.TOP | android.view.Gravity.START;
                params.x = location[0];
                params.y = location[1] + headerBandCount.getHeight();
                window.setAttributes(params);
            }
        }
    }
    
    /**
     * Confirms copying a shared profile to Default (making it your own)
     */
    private void confirmCopyToDefault(String profileKey, String displayName) {
        String message = getString(R.string.make_settings_own_message).replace("{profileName}", displayName);
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(getString(R.string.make_settings_own));
        builder.setMessage(message);
        
        builder.setPositiveButton(getString(R.string.make_my_own), (dialog, which) -> {
            SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
            
            Log.d("ProfileAction", "📋 [COPY] Copying '" + displayName + "' to Default");
            
            // Copy priorities and attendance to Default
            try {
                File profileDir = new File(getFilesDir(), "profiles/" + profileKey);
                
                // **FIX: Switch to Default BEFORE copying data**
                // This ensures rankStore.saveBandRanking() saves to Default, not the shared profile
                sharingManager.setActivePreferenceSource("Default");
                rankStore.reloadForActiveProfile();
                staticVariables.attendedHandler.reloadForActiveProfile();
                Log.d("ProfileAction", "🔄 [COPY] Switched to Default profile before copying");
                
                // Copy priorities
                File prioritiesFile = new File(profileDir, "bandRankings.txt");
                if (prioritiesFile.exists()) {
                    java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(prioritiesFile));
                    String line;
                    int priorityCount = 0;
                    while ((line = br.readLine()) != null) {
                        String[] parts = line.split(":");
                        if (parts.length == 2) {
                            rankStore.saveBandRanking(parts[0], parts[1]);
                            priorityCount++;
                        }
                    }
                    br.close();
                    Log.d("ProfileAction", "✅ [COPY] Copied " + priorityCount + " band priorities to Default");
                }
                
                // Copy attendance
                File attendanceFile = new File(profileDir, "showsAttended.data");
                if (attendanceFile.exists()) {
                    java.io.FileInputStream fis = new java.io.FileInputStream(attendanceFile);
                    java.io.ObjectInputStream ois = new java.io.ObjectInputStream(fis);
                    java.util.Map<String, String> attendanceMap = (java.util.Map<String, String>) ois.readObject();
                    ois.close();
                    
                    int attendanceCount = 0;
                    for (java.util.Map.Entry<String, String> entry : attendanceMap.entrySet()) {
                        staticVariables.attendedHandler.addShowsAttended(entry.getKey(), entry.getValue());
                        attendanceCount++;
                    }
                    Log.d("ProfileAction", "✅ [COPY] Copied " + attendanceCount + " attended events to Default");
                }
                
                // Refresh UI with Default profile data
                refreshNewData();
                updateHeaderColorForCurrentProfile();
                Log.d("ProfileAction", "✅ [COPY] Successfully copied '" + displayName + "' to Default profile");
                
                Toast.makeText(this, getString(R.string.settings_copied_to_default), Toast.LENGTH_LONG).show();
                
            } catch (Exception e) {
                Log.e("ProfileAction", "❌ [COPY] Failed to copy to Default", e);
                Toast.makeText(this, "Failed to copy settings", Toast.LENGTH_SHORT).show();
            }
        });
        
        builder.setNegativeButton(getString(R.string.Cancel), null);
        builder.show();
    }
    
    /**
     * Confirms deleting a profile
     */
    private void confirmDeleteProfile(String profileKey) {
        SharedPreferencesManager sharingManager = SharedPreferencesManager.getInstance();
        String displayName = sharingManager.getDisplayName(profileKey);
        
        String message = getString(R.string.delete_profile_message).replace("{profileName}", displayName);
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(getString(R.string.delete_entry));
        builder.setMessage(message);
        
        builder.setPositiveButton(getString(R.string.Delete), (dialog, which) -> {
            Log.d("ProfileAction", "🗑️ [DELETE] Deleting profile: " + displayName);
            
            if (sharingManager.deleteImportedSet(profileKey)) {
                // If this was the active profile, we're now on Default
                refreshNewData();
                updateHeaderColorForCurrentProfile();
                Toast.makeText(this, getString(R.string.profile_deleted), Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Failed to delete profile", Toast.LENGTH_SHORT).show();
            }
        });
        
        builder.setNegativeButton(getString(R.string.Cancel), null);
        builder.show();
    }
    
    /**
     * Shows a dialog prompting for a name when exporting preferences
     */
    private void showExportNamePrompt() {
        // Get device name as default (must be final for lambda)
        final String deviceName;
        if (android.os.Build.MODEL != null && !android.os.Build.MODEL.isEmpty()) {
            deviceName = android.os.Build.MODEL;
        } else {
            deviceName = "My Device";
        }
        
        // Use dark theme for the dialog
        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DarkDialogTheme);
        builder.setTitle(R.string.name_your_share);
        builder.setMessage(R.string.name_share_message);
        
        // Set up the input field with explicit colors for dark theme
        final EditText input = new EditText(this);
        input.setHint("e.g., John's Phone");
        input.setText(deviceName);
        input.selectAll();
        input.setTextColor(android.graphics.Color.WHITE);  // White text
        input.setHintTextColor(android.graphics.Color.LTGRAY);  // Light gray hint
        input.setBackgroundColor(android.graphics.Color.parseColor("#303030"));  // Dark gray background
        input.setPadding(40, 40, 40, 40);  // Add padding for better visibility
        builder.setView(input);
        
        // Cancel button
        builder.setNegativeButton(R.string.Cancel, (dialog, which) -> dialog.cancel());
        
        // Share button
        builder.setPositiveButton(R.string.share_preferences, (dialog, which) -> {
            String shareName = input.getText().toString().trim();
            if (shareName.isEmpty()) {
                shareName = deviceName;
            }
            performExport(shareName);
        });
        
        builder.show();
    }
    
    /**
     * Performs the actual export with the given name
     */
    private void performExport(String shareName) {
        // Export preferences using SharedPreferencesManager with custom name
        Uri fileUri = SharedPreferencesManager.getInstance().exportCurrentPreferences(shareName);
        if (fileUri != null) {
            Intent sharingIntent = new Intent(Intent.ACTION_SEND);
            sharingIntent.setType("*/*");
            sharingIntent.putExtra(Intent.EXTRA_STREAM, fileUri);
            sharingIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            
            // Use share name with extension as the subject so Google Drive uses it as filename
            // Simple format: "John's Phone.70kshare"
            String fileExtension = FestivalConfig.getInstance().isMDF() ? ".mdfshare" : ".70kshare";
            String subject = shareName + fileExtension;
            sharingIntent.putExtra(Intent.EXTRA_SUBJECT, subject);
            
            String appName = FestivalConfig.getInstance().appName;
            sharingIntent.putExtra(Intent.EXTRA_TEXT, "Sharing my " + appName + " band priorities and event attendance");
            
            startActivity(Intent.createChooser(sharingIntent, getString(R.string.share_preferences)));
        } else {
            Toast.makeText(showBands.this, R.string.failed_to_export_preferences, Toast.LENGTH_SHORT).show();
        }
    }

    public void shareMenuPrompt() {

        sharedZipFile = false;
        TextView titleView = new TextView(context);
        titleView.setText(getString(R.string.ShareTitle));
        titleView.setPadding(20, 30, 20, 30);
        titleView.setTextSize(20F);
        titleView.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
        titleView.setGravity(Gravity.CENTER);
        titleView.setBackgroundColor(Color.parseColor("#505050"));
        titleView.setTextColor(Color.WHITE);

        // create an alert builder
        final AlertDialog.Builder builder = new AlertDialog.Builder(new ContextThemeWrapper(this, R.style.AlertDialog));
        builder.setCustomTitle(titleView);

        // set the custom layout
        final View customLayout = getLayoutInflater().inflate(R.layout.prompt_show_dialog, null);
        builder.setView(customLayout);

        Button shareImportableData = (Button) customLayout.findViewById(R.id.GoToDetails);
        Button shareBandReport = (Button) customLayout.findViewById(R.id.AttendedAll);
        Button shareEventReport = (Button) customLayout.findViewById(R.id.AttendeSome);
        Button na1 = (Button) customLayout.findViewById(R.id.AttendeNone);
        Button na2 = (Button) customLayout.findViewById(R.id.Disable);

        shareImportableData.setText(getString(R.string.ShareImportableData));
        shareBandReport.setText(getString(R.string.ShareBandChoices));
        shareEventReport.setText(getString(R.string.ShareShowChoices));
        na1.setVisibility(View.INVISIBLE);
        na2.setVisibility(View.INVISIBLE);
        
        // Check if Share Event Report should be enabled
        boolean hasScheduleData = BandInfo.scheduleRecords != null && !BandInfo.scheduleRecords.isEmpty();
        boolean hasAttendanceData = hasUserAttendanceData();
        
        if (!hasScheduleData || !hasAttendanceData) {
            shareEventReport.setEnabled(false);
            shareEventReport.setAlpha(0.5f); // Visual indication that it's disabled
        }

        // add a button
        builder.setPositiveButton(getString(R.string.Cancel), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {

            }
        });

        // create and show the alert dialog
        final AlertDialog dialog = builder.create();


        // NEW: Share Importable Band/Event Data - First option
        shareImportableData.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                dialog.dismiss();
                showExportNamePrompt();
            }
        });

        // Share Band Report - Second option
        shareBandReport.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                dialog.dismiss();
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");

                String shareBody = buildShareMessage();
                String subject = FestivalConfig.getInstance().appName + " " + getString(R.string.Choices);

                sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, subject);
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, shareBody);
                startActivity(Intent.createChooser(sharingIntent, "Share via"));
            }
        });

        // Share Event Report - Third option
        shareEventReport.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                dialog.dismiss();
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");

                showsAttendedReport reportHandler = new showsAttendedReport();
                reportHandler.assembleReport();
                String shareBody = reportHandler.buildMessage();
                String subject = FestivalConfig.getInstance().appName + " - " + getString(R.string.EventsAttended);

                sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, subject);
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, shareBody);
                startActivity(Intent.createChooser(sharingIntent, "Share via"));
            }
        });

        dialog.show();

        if (sharedZipFile == true) {
            zipFile.delete();
        }
    }

    /**
     * Updates the profile switcher button with current profile name and color
     */
    private void updateProfileSwitcherButton() {
        Button profileButton = (Button) findViewById(R.id.profileSwitcher);
        if (profileButton == null) return;
        
        SharedPreferencesManager manager = SharedPreferencesManager.getInstance();
        String activeProfileKey = manager.getActivePreferenceSource();
        String displayName = manager.getDisplayName(activeProfileKey);
        
        // Get profile color
        int color = ProfileColorManager.getInstance().getColorInt(activeProfileKey);
        
        // Update button
        profileButton.setText(displayName);
        profileButton.setTextColor(color);
        
        Log.d(TAG, "Updated profile switcher button: " + displayName);
    }

    private void showNotification() {

        String messageString = "";
        Intent intent = getIntent();
        if (intent.hasExtra("messageString") == true) {
            messageString = intent.getStringExtra("messageString");
            Log.d(TAG, notificationTag + " Using messageString");

        } else if (intent.hasExtra("messageText") == true) {
            messageString = intent.getStringExtra("messageText");
            Log.d(TAG, notificationTag + " Using messageText");

        } else if (MyFcmListenerService.messageString != null) {
            messageString = MyFcmListenerService.messageString;
            Log.d(TAG, notificationTag + " MyFcmListenerService.messageString");
            MyFcmListenerService.messageString = null;
        }

        Log.d(TAG, notificationTag + " in showNotification");

        if (!messageString.isEmpty()) {
            Log.d(TAG, notificationTag + " messageString has value");
            if (messageString.contains(".intent.")) {
                Log.d(TAG, notificationTag + " messageString passed");
                MyFcmListenerService.messageString = null;

            } else {
                Log.d(TAG, notificationTag + " messageString displayed");
                new AlertDialog.Builder(this)
                        .setTitle(FestivalConfig.getInstance().appName + " Message")
                        .setMessage(messageString)
                        .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                // continue with delete
                            }
                        })
                        .setIcon(android.R.drawable.ic_dialog_alert)
                        .show();
                intent.putExtra("messageString", "");
            }
        }
    }

    public void setupButtons() {

        // Profile switcher button
        Button profileSwitcher = (Button) findViewById(R.id.profileSwitcher);
        if (profileSwitcher != null) {
            updateProfileSwitcherButton();
            profileSwitcher.setOnClickListener(v -> showProfilePicker());
        }

        ImageButton preferencesButton = (ImageButton) findViewById(R.id.preferences);

        preferencesButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
        Intent showPreferences = new Intent(showBands.this, preferenceLayout.class);
        // Update activity reference for progress indicator if downloads are running
        ForegroundDownloadManager.setCurrentActivity(showBands.this);
        startActivityForResult(showPreferences, 1);
            }
        });


        Button shareButton = (Button) findViewById(R.id.shareButton);
        shareButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");

                shareMenuPrompt();

            }
        });

        // Download Report Button
        Button downloadReportButton = (Button) findViewById(R.id.downloadReportButton);
        downloadReportButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                // Set flag to prevent main activity refresh when returning from stats page
                returningFromStatsPage = true;
                
                // Show WebView immediately - it will handle loading internally
                Intent webViewIntent = new Intent(showBands.this, WebViewActivity.class);
                webViewIntent.putExtra("isStatsPage", true);
                startActivity(webViewIntent);
                
                // No need to fetch URL here - WebViewActivity will handle it
                Log.d("showBands", "Stats button clicked - WebViewActivity will handle loading");
            }
        });

    }

    private String readCachedFile(String filePath) throws IOException {
        StringBuilder content = new StringBuilder();
        BufferedReader reader = new BufferedReader(new InputStreamReader(new java.io.FileInputStream(filePath), "UTF-8"));
        String line;
        while ((line = reader.readLine()) != null) {
            content.append(line).append("\n");
        }
        reader.close();
        return content.toString();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode == RESULT_OK) {
            ///Intent refresh = new Intent(this, showBands.class);
            //startActivity(refresh);
            //finish();
        }
    }

    private String buildShareMessage() {
        Log.d("buildShareMessage", "🔍 [SHARE_REPORT] ========== STARTING MUST/MIGHT REPORT ==========");
        
        // CRITICAL: Always use "Default" profile for sharing reports
        // Save current active profile
        SharedPreferencesManager profileManager = SharedPreferencesManager.getInstance();
        String originalProfile = profileManager.getActivePreferenceSource();
        Log.d("buildShareMessage", "🔍 [SHARE_REPORT] Original active profile: '" + originalProfile + "'");
        
        // Temporarily switch to "Default" profile
        if (!"Default".equals(originalProfile)) {
            Log.d("buildShareMessage", "🔍 [SHARE_REPORT] Temporarily switching to 'Default' profile for report generation");
            profileManager.setActivePreferenceSource("Default");
            // Force rankStore to reload for Default profile
            rankStore.reloadForActiveProfile();
        } else {
            Log.d("buildShareMessage", "🔍 [SHARE_REPORT] Already on 'Default' profile, no switch needed");
        }

        String message = "🤘 " + staticVariables.context.getString(R.string.HereAreMy) + " " + FestivalConfig.getInstance().appName + " " + getString(R.string.Choices) + "\n\n";
        
        // Collect must-see and might-see bands
        java.util.List<String> mustSeeBands = new java.util.ArrayList<>();
        java.util.List<String> mightSeeBands = new java.util.ArrayList<>();

        for (String band : bandNames) {
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(mustSeeIcon)) {
                mustSeeBands.add(band);
            } else if (bandRank.equals(mightSeeIcon)) {
                mightSeeBands.add(band);
            }
        }
        
        Log.d("buildShareMessage", "🔍 [SHARE_REPORT] Found " + mustSeeBands.size() + " Must See bands and " + mightSeeBands.size() + " Might See bands");
        
        // Format must-see section with localized text
        message += "🟢 " + getString(R.string.MustSeeBands) + " (" + mustSeeBands.size() + "):\n";
        if (!mustSeeBands.isEmpty()) {
            for (int i = 0; i < mustSeeBands.size(); i++) {
                message += "• " + mustSeeBands.get(i);
                if (i < mustSeeBands.size() - 1) {
                    message += " ";
                }
            }
            message += "\n";
        }
        
        // Format might-see section with localized text
        message += "\n🟡 " + getString(R.string.MightSeeBands) + " (" + mightSeeBands.size() + "):\n";
        if (!mightSeeBands.isEmpty()) {
            for (int i = 0; i < mightSeeBands.size(); i++) {
                message += "• " + mightSeeBands.get(i);
                if (i < mightSeeBands.size() - 1) {
                    message += " ";
                }
            }
            message += "\n";
        }

        message += "\n\n" + FestivalConfig.getInstance().shareUrl;
        
        // CRITICAL: Restore original profile
        if (!"Default".equals(originalProfile)) {
            Log.d("buildShareMessage", "🔍 [SHARE_REPORT] Restoring original profile: '" + originalProfile + "'");
            profileManager.setActivePreferenceSource(originalProfile);
            // Force rankStore to reload for original profile
            rankStore.reloadForActiveProfile();
            Log.d("buildShareMessage", "🔍 [SHARE_REPORT] Profile restored and rankStore reloaded");
        }
        
        Log.d("buildShareMessage", "🔍 [SHARE_REPORT] ========== REPORT COMPLETE ==========");
        return message;
    }
    
    /**
     * Checks if the user has indicated attendance for at least one event
     * @return true if user has attendance data, false otherwise
     */
    private boolean hasUserAttendanceData() {
        try {
            showsAttended attendedHandler = new showsAttended();
            attendedHandler.loadShowsAttended();
            Map<String, String> showsAttendedArray = attendedHandler.getShowsAttended();
            
            if (showsAttendedArray == null || showsAttendedArray.isEmpty()) {
                return false;
            }
            
            // Check if user has indicated attendance for any event in current year
            for (String index : showsAttendedArray.keySet()) {
                String[] indexArray = index.split(":");
                if (indexArray.length >= 6) {
                    Integer eventYear = Integer.valueOf(indexArray[5]);
                    String attendanceStatus = showsAttendedArray.get(index);
                    
                    if (eventYear.equals(staticVariables.eventYear) && 
                        (attendanceStatus.equals(staticVariables.sawAllStatus) || 
                         attendanceStatus.equals(staticVariables.sawSomeStatus))) {
                        return true;
                    }
                }
            }
            return false;
        } catch (Exception e) {
            Log.e("hasUserAttendanceData", "Error checking attendance data", e);
            return false;
        }
    }

    public void populateBandList() {

        bandNamesList = (SwipeMenuListView) findViewById(R.id.bandNames);
        
        // CLICK LISTENER FIX: Ensure click listener is set when list is re-initialized
        setupClickListener();

        // OFFLINE FIX: Check for cached files directly for faster offline loading
        // This ensures events appear quickly even when offline
        boolean hasCachedData = FileHandler70k.bandInfo.exists() && FileHandler70k.schedule.exists();
        
        if (fileDownloaded == false && !hasCachedData) {
            // No cached data - need to download
            refreshNewData();
        } else {
            // We have cached data (either fileDownloaded=true or files exist) - load from cache
            reloadData();
        }

        setupSwipeList();
    }


    public void refreshNewData() {
        refreshNewData(false);  // Default: check for data changes
    }
    
    public void refreshNewData(boolean forceRefresh) {

        RelativeLayout showBandLayout = (RelativeLayout) findViewById(R.id.showBandsView);
        showBandLayout.invalidate();
        showBandLayout.requestLayout();

        Log.d("refreshNewData", "refreshNewData - 1 (forceRefresh: " + forceRefresh + ")");

        executeAsyncListViewLoader();

        // REMOVED: AsyncNotesLoader should only run during background operations
        // Individual note loading happens in details screen only
        // Bulk note loading happens when app goes to background only

        Log.d("refreshNewData", "refreshNewData - 2");
        scheduleAlertHandler alerts = new scheduleAlertHandler();
        alerts.execute();

        // Combined image list regeneration is now handled automatically when band/schedule data changes
        // This prevents unnecessary regeneration when data hasn't actually changed
        Log.d("refreshNewData", "Combined image list will be regenerated only if underlying data changed");

        Log.d("refreshNewData", "refreshNewData - 3");
        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("DisplayListData", "finished display header " + headerText);

        Log.d("refreshNewData", "refreshNewData - 4");
        if (headerText.equals(FestivalConfig.getInstance().festivalName)) {
            Log.d("DisplayListData", "running extra refresh");
            
            // UNIVERSAL SCROLL PRESERVATION: Save position before refresh to make it transparent
            if (bandNamesList != null && staticVariables.savedScrollPosition < 0) {
                saveScrollPosition();
                Log.d("ScrollPosition", "Universal scroll preservation activated for extra refresh");
            }
            displayBandData();
            // REMOVED: Redundant position restoration - displayBandData already handles position preservation
            // restoreScrollPosition();
        }
        Log.d("refreshNewData", "refreshNewData - 5");
    }

    @Override
    public void onUserLeaveHint() {
        super.onUserLeaveHint();
        Log.d("BackgroundFlag", "onUserLeaveHint() called - user trying to leave app");
        
        // No longer showing blocking dialog - downloads continue in background with minimal floating indicator
        Log.d("BackgroundFlag", "Downloads continue in background (if any) with minimal indicator");
    }
    
    @Override
    public void onStop() {
        super.onStop();
        
        Log.d("BackgroundFlag", "onStop() called - using proper Application-level background detection");
        
        // Background detection is now handled properly at the Application level using ActivityLifecycleCallbacks
        // This prevents inappropriate bulk loading during internal navigation (main list ↔ details screen)
        // and only starts bulk loading when the ENTIRE app goes to background
        
        // Firebase reporting is now handled by ImageDownloadService (foreground service)
        // which is started by Bands70k.onActivityStopped() when app goes to background
        // This ensures network access works on Android 15+
        Log.d("BackgroundFlag", "Firebase reporting will be handled by BackgroundNetworkService");
    }

    private void reloadData() {

        // OFFLINE FIX: Check for cached files directly, not just fileDownloaded flag
        // This ensures events load quickly even when offline
        boolean hasCachedData = FileHandler70k.bandInfo.exists() && FileHandler70k.schedule.exists();
        
        if (fileDownloaded == true || hasCachedData) {
            Log.d("BandData Loaded", "from Cache");

            Log.d("reloadData", "reloadData - 1");
            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            Log.d("reloadData", "reloadData - 2");
            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            Log.d("reloadData", "reloadData - 3");
            // ERRATIC JUMPING FIX: Remove duplicate position restoration from reloadData
            // Position restoration is now handled centrally in displayBandDataWithSchedule()

            Log.d("reloadData", "reloadData - 4");
            scheduleAlertHandler alerts = new scheduleAlertHandler();
            alerts.execute();

        }
    }


    private String getBandNameFromIndex(String index) {

        Log.d("showBands.getBandNameFromIndex", "🔍 Processing index: " + index);
        String[] indexSplit = index.split(":");

        if (indexSplit.length >= 2) {
            // Use timestamp detection to identify format
            boolean firstPartIsTimestamp = isTimestamp(indexSplit[0]);
            boolean secondPartIsTimestamp = isTimestamp(indexSplit[1]);
            
            String result;
            if (firstPartIsTimestamp && !secondPartIsTimestamp) {
                // Format: "timeIndex:bandName" -> return second part (band name)
                result = indexSplit[1];
                Log.d("showBands.getBandNameFromIndex", "🔍 TIME FORMAT detected, returning band name: '" + result + "'");
            } else if (!firstPartIsTimestamp && secondPartIsTimestamp) {
                // Format: "bandName:timeIndex" -> return first part (band name)
                result = indexSplit[0];
                Log.d("showBands.getBandNameFromIndex", "🔍 ALPHA FORMAT detected, returning band name: '" + result + "'");
            } else {
                // Fallback: use sort mode
                if (staticVariables.preferences.getSortByTime()) {
                    result = indexSplit[1]; // Time mode: second part is band name
                    Log.d("showBands.getBandNameFromIndex", "🔍 FALLBACK TIME MODE, returning band name: '" + result + "'");
                } else {
                    result = indexSplit[0]; // Alphabetical mode: first part is band name
                    Log.d("showBands.getBandNameFromIndex", "🔍 FALLBACK ALPHA MODE, returning band name: '" + result + "'");
                }
            }
            return result;
        } else if (indexSplit.length == 1) {
            // Single part, assume it's the band name
            Log.d("showBands.getBandNameFromIndex", "🔍 SINGLE PART, returning: '" + indexSplit[0] + "'");
            return indexSplit[0];
        }
        
        Log.d("showBands.getBandNameFromIndex", "🔍 FALLBACK, returning original index: '" + index + "'");
        return index;
    }

    private Long getTimeIndexFromIndex(String index) {

        Log.d("showBands.getTimeIndexFromIndex", "🔍 Processing index: " + index);
        String[] indexSplit = index.split(":");

        if (indexSplit.length >= 2) {
            // Use timestamp detection to identify format
            boolean firstPartIsTimestamp = isTimestamp(indexSplit[0]);
            boolean secondPartIsTimestamp = isTimestamp(indexSplit[1]);
            
            try {
                Long result;
                if (firstPartIsTimestamp && !secondPartIsTimestamp) {
                    // Format: "timeIndex:bandName" -> return first part (time index)
                    result = Long.valueOf(indexSplit[0]);
                    Log.d("showBands.getTimeIndexFromIndex", "🔍 TIME FORMAT detected, returning time index: " + result);
                } else if (!firstPartIsTimestamp && secondPartIsTimestamp) {
                    // Format: "bandName:timeIndex" -> return second part (time index)
                    result = Long.valueOf(indexSplit[1]);
                    Log.d("showBands.getTimeIndexFromIndex", "🔍 ALPHA FORMAT detected, returning time index: " + result);
                } else {
                    // Fallback: use sort mode
                    if (staticVariables.preferences.getSortByTime()) {
                        result = Long.valueOf(indexSplit[0]); // Time mode: first part is time index
                        Log.d("showBands.getTimeIndexFromIndex", "🔍 FALLBACK TIME MODE, returning time index: " + result);
                    } else {
                        result = Long.valueOf(indexSplit[1]); // Alphabetical mode: second part is time index
                        Log.d("showBands.getTimeIndexFromIndex", "🔍 FALLBACK ALPHA MODE, returning time index: " + result);
                    }
                }
                return result;
            } catch (NumberFormatException e) {
                Log.e("showBands.getTimeIndexFromIndex", "🚨 Failed to parse time index from: " + index, e);
                return Long.valueOf(0);
            }
        }
        
        Log.d("showBands.getTimeIndexFromIndex", "🔍 FALLBACK, returning 0");
        return Long.valueOf(0);
    }
    
    /**
     * Helper method to detect if a string represents a timestamp
     * Timestamps are typically very large numbers (> 1000000)
     * Band names like "1914" will be < 1000000
     */
    private boolean isTimestamp(String value) {
        try {
            Long number = Long.valueOf(value);
            // Timestamps are typically very large numbers (> 1000000)
            // Band names like "1914" will be < 1000000
            boolean result = number > 1000000;
            Log.d("showBands.isTimestamp", "🔢 isTimestamp('" + value + "') -> number=" + number + ", result=" + result);
            return result;
        } catch (NumberFormatException e) {
            Log.d("showBands.isTimestamp", "🔢 isTimestamp('" + value + "') -> NOT A NUMBER, result=false");
            return false;
        }
    }

    private void displayBandData() {

        Log.d("DisplayListData", "starting display ");
        
        // Check view mode preference to determine which display method to use
        boolean showScheduleView = staticVariables.preferences.getShowScheduleView();
        Log.d("VIEW_MODE_DEBUG", "🔍 displayBandData: getShowScheduleView() = " + showScheduleView);
        
        if (showScheduleView) {
            Log.d("VIEW_MODE_DEBUG", "🔍 displayBandData: Calling displayBandDataWithSchedule()");
            displayBandDataWithSchedule();
        } else {
            Log.d("VIEW_MODE_DEBUG", "🔍 displayBandData: Calling displayBandDataWithoutSchedule()");
            displayBandDataWithoutSchedule();
        }
    }

    private void displayBandDataWithoutSchedule() {
        
        // CLICK FIX: Mark refresh as in progress to prevent clicks during adapter updates
        refreshCounter++;
        lastRefreshStartTime = System.currentTimeMillis();
        isRefreshing = true;
        
        Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Starting bands-only display");
        
        // TRANSPARENT REFRESH: Save center item (band name) for position preservation
        String centerBandName = null;
        if (bandNamesList != null && adapter != null && adapter.getCount() > 0) {
            int firstVisible = bandNamesList.getFirstVisiblePosition();
            int lastVisible = bandNamesList.getLastVisiblePosition();
            int centerIndex = (firstVisible + lastVisible) / 2;
            if (centerIndex >= 0 && centerIndex < adapter.getCount()) {
                try {
                    bandListItem centerItem = adapter.getItem(centerIndex);
                    if (centerItem != null) {
                        centerBandName = centerItem.getBandName();
                        Log.d("TransparentRefresh", "Saved center band for position: " + centerBandName + " at index " + centerIndex);
                    }
                } catch (Exception e) {
                    Log.w("TransparentRefresh", "Error getting center item: " + e.getMessage());
                }
            }
        }
        
        // TRANSPARENT REFRESH: Build new list first, then replace atomically to avoid flash
        // This prevents the adapter from going to 0 items, which causes flashing
        BandInfo bandInfoNames = new BandInfo();
        bandNames = bandInfoNames.getBandNames();
        
        // Initialize listHandler if not already initialized
        if (listHandler == null) {
            listHandler = new mainListHandler(showBands.this);
        }
        
        // FLASHING FIX: Build the new list of items FIRST (without modifying adapter)
        List<bandListItem> newItems = new ArrayList<>();
        List<String> newBandNamesIndex = new ArrayList<>();
        List<String> newScheduleSortedBandNames = new ArrayList<>();
        
        if (bandNames.size() == 0) {
            String emptyDataMessage = getResources().getString(R.string.waiting_for_data);
            bandListItem bandItem = new bandListItem(emptyDataMessage);
            newItems.add(bandItem);
        } else {
            // Sort bands alphabetically for bands-only view
            Collections.sort(bandNames);
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Processing " + bandNames.size() + " bands");
            
            Integer counter = 0;
            for (String bandName : bandNames) {
                bandListItem bandItem = new bandListItem(bandName);
                bandItem.setRankImg(rankStore.getRankImageForBand(bandName));
                newItems.add(bandItem);
                // CRITICAL FIX: Add band name to both lists to keep in sync with adapter
                newBandNamesIndex.add(bandName);
                newScheduleSortedBandNames.add(bandName);
                counter++;
            }
            
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Built " + counter + " items in new list");
        }
        
        // FLASHING FIX: Now replace adapter data atomically (adapter never goes to 0 items)
        if (adapter == null) {
            adapter = new bandListView(getApplicationContext(), R.layout.bandlist70k);
            Log.d("VIEW_MODE_DEBUG", "🎵 Created new adapter");
        }
        
        // FLASHING FIX: Only replace if data actually changed
        // This prevents unnecessary clears that cause flashing
        boolean dataChanged = adapter.replaceAll(newItems);
        
        if (dataChanged) {
            // Update the index lists atomically
            listHandler.bandNamesIndex.clear();
            listHandler.bandNamesIndex.addAll(newBandNamesIndex);
            scheduleSortedBandNames.clear();
            scheduleSortedBandNames.addAll(newScheduleSortedBandNames);
            
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Replaced adapter with " + adapter.getCount() + " items");
            
            // TRANSPARENT REFRESH: Immediately notify adapter of change to minimize flash
            // Do this BEFORE any other operations to ensure ListView sees the new data immediately
            if (bandNamesList != null) {
                // FLASHING FIX: Disable animations and notify immediately
                boolean animationsEnabled = bandNamesList.getLayoutAnimation() != null;
                if (animationsEnabled) {
                    bandNamesList.setLayoutAnimation(null);
                }
                
                // CRITICAL: Notify immediately after replaceAll to minimize flash window
                // With stable IDs, Android should preserve scroll position
                if (bandNamesList.getAdapter() != adapter) {
                    bandNamesList.setAdapter(adapter);
                    Log.d("VIEW_MODE_DEBUG", "🎵 SUCCESS: Adapter set for first time");
                } else {
                    // Immediately notify - this is critical to minimize flash
                    adapter.notifyDataSetChanged();
                    Log.d("VIEW_MODE_DEBUG", "🎵 SUCCESS: Adapter notified immediately after replaceAll");
                }
                
                // FLASHING FIX: Re-enable animations after update completes
                if (animationsEnabled) {
                    bandNamesList.post(new Runnable() {
                        @Override
                        public void run() {
                            // Animations will be restored naturally if needed
                        }
                    });
                }
                
                // TRANSPARENT REFRESH: Restore to center item if we saved one
                if (centerBandName != null) {
                final String targetBandName = centerBandName;
                final int savedScrollPosition = staticVariables.savedScrollPosition;
                final int savedScrollOffset = staticVariables.savedScrollOffset;
                bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        boolean found = false;
                        // Find the band in the new adapter and scroll to it
                        for (int i = 0; i < adapter.getCount(); i++) {
                            try {
                                bandListItem item = adapter.getItem(i);
                                if (item != null && targetBandName.equals(item.getBandName())) {
                                    // Scroll to center this item on screen
                                    int screenHeight = bandNamesList.getHeight();
                                    int itemHeight = (screenHeight > 0) ? screenHeight / 3 : 0; // Approximate item height
                                    bandNamesList.setSelectionFromTop(i, itemHeight);
                                    Log.d("TransparentRefresh", "Restored center band: " + targetBandName + " at index " + i);
                                    found = true;
                                    break;
                                }
                            } catch (Exception e) {
                                Log.w("TransparentRefresh", "Error finding band: " + e.getMessage());
                            }
                        }
                        // FALLBACK: If center band not found, use saved scroll position
                        if (!found && savedScrollPosition >= 0 && savedScrollPosition < adapter.getCount()) {
                            bandNamesList.setSelectionFromTop(savedScrollPosition, savedScrollOffset);
                            Log.d("TransparentRefresh", "Center band not found, using fallback scroll position: " + savedScrollPosition);
                        }
                        // Reset returningFromDetailsScreen flag after position restoration completes
                        if (returningFromDetailsScreen) {
                            returningFromDetailsScreen = false;
                            Log.d("ListPosition", "Reset returningFromDetailsScreen flag after position restoration");
                        }
                    }
                });
            } else if (staticVariables.savedScrollPosition >= 0) {
                // FALLBACK: If no center band was saved, use saved scroll position directly
                final int savedScrollPosition = staticVariables.savedScrollPosition;
                final int savedScrollOffset = staticVariables.savedScrollOffset;
                bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        if (adapter != null && savedScrollPosition < adapter.getCount()) {
                            bandNamesList.setSelectionFromTop(savedScrollPosition, savedScrollOffset);
                            Log.d("TransparentRefresh", "Using saved scroll position (no center band): " + savedScrollPosition);
                        }
                        // Reset returningFromDetailsScreen flag after position restoration completes
                        if (returningFromDetailsScreen) {
                            returningFromDetailsScreen = false;
                            Log.d("ListPosition", "Reset returningFromDetailsScreen flag after position restoration");
                        }
                    }
                });
            } else {
                // No position to restore, but still reset flag
                if (returningFromDetailsScreen) {
                    bandNamesList.post(new Runnable() {
                        @Override
                        public void run() {
                            returningFromDetailsScreen = false;
                            Log.d("ListPosition", "Reset returningFromDetailsScreen flag (no position to restore)");
                        }
                    });
                }
            }
            } else {
                Log.w("VIEW_MODE_DEBUG", "🚨 WARNING: bandNamesList is null, deferring adapter setup");
                // Store adapter for later when UI is initialized
                this.adapter = adapter;
            }
        } else {
            // Data unchanged - no refresh needed, no flash!
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Data unchanged, skipping refresh to avoid flash");
        }
        
        // Setup swipe and filters
        setupSwipeList();
        FilterButtonHandler filterButtonHandle = new FilterButtonHandler();
        filterButtonHandle.setUpFiltersButton(this);
        
        // Update band count display
        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Finished display " + adapter.getCount() + " bands");
        
        // CLICK FIX: Mark refresh as complete after a short delay to allow UI to settle
        final long refreshStartTime = lastRefreshStartTime;
        bandNamesList.postDelayed(new Runnable() {
            @Override
            public void run() {
                refreshCounter = Math.max(0, refreshCounter - 1); // Decrement but don't go negative
                isRefreshing = (refreshCounter > 0); // Only false if no refreshes in progress
                lastRefreshEndTime = System.currentTimeMillis();
            }
        }, 100); // Small delay to ensure adapter update is complete
    }

    private void displayBandDataWithSchedule() {

        // CLICK FIX: Mark refresh as in progress to prevent clicks during adapter updates
        refreshCounter++;
        lastRefreshStartTime = System.currentTimeMillis();
        isRefreshing = true;

        Log.d("ListPosition", "displayBandDataWithSchedule called - returningFromDetailsScreen: " + returningFromDetailsScreen + ", savedPosition: " + staticVariables.listPosition);
        
        // TRANSPARENT REFRESH: Save center item (band name) for position preservation
        String centerBandName = null;
        if (bandNamesList != null && adapter != null && adapter.getCount() > 0) {
            int firstVisible = bandNamesList.getFirstVisiblePosition();
            int lastVisible = bandNamesList.getLastVisiblePosition();
            int centerIndex = (firstVisible + lastVisible) / 2;
            if (centerIndex >= 0 && centerIndex < adapter.getCount()) {
                try {
                    bandListItem centerItem = adapter.getItem(centerIndex);
                    if (centerItem != null) {
                        centerBandName = centerItem.getBandName();
                        Log.d("TransparentRefresh", "Saved center band for position: " + centerBandName + " at index " + centerIndex);
                    }
                } catch (Exception e) {
                    Log.w("TransparentRefresh", "Error getting center item: " + e.getMessage());
                }
            }
        }
        
        // FLASHING FIX: Build new list first, then replace atomically to avoid flash
        // This prevents the adapter from going to 0 items, which causes flashing
        BandInfo bandInfoNames = new BandInfo();
        bandNames = bandInfoNames.getBandNames();

        if (bandNames.size() == 0) {
            String emptyDataMessage = "";
            if (unfilteredBandCount > 1) {
                Log.d("populateBandInfo", "BandList has issues 1");
                //emptyDataMessage = getResources().getString(R.string.data_filter_issue);
            } else {
                emptyDataMessage = getResources().getString(R.string.waiting_for_data);
                bandNames.add(emptyDataMessage);
            }

        }

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 4");
        rankedBandNames = bandInfo.getRankedBandNames(bandNames);
        rankStore.getBandRankings();

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 5");
        listHandler = new mainListHandler(showBands.this);


        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 6");
        
        // CRITICAL FIX: Force fresh data processing in alphabetical mode to prevent stale cache
        if (!staticVariables.preferences.getSortByTime()) {
            Log.d("DisplayListData", "🔧 CRITICAL: Alphabetical mode detected, clearing cache to force fresh data");
            listHandler.clearCache();
            scheduleSortedBandNames = listHandler.populateBandInfo(bandInfo, bandNames);
            Log.d("CRITICAL_DEBUG", "🚨 SHOWBANDS: populateBandInfo() returned " + scheduleSortedBandNames.size() + " items");
        } else {
            scheduleSortedBandNames = listHandler.getSortableBandNames();
            Log.d("CRITICAL_DEBUG", "🚨 SHOWBANDS: getSortableBandNames() returned " + scheduleSortedBandNames.size() + " items");
            Log.d("CRITICAL_DEBUG", "🚨 SHOWBANDS: Current sortByTime preference = " + staticVariables.preferences.getSortByTime());

            if (scheduleSortedBandNames.isEmpty() == true) {
                Log.d("CRITICAL_DEBUG", "🚨 SHOWBANDS: scheduleSortedBandNames is empty, calling populateBandInfo()");
                scheduleSortedBandNames = listHandler.populateBandInfo(bandInfo, bandNames);
                Log.d("CRITICAL_DEBUG", "🚨 SHOWBANDS: populateBandInfo() returned " + scheduleSortedBandNames.size() + " items");
            } else {
                Log.d("CRITICAL_DEBUG", "🚨 SHOWBANDS: scheduleSortedBandNames already has " + scheduleSortedBandNames.size() + " items, skipping populateBandInfo()");
            }
        }

        if (scheduleSortedBandNames.get(0).contains(":") == false) {
            //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 7");
            //Log.d("DisplayListData", "starting file download ");
            //bandInfoNames.DownloadBandFile();
            bandNames = bandInfoNames.getBandNames();
            Log.d("DisplayListData", "starting file download, done ");
        }

        // FLASHING FIX: Build new list of items FIRST (without modifying adapter)
        List<bandListItem> newItems = new ArrayList<>();
        List<String> newBandNamesIndex = new ArrayList<>();
        
        Integer counter = 0;
        attendedHandler.loadShowsAttended();
        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 8");
        
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: About to iterate over scheduleSortedBandNames");
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: scheduleSortedBandNames.size() = " + scheduleSortedBandNames.size());
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: scheduleSortedBandNames = " + (scheduleSortedBandNames != null ? "NOT NULL" : "NULL"));
        
        for (String bandIndex : scheduleSortedBandNames) {

            Log.d("WorkingOnScheduleIndex", "WorkingOnScheduleIndex " + bandIndex + "-" + String.valueOf(staticVariables.eventYear));

            String[] indexSplit = bandIndex.split(":");

            if (indexSplit.length == 2) {

                String bandName = getBandNameFromIndex(bandIndex);
                Long timeIndex = getTimeIndexFromIndex(bandIndex);

                // Ensure eventYear is set before using it
                if (staticVariables.eventYear == 0) {
                    staticVariables.ensureEventYearIsSet();
                }
                String eventYear = String.valueOf(staticVariables.eventYear);

                bandListItem bandItem = new bandListItem(bandName);
                loadOnceStopper = false;

                if (timeIndex > 0) {

                    if (bandName == null || timeIndex == null || BandInfo.scheduleRecords == null) {
                        return;
                    }
                    if (BandInfo.scheduleRecords.containsKey(bandName) == false) {
                        Log.d("WorkingOnScheduleIndex", "WorkingOnScheduleIndex No bandname " + bandName + " - " + timeIndex);
                        bandName = bandNames.get(0);
                        if (BandInfo.scheduleRecords.containsKey(bandName) == false) {
                            Log.d("WorkingOnScheduleIndex", "WorkingOnScheduleIndex No bandname 1 " + bandName + " - " + timeIndex);
                        }
                    }
                    if (BandInfo.scheduleRecords.get(bandName) == null){
                        return;
                    }
                    if (BandInfo.scheduleRecords.get(bandName).scheduleByTime.containsKey(timeIndex) == false) {
                        return;
                    }

                    Log.d("WorkingOnScheduleIndex", "WorkingOnScheduleIndex No bandname 1 " + bandName + " - " + timeIndex);
                    if (BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex) != null) {

                        scheduleHandler scheduleHandle = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex);
                        String location = scheduleHandle.getShowLocation();
                        String startTime = scheduleHandle.getStartTimeString();
                        String endTime = scheduleHandle.getEndTimeString();
                        String eventType = scheduleHandle.getShowType();
                        String day = scheduleHandle.getShowDay();
                        String note = scheduleHandle.getShowNotes();

                        String attendedIcon = attendedHandler.getShowAttendedIcon(bandName, location, startTime, eventType, eventYear);
                        Log.d("ShowsAttended", "attendedIcon is " + attendedIcon + " for " + bandName + "-" + location + "-" + "-" + startTime);
                        if (day.contains("Day")) {
                            day = " " + day.replaceAll("Day", "");
                        }

                        if (day.contains("/") == false) {
                            day = day + "  ";
                        }

                        Log.d("PopulatingDayValue", "Day = " + day);
                        startTime = dateTimeFormatter.formatScheduleTime(startTime);
                        endTime = dateTimeFormatter.formatScheduleTime(endTime);

                        bandItem.setLocationColor(iconResolve.getLocationColor(location));

                        if (venueLocation.containsKey(location)) {
                            location += " " + venueLocation.get(location);
                        }

                        Log.d("settingEvent", " for " + bandName + " note of " + note);
                        bandItem.setEventNote(note);

                        Integer eventImage = iconResolve.getEventIcon(eventType, bandName);

                        bandItem.setLocation(location);
                        bandItem.setStartTime(startTime);
                        bandItem.setEndTime(endTime);
                        bandItem.setDay(day);

                        if (eventImage != 0) {
                            bandItem.setEventTypeImage(eventImage);
                        }

                        bandItem.setAttendedImage(iconResolve.getAttendedIcon(attendedIcon));

                        Log.d("settingEvent", " for " + bandName + " eventType of " + eventType + "returned image " + eventImage);
                    }
                }

                bandItem.setRankImg(rankStore.getRankImageForBand(bandName));
                counter = counter + 1;
                newItems.add(bandItem);
                // CRITICAL FIX: Add band name to index to keep in sync with adapter
                newBandNamesIndex.add(bandName);
            } else {

                bandIndex = bandIndex.replaceAll(":", "");
                bandListItem bandItem = new bandListItem(bandIndex);
                bandItem.setRankImg(rankStore.getRankImageForBand(bandIndex));
                counter = counter + 1;
                newItems.add(bandItem);
                // CRITICAL FIX: Add band name to index to keep in sync with adapter
                newBandNamesIndex.add(bandIndex);
            }

        }
        
        // Handle empty data case
        if (counter == 0) {
            String emptyDataMessage = "";
            if (unfilteredBandCount > 1) {
                Log.d("populateBandInfo", "BandList has issues 2");
                emptyDataMessage = getResources().getString(R.string.data_filter_issue);
            } else {
                emptyDataMessage = getResources().getString(R.string.waiting_for_data);
            }
            bandListItem bandItem = new bandListItem(emptyDataMessage);
            newItems.add(bandItem);
        }
        
        // FLASHING FIX: Now replace adapter data atomically (adapter never goes to 0 items)
        if (adapter == null) {
            adapter = new bandListView(getApplicationContext(), R.layout.bandlist70k);
            Log.d("DisplayListData", "🔧 Created new adapter");
        }
        
        // FLASHING FIX: Only replace if data actually changed
        // This prevents unnecessary clears that cause flashing
        boolean dataChanged = adapter.replaceAll(newItems);
        
        if (dataChanged) {
            // Update the index list atomically
            listHandler.bandNamesIndex.clear();
            listHandler.bandNamesIndex.addAll(newBandNamesIndex);
            
            Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: Replaced adapter with " + adapter.getCount() + " items");
            
            // TRANSPARENT REFRESH: Immediately notify adapter of change to minimize flash
            // Do this BEFORE any other operations to ensure ListView sees the new data immediately
            if (bandNamesList != null) {
                // FLASHING FIX: Disable animations and notify immediately
                boolean animationsEnabled = bandNamesList.getLayoutAnimation() != null;
                if (animationsEnabled) {
                    bandNamesList.setLayoutAnimation(null);
                }
                
                // CRITICAL: Notify immediately after replaceAll to minimize flash window
                // With stable IDs, Android should preserve scroll position
                if (bandNamesList.getAdapter() != adapter) {
                    bandNamesList.setAdapter(adapter);
                    Log.d("DisplayListData", "🔧 SUCCESS: Adapter set for first time");
                } else {
                    // Immediately notify - this is critical to minimize flash
                    adapter.notifyDataSetChanged();
                    Log.d("DisplayListData", "🔧 SUCCESS: Adapter notified immediately after replaceAll");
                }
            
            // FLASHING FIX: Re-enable animations after update completes
            if (animationsEnabled) {
                bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        // Animations will be restored naturally if needed
                    }
                });
            }
            
            // TRANSPARENT REFRESH: Restore to center item if we saved one
            if (centerBandName != null) {
                final String targetBandName = centerBandName;
                final int savedScrollPosition = staticVariables.savedScrollPosition;
                final int savedScrollOffset = staticVariables.savedScrollOffset;
                bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        boolean found = false;
                        // Find the band in the new adapter and scroll to it
                        for (int i = 0; i < adapter.getCount(); i++) {
                            try {
                                bandListItem item = adapter.getItem(i);
                                if (item != null && targetBandName.equals(item.getBandName())) {
                                    // Scroll to center this item on screen
                                    int screenHeight = bandNamesList.getHeight();
                                    int itemHeight = (screenHeight > 0) ? screenHeight / 3 : 0; // Approximate item height
                                    bandNamesList.setSelectionFromTop(i, itemHeight);
                                    Log.d("TransparentRefresh", "Restored center band: " + targetBandName + " at index " + i);
                                    found = true;
                                    break;
                                }
                            } catch (Exception e) {
                                Log.w("TransparentRefresh", "Error finding band: " + e.getMessage());
                            }
                        }
                        // FALLBACK: If center band not found, use saved scroll position
                        if (!found && savedScrollPosition >= 0 && savedScrollPosition < adapter.getCount()) {
                            bandNamesList.setSelectionFromTop(savedScrollPosition, savedScrollOffset);
                            Log.d("TransparentRefresh", "Center band not found, using fallback scroll position: " + savedScrollPosition);
                        }
                        // Reset returningFromDetailsScreen flag after position restoration completes
                        if (returningFromDetailsScreen) {
                            returningFromDetailsScreen = false;
                            Log.d("ListPosition", "Reset returningFromDetailsScreen flag after position restoration");
                        }
                    }
                });
            } else if (staticVariables.savedScrollPosition >= 0) {
                // FALLBACK: If no center band was saved, use saved scroll position directly
                final int savedScrollPosition = staticVariables.savedScrollPosition;
                final int savedScrollOffset = staticVariables.savedScrollOffset;
                bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        if (adapter != null && savedScrollPosition < adapter.getCount()) {
                            bandNamesList.setSelectionFromTop(savedScrollPosition, savedScrollOffset);
                            Log.d("TransparentRefresh", "Using saved scroll position (no center band): " + savedScrollPosition);
                        }
                        // Reset returningFromDetailsScreen flag after position restoration completes
                        if (returningFromDetailsScreen) {
                            returningFromDetailsScreen = false;
                            Log.d("ListPosition", "Reset returningFromDetailsScreen flag after position restoration");
                        }
                    }
                });
            } else {
                // No position to restore, but still reset flag
                if (returningFromDetailsScreen) {
                    bandNamesList.post(new Runnable() {
                        @Override
                        public void run() {
                            returningFromDetailsScreen = false;
                            Log.d("ListPosition", "Reset returningFromDetailsScreen flag (no position to restore)");
                        }
                    });
                }
            }
            } else {
                Log.w("DisplayListData", "🚨 WARNING: bandNamesList is null, deferring adapter setup");
                // Store adapter for later when UI is initialized
                this.adapter = adapter;
            }
        } else {
            // Data unchanged - no refresh needed, no flash!
            Log.d("DisplayListData", "🔧 displayBandDataWithSchedule: Data unchanged, skipping refresh to avoid flash");
        }

        //swip stuff
        setupSwipeList();

        FilterButtonHandler filterButtonHandle = new FilterButtonHandler();
        //filterButtonHandle.onCreate(null);
        filterButtonHandle.setUpFiltersButton(this);

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 9");
        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("DisplayListData", "finished display " + String.valueOf(counter) + '-' + headerText);
        
        // CLICK FIX: Mark refresh as complete after a short delay to allow UI to settle
        final long refreshStartTime = lastRefreshStartTime;
        if (bandNamesList != null) {
            bandNamesList.postDelayed(new Runnable() {
                @Override
                public void run() {
                    refreshCounter = Math.max(0, refreshCounter - 1); // Decrement but don't go negative
                    isRefreshing = (refreshCounter > 0); // Only false if no refreshes in progress
                    lastRefreshEndTime = System.currentTimeMillis();
                }
            }, 100); // Small delay to ensure adapter update is complete
        } else {
            refreshCounter = Math.max(0, refreshCounter - 1);
            isRefreshing = (refreshCounter > 0);
            lastRefreshEndTime = System.currentTimeMillis();
        }
        
        // JUMPING FIX: Position restoration is no longer needed here
        // We now prevent the refresh entirely when returning from details screen
        // This eliminates the jumping because the list never gets rebuilt
    }



    /**
     * Check if data files have changed since last refresh
     * Uses OR logic: returns true if ANY data source has changed
     * @return true if any data file, profile, or filters have changed, false if all unchanged
     */
    private boolean hasDataChanged() {
        boolean changed = false;
        boolean isFirstCheck = !dataTimestampPrefs.contains("data_initialized");
        
        // PROFILE CHANGE CHECK: Check if active profile has changed (OR operation)
        String currentProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        String lastProfile = dataTimestampPrefs.getString("active_profile", null);
        if (isFirstCheck || lastProfile == null || !currentProfile.equals(lastProfile)) {
            Log.d("DataChangeCheck", "Active profile " + (isFirstCheck ? "initialized" : "changed") + ": '" + (lastProfile != null ? lastProfile : "null") + "' → '" + currentProfile + "'");
            changed = true;  // OR operation: any change sets changed=true
            dataTimestampPrefs.edit().putString("active_profile", currentProfile).apply();
        }
        
        // FILTER CHANGE CHECK: Check if any filter preferences have changed (OR operation)
        if (staticVariables.preferences != null) {
            // Build a filter state string to compare
            String currentFilterState = buildFilterStateString();
            String lastFilterState = dataTimestampPrefs.getString("filter_state", null);
            
            if (isFirstCheck || lastFilterState == null || !currentFilterState.equals(lastFilterState)) {
                Log.d("DataChangeCheck", "Filters " + (isFirstCheck ? "initialized" : "changed") + 
                      (lastFilterState != null ? ": '" + lastFilterState.substring(0, Math.min(50, lastFilterState.length())) + "...' → '" + currentFilterState.substring(0, Math.min(50, currentFilterState.length())) + "...'" : ""));
                changed = true;  // OR operation: any change sets changed=true
                dataTimestampPrefs.edit().putString("filter_state", currentFilterState).apply();
            }
        }
        
        // Check bandInfo CSV using content hash (OR operation: any change sets changed=true)
        if (FileHandler70k.bandInfo.exists()) {
            CacheHashManager hashManager = CacheHashManager.getInstance();
            String currentHash = hashManager.calculateFileHash(FileHandler70k.bandInfo);
            String lastHash = dataTimestampPrefs.getString("bandInfo_hash", null);
            
            if (currentHash != null) {
                if (isFirstCheck || lastHash == null || !currentHash.equals(lastHash)) {
                    Log.d("DataChangeCheck", "bandInfo.csv " + (isFirstCheck ? "initialized" : "content changed") + 
                          (lastHash != null ? " (hash: " + currentHash.substring(0, 8) + " vs " + lastHash.substring(0, 8) + ")" : ""));
                    changed = true;  // OR operation: any change sets changed=true
                    dataTimestampPrefs.edit().putString("bandInfo_hash", currentHash).apply();
                } else {
                    Log.d("DataChangeCheck", "bandInfo.csv content unchanged (hash: " + currentHash.substring(0, 8) + ")");
                }
            } else {
                // Fallback to timestamp if hash calculation fails
                long currentTime = FileHandler70k.bandInfo.lastModified();
                long lastTime = dataTimestampPrefs.getLong("bandInfo_timestamp", 0);
                if (isFirstCheck || currentTime != lastTime) {
                    Log.d("DataChangeCheck", "bandInfo.csv " + (isFirstCheck ? "initialized" : "changed") + " (using timestamp fallback): " + currentTime + " vs " + lastTime);
                    changed = true;
                    dataTimestampPrefs.edit().putLong("bandInfo_timestamp", currentTime).apply();
                }
            }
        } else {
            if (dataTimestampPrefs.contains("bandInfo_hash") || dataTimestampPrefs.contains("bandInfo_timestamp")) {
                Log.d("DataChangeCheck", "bandInfo.csv deleted");
                changed = true;
                dataTimestampPrefs.edit().remove("bandInfo_hash").remove("bandInfo_timestamp").apply();
            }
        }
        
        // Check schedule CSV using content hash (OR operation: any change sets changed=true)
        if (FileHandler70k.schedule.exists()) {
            CacheHashManager hashManager = CacheHashManager.getInstance();
            String currentHash = hashManager.calculateFileHash(FileHandler70k.schedule);
            String lastHash = dataTimestampPrefs.getString("schedule_hash", null);
            
            if (currentHash != null) {
                if (isFirstCheck || lastHash == null || !currentHash.equals(lastHash)) {
                    Log.d("DataChangeCheck", "schedule.csv " + (isFirstCheck ? "initialized" : "content changed") + 
                          (lastHash != null ? " (hash: " + currentHash.substring(0, 8) + " vs " + lastHash.substring(0, 8) + ")" : ""));
                    changed = true;  // OR operation: any change sets changed=true
                    dataTimestampPrefs.edit().putString("schedule_hash", currentHash).apply();
                } else {
                    Log.d("DataChangeCheck", "schedule.csv content unchanged (hash: " + currentHash.substring(0, 8) + ")");
                }
            } else {
                // Fallback to timestamp if hash calculation fails
                long currentTime = FileHandler70k.schedule.lastModified();
                long lastTime = dataTimestampPrefs.getLong("schedule_timestamp", 0);
                if (isFirstCheck || currentTime != lastTime) {
                    Log.d("DataChangeCheck", "schedule.csv " + (isFirstCheck ? "initialized" : "changed") + " (using timestamp fallback): " + currentTime + " vs " + lastTime);
                    changed = true;
                    dataTimestampPrefs.edit().putLong("schedule_timestamp", currentTime).apply();
                }
            }
        } else {
            if (dataTimestampPrefs.contains("schedule_hash") || dataTimestampPrefs.contains("schedule_timestamp")) {
                Log.d("DataChangeCheck", "schedule.csv deleted");
                changed = true;  // OR operation: any change sets changed=true
                dataTimestampPrefs.edit().remove("schedule_hash").remove("schedule_timestamp").apply();
            }
        }
        
        // Check band rankings using content hash (OR operation: any change sets changed=true)
        if (FileHandler70k.bandRankings.exists()) {
            CacheHashManager hashManager = CacheHashManager.getInstance();
            String currentHash = hashManager.calculateFileHash(FileHandler70k.bandRankings);
            String lastHash = dataTimestampPrefs.getString("bandRankings_hash", null);
            
            if (currentHash != null) {
                if (isFirstCheck || lastHash == null || !currentHash.equals(lastHash)) {
                    Log.d("DataChangeCheck", "bandRankings.txt " + (isFirstCheck ? "initialized" : "content changed") + 
                          (lastHash != null ? " (hash: " + currentHash.substring(0, 8) + " vs " + lastHash.substring(0, 8) + ")" : ""));
                    changed = true;  // OR operation: any change sets changed=true
                    dataTimestampPrefs.edit().putString("bandRankings_hash", currentHash).apply();
                } else {
                    Log.d("DataChangeCheck", "bandRankings.txt content unchanged (hash: " + currentHash.substring(0, 8) + ")");
                }
            } else {
                // Fallback to timestamp if hash calculation fails
                long currentTime = FileHandler70k.bandRankings.lastModified();
                long lastTime = dataTimestampPrefs.getLong("bandRankings_timestamp", 0);
                if (isFirstCheck || currentTime != lastTime) {
                    Log.d("DataChangeCheck", "bandRankings.txt " + (isFirstCheck ? "initialized" : "changed") + " (using timestamp fallback): " + currentTime + " vs " + lastTime);
                    changed = true;
                    dataTimestampPrefs.edit().putLong("bandRankings_timestamp", currentTime).apply();
                }
            }
        } else {
            if (dataTimestampPrefs.contains("bandRankings_hash") || dataTimestampPrefs.contains("bandRankings_timestamp")) {
                Log.d("DataChangeCheck", "bandRankings.txt deleted");
                changed = true;  // OR operation: any change sets changed=true
                dataTimestampPrefs.edit().remove("bandRankings_hash").remove("bandRankings_timestamp").apply();
            }
        }
        
        // Check attendance data using content hash (not timestamp) to avoid false positives
        // The file gets rewritten with same content, causing timestamp changes without content changes
        if (FileHandler70k.showsAttendedFile.exists()) {
            CacheHashManager hashManager = CacheHashManager.getInstance();
            String currentHash = hashManager.calculateFileHash(FileHandler70k.showsAttendedFile);
            String lastHash = dataTimestampPrefs.getString("showsAttended_hash", null);
            
            if (currentHash != null) {
                if (isFirstCheck || lastHash == null || !currentHash.equals(lastHash)) {
                    Log.d("DataChangeCheck", "showsAttended.data " + (isFirstCheck ? "initialized" : "content changed") + 
                          (lastHash != null ? " (hash: " + currentHash.substring(0, 8) + " vs " + lastHash.substring(0, 8) + ")" : ""));
                    changed = true;  // OR operation: any change sets changed=true
                    dataTimestampPrefs.edit().putString("showsAttended_hash", currentHash).apply();
                } else {
                    Log.d("DataChangeCheck", "showsAttended.data content unchanged (hash: " + currentHash.substring(0, 8) + ")");
                }
            } else {
                // Fallback to timestamp if hash calculation fails
                long currentTime = FileHandler70k.showsAttendedFile.lastModified();
                long lastTime = dataTimestampPrefs.getLong("showsAttended_timestamp", 0);
                if (isFirstCheck || currentTime != lastTime) {
                    Log.d("DataChangeCheck", "showsAttended.data " + (isFirstCheck ? "initialized" : "changed") + " (using timestamp fallback): " + currentTime + " vs " + lastTime);
                    changed = true;
                    dataTimestampPrefs.edit().putLong("showsAttended_timestamp", currentTime).apply();
                }
            }
        } else {
            if (dataTimestampPrefs.contains("showsAttended_hash") || dataTimestampPrefs.contains("showsAttended_timestamp")) {
                Log.d("DataChangeCheck", "showsAttended.data deleted");
                changed = true;  // OR operation: any change sets changed=true
                dataTimestampPrefs.edit().remove("showsAttended_hash").remove("showsAttended_timestamp").apply();
            }
        }
        
        // Mark as initialized after first check
        if (isFirstCheck && changed) {
            dataTimestampPrefs.edit().putBoolean("data_initialized", true).apply();
            Log.d("DataChangeCheck", "Data timestamps initialized");
        }
        
        // OR LOGIC: Returns true if ANY data source changed (profile, filters, CSV files, rankings, or attendance)
        // Returns false only if ALL data sources are unchanged
        if (!changed) {
            Log.d("DataChangeCheck", "No data changes detected (all sources unchanged: profile, filters, files) - skipping refresh");
        } else {
            Log.d("DataChangeCheck", "Data change detected (OR operation: at least one source changed - profile, filters, or files) - refresh will occur");
        }
        
        return changed;
    }
    
    /**
     * Build a string representation of all filter states for change detection
     * @return A string containing all filter preference values
     */
    private String buildFilterStateString() {
        if (staticVariables.preferences == null) {
            return "";
        }
        
        StringBuilder filterState = new StringBuilder();
        filterState.append("must:").append(staticVariables.preferences.getShowMust());
        filterState.append("|might:").append(staticVariables.preferences.getShowMight());
        filterState.append("|wont:").append(staticVariables.preferences.getShowWont());
        filterState.append("|unknown:").append(staticVariables.preferences.getShowUnknown());
        filterState.append("|willAttend:").append(staticVariables.preferences.getShowWillAttend());
        filterState.append("|hideExpired:").append(staticVariables.preferences.getHideExpiredEvents());
        filterState.append("|pool:").append(staticVariables.preferences.getShowPoolShows());
        filterState.append("|theater:").append(staticVariables.preferences.getShowTheaterShows());
        filterState.append("|rink:").append(staticVariables.preferences.getShowRinkShows());
        filterState.append("|lounge:").append(staticVariables.preferences.getShowLoungeShows());
        filterState.append("|other:").append(staticVariables.preferences.getShowOtherShows());
        filterState.append("|special:").append(staticVariables.preferences.getShowSpecialEvents());
        filterState.append("|meetGreet:").append(staticVariables.preferences.getShowMeetAndGreet());
        filterState.append("|clinic:").append(staticVariables.preferences.getShowClinicEvents());
        filterState.append("|albumListen:").append(staticVariables.preferences.getShowAlbumListen());
        filterState.append("|unofficial:").append(staticVariables.preferences.getShowUnofficalEvents());
        filterState.append("|sortByTime:").append(staticVariables.preferences.getSortByTime());
        filterState.append("|scheduleView:").append(staticVariables.preferences.getShowScheduleView());
        
        return filterState.toString();
    }
    
    /**
     * Check if data is currently displayed in the list
     * Returns true if adapter has items (and not just "waiting for data" message)
     * Returns false if no adapter, empty adapter, or only "waiting for data" is shown
     */
    private boolean hasDataDisplayed() {
        // Check if adapter exists and has real data (not just "waiting for data")
        if (adapter != null && adapter.getCount() > 0) {
            // Check if the first item is not "waiting for data"
            try {
                bandListItem firstItem = adapter.getItem(0);
                if (firstItem != null) {
                    String firstBandName = firstItem.getBandName();
                    String waitingMessage = getResources().getString(R.string.waiting_for_data);
                    if (firstBandName != null && !firstBandName.equals(waitingMessage)) {
                        Log.d("DataDisplayCheck", "Data is displayed: adapter has " + adapter.getCount() + " items, first item: " + firstBandName);
                        return true;
                    }
                }
            } catch (Exception e) {
                Log.w("DataDisplayCheck", "Error checking adapter item: " + e.getMessage());
            }
        }
        
        // Check if listHandler has data (more reliable than ListView count)
        if (listHandler != null && listHandler.bandNamesIndex != null && listHandler.bandNamesIndex.size() > 0) {
            Log.d("DataDisplayCheck", "Data is displayed: listHandler has " + listHandler.bandNamesIndex.size() + " bands");
            return true;
        }
        
        // Don't check ListView count - it might have "waiting for data" items
        Log.d("DataDisplayCheck", "No data displayed - adapter: " + (adapter != null ? adapter.getCount() : "null") + 
              ", listHandler: " + (listHandler != null && listHandler.bandNamesIndex != null ? listHandler.bandNamesIndex.size() : "null"));
        return false;
    }
    
    /**
     * Update all data timestamps to current values without checking for changes
     * Used when forcing a refresh (e.g., pull-to-refresh) to prevent false positives on next check
     */
    private void updateDataTimestamps() {
        // Update profile timestamp
        String currentProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        dataTimestampPrefs.edit().putString("active_profile", currentProfile).apply();
        
        // Update filter state to prevent false positives on next check
        if (staticVariables.preferences != null) {
            String currentFilterState = buildFilterStateString();
            dataTimestampPrefs.edit().putString("filter_state", currentFilterState).apply();
        }
        
        // Update file hashes if files exist (using content hashing for all files)
        CacheHashManager hashManager = CacheHashManager.getInstance();
        
        if (FileHandler70k.bandInfo.exists()) {
            String currentHash = hashManager.calculateFileHash(FileHandler70k.bandInfo);
            if (currentHash != null) {
                dataTimestampPrefs.edit().putString("bandInfo_hash", currentHash).apply();
            } else {
                // Fallback to timestamp if hash calculation fails
                dataTimestampPrefs.edit().putLong("bandInfo_timestamp", FileHandler70k.bandInfo.lastModified()).apply();
            }
        }
        if (FileHandler70k.schedule.exists()) {
            String currentHash = hashManager.calculateFileHash(FileHandler70k.schedule);
            if (currentHash != null) {
                dataTimestampPrefs.edit().putString("schedule_hash", currentHash).apply();
            } else {
                // Fallback to timestamp if hash calculation fails
                dataTimestampPrefs.edit().putLong("schedule_timestamp", FileHandler70k.schedule.lastModified()).apply();
            }
        }
        if (FileHandler70k.bandRankings.exists()) {
            String currentHash = hashManager.calculateFileHash(FileHandler70k.bandRankings);
            if (currentHash != null) {
                dataTimestampPrefs.edit().putString("bandRankings_hash", currentHash).apply();
            } else {
                // Fallback to timestamp if hash calculation fails
                dataTimestampPrefs.edit().putLong("bandRankings_timestamp", FileHandler70k.bandRankings.lastModified()).apply();
            }
        }
        if (FileHandler70k.showsAttendedFile.exists()) {
            String currentHash = hashManager.calculateFileHash(FileHandler70k.showsAttendedFile);
            if (currentHash != null) {
                dataTimestampPrefs.edit().putString("showsAttended_hash", currentHash).apply();
            } else {
                // Fallback to timestamp if hash calculation fails
                dataTimestampPrefs.edit().putLong("showsAttended_timestamp", FileHandler70k.showsAttendedFile.lastModified()).apply();
            }
        }
        
        Log.d("DataChangeCheck", "Updated all data hashes after forced refresh");
    }
    
    /**
     * Save the current scroll position of the list
     * NOTE: This is now primarily for legacy support. With notifyDataSetChanged(),
     * Android automatically preserves scroll position, so this is less critical.
     */
    private void saveScrollPosition() {
        if (bandNamesList != null) {
            staticVariables.savedScrollPosition = bandNamesList.getFirstVisiblePosition();
            View firstView = bandNamesList.getChildAt(0);
            staticVariables.savedScrollOffset = (firstView == null) ? 0 : firstView.getTop();
            Log.d("ScrollPosition", "Saved scroll position: " + staticVariables.savedScrollPosition + ", offset: " + staticVariables.savedScrollOffset);
            // REMOVED: List visibility hiding - not needed with notifyDataSetChanged()
        }
    }
    
    /**
     * Restore the saved scroll position of the list
     * NOTE: With notifyDataSetChanged(), Android preserves scroll position automatically.
     * This method is now primarily for legacy support or edge cases.
     */
    private void restoreScrollPosition() {
        if (bandNamesList != null && staticVariables.savedScrollPosition >= 0) {
            // DETAILS RETURN FIX: Add slight delay for smoother restoration from showDetails
            int delay = returningFromDetailsScreen ? 100 : 0;
            
            bandNamesList.postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (adapter != null && staticVariables.savedScrollPosition < adapter.getCount()) {
                        bandNamesList.setSelectionFromTop(staticVariables.savedScrollPosition, staticVariables.savedScrollOffset);
                        Log.d("ScrollPosition", "Restored scroll position: " + staticVariables.savedScrollPosition + ", offset: " + staticVariables.savedScrollOffset);
                        
                        // REMOVED: List visibility and animation handling - not needed with notifyDataSetChanged()
                        
                        // Clear saved position after restore
                        staticVariables.savedScrollPosition = -1;
                        staticVariables.savedScrollOffset = 0;
                    }
                }
            }, delay);
        }
    }

    public void refreshData() {
        refreshData(false);  // Default: check for data changes
    }
    
    public void refreshData(boolean forceRefresh) {

        Log.d("DisplayListData", "called from refreshData (forceRefresh: " + forceRefresh + ")");
        
        // UNIVERSAL SCROLL PRESERVATION: Always save position before any refresh to make it transparent
        if (bandNamesList != null && staticVariables.savedScrollPosition < 0) {
            // Only save if we don't already have a saved position
            saveScrollPosition();
            Log.d("ScrollPosition", "Universal scroll preservation activated for refreshData()");
        }
        
        // INTERMITTENT POSITION LOSS FIX: Save current position before refresh (legacy support)
        if (bandNamesList != null && staticVariables.listPosition == 0) {
            int currentPosition = bandNamesList.getFirstVisiblePosition();
            if (currentPosition > 0) {
                staticVariables.listPosition = currentPosition;
                Log.d("ListPosition", "Saved current scroll position before refresh: " + currentPosition);
            }
        }
        
        displayBandData();
        
        // CRITICAL FIX: Ensure list is visible after refresh, especially on first install
        // This is important because saveScrollPosition() might have hidden it
        if (bandNamesList != null) {
            // If no scroll position was saved (first install), make sure list is visible immediately
            if (staticVariables.savedScrollPosition < 0) {
                bandNamesList.setVisibility(View.VISIBLE);
                bandNamesList.requestLayout();
                Log.d("FRESH_INSTALL", "Ensuring list is visible after refreshData (no saved position)");
            } else {
                // Restore scroll position if it was saved
                restoreScrollPosition();
            }
        }
        
        // ANIMATION FIX: Safety fallback - ensure list is visible even if restore fails
        bandNamesList.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (bandNamesList.getVisibility() != View.VISIBLE) {
                    Log.d("AnimationFix", "Safety fallback: Making list visible");
                    bandNamesList.setVisibility(View.VISIBLE);
                }
                
                // BLANK LIST FIX: Additional safety check for adapter
                // TRANSPARENT REFRESH FIX: Use notifyDataSetChanged() instead of setAdapter() to preserve scroll position
                if (adapter != null && adapter.getCount() > 0 && bandNamesList.getCount() == 0) {
                    Log.d("BlankListFix", "Detected blank list with valid adapter data - refreshing adapter");
                    // TRANSPARENT REFRESH: Only set adapter if not already set, otherwise use notifyDataSetChanged()
                    if (bandNamesList.getAdapter() != adapter) {
                        bandNamesList.setAdapter(adapter);
                    } else {
                        adapter.notifyDataSetChanged();
                    }
                    bandNamesList.invalidateViews();
                }
            }
        }, 500); // 500ms timeout

    }

    @Override
    public void onBackPressed() {
        if (dialog != null){
            if (dialog.isShowing()){
                dialog.dismiss();
            }
        }
        moveTaskToBack(true);
    }


    public void toogleDisplayFilter(String value) {

        Intent showBands = new Intent(com.Bands70k.showBands.this, com.Bands70k.showBands.class);
        startActivity(showBands);
        finish();

    }

    @Override
    protected void onDestroy() {
        Log.d("Saving Data", "Saving state during Destroy");
        onPause();
        super.onDestroy();

    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        
        // Save scroll position for lifecycle events (orientation change, system kill, etc.)
        if (bandNamesList != null) {
            int scrollPosition = bandNamesList.getFirstVisiblePosition();
            View firstView = bandNamesList.getChildAt(0);
            int scrollOffset = (firstView == null) ? 0 : firstView.getTop();
            
            outState.putInt("scroll_position", scrollPosition);
            outState.putInt("scroll_offset", scrollOffset);
            outState.putInt("list_position", staticVariables.listPosition);
            
            // Also save list state
            listState = bandNamesList.onSaveInstanceState();
            if (listState != null) {
                outState.putParcelable("list_state", listState);
            }
            
            Log.d("ScrollPosition", "Saved scroll position in Bundle: " + scrollPosition + ", offset: " + scrollOffset);
        }
    }
    
    @Override
    protected void onRestoreInstanceState(Bundle savedInstanceState) {
        super.onRestoreInstanceState(savedInstanceState);
        
        // Restore scroll position from Bundle
        if (savedInstanceState != null && bandNamesList != null) {
            int scrollPosition = savedInstanceState.getInt("scroll_position", -1);
            int scrollOffset = savedInstanceState.getInt("scroll_offset", 0);
            int listPosition = savedInstanceState.getInt("list_position", 0);
            
            if (scrollPosition >= 0) {
                staticVariables.savedScrollPosition = scrollPosition;
                staticVariables.savedScrollOffset = scrollOffset;
                staticVariables.listPosition = listPosition;
                
                // Restore list state if available
                Parcelable savedListState = savedInstanceState.getParcelable("list_state");
                if (savedListState != null) {
                    listState = savedListState;
                }
                
                Log.d("ScrollPosition", "Restored scroll position from Bundle: " + scrollPosition + ", offset: " + scrollOffset);
                
                // Restore position after layout is complete
                bandNamesList.post(new Runnable() {
                    @Override
                    public void run() {
                        if (staticVariables.savedScrollPosition >= 0 && adapter != null && 
                            staticVariables.savedScrollPosition < adapter.getCount()) {
                            bandNamesList.setSelectionFromTop(staticVariables.savedScrollPosition, staticVariables.savedScrollOffset);
                            Log.d("ScrollPosition", "Applied restored scroll position: " + staticVariables.savedScrollPosition);
                        }
                    }
                });
            }
        }
    }

    @Override
    public void onPause() {
        if (dialog != null){
            if (dialog.isShowing()){
                dialog.dismiss();
            }
        }
        listState = bandNamesList.onSaveInstanceState();
        Log.d("Saving Data", "Saving state during Pause");
        super.onPause();

        // Background loading will be started in onStop() when app truly goes to background

        scheduleAlertHandler alerts = new scheduleAlertHandler();
        alerts.execute();

        staticVariables.preferences.saveData();
        LocalBroadcastManager.getInstance(this).unregisterReceiver(mRegistrationBroadcastReceiver);
        isReceiverRegistered = false;
        loadOnceStopper = false;
    }

    @Override
    public void onStart() {
        super.onStart();
        showNotification();

    }

    private void registerReceiver() {
        if (!isReceiverRegistered) {
            LocalBroadcastManager.getInstance(this).registerReceiver(mRegistrationBroadcastReceiver,
                    new IntentFilter(REGISTRATION_COMPLETE));
            isReceiverRegistered = true;
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Log.d(TAG, "🔥🔥🔥 onNewIntent called 🔥🔥🔥");
        setIntent(intent);  // CRITICAL: Update the activity's intent
        handleIncomingIntent(intent);
    }
    
    /**
     * Handles incoming intent for shared preference file imports
     */
    private void handleIncomingIntent(Intent intent) {
        Log.d(TAG, "🔥 handleIncomingIntent called 🔥");
        
        if (intent == null) {
            Log.d(TAG, "🔥 Intent is NULL");
            return;
        }
        
        String action = intent.getAction();
        Uri data = intent.getData();
        
        if (!Intent.ACTION_VIEW.equals(action) || data == null) {
            Log.d(TAG, "🔥 Not ACTION_VIEW or data is null - Action:" + action + ", Data:" + data);
            return;
        }
        
        String scheme = data.getScheme();
        String path = data.getPath();
        
        Log.d(TAG, "🔥🔥🔥 handleIncomingIntent - Action: " + action + ", Data: " + data + ", Scheme: " + scheme + ", Path: " + path);
        Log.d(TAG, "🔥 ACTION_VIEW detected with data");
        
        // Get the actual filename from the URI
        String filename = getFilenameFromUri(data);
        Log.d(TAG, "🔥🔥🔥 Resolved filename: " + filename + " 🔥🔥🔥");
        
        // Only accept the appropriate file extension for this app variant
        String expectedExtension = FestivalConfig.getInstance().isMDF() ? ".mdfshare" : ".70kshare";
        
        if (filename != null && filename.endsWith(expectedExtension)) {
            Log.d(TAG, "🔥🔥🔥 Detected shared preference file: " + filename + " 🔥🔥🔥");
            SharedPreferencesImportHandler.getInstance().handleIncomingFile(data, this);
            // Clear the intent so we don't process it again on resume
            setIntent(new Intent());
        } else {
            String wrongExtension = FestivalConfig.getInstance().isMDF() ? ".70kshare" : ".mdfshare";
            if (filename != null && filename.endsWith(wrongExtension)) {
                String appName = FestivalConfig.getInstance().appName;
                Toast.makeText(this, "This file is not compatible with " + appName + ". Please use the correct app to open this file.", Toast.LENGTH_LONG).show();
                Log.d(TAG, "🔥 Wrong file extension detected. Expected: " + expectedExtension + ", got: " + wrongExtension);
            } else {
                Log.d(TAG, "🔥 Filename doesn't end with " + expectedExtension + ": " + filename);
            }
        }
    }
    
    /**
     * Get the actual filename from a content URI
     */
    private String getFilenameFromUri(Uri uri) {
        String filename = null;
        
        // First try to get display name from ContentResolver
        if ("content".equals(uri.getScheme())) {
            android.database.Cursor cursor = null;
            try {
                cursor = getContentResolver().query(uri, null, null, null, null);
                if (cursor != null && cursor.moveToFirst()) {
                    int nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME);
                    if (nameIndex != -1) {
                        filename = cursor.getString(nameIndex);
                        Log.d(TAG, "🔥 Got filename from ContentResolver: " + filename);
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "🔥 Error getting filename from ContentResolver", e);
            } finally {
                if (cursor != null) {
                    cursor.close();
                }
            }
        }
        
        // Fallback to path parsing if content resolver didn't work
        if (filename == null) {
            String path = uri.getPath();
            if (path != null) {
                int lastSlash = path.lastIndexOf('/');
                if (lastSlash != -1 && lastSlash < path.length() - 1) {
                    filename = path.substring(lastSlash + 1);
                    Log.d(TAG, "🔥 Got filename from path parsing: " + filename);
                }
            }
        }
        
        return filename;
    }

    @Override
    public void onResume() {
        if (dialog != null){
            if (dialog.isShowing()){
                dialog.dismiss();
            }
        }
        Log.d(TAG, notificationTag + " In onResume - 1");
        super.onResume();
        
        // Check for incoming file share intent (for API 35 emulator compatibility)
        Log.d(TAG, "🔥🔥🔥 onResume - checking for file share intent 🔥🔥🔥");
        handleIncomingIntent(getIntent());

        Log.d("DisplayListData", "On Resume refreshNewData");
        
        appFullyInitialized = true;
        Log.d("BackgroundFlag", "appFullyInitialized = TRUE (background detection handled at Application level)");

        Log.d(TAG, notificationTag + " In onResume - 2");
        
        // Only refresh if we're not returning from stats page to avoid blocking stats loading
        // The stats page should load immediately without waiting for main activity refresh
        if (!returningFromStatsPage) {
            
            // FRESH INSTALL FIX: Only trigger refresh if data loading is NOT already in progress
            // This prevents duplicate downloads on first install (onCreate already started loading)
            if (staticVariables.loadingBands) {
                Log.d("FRESH_INSTALL", "Data loading already in progress from onCreate, skipping onResume refresh");
                return; // Don't interfere with the initial load
            }
            
            // FRESH INSTALL FIX: Apply exact pull-to-refresh logic on first launch
            // Check if this looks like a fresh install (no data loaded yet)
            boolean isWaitingForData = false;
            if (listHandler == null) {
                isWaitingForData = true;
            } else {
                List<String> sortableNames = listHandler.getSortableBandNames();
                if (sortableNames.isEmpty() || 
                    (sortableNames.size() == 1 && sortableNames.get(0).contains("Waiting for data"))) {
                    isWaitingForData = true;
                }
            }
            
            if (isWaitingForData) {
                Log.d("FRESH_INSTALL", "🚀 Applying pull-to-refresh logic for fresh install");
                
                // PERFORMANCE FIX: Move heavy operations to background thread to prevent ANR
                new Thread(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            // Apply the EXACT same logic as pull-to-refresh (in background)
                            bandInfo = new BandInfo();
                            staticVariables.loadingNotes = false;
                            SynchronizationManager.signalNotesLoadingComplete();
                            
                            // Refresh description map cache (same as pull-to-refresh)
                            Log.d("DescriptionMap", "Refreshing description map cache on fresh install");
                            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
                            descHandler.getDescriptionMap();
                            
                            // Apply the same refresh sequence as pull-to-refresh (on UI thread)
                            runOnUiThread(new Runnable() {
                                @Override
                                public void run() {
                                    try {
                                        refreshNewData();
                                        reloadData();
                                        Log.d("FRESH_INSTALL", "🚀 Fresh install refresh sequence complete");
                                    } catch (Exception e) {
                                        Log.e("FRESH_INSTALL", "🚨 Error in UI refresh: " + e.getMessage(), e);
                                    }
                                }
                            });
                        } catch (Exception e) {
                            Log.e("FRESH_INSTALL", "🚨 Error in background refresh: " + e.getMessage(), e);
                        }
                    }
                }).start();
                
                return; // Skip the normal refresh logic below
            }
            // DETAILS RETURN FIX: Always refresh to show updated data, but preserve scroll position
            if (staticVariables.listPosition > 0) {
                returningFromDetailsScreen = true;
                Log.d("ListPosition", "Detected return from details screen - refreshing with smooth animation control");
                
                // Save current scroll position before refresh (AsyncTask will also save if needed)
                saveScrollPosition();
                
                // Refresh data to show updated rankings
                refreshNewData();
                
                // Reset flags after refresh completes (not immediately, as refreshNewData is async)
                // The flag will be reset after displayBandData completes in displayBandDataWithSchedule
                staticVariables.listPosition = 0;
                
                // Restore progress indicator if downloads are still running
                if (ForegroundDownloadManager.isDownloading()) {
                    Log.d("ListPosition", "Downloads still running, restoring progress indicator");
                    ForegroundDownloadManager.setCurrentActivity(showBands.this);
                }
            } else {
                Log.d("ListPosition", "Normal onResume - checking if offline to optimize loading");
                
                // OFFLINE FIX: If offline and we have cached data, just reload from cache
                // This is much faster than trying to refresh (which waits for network)
                boolean hasCachedData = FileHandler70k.bandInfo.exists() && FileHandler70k.schedule.exists();
                if (!OnlineStatus.isOnline() && hasCachedData) {
                    Log.d("OFFLINE_FIX", "Offline with cached data - reloading from cache immediately");
                    // Just reload from cache - much faster than refreshNewData()
                    reloadData();
                    // Still need to refresh the display
                    refreshData();
                } else {
                    // Online or no cached data - do normal refresh
                    refreshNewData();
                }
            }
        } else {
            Log.d("DisplayListData", "Skipping refresh - returning from stats page");
            returningFromStatsPage = false; // Reset flag
        }

        Log.d(TAG, notificationTag + " In onResume - 3");
        
        // BLANK LIST FIX: Final safety check to ensure list is populated after resume
        // TRANSPARENT REFRESH FIX: Use notifyDataSetChanged() instead of setAdapter() to preserve scroll position
        bandNamesList.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (bandNamesList != null && adapter != null) {
                    if (bandNamesList.getVisibility() != View.VISIBLE) {
                        Log.d("BlankListFix", "onResume safety: List not visible, making visible");
                        bandNamesList.setVisibility(View.VISIBLE);
                    }
                    if (adapter.getCount() > 0 && bandNamesList.getCount() == 0) {
                        Log.d("BlankListFix", "onResume safety: Adapter has data but list is empty, refreshing");
                        // TRANSPARENT REFRESH: Only set adapter if not already set, otherwise use notifyDataSetChanged()
                        if (bandNamesList.getAdapter() != adapter) {
                            bandNamesList.setAdapter(adapter);
                        } else {
                            adapter.notifyDataSetChanged();
                        }
                        bandNamesList.invalidateViews();
                    }
                }
            }
        }, 200); // Quick check after resume completes
        
        // CLICK LISTENER FIX: Always re-establish click listener on resume
        // This ensures it's present even if it was cleared by system or other operations
        setupClickListener();

        handleSearch();

        Log.d(TAG, notificationTag + " In onResume - 4");
        // ERRATIC JUMPING FIX: Disable automatic state restoration that conflicts with position restoration
        // Our manual position restoration in displayBandDataWithSchedule() is more reliable
        if (listState != null && !returningFromDetailsScreen) {
            Log.d("State Status", "restoring state during Resume (not returning from details)");
            bandNamesList.onRestoreInstanceState(listState);
        } else if (returningFromDetailsScreen) {
            Log.d("State Status", "skipping automatic state restoration - returning from details screen");
        }

        Log.d(TAG, notificationTag + " In onResume - 5");
        registerReceiver();

        Log.d(TAG, notificationTag + " In onResume - 6");

        Log.d(TAG, notificationTag + " calling showNotification");
        showNotification();

        subscribeToAlerts();

        Log.d(TAG, notificationTag + " In onResume - 7");
        // ERRATIC JUMPING FIX: Remove duplicate position restoration from onResume
        // This was causing jumping by overriding the restoration in displayBandDataWithSchedule()
        // Position restoration is now handled centrally in displayBandDataWithSchedule()

        Log.d(TAG, notificationTag + " In onResume - 8");

        // Background loading management is now handled at the Application level
        // Dimageescription map cache refresh on return to foreground
        CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
        Log.d("DescriptionMap", "Refreshing description map cache on return to foreground");
        descHandler.getDescriptionMap();

    }

    public void showClickChoices(final int position) {
        if (listHandler == null || listHandler.bandNamesIndex == null) {
            Log.e("CLICK_DEBUG", "listHandler or bandNamesIndex is null!");
            return;
        }
        
        if (position >= listHandler.bandNamesIndex.size()) {
            Log.e("CLICK_DEBUG", "Position out of bounds: " + position);
            return;
        }

        final String selectedBand = listHandler.bandNamesIndex.get(position);
        currentListForDetails = listHandler.bandNamesIndex;
        currentListPosition = position;

        if (scheduleSortedBandNames == null || position >= scheduleSortedBandNames.size()) {
            Log.e("CLICK_DEBUG", "scheduleSortedBandNames issue at position: " + position);
            return;
        }

        String bandIndex = scheduleSortedBandNames.get(position);
        String bandName = getBandNameFromIndex(bandIndex);
        Long timeIndex = getTimeIndexFromIndex(bandIndex);

        //bypass prompt if appropriate
        if (timeIndex == 0 || preferences.getPromptForAttendedStatus() == false) {
            showDetailsScreen(position, selectedBand);
            return;
        }

        final String rawStartTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getStartTimeString();
        final String location = listHandler.getLocation(bandName, timeIndex);
        final String startTime = listHandler.getStartTime(bandName, timeIndex);
        final String eventType = listHandler.getEventType(bandName, timeIndex);
        final String status = attendedHandler.getShowAttendedStatus(bandName, location, startTime, eventType, eventYear.toString());

        final String attendedString = getResources().getString(R.string.AllOfEvent);
        final String partAttendedString = getResources().getString(R.string.PartOfEvent);
        final String notAttendedString = getResources().getString(R.string.NoneOfEvent);
        final String goToDetailsString = getResources().getString(R.string.GoToDetails);

        // String array for alert dialog multi choice items
        ArrayList<String> eventChoices = new ArrayList<String>();
        eventChoices.add(goToDetailsString);

        String titleStatus;
        if (status.equals(sawAllStatus)) {
            titleStatus = attendedString;
            if (eventType.equals(show)) {
                eventChoices.add(partAttendedString);
            }
            eventChoices.add(notAttendedString);

        } else if (status.equals(sawSomeStatus)) {
            titleStatus = partAttendedString;
            eventChoices.add(attendedString);
            eventChoices.add(notAttendedString);

        } else {
            titleStatus = notAttendedString;
            eventChoices.add(attendedString);
            if (eventType.equals(show)) {
                eventChoices.add(partAttendedString);
            }
        }

        TextView titleView = new TextView(context);
        titleView.setText(selectedBand + "\n" + titleStatus);
        titleView.setPadding(20, 30, 20, 30);
        titleView.setTextSize(20F);
        titleView.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
        titleView.setGravity(Gravity.CENTER);
        titleView.setBackgroundColor(Color.parseColor("#505050"));
        titleView.setTextColor(Color.WHITE);

        // create an alert builder
        final AlertDialog.Builder builder = new AlertDialog.Builder(new ContextThemeWrapper(this, R.style.AlertDialog));
        builder.setCustomTitle(titleView);

        // set the custom layout
        final View customLayout = getLayoutInflater().inflate(R.layout.prompt_show_dialog, null);
        builder.setView(customLayout);

        Button goToDetails = (Button) customLayout.findViewById(R.id.GoToDetails);
        Button attendAll = (Button) customLayout.findViewById(R.id.AttendedAll);
        Button attendSome = (Button) customLayout.findViewById(R.id.AttendeSome);
        Button attendNone = (Button) customLayout.findViewById(R.id.AttendeNone);
        Button disable = (Button) customLayout.findViewById(R.id.Disable);

        if (status.equals(sawAllStatus)) {
            attendAll.setVisibility(View.GONE);

        } else if (status.equals(sawSomeStatus)) {
            attendSome.setVisibility(View.GONE);

        } else {
            attendNone.setVisibility(View.GONE);
        }

        goToDetails.setText(getText(R.string.GoToDetails));
        attendAll.setText(getText(R.string.AllOfEvent));
        attendSome.setText(getText(R.string.PartOfEvent));
        attendNone.setText(getText(R.string.NoneOfEvent));
        disable.setText(getText(R.string.disableAttendedPrompt));


        // add a button
        builder.setPositiveButton(getText(R.string.Cancel), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {

            }
        });

        // create and show the alert dialog
        final AlertDialog dialog = builder.create();


        goToDetails.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                dialog.dismiss();
                showDetailsScreen(position, selectedBand);
            }
        });

        attendAll.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                setAttendedStatusViaDialog(sawAllStatus, selectedBand, location, rawStartTime, eventType, dialog);
            }
        });

        attendSome.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                setAttendedStatusViaDialog(sawSomeStatus, selectedBand, location, rawStartTime, eventType, dialog);
            }
        });

        attendNone.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                setAttendedStatusViaDialog(sawNoneStatus, selectedBand, location, rawStartTime, eventType, dialog);
            }
        });

        disable.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                preferences.setPromptForAttendedStatus(false);
                dialog.dismiss();
            }
        });

        dialog.show();
    }

    private void setAttendedStatusViaDialog(String desiredStatus,
                                            String selectedBand,
                                            String location,
                                            String startTime,
                                            String eventType,
                                            AlertDialog dialog) {

        String status = attendedHandler.addShowsAttended(selectedBand, location, startTime, eventType, desiredStatus);
        String message = attendedHandler.setShowsAttendedStatus(status);

        dialog.dismiss();
        Toast.makeText(getApplicationContext(),
                message + " ", Toast.LENGTH_SHORT).show();

        refreshData();
    }

    public void showDetailsScreen(int position, String selectedBand) {

        Log.d("NAVIGATION_DEBUG", "🚀 showDetailsScreen called - position: " + position + ", band: " + selectedBand);
        
        getWindow().getDecorView().findViewById(android.R.id.content).invalidate();

        BandInfo.setSelectedBand(selectedBand);
        
        // LIST POSITION FIX: Save the current list position before launching details screen
        staticVariables.listPosition = position;
        Log.d("ListPosition", "Saved list position: " + position + " for band: " + selectedBand);

        Intent showDetails = new Intent(showBands.this, showBandDetails.class);
        Log.d("NAVIGATION_DEBUG", "🚀 Starting showBandDetails activity");
        // Update activity reference for progress indicator if downloads are running
        ForegroundDownloadManager.setCurrentActivity(showBands.this);
        startActivity(showDetails);
        Log.d("NAVIGATION_DEBUG", "🚀 showBandDetails activity started");
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();
        listState = bandNamesList.onSaveInstanceState();
        Log.d("State Status", "Saving state");
        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    private void subscribeToAlerts() {
        FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.getMainAlertChannel());
        FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.getTestAlertChannel());
        if (staticVariables.preferences.getAlertForUnofficalEvents() == true) {
            //FirebaseMessaging.getInstance().subscribeToTopic("topic/" + staticVariables.getUnofficialAlertChannel());
            FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.getUnofficialAlertChannel());
        } else {
            //FirebaseMessaging.getInstance().unsubscribeFromTopic("topic/" + staticVariables.getUnofficialAlertChannel());
            FirebaseMessaging.getInstance().unsubscribeFromTopic(staticVariables.getUnofficialAlertChannel());
        }
    }

    @Override
    public void onPrepared(MediaPlayer mediaPlayer) {

    }
    
    /**
     * Modern replacement for AsyncListViewLoader - executes list loading in background.
     * Uses ThreadManager instead of deprecated AsyncTask.
     */
    private void executeAsyncListViewLoader() {
        ThreadManager.getInstance().executeGeneralWithCallbacks(
            () -> {
                // Background task
                Log.d("Refresh", "Refresh Stage = Background-Start");
                
                // Wait for any existing loading to complete using proper synchronization
                if (!SynchronizationManager.waitForBandLoadingComplete(10)) {
                    Log.w("Refresh", "Timeout waiting for existing band loading to complete");
                    return; // Don't proceed if we can't ensure exclusive access
                }
                
                // Signal that we're starting band loading
                SynchronizationManager.signalBandLoadingStarted();
                staticVariables.loadingBands = true;

                // CRITICAL FIX: Check if we have cached data - if so, skip network wait for faster offline loading
                boolean hasCachedData = FileHandler70k.bandInfo.exists() && FileHandler70k.schedule.exists();
                
                if (hasCachedData && !OnlineStatus.isOnline()) {
                    // We have cached data and we're offline - skip network wait and load from cache immediately
                    Log.d("AsyncTask", "Offline with cached data - loading from cache immediately (no network wait)");
                } else {
                    // CRITICAL FIX: Wait for network to be available before attempting download
                    // This is especially important on Android API 30 and below where network detection
                    // can be delayed on first install
                    // BUT: Only wait if we don't have cached data (first install scenario)
                    if (!hasCachedData) {
                        int maxWaitAttempts = 20; // Wait up to 10 seconds (20 * 500ms)
                        int waitAttempt = 0;
                        while (!OnlineStatus.isOnline() && waitAttempt < maxWaitAttempts) {
                            try {
                                Thread.sleep(500); // Wait 500ms between checks
                                waitAttempt++;
                                if (waitAttempt % 4 == 0) { // Log every 2 seconds
                                    Log.d("AsyncTask", "Waiting for network connectivity... (attempt " + waitAttempt + "/" + maxWaitAttempts + ")");
                                }
                            } catch (InterruptedException e) {
                                Thread.currentThread().interrupt();
                                Log.w("AsyncTask", "Interrupted while waiting for network", e);
                                break;
                            }
                        }
                    }
                    
                    if (!OnlineStatus.isOnline()) {
                        Log.w("AsyncTask", "Network not available, will use cached data if available");
                    } else {
                        Log.d("AsyncTask", "Network available, proceeding with download");
                    }
                }

                Log.d("AsyncTask", "Downloading data");
                try {
                    BandInfo bandInfo = new BandInfo();
                    bandInfo.DownloadBandFile();

                    // Keep descriptionMap in sync with band/schedule on startup/foreground refresh:
                    // Download (hash-checked) and then parse to populate descriptionMapData + descriptionMapModData.
                    try {
                        CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
                        descHandler.getDescriptionMapFile();   // content-hash checked
                        descHandler.getDescriptionMap();       // parse into in-memory maps (incl. mod dates)
                    } catch (Exception e) {
                        Log.e("bandInfo", "Error downloading/parsing descriptionMap: " + e.getMessage(), e);
                    }
                } catch (Exception error) {
                    Log.e("bandInfo", "Error downloading band data: " + error.getMessage(), error);
                } finally {
                    // Always signal completion, even if there was an error
                    staticVariables.loadingBands = false;
                    SynchronizationManager.signalBandLoadingComplete();
                }
                Log.d("Refresh", "Refresh Stage = Background-Stop");
            },
            // Pre-execute on UI thread
            () -> {
                Log.d("DisplayListData", "Refresh Stage = Pre-Start");
                if (!staticVariables.loadingBands) {
                    Log.d("DisplayListData", "onPreExecuteRefresh - 1");
                    staticVariables.loadingBands = true;
                    Log.d("AsyncList refresh", "Starting AsyncList refresh");
                    
                    // ANIMATION FIX: Save scroll position before async refresh
                    if (bandNamesList != null && staticVariables.savedScrollPosition < 0) {
                        saveScrollPosition();
                        Log.d("ScrollPosition", "Async refresh scroll preservation activated");
                    }
                    
                    refreshData();
                    staticVariables.loadingBands = false;
                    Log.d("DisplayListData", "onPreExecuteRefresh - 2");
                }
                Log.d("Refresh", "Refresh Stage = Pre-Stop");
            },
            // Post-execute on UI thread
            () -> {
                Log.d("Refresh", "Refresh Stage = Post-Start");
                
                // FRESH INSTALL FIX: Refresh display after data download
                // NOTE: refreshData() will check if data changed and skip refresh if unchanged
                // This prevents unnecessary refreshes that cause flashing
                // Only refresh if we don't have data yet (fresh install) or if forceRefresh is needed
                boolean needsRefresh = (adapter == null || adapter.getCount() == 0 || 
                    (adapter.getCount() == 1 && adapter.getItem(0) != null && 
                     adapter.getItem(0).getBandName() != null && 
                     adapter.getItem(0).getBandName().contains("waiting for data")));
                
                if (needsRefresh) {
                    Log.d("onPostExecuteRefresh", "Fresh install or blank list - refreshing");
                    refreshData();
                } else {
                    Log.d("onPostExecuteRefresh", "List already has data - refreshData() will check if update needed");
                    refreshData(); // Still call it, but it will skip if data unchanged
                }
                Log.d("onPostExecuteRefresh", "Post-execute refresh (displaying downloaded data)");
                
                // Note: Scroll preservation is handled within refreshData() if needed

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 1");
                
                // ANIMATION FIX: Don't manually control visibility - let our system handle it
                if (staticVariables.savedScrollPosition < 0) {
                    // Only set visibility if our animation system isn't managing it
                    showBands.this.bandNamesList.setVisibility(View.VISIBLE);
                    showBands.this.bandNamesList.requestLayout();
                }

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 3");
                bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
                bandNamesPullRefresh.setRefreshing(false);
                fileDownloaded = true;
                
                // FLASHING FIX: refreshData() already handles setting/updating the adapter
                // We should NOT call setAdapter() here as it causes flashing when data is unchanged
                // The adapter is set/updated in displayBandDataWithSchedule() or displayBandDataWithoutSchedule()
                // which are called by refreshData() -> displayBandData()
                // Only exception: if adapter is null and list is blank (fresh install), but refreshData() handles that too
                Log.d("FRESH_INSTALL", "Skipping adapter update in onPostExecuteRefresh - refreshData() already handled it");
                
                // Start bulk downloads after CSV processing completes
                Log.d("Refresh", "CSV processing complete, starting bulk downloads");
                ForegroundDownloadManager.startDownloadsAfterCSV(showBands.this);
                
                Log.d("Refresh", "Refresh Stage = Post-Stop");
            }
        );
    }



    class AsyncNotesLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            // Wait for any existing notes loading to complete using proper synchronization
            if (!SynchronizationManager.waitForNotesLoadingComplete(10)) {
                Log.w("AsyncNotesLoader", "Timeout waiting for notes loading to complete");
                return result; // Don't proceed if we can't ensure exclusive access
            }
            
            // Signal that we're starting notes loading
            SynchronizationManager.signalNotesLoadingStarted();
            staticVariables.loadingNotes = true;

            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading data");

            try {

                // Description map should only be downloaded when app goes to background
                // Removed: bandNotes.getDescriptionMap();

                // Descriptions should only be downloaded when app goes to background
                // Removed: bandNotes.getAllDescriptions();

                // Images should only be downloaded when app goes to background or when entering details screen
                // Removed: imageHandler.getAllRemoteImages();

            } catch (Exception error) {
                //Log.d("bandInfo", error.getMessage());
            }
            staticVariables.loadingNotes = false;
            SynchronizationManager.signalNotesLoadingComplete();


            return result;

        }
    }
}

