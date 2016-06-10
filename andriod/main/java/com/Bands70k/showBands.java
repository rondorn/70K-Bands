package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.StrictMode;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.ToggleButton;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;

import java.util.ArrayList;

public class showBands extends Activity {

    private ArrayList<String> bandNames;
    public ArrayList<String> scheduleSortedBandNames;
    private ListView bandNamesList;

    private ArrayList<String> rankedBandNames;

    private ProgressBar progressBar;
    private BandInfo bandInfo;
    public Button sortButton;
    private preferencesHandler preferences = new preferencesHandler();

    public static Boolean inBackground = true;

    private static final int PLAY_SERVICES_RESOLUTION_REQUEST = 9000;
    private static final String TAG = "MainActivity";

    private BroadcastReceiver mRegistrationBroadcastReceiver;
    private boolean isReceiverRegistered;

    private mainListHandler listHandler;

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
                        .getBoolean(staticVariables.SENT_TOKEN_TO_SERVER, false);
            }
        };

        // Registering BroadcastReceiver
        registerReceiver();

        if (checkPlayServices()) {
            // Start IntentService to register this application with GCM.
            Intent intent = new Intent(this, RegistrationIntentService.class);
            startService(intent);
        }

        bandInfo = new BandInfo();
        preferences.loadData();

        populateBandList();
        showNotification();

    }

    private void showNotification(){

        if (MyGcmListenerService.messageString != null) {

            if (MyGcmListenerService.messageString.contains(".intent.")){
                MyGcmListenerService.messageString = null;

            } else {
                new AlertDialog.Builder(this)
                        .setTitle("70K Bands Message")
                        .setMessage(MyGcmListenerService.messageString)
                        .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                                // continue with delete
                            }
                        })
                        .setIcon(android.R.drawable.ic_dialog_alert)
                        .show();
                MyGcmListenerService.messageString = null;
            }
        }
    }

    public void setupNoneFilterButtons() {

        Button refreshButton = (Button) findViewById(R.id.refresh);

        refreshButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                setContentView(R.layout.activity_show_bands);
                staticVariables.fileDownloaded = false;
                staticVariables.refreshActivated = true;
                populateBandList();
                Intent showDetails = new Intent(showBands.this, showBands.class);
                startActivity(showDetails);

            }
        });

        Button preferencesButton = (Button) findViewById(R.id.preferences);

        preferencesButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                Intent showPreferences = new Intent(showBands.this, preferenceLayout.class);
                startActivity(showPreferences);
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
                if (staticVariables.sortBySchedule == true) {
                    staticVariables.sortBySchedule = false;
                } else {
                    staticVariables.sortBySchedule = true;
                }
                setSortButton();
                Intent showBandList = new Intent(showBands.this, showBands.class);
                startActivity(showBandList);
            }
        });
    }

    private String buildShareMessage(){

        String message = "These are the bands I MUST see on the 70,000 Tons Cruise\n\n";

        for (String band: bandNames){
            String bandRank = rankStore.getRankForBand(band);
            Log.d("BandRank", bandRank);
            if (bandRank.equals(staticVariables.mustSeeIcon)) {
                message += staticVariables.mustSeeIcon + "\t" + band + "\n";
            }
        }

        message += "\n\nhttp://www.facebook.com/70kBands";
        return message;
    }

    public void setupButtonFilters(){

        staticVariables.staticVariablesInitialize();

        ToggleButton mustFilterButton = (ToggleButton)findViewById(R.id.mustSeeFilter);
        mustFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug));

        if (staticVariables.filterToogle.get(staticVariables.mustSeeIcon) == true) {
            Log.d("filter is ", "true");
            mustFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug));
            mustFilterButton.setChecked(true);

        } else {
            mustFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.beer_mug_alt));
            mustFilterButton.setChecked(false);
        }

        ToggleButton mightFilterButton = (ToggleButton)findViewById(R.id.mightSeeFilter);
        mightFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark));

        if (staticVariables.filterToogle.get(staticVariables.mightSeeIcon) == true) {
            mightFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark));
            mightFilterButton.setChecked(true);

        } else {
            mightFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.heavy_checkmark_alt));
            mightFilterButton.setChecked(false);
        }

        ToggleButton wontFilterButton = (ToggleButton)findViewById(R.id.wontSeeFilter);
        wontFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign));

        if (staticVariables.filterToogle.get(staticVariables.wontSeeIcon) == true) {
            wontFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign));
            wontFilterButton.setChecked(true);

        } else {
            wontFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.no_entrysign_alt));
            wontFilterButton.setChecked(false);
        }

        ToggleButton unknownFilterButton = (ToggleButton)findViewById(R.id.unknownFilter);
        unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.black_questionmark));

        if (staticVariables.filterToogle.get(staticVariables.unknownIcon) == true) {
            unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.black_questionmark));
            unknownFilterButton.setChecked(true);

        } else {
            unknownFilterButton.setBackgroundDrawable(getResources().getDrawable(R.drawable.black_questionmark_alt));
            unknownFilterButton.setChecked(false);
        }

        mustFilterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(staticVariables.mustSeeIcon);
            }
        });
        mightFilterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(staticVariables.mightSeeIcon);
            }
        });
        wontFilterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(staticVariables.wontSeeIcon);
            }
        });
        unknownFilterButton.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                toogleDisplayFilter(staticVariables.unknownIcon);
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

        bandNamesList = (ListView)findViewById(R.id.bandNames);

        if (staticVariables.fileDownloaded == false) {
            refreshNewData();

        } else {
            reloadData();
        }
    }

    private void refreshNewData(){

        RelativeLayout showBandLayout = (RelativeLayout)findViewById(R.id.showBandsView);
        showBandLayout.invalidate();
        showBandLayout.requestLayout();

        Log.d("BandData Loaded", "from Internet");

        AsyncListViewLoader mytask = new AsyncListViewLoader();
        mytask.execute();

        scheduleAlertHandler alerts = new scheduleAlertHandler(preferences, getApplicationContext());
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

        if (staticVariables.fileDownloaded == true) {
            Log.d("BandData Loaded", "from Cache");

            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            ListAdapter arrayAdapter = updateList(bandInfo, bandNames);

            bandNamesList.setAdapter(arrayAdapter);
            bandNamesList.requestLayout();

            progressBar = (ProgressBar) findViewById(R.id.progressBar);
            progressBar.setVisibility(View.INVISIBLE);

        }
    }

    private void refreshData(){

        if (staticVariables.refreshActivated == false) {


            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            ListAdapter arrayAdapter = updateList(bandInfo, bandNames);

            bandNamesList.setAdapter(arrayAdapter);
        } else {
            staticVariables.refreshActivated = false;
        }
    }

    @Override
    public void onBackPressed(){
        moveTaskToBack(true);
    }


    public void toogleDisplayFilter(String value){

        Log.d("Value for displayFilter is ", "'" + value + "'");
        if (staticVariables.filterToogle.get(value) == true){
            staticVariables.filterToogle.put(value, false);
        } else {
            staticVariables.filterToogle.put(value, true);
        }

        Intent showBands = new Intent(com.Bands70k.showBands.this, com.Bands70k.showBands.class);
        startActivity(showBands);

    }

    @Override
    public void onPause() {
        staticVariables.listState = bandNamesList.onSaveInstanceState();
        Log.d("State Status", "Saving state during Pause");
        super.onPause();

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
                    new IntentFilter(staticVariables.REGISTRATION_COMPLETE));
            isReceiverRegistered = true;
        }
    }
    /**
     * Check the device to make sure it has the Google Play Services APK. If
     * it doesn't, display a dialog that allows users to download the APK from
     * the Google Play Store or enable it in the device's system settings.
     */
    private boolean checkPlayServices() {
        GoogleApiAvailability apiAvailability = GoogleApiAvailability.getInstance();
        int resultCode = apiAvailability.isGooglePlayServicesAvailable(this);
        if (resultCode != ConnectionResult.SUCCESS) {
            if (apiAvailability.isUserResolvableError(resultCode)) {
                apiAvailability.getErrorDialog(this, resultCode, PLAY_SERVICES_RESOLUTION_REQUEST)
                        .show();
            } else {
                Log.i(TAG, "This device is not supported.");
                finish();
            }
            return false;
        }
        return true;
    }

    @Override
    public void onResume() {

        super.onResume();
        inBackground = false;

        bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            // argument position gives the index of item which is clicked
            public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {

                try {
                    String selectedBand;
                    getWindow().getDecorView().findViewById(android.R.id.content).invalidate();

                    if (scheduleSortedBandNames == null) {
                        scheduleSortedBandNames = bandNames;
                    }
                    selectedBand = listHandler.bandNamesIndex.get(position);

                    Log.d("The follow band was clicked ", selectedBand);

                    BandInfo.setSelectedBand(selectedBand);

                    Intent showDetails = new Intent(showBands.this, showBandDetails.class);
                    startActivity(showDetails);
                } catch (Exception error) {
                    Log.e("Unable to find band", error.toString());
                    System.exit(0);
                }
            }
        });
        if(staticVariables.listState != null) {
            Log.d("State Status", "restoring state during Resume");
            bandNamesList.onRestoreInstanceState(staticVariables.listState);
        }
        setupNoneFilterButtons();
        setupButtonFilters();
        registerReceiver();

        showNotification();

    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();
        staticVariables.listState  = bandNamesList.onSaveInstanceState();
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
            if (staticVariables.sortBySchedule == true) {
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

        listHandler = new mainListHandler(showBands.this, preferences);
        listHandler.populateBandInfo(bandInfo, bandList);
        setSortButton();

        ListAdapter arrayAdapter = listHandler.arrayAdapter;

        return arrayAdapter;
    }

    class AsyncListViewLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {

            super.onPreExecute();
            progressBar = (ProgressBar) findViewById(R.id.progressBar);
            progressBar.setVisibility(View.VISIBLE);
            super.onPreExecute();
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading data");

            try {
                BandInfo bandInfo = new BandInfo();
                bandInfo.DownloadBandFile();
            } catch (Exception error){
                Log.d("bandInfo", error.getMessage());
            }

            return result;

        }


        @Override
        protected void onPostExecute(ArrayList<String> result) {

            BandInfo bandInfo = new BandInfo();
            ArrayList<String> bandList = bandInfo.getBandNames();

            ListAdapter arrayAdapter = updateList(bandInfo, bandList);

            showBands.this.bandNamesList.setAdapter(arrayAdapter);
            progressBar.setVisibility(View.INVISIBLE);

            showBands.this.bandNamesList.requestLayout();
            staticVariables.fileDownloaded = true;
        }
    }
}