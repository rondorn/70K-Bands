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
import android.os.Environment;
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

import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import static com.Bands70k.staticVariables.*;
import static java.lang.Thread.sleep;


public class showBands extends Activity implements MediaPlayer.OnPreparedListener {

    String notificationTag = "notificationTag";

    public static String newRootDir = Environment.getExternalStorageDirectory().toString();

    private ArrayList<String> bandNames;
    public List<String> scheduleSortedBandNames = new ArrayList<String>();

    private SwipeMenuListView bandNamesList;
    private SwipeRefreshLayout bandNamesPullRefresh;

    private ArrayList<String> rankedBandNames;

    private BandInfo bandInfo;
    private CustomerDescriptionHandler bandNotes;
    public Button filterMenuButton;
    public Button willAttendFilterButton;

    public static Boolean inBackground = true;

    //private static final int PLAY_SERVICES_RESOLUTION_REQUEST = 9000;
    private static final String TAG = "MainActivity";

    private BroadcastReceiver mRegistrationBroadcastReceiver;
    private boolean isReceiverRegistered;

    private mainListHandler listHandler;
    private bandListView adapter;
    private ListView listView;

    public SearchView searchCriteriaObject;

    private static Boolean recievedPermAnswer = false;
    private Boolean loadOnceStopper = false;

    private Boolean sharedZipFile = false;
    private File zipFile;

    private Dialog dialog;

    // inside my class
    private static final String[] INITIAL_PERMS = {
            android.Manifest.permission.READ_EXTERNAL_STORAGE,
            android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
            android.Manifest.permission.INTERNET,
            android.Manifest.permission.ACCESS_NETWORK_STATE,
            android.Manifest.permission.WAKE_LOCK,
            android.Manifest.permission.VIBRATE
    };
    private static final int REQUEST = 1337;

    private boolean checkWriteExternalPermission() {
        String permission = android.Manifest.permission.WRITE_EXTERNAL_STORAGE;
        int res = Bands70k.getAppContext().checkCallingOrSelfPermission(permission);
        return (res == PackageManager.PERMISSION_GRANTED);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {

        if (this.checkWriteExternalPermission() == false) {
            newRootDir = Bands70k.getAppContext().getFilesDir().getPath();

        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                Log.d("get perms", "Getting access to storage " + Build.VERSION.SDK_INT + "-" + Build.VERSION_CODES.M);
                int permission = ActivityCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
                int readpermission = ActivityCompat.checkSelfPermission(this, android.Manifest.permission.READ_EXTERNAL_STORAGE);
                Log.d("get perms", "Getting access to storage - pre- asking");
                if (permission != 0) {
                    //ActivityCompat.requestPermissions(this,new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, 1);

                    //requestPermissions((new String[]
                    //        {Manifest.permission.WRITE_EXTERNAL_STORAGE}), 1);

                    Log.d("get perms", "Getting access to storage - asking");
                    Integer count = 0;
                    while (permission != 0 || recievedPermAnswer == false) {
                        permission = checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
                        Log.d("get perms", "Getting access to storage - waiting " + permission + " " + count.toString());
                        sleep(1000);
                        requestPermissions((new String[]
                                {Manifest.permission.WRITE_EXTERNAL_STORAGE}), 1);
                        count = count + 1;
                    }
                    Log.d("get perms", "Getting access to storage - granted " + permission);
                }
                if (readpermission != 0) {
                    requestPermissions(INITIAL_PERMS, REQUEST);
                    while (readpermission != 0) {
                        readpermission = ActivityCompat.checkSelfPermission(this, android.Manifest.permission.READ_EXTERNAL_STORAGE);
                    }
                }
            } catch (Exception error) {
                newRootDir = Bands70k.getAppContext().getFilesDir().getPath();
            }

        } else {
            newRootDir = Bands70k.getAppContext().getFilesDir().getPath();
        }
        Log.d("Rool volume", "Root volume is " + newRootDir);
        try {
            File testFile = new File(showBands.newRootDir + FileHandler70k.directoryName + "test.txt");
            String test = "test";
            FileOutputStream stream = new FileOutputStream(testFile);
            try {
                stream.write(test.getBytes());
            } finally {
                stream.close();
            }
        } catch (Exception error) {
            //It appears I do not have access to external storage...lets fix that
            //by changing to use app storage
            newRootDir = Bands70k.getAppContext().getFilesDir().getPath();
        }

        setTheme(R.style.AppTheme);
        super.onCreate(savedInstanceState);

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
        bandNotes = new CustomerDescriptionHandler();

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

                if (firstVisibleItem > 0) {
                    Log.d("Setting position", "Setting position ito be  " + String.valueOf(firstVisibleItem));
                    listPosition = firstVisibleItem;
                    if (listPosition == 1) {
                        listPosition = 0;
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

                refreshData();
                bandNamesList.onRestoreInstanceState(listState);

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
                String subject = "Bands I MUST see on 70,000 Tons";

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
                String subject = "These are the events I attended on the 70,000 Tons Cruise";

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

                Uri zipFileUri = FileProvider.getUriForFile(
                        context,
                        "com.Bands70k",
                        zipFile);

                Intent sharingIntent = new Intent(Intent.ACTION_SEND);

                sharingIntent.setType("application/zip");
                sharingIntent.putExtra(Intent.EXTRA_STREAM, zipFileUri);

                sharingIntent.putExtra(Intent.EXTRA_SUBJECT, "Sharing File...");
                sharingIntent.putExtra(Intent.EXTRA_TEXT, "Sharing File...");

                startActivity(Intent.createChooser(sharingIntent, "Share File"));

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
                        .setTitle("70K Bands Message")
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

        String message = mustSeeIcon + " These are the bands I MUST see on the 70,000 Tons Cruise\n\n";

        for (String band : bandNames) {
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(mustSeeIcon)) {
                message += "\t\t" + band + "\n";
            }
        }
        message += "\n" + mightSeeIcon + " These are the bands I might see\n\n";

        for (String band : bandNames) {
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(mightSeeIcon)) {
                message += "\t\t" + band + "\n";
            }
        }

        message += "\n\nhttp://www.facebook.com/70kBands";
        return message;
    }

    public void populateBandList() {

        bandNamesList = (SwipeMenuListView) findViewById(R.id.bandNames);

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

        AsyncListViewLoader mytask = new AsyncListViewLoader();
        mytask.execute();

        AsyncNotesLoader myNotesTask = new AsyncNotesLoader();
        myNotesTask.execute();

        Log.d("refreshNewData", "refreshNewData - 2");
        scheduleAlertHandler alerts = new scheduleAlertHandler();
        alerts.execute();

        Log.d("refreshNewData", "refreshNewData - 3");
        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("DisplayListData", "finished display header " + headerText);

        Log.d("refreshNewData", "refreshNewData - 4");
        if (headerText.equals("70,000 Tons")) {
            Log.d("DisplayListData", "running extra refresh");
            displayBandData();
        }
        Log.d("refreshNewData", "refreshNewData - 5");
    }

    public void onStop() {

        super.onStop();
        inBackground = true;
        FireBaseAsyncBandEventWrite backgroundTask = new FireBaseAsyncBandEventWrite();
        backgroundTask.execute();
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
            Log.d("Setting position", "Setting position in reloadData to " + String.valueOf(listPosition));
            bandNamesList.setSelection(listPosition);

            Log.d("reloadData", "reloadData - 4");
            scheduleAlertHandler alerts = new scheduleAlertHandler();
            alerts.execute();

        }
    }


    private String getBandNameFromIndex(String index) {

        String bandName = "";
        Long timeIndex = Long.valueOf(0);

        String[] indexSplit = index.split(":");

        if (indexSplit.length == 2) {

            try {
                timeIndex = Long.valueOf(indexSplit[0]);
                bandName = indexSplit[1];

            } catch (NumberFormatException e) {
                bandName = indexSplit[0];
            }
        }

        if (bandName.isEmpty() == true) {
            bandName = indexSplit[0];
        }

        return bandName;
    }

    private Long getTimeIndexFromIndex(String index) {

        Long timeIndex = Long.valueOf(0);
        try {
            String[] indexSplit = index.split(":");

            if (indexSplit.length == 2) {

                try {
                    timeIndex = Long.valueOf(indexSplit[0]);

                } catch (NumberFormatException e) {
                    timeIndex = Long.valueOf(indexSplit[1]);
                }
            }

        } catch (Exception error){
            Log.d("getTimeIndexFromIndex", error.getMessage());
        }

        return timeIndex;
    }

    private void displayBandData() {

        Log.d("DisplayListData", "starting display ");

        displayBandDataWithSchedule();
    }

    private void displayBandDataWithSchedule() {

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 1");
        adapter = new bandListView(getApplicationContext(), R.layout.bandlist70k);
        bandNamesList.setAdapter(adapter);

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
        scheduleSortedBandNames = listHandler.getSortableBandNames();

        if (scheduleSortedBandNames.isEmpty() == true) {
            scheduleSortedBandNames = listHandler.populateBandInfo(bandInfo, bandNames);
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
            } else {

                bandIndex = bandIndex.replaceAll(":", "");
                bandListItem bandItem = new bandListItem(bandIndex);
                bandItem.setRankImg(rankStore.getRankImageForBand(bandIndex));
                counter = counter + 1;
                adapter.add(bandItem);
            }

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

            //swip stuff
            setupSwipeList();

            FilterButtonHandler filterButtonHandle = new FilterButtonHandler();
            //filterButtonHandle.onCreate(null);
            filterButtonHandle.setUpFiltersButton(this);

        }

        //Log.d("displayBandDataWithSchedule", "displayBandDataWithSchedule - 9");
        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("DisplayListData", "finished display " + String.valueOf(counter) + '-' + headerText);
    }



    public void refreshData() {

        Log.d("DisplayListData", "called from refreshData");
        displayBandData();

        Log.d("Setting position", "Setting position in refreshData to " + String.valueOf(listPosition));
        bandNamesList.setSelection(listPosition);

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
        inBackground = false;

        Log.d(TAG, notificationTag + " In onResume - 2");
        refreshNewData();

        Log.d(TAG, notificationTag + " In onResume - 3");
        bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            // argument position gives the index of item which is clicked
            public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {

                try {
                    showClickChoices(position);
                } catch (Exception error) {
                    Log.e("Unable to find band", error.toString());
                    System.exit(0);
                }
            }
        });

        handleSearch();

        Log.d(TAG, notificationTag + " In onResume - 4");
        if (listState != null) {
            Log.d("State Status", "restoring state during Resume");
            bandNamesList.onRestoreInstanceState(listState);
        }

        Log.d(TAG, notificationTag + " In onResume - 5");
        registerReceiver();

        Log.d(TAG, notificationTag + " In onResume - 6");

        Log.d(TAG, notificationTag + " calling showNotification");
        showNotification();

        subscribeToAlerts();

        Log.d(TAG, notificationTag + " In onResume - 7");
        Log.d("Setting position", "Setting position in onResume to " + String.valueOf(listPosition));
        bandNamesList.setSelection(listPosition);

        Log.d(TAG, notificationTag + " In onResume - 8");


    }

    public void showClickChoices(final int position) {

        final String selectedBand = listHandler.bandNamesIndex.get(position);

        currentListForDetails = listHandler.bandNamesIndex;
        currentListPosition = position;

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

        getWindow().getDecorView().findViewById(android.R.id.content).invalidate();

        BandInfo.setSelectedBand(selectedBand);

        Intent showDetails = new Intent(showBands.this, showBandDetails.class);
        startActivity(showDetails);
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
        FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.mainAlertChannel);
        FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.testAlertChannel);
        if (staticVariables.preferences.getAlertForUnofficalEvents() == true) {
            //FirebaseMessaging.getInstance().subscribeToTopic("topic/" + staticVariables.unofficalAlertChannel);
            FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.unofficalAlertChannel);
        } else {
            //FirebaseMessaging.getInstance().unsubscribeFromTopic("topic/" + staticVariables.unofficalAlertChannel);
            FirebaseMessaging.getInstance().unsubscribeFromTopic(staticVariables.unofficalAlertChannel);
        }
    }

    @Override
    public void onPrepared(MediaPlayer mediaPlayer) {

    }

    class AsyncListViewLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {

            Log.d("DisplayListData", "Refresh Stage = Pre-Start");
            super.onPreExecute();
            if (staticVariables.loadingBands == false) {

                Log.d("DisplayListData", "onPreExecuteRefresh - 1");
                staticVariables.loadingBands = true;
                Log.d("AsyncList refresh", "Starting AsyncList refresh");
                refreshData();
                staticVariables.loadingBands = false;
                Log.d("DisplayListData", "onPreExecuteRefresh - 2");

            }
            Log.d("Refresh", "Refresh Stage = Pre-Stop");
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            Log.d("Refresh", "Refresh Stage = Background-Start");
            while (staticVariables.loadingBands == true) {
                Log.d("bandInfo", "Waiting for background process to finish");
                SystemClock.sleep(2000);
            }
            staticVariables.loadingBands = true;

            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading data");

            try {
                BandInfo bandInfo = new BandInfo();
                bandInfo.DownloadBandFile();

                AsyncNotesLoader myNotesTask = new AsyncNotesLoader();
                myNotesTask.execute();

            } catch (Exception error) {
                Log.d("bandInfo", error.getMessage());
            }
            staticVariables.loadingBands = false;


            Log.d("Refresh", "Refresh Stage = Background-Stop");
            return result;

        }


        @Override
        protected void onPostExecute(ArrayList<String> result) {

            Log.d("Refresh", "Refresh Stage = Post-Start");
            //if (staticVariables.loadingBands == false) {

                refreshData();

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 1");

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 2");
                showBands.this.bandNamesList.setVisibility(View.VISIBLE);
                showBands.this.bandNamesList.requestLayout();

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 3");
                bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
                bandNamesPullRefresh.setRefreshing(false);

                fileDownloaded = true;

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 4");
                Log.d("Setting position", "Setting position in onPostExecute to " + String.valueOf(listPosition));
                bandNamesList.setSelection(listPosition);

                Log.d("onPostExecuteRefresh", "onPostExecuteRefresh - 5");


                Log.d("DisplayListData", "Refresh Stage = Post-Stop");
            //}
        }
    }


    class AsyncNotesLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            while (staticVariables.loadingNotes == true) {
                SystemClock.sleep(2000);
            }
            staticVariables.loadingNotes = true;

            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading data");

            try {

                //get the descriptionMap
                bandNotes.getDescriptionMap();

                //download all descriptions in the background
                bandNotes.getAllDescriptions();

                //download all band logos in the background
                ImageHandler imageHandler = new ImageHandler();
                imageHandler.getAllRemoteImages();

            } catch (Exception error) {
                //Log.d("bandInfo", error.getMessage());
            }
            staticVariables.loadingNotes = false;


            return result;

        }
    }
}
