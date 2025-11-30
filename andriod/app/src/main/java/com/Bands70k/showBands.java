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
import android.os.Bundle;
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
        jumpToTop.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                bandNamesList.setSelectionAfterHeaderView();
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
                        new Handler().postDelayed(new Runnable() {
                            @Override
                            public void run() {
                                bandNamesPullRefresh.setRefreshing(false);
                            }
                        }, 5000);

                        Log.i("AsyncList refresh", "onRefresh called from SwipeRefreshLayout");

                        //start spinner and stop after 5 seconds
                        bandNamesPullRefresh.setRefreshing(true);
                        bandInfo = new BandInfo();
                        staticVariables.loadingNotes = false;
                        SynchronizationManager.signalNotesLoadingComplete();
                        
                        // Refresh description map cache on pull to refresh
                        // This updates the cache with band names and description URLs (not actual descriptions)
                        Log.d("DescriptionMap", "Refreshing description map cache on pull to refresh");
                        CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
                        descHandler.getDescriptionMap();
                        
                        refreshNewData();
                        reloadData();

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


        VideoView mVideoView = (VideoView)dialog.findViewById(R.id.VideoView);

        String path = ("android.resource://com.Bands70k/" +  R.raw.snl_more_cowbell);
        mVideoView.setOnPreparedListener(this);
        mVideoView.getHolder().setFixedSize(300, 400);
        dialog.show();

        // Center the dialog on the screen
        Window window = dialog.getWindow();
        if (window != null) {
            WindowManager.LayoutParams layoutParams = new WindowManager.LayoutParams();
            layoutParams.copyFrom(window.getAttributes());
            layoutParams.gravity = Gravity.CENTER;
            // Optionally set width/height:
            // layoutParams.width = WindowManager.LayoutParams.WRAP_CONTENT;
            // layoutParams.height = WindowManager.LayoutParams.WRAP_CONTENT;
            window.setAttributes(layoutParams);
        }

        mVideoView.setVideoPath(path);
        mVideoView.requestFocus();
        mVideoView.start();
        mVideoView.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
            @Override
            public void onCompletion(MediaPlayer mediaPlayer) {
                dialog.dismiss();
            }
        });

    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        Log.d("orientation", "orientation DONE!");
        setSearchBarWidth();
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
        searchCriteriaObject.setQuery(searchCriteria, true);
        searchCriteria = searchCriteriaObject.getQuery().toString();

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
            Log.d("CLICK_LISTENER_FIX", "✅ Setting up click listener for bandNamesList");
            bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
                // argument position gives the index of item which is clicked
                public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {
                    try {
                        Log.d("CLICK_LISTENER_FIX", "✅ Click detected at position: " + position);
                        showClickChoices(position);
                    } catch (Exception error) {
                        Log.e("CLICK_DEBUG", "Error in showClickChoices: " + error.toString(), error);
                        System.exit(0);
                    }
                }
            });
        } else {
            Log.e("CLICK_LISTENER_FIX", "❌ Cannot set OnItemClickListener - bandNamesList is null!");
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

        bandNamesList.setOnScrollListener(new AbsListView.OnScrollListener() {
            @Override
            public void onScrollStateChanged(AbsListView view, int scrollState) {
                // TODO Auto-generated method stub

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
        });

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

        Button shareBandChoices = (Button) customLayout.findViewById(R.id.GoToDetails);
        Button shareShowChoices = (Button) customLayout.findViewById(R.id.AttendedAll);
        Button saveData = (Button) customLayout.findViewById(R.id.AttendeSome);
        Button na1 = (Button) customLayout.findViewById(R.id.AttendeNone);
        Button na2 = (Button) customLayout.findViewById(R.id.Disable);

        shareBandChoices.setText(getString(R.string.ShareBandChoices));
        shareShowChoices.setText(getString(R.string.ShareShowChoices));
        saveData.setText(getString(R.string.ExportUserData));
        na1.setVisibility(View.INVISIBLE);
        na2.setVisibility(View.INVISIBLE);
        
        // Check if Share Show Choice should be enabled
        boolean hasScheduleData = BandInfo.scheduleRecords != null && !BandInfo.scheduleRecords.isEmpty();
        boolean hasAttendanceData = hasUserAttendanceData();
        
        if (!hasScheduleData || !hasAttendanceData) {
            shareShowChoices.setEnabled(false);
            shareShowChoices.setAlpha(0.5f); // Visual indication that it's disabled
        }

        // add a button
        builder.setPositiveButton(getString(R.string.Cancel), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {

            }
        });

        // create and show the alert dialog
        final AlertDialog dialog = builder.create();


        shareBandChoices.setOnClickListener(new View.OnClickListener() {
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

        shareShowChoices.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {

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

        saveData.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                String zipFileName = UserDataExportImport.exportDataToZip();

                Log.d("", "Zip file name 1 is  " + zipFileName);
                zipFile = new File(zipFileName);
                Log.d("", "Zip file name 2 is  " + zipFile.getAbsolutePath());

                // Use dynamic authority based on current application ID (works for both 70K and MDF)
                String authority = context.getPackageName() + ".fileprovider";
                Uri zipFileUri = FileProvider.getUriForFile(
                        context,
                        authority,
                        zipFile);

                Intent sharingIntent = new Intent(Intent.ACTION_SEND);

                sharingIntent.setType("application/zip");
                sharingIntent.putExtra(Intent.EXTRA_STREAM, zipFileUri);

                // Use descriptive subject with actual filename
                String fileName = zipFile.getName();
                sharingIntent.putExtra(Intent.EXTRA_SUBJECT, "Backup: " + fileName);
                sharingIntent.putExtra(Intent.EXTRA_TEXT, "Sharing user data backup: " + fileName);

                startActivity(Intent.createChooser(sharingIntent, "Share Backup File"));

                dialog.dismiss();
                sharedZipFile = true;
            }
        });

        dialog.show();

        if (sharedZipFile == true) {
            zipFile.delete();
        }
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

        if (fileDownloaded == false) {
            refreshNewData();

        } else {
            reloadData();
        }

        setupSwipeList();
    }


    public void refreshNewData() {

        RelativeLayout showBandLayout = (RelativeLayout) findViewById(R.id.showBandsView);
        showBandLayout.invalidate();
        showBandLayout.requestLayout();

        Log.d("refreshNewData", "refreshNewData - 1");

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
            // UNIVERSAL SCROLL PRESERVATION: Save position before extra refresh
            if (bandNamesList != null && staticVariables.savedScrollPosition < 0) {
                saveScrollPosition();
                Log.d("ScrollPosition", "Universal scroll preservation activated for extra refresh");
            }
            displayBandData();
            // Restore position after extra refresh
            restoreScrollPosition();
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

        if (fileDownloaded == true) {
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
        
        Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Starting bands-only display");
        
        adapter = new bandListView(getApplicationContext(), R.layout.bandlist70k);
        
        BandInfo bandInfoNames = new BandInfo();
        bandNames = bandInfoNames.getBandNames();
        
        // Initialize listHandler if not already initialized
        if (listHandler == null) {
            listHandler = new mainListHandler(showBands.this);
        }
        
        // CRITICAL FIX: Clear both lists before repopulating to ensure sync with adapter
        listHandler.bandNamesIndex.clear();
        scheduleSortedBandNames.clear();
        Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Cleared bandNamesIndex and scheduleSortedBandNames before populating");
        
        if (bandNames.size() == 0) {
            String emptyDataMessage = getResources().getString(R.string.waiting_for_data);
            bandListItem bandItem = new bandListItem(emptyDataMessage);
            adapter.add(bandItem);
        } else {
            // Sort bands alphabetically for bands-only view
            Collections.sort(bandNames);
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Processing " + bandNames.size() + " bands");
            
            Integer counter = 0;
            for (String bandName : bandNames) {
                bandListItem bandItem = new bandListItem(bandName);
                bandItem.setRankImg(rankStore.getRankImageForBand(bandName));
                adapter.add(bandItem);
                // CRITICAL FIX: Add band name to both lists to keep in sync with adapter
                listHandler.bandNamesIndex.add(bandName);
                scheduleSortedBandNames.add(bandName);
                counter++;
            }
            
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Added " + counter + " bands to adapter");
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: bandNamesIndex.size() = " + listHandler.bandNamesIndex.size());
            Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: scheduleSortedBandNames.size() = " + scheduleSortedBandNames.size());
            
            // Verify sync between adapter and both lists
            if (adapter.getCount() != listHandler.bandNamesIndex.size() || adapter.getCount() != scheduleSortedBandNames.size()) {
                Log.e("SYNC_ERROR", "🚨 MISMATCH: adapter has " + adapter.getCount() + " items but bandNamesIndex has " + listHandler.bandNamesIndex.size() + " and scheduleSortedBandNames has " + scheduleSortedBandNames.size() + " items!");
            } else {
                Log.d("SYNC_SUCCESS", "✅ Adapter, bandNamesIndex, and scheduleSortedBandNames are in sync with " + adapter.getCount() + " items");
            }
        }
        
        // Set the adapter after processing all data
        Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Setting adapter with " + adapter.getCount() + " items");
        if (bandNamesList != null) {
            bandNamesList.setAdapter(adapter);
            Log.d("VIEW_MODE_DEBUG", "🎵 SUCCESS: Adapter set successfully");
        } else {
            Log.w("VIEW_MODE_DEBUG", "🚨 WARNING: bandNamesList is null, deferring adapter setup");
            // Store adapter for later when UI is initialized
            this.adapter = adapter;
        }
        
        // Setup swipe and filters
        setupSwipeList();
        FilterButtonHandler filterButtonHandle = new FilterButtonHandler();
        filterButtonHandle.setUpFiltersButton(this);
        
        // Update band count display
        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("VIEW_MODE_DEBUG", "🎵 displayBandDataWithoutSchedule: Finished display " + adapter.getCount() + " bands");
    }

    private void displayBandDataWithSchedule() {

        Log.d("ListPosition", "displayBandDataWithSchedule called - returningFromDetailsScreen: " + returningFromDetailsScreen + ", savedPosition: " + staticVariables.listPosition);
        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 1");
        
        // ANIMATION FIX: Disable layout animations during swipe menu refresh
        if (staticVariables.disableListAnimations) {
            Log.d("AnimationFix", "Disabling list animations for smooth refresh");
            // Disable layout animations completely
            bandNamesList.setLayoutAnimation(null);
            // Disable list selector animations
            bandNamesList.setLayoutAnimationListener(null);
            // Ensure no transition animations
            bandNamesList.setItemsCanFocus(false);
        }
        
        adapter = new bandListView(getApplicationContext(), R.layout.bandlist70k);
        // Note: setAdapter() moved to after the loop that populates the adapter

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 2");
        BandInfo bandInfoNames = new BandInfo();

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 3");
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

        Integer counter = 0;
        attendedHandler.loadShowsAttended();
        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 8");
        
        // CRITICAL FIX: Clear bandNamesIndex before repopulating to ensure sync with adapter
        listHandler.bandNamesIndex.clear();
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: Cleared bandNamesIndex before populating");
        
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: About to iterate over scheduleSortedBandNames");
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: scheduleSortedBandNames.size() = " + scheduleSortedBandNames.size());
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: scheduleSortedBandNames = " + (scheduleSortedBandNames != null ? "NOT NULL" : "NULL"));
        
        for (String bandIndex : scheduleSortedBandNames) {

            Log.d("WorkingOnScheduleIndex", "WorkingOnScheduleIndex " + bandIndex + "-" + String.valueOf(staticVariables.eventYear));

            String[] indexSplit = bandIndex.split(":");

            if (indexSplit.length == 2) {

                String bandName = getBandNameFromIndex(bandIndex);
                Long timeIndex = getTimeIndexFromIndex(bandIndex);

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
                adapter.add(bandItem);
                // CRITICAL FIX: Add band name to index to keep in sync with adapter
                listHandler.bandNamesIndex.add(bandName);
            } else {

                bandIndex = bandIndex.replaceAll(":", "");
                bandListItem bandItem = new bandListItem(bandIndex);
                bandItem.setRankImg(rankStore.getRankImageForBand(bandIndex));
                counter = counter + 1;
                adapter.add(bandItem);
                // CRITICAL FIX: Add band name to index to keep in sync with adapter
                listHandler.bandNamesIndex.add(bandIndex);
            }

        }
        
        // Handle processing after the main loop
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: Finished processing loop, counter = " + counter);
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: adapter.getCount() = " + adapter.getCount());
        Log.d("CRITICAL_DEBUG", "🎯 SHOWBANDS: bandNamesIndex.size() = " + listHandler.bandNamesIndex.size());
        
        // Verify sync between adapter and bandNamesIndex
        if (adapter.getCount() != listHandler.bandNamesIndex.size()) {
            Log.e("SYNC_ERROR", "🚨 MISMATCH: adapter has " + adapter.getCount() + " items but bandNamesIndex has " + listHandler.bandNamesIndex.size() + " items!");
        } else {
            Log.d("SYNC_SUCCESS", "✅ Adapter and bandNamesIndex are in sync with " + adapter.getCount() + " items");
        }

        // Handle empty data case AFTER the loop
        if (counter == 0) {
            String emptyDataMessage = "";
            if (unfilteredBandCount > 1) {
                Log.d("populateBandInfo", "BandList has issues 2");
                emptyDataMessage = getResources().getString(R.string.data_filter_issue);
            } else {
                emptyDataMessage = getResources().getString(R.string.waiting_for_data);
            }
            bandListItem bandItem = new bandListItem(emptyDataMessage);
            adapter.add(bandItem);
        }
        
        // CRITICAL FIX: Set the adapter after processing all data
        Log.d("DisplayListData", "🔧 CRITICAL: Setting adapter with " + adapter.getCount() + " items");
        if (bandNamesList != null) {
            bandNamesList.setAdapter(adapter);
            Log.d("DisplayListData", "🔧 SUCCESS: Adapter set successfully");
        } else {
            Log.w("DisplayListData", "🚨 WARNING: bandNamesList is null, deferring adapter setup");
            // Store adapter for later when UI is initialized
            this.adapter = adapter;
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
        
        // JUMPING FIX: Position restoration is no longer needed here
        // We now prevent the refresh entirely when returning from details screen
        // This eliminates the jumping because the list never gets rebuilt
    }



    /**
     * Save the current scroll position of the list
     */
    private void saveScrollPosition() {
        if (bandNamesList != null) {
            staticVariables.savedScrollPosition = bandNamesList.getFirstVisiblePosition();
            View firstView = bandNamesList.getChildAt(0);
            staticVariables.savedScrollOffset = (firstView == null) ? 0 : firstView.getTop();
            Log.d("ScrollPosition", "Saved scroll position: " + staticVariables.savedScrollPosition + ", offset: " + staticVariables.savedScrollOffset);
            
            // ANIMATION FIX: Disable list animations and briefly hide list for smoother refresh
            staticVariables.disableListAnimations = true;
            bandNamesList.setVisibility(View.INVISIBLE);
        }
    }
    
    /**
     * Restore list animations to default state
     */
    private void restoreListAnimations() {
        if (bandNamesList != null) {
            Log.d("AnimationFix", "Restoring list animations to default state");
            // Restore default list behavior
            bandNamesList.setItemsCanFocus(true);
            // Note: Layout animations are typically null by default, so we leave them disabled
            // to prevent unwanted animations during normal operation
        }
    }
    
    /**
     * Restore the saved scroll position of the list
     */
    private void restoreScrollPosition() {
        if (bandNamesList != null && staticVariables.savedScrollPosition >= 0) {
            // DETAILS RETURN FIX: Add slight delay for smoother restoration from showDetails
            int delay = returningFromDetailsScreen ? 100 : 0;
            
            bandNamesList.postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (staticVariables.savedScrollPosition < adapter.getCount()) {
                        bandNamesList.setSelectionFromTop(staticVariables.savedScrollPosition, staticVariables.savedScrollOffset);
                        Log.d("ScrollPosition", "Restored scroll position: " + staticVariables.savedScrollPosition + ", offset: " + staticVariables.savedScrollOffset);
                        
                        // ANIMATION FIX: Re-enable animations and show list after position is restored
                        restoreListAnimations();
                        bandNamesList.setVisibility(View.VISIBLE);
                        staticVariables.disableListAnimations = false;
                        
                        // Clear saved position after restore
                        staticVariables.savedScrollPosition = -1;
                        staticVariables.savedScrollOffset = 0;
                    }
                }
            }, delay);
        }
    }

    public void refreshData() {

        Log.d("DisplayListData", "called from refreshData");
        
        // UNIVERSAL SCROLL PRESERVATION: Always save position before any refresh
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
        
        // Restore scroll position if it was saved
        restoreScrollPosition();
        
        // ANIMATION FIX: Safety fallback - ensure list is visible even if restore fails
        bandNamesList.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (bandNamesList.getVisibility() != View.VISIBLE) {
                    Log.d("AnimationFix", "Safety fallback: Making list visible");
                    bandNamesList.setVisibility(View.VISIBLE);
                    staticVariables.disableListAnimations = false;
                }
                
                // BLANK LIST FIX: Additional safety check for adapter
                if (adapter != null && adapter.getCount() > 0 && bandNamesList.getCount() == 0) {
                    Log.d("BlankListFix", "Detected blank list with valid adapter data - refreshing adapter");
                    bandNamesList.setAdapter(adapter);
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
    public void onResume() {
        if (dialog != null){
            if (dialog.isShowing()){
                dialog.dismiss();
            }
        }
        Log.d(TAG, notificationTag + " In onResume - 1");
        super.onResume();

        Log.d("DisplayListData", "On Resume refreshNewData");
        
        appFullyInitialized = true;
        Log.d("BackgroundFlag", "appFullyInitialized = TRUE (background detection handled at Application level)");

        Log.d(TAG, notificationTag + " In onResume - 2");
        
        // Only refresh if we're not returning from stats page to avoid blocking stats loading
        // The stats page should load immediately without waiting for main activity refresh
        if (!returningFromStatsPage) {
            
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
                
                // ANIMATION FIX: Enable smooth refresh for details return
                staticVariables.disableListAnimations = true;
                
                // Save current scroll position before refresh (AsyncTask will also save if needed)
                saveScrollPosition();
                
                // Refresh data to show updated rankings
                refreshNewData();
                
                // Reset flags after refresh
                staticVariables.listPosition = 0;
                returningFromDetailsScreen = false;
                
                // Restore progress indicator if downloads are still running
                if (ForegroundDownloadManager.isDownloading()) {
                    Log.d("ListPosition", "Downloads still running, restoring progress indicator");
                    ForegroundDownloadManager.setCurrentActivity(showBands.this);
                }
            } else {
                Log.d("ListPosition", "Normal onResume - proceeding with refresh");
                refreshNewData();
            }
        } else {
            Log.d("DisplayListData", "Skipping refresh - returning from stats page");
            returningFromStatsPage = false; // Reset flag
        }

        Log.d(TAG, notificationTag + " In onResume - 3");
        
        // BLANK LIST FIX: Final safety check to ensure list is populated after resume
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
                        bandNamesList.setAdapter(adapter);
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

                Log.d("AsyncTask", "Downloading data");
                try {
                    BandInfo bandInfo = new BandInfo();
                    bandInfo.DownloadBandFile();
                } catch (Exception error) {
                    Log.d("bandInfo", error.getMessage());
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
                
                // FRESH INSTALL FIX: Always refresh display after data download
                // This ensures downloaded data is displayed even on fresh install
                refreshData();
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

