package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.StrictMode;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.support.annotation.NonNull;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.LocalBroadcastManager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AbsListView;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.ImageButton;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.ToggleButton;

import com.baoyz.swipemenulistview.SwipeMenu;
import com.baoyz.swipemenulistview.SwipeMenuCreator;
import com.baoyz.swipemenulistview.SwipeMenuItem;
import com.baoyz.swipemenulistview.SwipeMenuListView;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.InstanceIdResult;
import com.google.firebase.messaging.FirebaseMessaging;

import java.util.ArrayList;
import java.util.List;

import static com.Bands70k.staticVariables.*;
import static java.lang.Thread.sleep;


public class showBands extends Activity {

    String notificationTag = "notificationTag";

    public static String newRootDir =  Environment.getExternalStorageDirectory().toString();

    private ArrayList<String> bandNames;
    public List<String> scheduleSortedBandNames = new ArrayList<String>();

    private SwipeMenuListView bandNamesList;
    private SwipeRefreshLayout bandNamesPullRefresh;

    private ArrayList<String> rankedBandNames;

    private BandInfo bandInfo;
    private CustomerDescriptionHandler bandNotes;
    public Button sortButton;
    public Button willAttendFilterButton;

    public static Boolean inBackground = true;

    //private static final int PLAY_SERVICES_RESOLUTION_REQUEST = 9000;
    private static final String TAG = "MainActivity";

    private BroadcastReceiver mRegistrationBroadcastReceiver;
    private boolean isReceiverRegistered;

    private mainListHandler listHandler;
    private bandListView adapter;
    private ListView listView;

    private Boolean loadOnceStopper = false;

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
    @Override
    protected void onCreate(Bundle savedInstanceState) {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            int permission = ActivityCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
            if (permission != 0) {
                requestPermissions(INITIAL_PERMS, REQUEST);
                while (permission != 0) {
                    permission = ActivityCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
                }
            }
        } else {
            newRootDir =Bands70k.getAppContext().getFilesDir().getPath();
        }

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

        //get FCM token for testing
        FirebaseInstanceId.getInstance().getInstanceId()
                .addOnCompleteListener(new OnCompleteListener<InstanceIdResult>() {
                    @Override
                    public void onComplete(@NonNull Task<InstanceIdResult> task) {
                        if (!task.isSuccessful()) {
                            Log.w(TAG, "getInstanceId failed", task.getException());
                            return;
                        }
                        // Get new Instance ID token
                        String token = task.getResult().getToken();
                        Log.d(TAG, "FCM Token Is " + token);
                    }
                });

        if (staticVariables.attendedHandler == null){
            staticVariables.attendedHandler = new showsAttended();
        }

        staticVariablesInitialize();
        bandInfo = new BandInfo();
        bandNotes = new CustomerDescriptionHandler();

        scheduleAlertHandler alertHandler = new scheduleAlertHandler();
        //alertHandler.sendLocalAlert("Testing after 10 seconds", 5);

        Log.d("prefsData", "Show Unknown 1  = " + staticVariables.preferences.getShowUnknown());

        TextView jumpToTop = (TextView) findViewById(R.id.headerBandCount);
        jumpToTop.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                bandNamesList.setSelectionAfterHeaderView();
            }
        });

        bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
        bandNamesPullRefresh.setOnRefreshListener(
                new SwipeRefreshLayout.OnRefreshListener() {
                    @Override
                    public void onRefresh() {

                        new Handler().postDelayed(new Runnable() {
                            @Override public void run() {
                                bandNamesPullRefresh.setRefreshing(false);
                            }
                        }, 5000);

                        Log.i("AsyncList refresh", "onRefresh called from SwipeRefreshLayout");

                        //start spinner and stop after 5 seconds
                        bandNamesPullRefresh.setRefreshing(true);
                        refreshNewData();

                    }

                }

        );

        Log.d(TAG, "2 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());
        populateBandList();
        showNotification();
        setFilterDefaults();

        setupButtonFilters();
        Log.d(TAG, "3 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());

        FirebaseUserWrite userDataWrite = new FirebaseUserWrite();
        userDataWrite.writeData();
    }

    private void setupSwipeList (){

        List<String> sortedList = new ArrayList<>();

        if (scheduleSortedBandNames != null){
            if (scheduleSortedBandNames.size()  > 0) {
                sortedList = scheduleSortedBandNames;

            } else {
                sortedList = bandNames;
            }
        } else {
            sortedList = bandNames;
        }

        Integer screenWidth = Resources.getSystem().getDisplayMetrics().widthPixels;
        final Integer menuWidth = screenWidth/6;

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


                if (listHandler == null){
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
                    if (listPosition == 1){
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

    private void setupOnSwipeListener(){

        bandNamesList.setOnMenuItemClickListener(new SwipeMenuListView.OnMenuItemClickListener() {

            @Override
            public boolean onMenuItemClick(int position, SwipeMenu menu, int index) {

                String bandIndex = scheduleSortedBandNames.get(position);

                String bandName = getBandNameFromIndex(bandIndex);
                Long timeIndex = getTimeIndexFromIndex(bandIndex);

                listState = bandNamesList.onSaveInstanceState();

                Log.d ("setupOnSwipeListener", "Index of " + index + " working on band = " + bandName + " and timeindex of " + String.valueOf(timeIndex));
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
                        Log.d ("attendedValue", "attendedValue = " + attendedValue);

                        if (timeIndex != 0) {
                            String location = listHandler.getLocation(bandName, timeIndex);
                            String startTime = listHandler.getStartTime(bandName, timeIndex);
                            String eventType = listHandler.getEventType(bandName, timeIndex);

                            String status = attendedHandler.addShowsAttended(bandName, location, startTime, eventType);
                            message = attendedHandler.setShowsAttendedStatus(status);
                        } else {
                            message = "No Show Is Associated With This Entry";
                        }
                        HelpMessageHandler.showMessage(message);
                        break;
                }

                refreshData();
                bandNamesList.onRestoreInstanceState(listState);

                return false;
            }
        });
    }

    private void showNotification(){

        String messageString = "";
        Intent intent = getIntent();
        if (intent.hasExtra("messageString") == true) {
            messageString = intent.getStringExtra("messageString");
            Log.d(TAG, notificationTag + " Using messageString");

        } else if (intent.hasExtra("messageText") == true) {
            messageString = intent.getStringExtra("messageText");
            Log.d(TAG, notificationTag + " Using messageText");

        } else if (MyFcmListenerService.messageString != null){
            messageString = MyFcmListenerService.messageString;
            Log.d(TAG, notificationTag + " MyFcmListenerService.messageString");
            MyFcmListenerService.messageString = null;
        }

        Log.d(TAG, notificationTag + " in showNotification");

        if (!messageString.isEmpty()) {
            Log.d(TAG, notificationTag + " messageString has value");
            if (messageString.contains(".intent.")){
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

    public void setupNoneFilterButtons() {

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

                String shareBody;
                String subject;

                if (staticVariables.showsIwillAttend > 0 && listHandler.numberOfEvents != listHandler.numberOfUnofficalEvents){
                    showsAttendedReport reportHandler = new showsAttendedReport();
                    reportHandler.assembleReport();
                    shareBody = reportHandler.buildMessage();
                    subject = "These are the events I attended on the 70,000 Tons Cruise";

                } else {
                    shareBody = buildShareMessage();
                    subject = "Bands I MUST see on 70,000 Tons";
                }

                Log.d("ShareMessage", shareBody);
                sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, subject);
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, shareBody);
                startActivity(Intent.createChooser(sharingIntent, "Share via"));
            }
        });

        sortButton = (Button) findViewById(R.id.sort);
        sortButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {

                setContentView(R.layout.activity_show_bands);

                if (staticVariables.preferences.getSortByTime() == true) {
                    HelpMessageHandler.showMessage(getString(R.string.SortingAlphabetically));
                    staticVariables.preferences.setSortByTime(false);
                } else {
                    staticVariables.preferences.setSortByTime(true);
                    HelpMessageHandler.showMessage(getString(R.string.SortingChronologically));
                }
                setSortButton();
                Intent showBandList = new Intent(showBands.this, showBands.class);
                startActivity(showBandList);
                finish();
            }
        });

        willAttendFilterButton = (Button) findViewById(R.id.willAttendFilter);
        willAttendFilterButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                setShowAttendedFilter();
                Intent showBandList = new Intent(showBands.this, showBands.class);
                startActivity(showBandList);
                finish();
            }
        });
    };

    private void setShowAttendedFilter(){

        ToggleButton showAttendedFilterButton = (ToggleButton) findViewById(R.id.willAttendFilter);

        if (staticVariables.preferences.getShowWillAttend() == false) {
            HelpMessageHandler.showMessage(getString(R.string.showAttendedFilterTrueHelp));

            showAttendedFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicAttended));
            showAttendedFilterButton.setChecked(true);
            staticVariables.preferences.setShowWillAttend(true);
            turnOffMustMightWont();

        } else {
            HelpMessageHandler.showMessage(getString(R.string.showAttendedFilterFalseHelp));

            showAttendedFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicAttendedAlt));
            showAttendedFilterButton.setChecked(false);
            staticVariables.preferences.setShowWillAttend(false);
            setFilterDefaults();
        }

    }

    private void turnOffMustMightWont(){
        ToggleButton mustFilterButton = (ToggleButton) findViewById(R.id.mustSeeFilter);
        mustFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMustSeeAlt));
        mustFilterButton.setEnabled(false);

        ToggleButton mightFilterButton = (ToggleButton) findViewById(R.id.mightSeeFilter);
        mightFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMightSeeAlt));
        mightFilterButton.setEnabled(false);

        ToggleButton wontFilterButton = (ToggleButton) findViewById(R.id.wontSeeFilter);
        wontFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicWontSeeAlt));
        wontFilterButton.setEnabled(false);

        ToggleButton unknownFilterButton = (ToggleButton) findViewById(R.id.unknownFilter);
        unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicUnknownSeeAlt));
        unknownFilterButton.setEnabled(false);
    }

    private void setFilterDefaults(){

        if (staticVariables.initializedSortButtons == false) {

            staticVariables.initializedSortButtons = true;

            Log.d(TAG, "1 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());

            ToggleButton mustFilterButton = (ToggleButton) findViewById(R.id.mustSeeFilter);
            if (staticVariables.preferences.getShowMust() == true) {
                mustFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMustSee));
                mustFilterButton.setChecked(false);
                filterToogle.put(mustSeeIcon, true);
            } else {
                mustFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMustSeeAlt));
                mustFilterButton.setChecked(true);
                filterToogle.put(mustSeeIcon, false);
            }

            ToggleButton mightFilterButton = (ToggleButton) findViewById(R.id.mightSeeFilter);
            if (staticVariables.preferences.getShowMight() == true) {
                mightFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMightSee));
                mightFilterButton.setChecked(false);
                filterToogle.put(mightSeeIcon, true);
            } else {
                mightFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMightSeeAlt));
                mightFilterButton.setChecked(true);
                filterToogle.put(mightSeeIcon, false);
            }

            ToggleButton wontFilterButton = (ToggleButton) findViewById(R.id.wontSeeFilter);
            if (staticVariables.preferences.getShowWont() == true) {
                wontFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicWontSee));
                wontFilterButton.setChecked(false);
                filterToogle.put(wontSeeIcon, true);
            } else {
                wontFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicWontSeeAlt));
                wontFilterButton.setChecked(true);
                filterToogle.put(wontSeeIcon, false);
            }

            ToggleButton unknownFilterButton = (ToggleButton) findViewById(R.id.unknownFilter);
            if (staticVariables.preferences.getShowUnknown() == true) {
                unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicUnknownSee));
                unknownFilterButton.setChecked(false);
                filterToogle.put(unknownIcon, true);
            } else {
                unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicUnknownSeeAlt));
                unknownFilterButton.setChecked(true);
                filterToogle.put(unknownIcon, false);
            }

            Log.d(TAG, "settingFilter for ShowWillAttend is " + staticVariables.preferences.getShowWillAttend());
        }
    }

    private void setShowAttendedFilterButton(){

        ToggleButton showAttendedFilterButton = (ToggleButton) findViewById(R.id.willAttendFilter);

        if (listHandler.numberOfEvents != 0 && staticVariables.showsIwillAttend != 0) {
            showAttendedFilterButton.setEnabled(true);
            showAttendedFilterButton.setClickable(true);
            showAttendedFilterButton.setVisibility(View.VISIBLE);

            if (staticVariables.preferences.getShowWillAttend() == true) {
                showAttendedFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicAttended));
                showAttendedFilterButton.setChecked(true);

                turnOffMustMightWont();

            } else {
                showAttendedFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicAttendedAlt));
                showAttendedFilterButton.setChecked(false);
                staticVariables.preferences.setShowWillAttend(false);
            }
        } else {
            showAttendedFilterButton.setEnabled(false);
            showAttendedFilterButton.setClickable(false);
            showAttendedFilterButton.setVisibility(View.INVISIBLE);
            setupButtonFilters();

        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if(resultCode==RESULT_OK){
            ///Intent refresh = new Intent(this, showBands.class);
            //startActivity(refresh);
            //finish();
        }
    }

    private String buildShareMessage(){

        String message = mustSeeIcon + " These are the bands I MUST see on the 70,000 Tons Cruise\n\n";

        for (String band: bandNames){
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(mustSeeIcon)) {
                message += "\t\t" + band + "\n";
            }
        }
        message += "\n" + mightSeeIcon + " These are the bands I might see\n\n";

        for (String band: bandNames){
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(mightSeeIcon)) {
                message += "\t\t" + band + "\n";
            }
        }

        message += "\n\nhttp://www.facebook.com/70kBands";
        return message;
    }

    public void setupButtonFilters(){

        ToggleButton mustFilterButton = (ToggleButton)findViewById(R.id.mustSeeFilter);
        mustFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMustSee));

        if (filterToogle.get(mustSeeIcon) == true) {
            setMustFilterButton(mustFilterButton, false);

        } else {
            setMustFilterButton(mustFilterButton, true);
        }

        ToggleButton mightFilterButton = (ToggleButton)findViewById(R.id.mightSeeFilter);
        mightFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMightSee));

        if (filterToogle.get(mightSeeIcon) == true) {
            setMightFilterButton(mightFilterButton, false);
        } else {
            setMightFilterButton(mightFilterButton, true);
        }

        ToggleButton wontFilterButton = (ToggleButton)findViewById(R.id.wontSeeFilter);
        wontFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicWontSee));

        if (filterToogle.get(wontSeeIcon) == true) {
            setWontFilterButton(wontFilterButton, false);

        } else {
            setWontFilterButton(wontFilterButton, true);
        }

        ToggleButton unknownFilterButton = (ToggleButton)findViewById(R.id.unknownFilter);
        unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicUnknownSee));

        if (filterToogle.get(unknownIcon) == true) {
            setUnknownFilterButton(unknownFilterButton, false);

        } else {
            setUnknownFilterButton(unknownFilterButton, true);
        }

        staticVariables.preferences.saveData();
    }

    private void setMustFilterButton(ToggleButton filterButton, Boolean setTo){
        if (setTo == false) {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMustSee));
            staticVariables.preferences.setshowMust(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMustSeeAlt));
            staticVariables.preferences.setshowMust(false);
        }

        filterButton.setChecked(setTo);
        staticVariables.preferences.saveData();


        filterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(mustSeeIcon);
            }
        });


    }
    private void setMightFilterButton(ToggleButton filterButton, Boolean setTo){
        if (setTo == false) {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMightSee));
            staticVariables.preferences.setshowMight(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicMightSeeAlt));
            staticVariables.preferences.setshowMight(false);
        }
        filterButton.setChecked(setTo);
        staticVariables.preferences.saveData();

        filterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(mightSeeIcon);
            }
        });
    }
    private void setWontFilterButton(ToggleButton filterButton, Boolean setTo){
        if (setTo == false) {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicWontSee));
            staticVariables.preferences.setshowWont(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicWontSeeAlt));
            staticVariables.preferences.setshowWont(false);
        }
        filterButton.setChecked(setTo);
        staticVariables.preferences.saveData();

        filterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(wontSeeIcon);
            }
        });
    }
    private void setUnknownFilterButton(ToggleButton filterButton, Boolean setTo){
        if (setTo == false) {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicUnknownSee));
            staticVariables.preferences.setshowUnknown(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(staticVariables.graphicUnknownSeeAlt));
            staticVariables.preferences.setshowUnknown(false);
        }
        filterButton.setChecked(setTo);
        staticVariables.preferences.saveData();

        filterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(unknownIcon);
            }
        });
    }


    @Override
    public
    boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_show_bands, menu);
        return true;
    }

    public void populateBandList(){

        bandNamesList = (SwipeMenuListView) findViewById(R.id.bandNames);

        if (fileDownloaded == false) {
            refreshNewData();

        } else {
            reloadData();
        }

        setupSwipeList();
    }

    private void setFilterButton() {

        //if (listHandler.allUpcomingEvents == 0 || staticVariables.preferences.getShowWillAttend() == true) {
        //    filterButton.setVisibility(View.INVISIBLE);
        //} else {
        //    if (staticVariables.preferences.getShowWillAttend() == false) {
        //        filterButton.setVisibility(View.VISIBLE);
        //    }
        //}
    }

    private void refreshNewData(){

        RelativeLayout showBandLayout = (RelativeLayout)findViewById(R.id.showBandsView);
        showBandLayout.invalidate();
        showBandLayout.requestLayout();

        Log.d("BandData Loaded", "from Internet");

        AsyncListViewLoader mytask = new AsyncListViewLoader();
        mytask.execute();

        AsyncNotesLoader myNotesTask = new AsyncNotesLoader();
        myNotesTask.execute();

        scheduleAlertHandler alerts = new scheduleAlertHandler();
        alerts.execute();

        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("DisplayListData", "finished display header " + headerText);

        if (headerText.equals("70,000 Tons")){
            Log.d("DisplayListData", "running extra refresh");
            displayBandData();
        }

    }

    public void onStop() {

        super.onStop();
        inBackground = true;

        FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
        bandWrite.writeData();

        FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
        eventWrite.writeData();
    }

    private void reloadData (){

        if (fileDownloaded == true) {
            Log.d("BandData Loaded", "from Cache");

            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            Log.d("Setting position", "Setting position in reloadData to " + String.valueOf(listPosition));
            bandNamesList.setSelection(listPosition);

            scheduleAlertHandler alerts = new scheduleAlertHandler();
            alerts.execute();

        }
    }


    private String getBandNameFromIndex(String index){

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

        if (bandName.isEmpty() == true){
            bandName = indexSplit[0];
        }

        return bandName;
    }

    private Long getTimeIndexFromIndex(String index){

        Long timeIndex = Long.valueOf(0);

        String[] indexSplit = index.split(":");

        if (indexSplit.length == 2) {

            try {
                timeIndex = Long.valueOf(indexSplit[0]);

            } catch (NumberFormatException e) {
                timeIndex = Long.valueOf(indexSplit[1]);
            }
        }

        return timeIndex;
    }

    private void displayBandData(){

        Log.d("DisplayListData", "starting display ");

        displayBandDataWithSchedule();
    }

    private void displayBandDataWithSchedule(){

        adapter = new bandListView(getApplicationContext(), R.layout.bandlist70k);
        bandNamesList.setAdapter(adapter);

        BandInfo bandInfoNames = new BandInfo();

        bandNames = bandInfoNames.getBandNames();

        if (bandNames.size() == 0){
            bandNames.add("Waiting for data to load, please standby....");
        }

        rankedBandNames = bandInfo.getRankedBandNames(bandNames);
        rankStore.getBandRankings();

        listHandler = new mainListHandler(showBands.this);


        scheduleSortedBandNames = listHandler.getSortableBandNames();

        if (scheduleSortedBandNames.isEmpty() == true){
            scheduleSortedBandNames = listHandler.populateBandInfo(bandInfo, bandNames);
        }

        if (scheduleSortedBandNames.get(0).contains(":") == false){
            Log.d("DisplayListData", "starting file download ");
            bandInfoNames.DownloadBandFile();
            bandNames = bandInfoNames.getBandNames();
            Log.d("DisplayListData", "starting file download, done ");
        }

        Integer counter = 0;
        for (String bandIndex: scheduleSortedBandNames){

            Log.d("WorkingOnScheduleIndex", "WorkingOnScheduleIndex " + bandIndex);

            String[] indexSplit = bandIndex.split(":");

            if (indexSplit.length == 2) {

                String bandName = getBandNameFromIndex(bandIndex);
                Long timeIndex = getTimeIndexFromIndex(bandIndex);

                String eventYear = String.valueOf(staticVariables.eventYear);

                bandListItem bandItem = new bandListItem(bandName);
                loadOnceStopper = false;

                if (timeIndex > 0) {

                    if (BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex) != null) {

                        scheduleHandler scheduleHandle = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex);
                        String location = scheduleHandle.getShowLocation();
                        String startTime = scheduleHandle.getStartTimeString();
                        String eventType = scheduleHandle.getShowType();
                        String day = scheduleHandle.getShowDay();
                        String attendedIcon = attendedHandler.getShowAttendedIcon(bandName, location, startTime, eventType, eventYear);

                        if (day.contains("Day")) {
                            day = " " + day.replaceAll("Day", "");
                        }

                        Log.d("PopulatingDayValue", "Day = " + day);
                        startTime = dateTimeFormatter.formatScheduleTime(startTime);

                        bandItem.setLocationColor(iconResolve.getLocationColor(location));

                        if (venueLocation.containsKey(location)) {
                            location += " " + venueLocation.get(location);
                        }

                        bandItem.setLocation(location);
                        bandItem.setStartTime(startTime);
                        bandItem.setDay(day);
                        bandItem.setEventTypeImage(iconResolve.getEventIcon(eventType, bandName));
                        bandItem.setAttendedImage(iconResolve.getAttendedIcon(attendedIcon));
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

            if (counter == 0){
                bandListItem bandItem = new bandListItem("Waiting for data to load, please standby....");
                adapter.add(bandItem);
            }
            setFilterButton();

            //swip stuff
            setupSwipeList();

            setSortButton();

            setShowAttendedFilterButton();
        }

        TextView bandCount = (TextView) this.findViewById(R.id.headerBandCount);
        String headerText = String.valueOf(bandCount.getText());
        Log.d("DisplayListData", "finished display " + String.valueOf(counter) + '-' + headerText);
    }


    private void refreshData(){

        Log.d("DisplayListData", "called from refreshData");
        displayBandData();

        Log.d("Setting position", "Setting position in refreshData to " + String.valueOf(listPosition));
        bandNamesList.setSelection(listPosition);

    }

    @Override
    public void onBackPressed(){
        moveTaskToBack(true);
    }


    public void toogleDisplayFilter(String value){

        //Log.d("Value for displayFilter is ", "'" + value + "'");
        if (filterToogle.get(value) == true){
            filterToogle.put(value, false);
        } else {
            filterToogle.put(value, true);
        }

        Intent showBands = new Intent(com.Bands70k.showBands.this, com.Bands70k.showBands.class);
        startActivity(showBands);
        finish();

    }

    @Override
    protected void onDestroy(){
        Log.d("Saving Data", "Saving state during Destroy");
        onPause();
        super.onDestroy();

    }
    @Override
    public void onPause() {
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

    private void registerReceiver(){
        if(!isReceiverRegistered) {
            LocalBroadcastManager.getInstance(this).registerReceiver(mRegistrationBroadcastReceiver,
                    new IntentFilter(REGISTRATION_COMPLETE));
            isReceiverRegistered = true;
        }
    }

    @Override
    public void onResume() {

        Log.d(TAG, notificationTag + " In onResume");
        super.onResume();

        Log.d("DisplayListData", "On Resume refreshNewData");
        inBackground = false;

        refreshNewData();

        bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            // argument position gives the index of item which is clicked
            public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {

                try {
                    String selectedBand;
                    getWindow().getDecorView().findViewById(android.R.id.content).invalidate();

                    selectedBand = listHandler.bandNamesIndex.get(position);

                    //Log.d("The follow band was clicked ", selectedBand);

                    BandInfo.setSelectedBand(selectedBand);

                    Intent showDetails = new Intent(showBands.this, showBandDetails.class);
                    startActivity(showDetails);
                } catch (Exception error) {
                    Log.e("Unable to find band", error.toString());
                    System.exit(0);
                }
            }
        });
        if(listState != null) {
            Log.d("State Status", "restoring state during Resume");
            bandNamesList.onRestoreInstanceState(listState);
        }
        setupNoneFilterButtons();
        //setupButtonFilters();
        registerReceiver();

        //populateBandList();
        Log.d(TAG, notificationTag + " calling showNotification");
        showNotification();

        subscribeToAlerts();

        Log.d("Setting position", "Setting position in onResume to " + String.valueOf(listPosition));
        bandNamesList.setSelection(listPosition);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();
        listState  = bandNamesList.onSaveInstanceState();
        Log.d("State Status", "Saving state");
        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    private void subscribeToAlerts(){
        FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.mainAlertChannel);
        FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.testAlertChannel);
        if (staticVariables.preferences.getAlertForUnofficalEvents() == true){
            //FirebaseMessaging.getInstance().subscribeToTopic("topic/" + staticVariables.unofficalAlertChannel);
            FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.unofficalAlertChannel);
        } else {
            //FirebaseMessaging.getInstance().unsubscribeFromTopic("topic/" + staticVariables.unofficalAlertChannel);
            FirebaseMessaging.getInstance().unsubscribeFromTopic(staticVariables.unofficalAlertChannel);
        }
    }
    public void setSortButton(){

        sortButton = (Button) findViewById(R.id.sort);

        if (listHandler.numberOfEvents != 0) {
            sortButton.setEnabled(true);
            sortButton.setClickable(true);
            sortButton.setVisibility(View.VISIBLE);
            if (staticVariables.preferences.getSortByTime() == true) {
                sortButton.setBackground(getResources().getDrawable(staticVariables.graphicAlphaSort));
                staticVariables.preferences.setSortByTime(true);
            } else {
                sortButton.setBackground(getResources().getDrawable(staticVariables.graphicTimeSort));
                staticVariables.preferences.setSortByTime(false);
            }
        } else {
            sortButton.setEnabled(false);
            sortButton.setVisibility(View.INVISIBLE);
        }
    }

    class AsyncListViewLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {

            super.onPreExecute();
            if (staticVariables.loadingBands == false) {

                staticVariables.loadingBands = true;
                Log.d("AsyncList refresh", "Starting AsyncList refresh");
                refreshData();
                staticVariables.loadingBands = false;

            }
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            if (staticVariables.loadingBands == false) {
                staticVariables.loadingBands = true;

                StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
                StrictMode.setThreadPolicy(policy);

                Log.d("AsyncTask", "Downloading data");

                try {
                    BandInfo bandInfo = new BandInfo();
                    bandInfo.DownloadBandFile();
                    //bandNotes.getAllDescriptions();

                } catch (Exception error) {
                    Log.d("bandInfo", error.getMessage());
                }
                staticVariables.loadingBands = false;
            }
            return result;

        }


        @Override
        protected void onPostExecute(ArrayList<String> result) {

            if (staticVariables.loadingBands == false) {

                Log.d("DisplayListData", "called from postExecute");

                displayBandDataWithSchedule();


                showBands.this.bandNamesList.setVisibility(View.VISIBLE);
                showBands.this.bandNamesList.requestLayout();

                bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
                bandNamesPullRefresh.setRefreshing(false);

                fileDownloaded = true;

                Log.d("Setting position", "Setting position in onPostExecute to " + String.valueOf(listPosition));
                bandNamesList.setSelection(listPosition);


            }
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

            if (staticVariables.loadingNotes == false) {
                staticVariables.loadingNotes = true;

                StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
                StrictMode.setThreadPolicy(policy);

                Log.d("AsyncTask", "Downloading data");

                try {
                    //download all descriptions in the background
                    bandNotes.getAllDescriptions();

                    //download all band logos in the background
                    ImageHandler imageHandler = new ImageHandler();
                    imageHandler.getAllRemoteImages();

                } catch (Exception error) {
                    Log.d("bandInfo", error.getMessage());
                }
                staticVariables.loadingNotes = false;
            }

            return result;

        }
    }
}