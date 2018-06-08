package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.AsyncTask;
import android.os.StrictMode;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.support.v4.content.LocalBroadcastManager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.ListAdapter;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.ToggleButton;

import com.baoyz.swipemenulistview.SwipeMenu;
import com.baoyz.swipemenulistview.SwipeMenuCreator;
import com.baoyz.swipemenulistview.SwipeMenuItem;
import com.baoyz.swipemenulistview.SwipeMenuListView;

import java.util.ArrayList;
import java.util.List;

import static com.Bands70k.staticVariables.*;


public class showBands extends Activity {

    String notificationTag = "notificationTag";

    private ArrayList<String> bandNames;
    public List<String> scheduleSortedBandNames;

    private SwipeMenuListView bandNamesList;
    private SwipeRefreshLayout bandNamesPullRefresh;

    private ArrayList<String> rankedBandNames;

    private BandInfo bandInfo;
    private CustomerDescriptionHandler bandNotes;
    public Button sortButton;

    public static Boolean inBackground = true;

    private static final int PLAY_SERVICES_RESOLUTION_REQUEST = 9000;
    private static final String TAG = "MainActivity";

    private BroadcastReceiver mRegistrationBroadcastReceiver;
    private boolean isReceiverRegistered;

    private mainListHandler listHandler;
    private CustomArrayAdapter adapter;


    @Override
    protected void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
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

        if (staticVariables.preferences == null) {
            staticVariables.preferences = new preferencesHandler();
        }

        staticVariablesInitialize();
        bandInfo = new BandInfo();
        bandNotes = new CustomerDescriptionHandler();
        staticVariables.preferences.loadData();

        Log.d("prefsData", "Show Unknown 1  = " + staticVariables.preferences.getShowUnknown());

        TextView jumpToTop = (TextView) findViewById(R.id.headerBandCount);
        jumpToTop.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                bandNamesList.setSelectionAfterHeaderView();
            }
        });

        populateBandList();
        showNotification();
        setFilterDefaults();

        setupButtonFilters();
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

        adapter = new CustomArrayAdapter(this, R.layout.activity_show_bands, sortedList);

        bandNamesList.setAdapter(adapter);

        SwipeMenuCreator creator = new SwipeMenuCreator() {

            @Override
            public void create(SwipeMenu menu) {
                //create an action that will be showed on swiping an item in the list
                SwipeMenuItem item1 = new SwipeMenuItem(
                        getApplicationContext());
                item1.setBackground(new ColorDrawable(Color.WHITE));
                // set width of an option (px)
                item1.setWidth(155);
                item1.setTitle(mustSeeIcon);
                item1.setTitleSize(18);
                item1.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item1);

                SwipeMenuItem item2 = new SwipeMenuItem(
                        getApplicationContext());
                // set item background
                item2.setBackground(new ColorDrawable(Color.WHITE));
                item2.setWidth(155);
                item2.setTitle(mightSeeIcon);
                item2.setTitleSize(18);
                item2.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item2);

                SwipeMenuItem item3 = new SwipeMenuItem(
                        getApplicationContext());
                // set item background
                item3.setBackground(new ColorDrawable(Color.WHITE));
                item3.setWidth(155);
                item3.setTitle(wontSeeIcon);
                item3.setTitleSize(18);
                item3.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item3);

                SwipeMenuItem item4 = new SwipeMenuItem(
                        getApplicationContext());
                // set item background
                item4.setBackground(new ColorDrawable(Color.WHITE));
                item4.setWidth(155);
                item4.setTitle(unknownIcon);
                item4.setTitleSize(18);
                item4.setTitleColor(Color.LTGRAY);
                menu.addMenuItem(item4);
            }
        };
        //set MenuCreator
        bandNamesList.setMenuCreator(creator);
        // set SwipeListener
        bandNamesList.setOnSwipeListener(new SwipeMenuListView.OnSwipeListener() {

            @Override
            public void onSwipeStart(int position) {
                // swipe start
            }

            @Override
            public void onSwipeEnd(int position) {
                // swipe end
            }
        });

        setupOnSwipeListener();

            /*
        * Sets up a SwipeRefreshLayout.OnRefreshListener that is invoked when the user
        * performs a swipe-to-refresh gesture.
        */

        bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
        bandNamesPullRefresh.setOnRefreshListener(
                new SwipeRefreshLayout.OnRefreshListener() {
                    @Override
                    public void onRefresh() {
                        Log.i("RefreshCalled", "onRefresh called from SwipeRefreshLayout");
                        refreshNewData();
                    }
                }
        );
    }

    private void setupOnSwipeListener(){

        bandNamesList.setOnMenuItemClickListener(new SwipeMenuListView.OnMenuItemClickListener() {

            @Override
            public boolean onMenuItemClick(int position, SwipeMenu menu, int index) {
                String value = listHandler.getBandNameFromIndex(adapter.getItem(position));

                listState = bandNamesList.onSaveInstanceState();

                switch (index) {
                    case 0:
                        rankStore.saveBandRanking(value, mustSeeIcon);
                        break;

                    case 1:
                        rankStore.saveBandRanking(value, mightSeeIcon);
                        break;

                    case 2:
                        rankStore.saveBandRanking(value, wontSeeIcon);
                        break;

                    case 3:
                        rankStore.saveBandRanking(value, unknownIcon);
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

        Button preferencesButton = (Button) findViewById(R.id.preferences);

        preferencesButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                Intent showPreferences = new Intent(showBands.this, preferenceLayout.class);
                startActivityForResult(showPreferences, 1);
            }
        });

        Button filterMenuButton = (Button) findViewById(R.id.filterMenu);

        filterMenuButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                setupButtonFilters();
                Intent showFilterMenu = new Intent(showBands.this, filterMenu.class);
                startActivityForResult(showFilterMenu, 1);
                //startActivity(showFilterMenu);
            }
        });

        Button shareButton = (Button) findViewById(R.id.shareButton);
        shareButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");
                String shareBody = buildShareMessage();
                sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, "Bands I MUST see on 70,000 Tons");
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, shareBody);
                startActivity(Intent.createChooser(sharingIntent, "Share via"));
            }
        });

        sortButton = (Button) findViewById(R.id.sort);
        sortButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View v) {
                setContentView(R.layout.activity_show_bands);
                if (sortBySchedule == true) {
                    sortBySchedule = false;
                } else {
                    sortBySchedule = true;
                }
                setSortButton();
                Intent showBandList = new Intent(showBands.this, showBands.class);
                startActivity(showBandList);
                finish();
            }
        });
    };

    private void setFilterDefaults(){

        if (staticVariables.initializedSortButtons == false) {

            staticVariables.initializedSortButtons = true;

            Log.d(TAG, "1 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());

            ToggleButton mustFilterButton = (ToggleButton) findViewById(R.id.mustSeeFilter);
            if (staticVariables.preferences.getShowMust() == true) {
                mustFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug));
                mustFilterButton.setChecked(false);
                filterToogle.put(mustSeeIcon, true);
            } else {
                mustFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug_alt));
                mustFilterButton.setChecked(true);
                filterToogle.put(mustSeeIcon, false);
            }

            ToggleButton mightFilterButton = (ToggleButton) findViewById(R.id.mightSeeFilter);
            if (staticVariables.preferences.getShowMight() == true) {
                mightFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark));
                mightFilterButton.setChecked(false);
                filterToogle.put(mightSeeIcon, true);
            } else {
                mightFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark_alt));
                mightFilterButton.setChecked(true);
                filterToogle.put(mightSeeIcon, false);
            }

            ToggleButton wontFilterButton = (ToggleButton) findViewById(R.id.wontSeeFilter);
            if (staticVariables.preferences.getShowWont() == true) {
                wontFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign));
                wontFilterButton.setChecked(false);
                filterToogle.put(wontSeeIcon, true);
            } else {
                wontFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign_alt));
                wontFilterButton.setChecked(true);
                filterToogle.put(wontSeeIcon, false);
            }

            ToggleButton unknownFilterButton = (ToggleButton) findViewById(R.id.unknownFilter);
            if (staticVariables.preferences.getShowUnknown() == true) {
                unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark));
                unknownFilterButton.setChecked(false);
                filterToogle.put(unknownIcon, true);
            } else {
                unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark_alt));
                unknownFilterButton.setChecked(true);
                filterToogle.put(unknownIcon, false);
            }

            Log.d(TAG, "2 settingFilters for ShowUnknown is " + staticVariables.preferences.getShowUnknown());
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if(resultCode==RESULT_OK){
            Intent refresh = new Intent(this, showBands.class);
            startActivity(refresh);
            finish();
            refreshNewData();
        }
    }

    private String buildShareMessage(){

        String message = "These are the bands I MUST see on the 70,000 Tons Cruise\n\n";

        for (String band: bandNames){
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(mustSeeIcon)) {
                message += mustSeeIcon + "\t" + band + "\n";
            }
        }

        message += "\n\nhttp://www.facebook.com/70kBands";
        return message;
    }

    public void setupButtonFilters(){

        ToggleButton mustFilterButton = (ToggleButton)findViewById(R.id.mustSeeFilter);
        mustFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug));

        if (filterToogle.get(mustSeeIcon) == true) {
            setMustFilterButton(mustFilterButton, false);

        } else {
            setMustFilterButton(mustFilterButton, true);
        }

        ToggleButton mightFilterButton = (ToggleButton)findViewById(R.id.mightSeeFilter);
        mightFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark));

        if (filterToogle.get(mightSeeIcon) == true) {
            setMightFilterButton(mightFilterButton, false);
        } else {
            setMightFilterButton(mightFilterButton, true);
        }

        ToggleButton wontFilterButton = (ToggleButton)findViewById(R.id.wontSeeFilter);
        wontFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign));

        if (filterToogle.get(wontSeeIcon) == true) {
            setWontFilterButton(wontFilterButton, false);

        } else {
            setWontFilterButton(wontFilterButton, true);
        }

        ToggleButton unknownFilterButton = (ToggleButton)findViewById(R.id.unknownFilter);
        unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.black_questionmark));

        if (filterToogle.get(unknownIcon) == true) {
            setUnknownFilterButton(unknownFilterButton, false);

        } else {
            setUnknownFilterButton(unknownFilterButton, true);
        }

    }

    private void setMustFilterButton(ToggleButton filterButton, Boolean setTo){
        if (setTo == false) {
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug));
            staticVariables.preferences.setshowMust(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug_alt));
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
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark));
            staticVariables.preferences.setshowMight(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark_alt));
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
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign));
            staticVariables.preferences.setshowWont(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign_alt));
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
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.black_questionmark));
            staticVariables.preferences.setshowUnknown(true);
        } else {
            filterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.black_questionmark_alt));
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

        Button filterButton = (Button) findViewById(R.id.filterMenu);

        if (listHandler.allUpcomingEvents == 0) {
            filterButton.setVisibility(View.INVISIBLE);
        } else {
            filterButton.setVisibility(View.VISIBLE);
        }
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

        BandInfo bandInfoNames = new BandInfo();
        bandNames = bandInfoNames.getBandNames();

        rankedBandNames = bandInfo.getRankedBandNames(bandNames);
        rankStore.getBandRankings();

    }

    public void onStop() {

        super.onStop();
        inBackground = true;

    }

    private void reloadData (){

        if (fileDownloaded == true) {
            Log.d("BandData Loaded", "from Cache");

            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            ListAdapter arrayAdapter = updateList(bandInfo, bandNames);

            bandNamesList.setAdapter(arrayAdapter);
            bandNamesList.requestLayout();

            scheduleAlertHandler alerts = new scheduleAlertHandler();
            alerts.execute();

        }
    }


    private void refreshData(){

        if (refreshActivated == false) {


            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            scheduleAlertHandler alerts = new scheduleAlertHandler();
            alerts.execute();

            if (bandNames == null){
                bandNames.add("Waiting for data to load, please standby....");
            }
            ListAdapter arrayAdapter = updateList(bandInfo, bandNames);

            bandNamesList.setAdapter(arrayAdapter);
        } else {
            refreshActivated = false;
        }
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
    public void onPause() {
        listState = bandNamesList.onSaveInstanceState();
        Log.d("State Status", "Saving state during Pause");
        super.onPause();

        staticVariables.preferences.saveData();
        LocalBroadcastManager.getInstance(this).unregisterReceiver(mRegistrationBroadcastReceiver);
        isReceiverRegistered = false;

    }

    @Override
    public void onStart() {
        super.onStart();

        if (listHandler != null){
            refreshData();
        }
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
        inBackground = false;

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

        Log.d(TAG, notificationTag + " calling showNotification");
        showNotification();

    }

    @Override
    protected void onDestroy(){
        super.onDestroy();
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

    public void setSortButton(){

        sortButton = (Button) findViewById(R.id.sort);

        if (listHandler.numberOfEvents != 0) {
            sortButton.setEnabled(true);
            sortButton.setClickable(true);
            sortButton.setVisibility(View.VISIBLE);
            if (sortBySchedule == true) {
                sortButton.setBackground(getResources().getDrawable(android.R.drawable.ic_menu_sort_alphabetically));
            } else {
                sortButton.setBackground(getResources().getDrawable(android.R.drawable.ic_menu_sort_by_size));
            }
        } else {
            sortButton.setEnabled(false);
            sortButton.setVisibility(View.INVISIBLE);
        }
    }

    public ListAdapter updateList(BandInfo bandInfo, ArrayList<String> bandList){

        listHandler = new mainListHandler(showBands.this);
        try {
            scheduleSortedBandNames = listHandler.populateBandInfo(bandInfo, bandList);
        } catch (Exception error){
            try {
                Thread.sleep(4000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            scheduleSortedBandNames = listHandler.populateBandInfo(bandInfo, bandList);
        }

        setFilterButton();

        //swip stuff
        setupSwipeList();

        setSortButton();

        ListAdapter arrayAdapter = listHandler.arrayAdapter;

        return arrayAdapter;
    }

    class AsyncListViewLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {

            if (staticVariables.loadingBands == false) {
                Log.d("AsyncList refresh", "Starting AsyncList refresh");
                super.onPreExecute();
                bandNamesPullRefresh = (SwipeRefreshLayout) findViewById(R.id.swiperefresh);
                bandNamesPullRefresh.setRefreshing(true);
                refreshData();
                super.onPreExecute();
            }
            bandNamesPullRefresh.setRefreshing(true);
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
                    bandNotes.getAllDescriptions();

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
                BandInfo bandInfo = new BandInfo();
                ArrayList<String> bandList = bandInfo.getBandNames();

                ListAdapter arrayAdapter = updateList(bandInfo, bandList);

                showBands.this.bandNamesList.setAdapter(arrayAdapter);
                showBands.this.bandNamesList.setVisibility(View.VISIBLE);
                showBands.this.bandNamesList.requestLayout();
                fileDownloaded = true;
            }
            bandNamesPullRefresh.setRefreshing(false);


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