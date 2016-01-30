package com.Bands70k;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Parcelable;
import android.os.StrictMode;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.Settings;
import android.support.v7.app.NotificationCompat;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ToggleButton;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Iterator;
import java.util.Map;
import java.util.TreeMap;

public class showBands extends Activity {

    private ArrayList<String> bandNames;
    private ArrayList<String> scheduleSortedBandNames;
    private ListView bandNamesList;

    private ArrayList<String> rankedBandNames;
    private ArrayAdapter<String> arrayAdapter;

    private ProgressBar progressBar;
    private BandInfo bandInfo;
    private Button sortButton;
    private preferencesHandler preferences = new preferencesHandler();

    private AlarmManager manager;

    public static int NOTIFICATION_ID = 1;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_show_bands);

        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        setContentView(R.layout.activity_show_bands);
        bandInfo = new BandInfo();
        preferences.loadData();

        populateBandList();

        Intent alarmIntent = new Intent(this, AlarmReceiver.class);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(this, 0, alarmIntent, 0);

        manager = (AlarmManager)getSystemService(Context.ALARM_SERVICE);
        int interval = 60000;
        manager.setExact(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + interval, pendingIntent);
        //manager.setRepeating(AlarmManager.RTC_WAKEUP, System.currentTimeMillis(), interval, pendingIntent);
        Toast.makeText(this, "Alarm Set 10 seconds", Toast.LENGTH_SHORT).show();

        Intent alarmIntent2 = new Intent(this, AlarmReceiver.class);
        PendingIntent pendingIntent2 = PendingIntent.getBroadcast(this, 0, alarmIntent2, 0);
        manager.setExact(AlarmManager.RTC_WAKEUP,System.currentTimeMillis() + 120000,pendingIntent2);
        Toast.makeText(this, "Alarm Set 20 seconds", Toast.LENGTH_SHORT).show();
    }


    public void scheduleNotification(Notification notification, long delay) {

        Intent notificationIntent = new Intent(this, NotificationPublisher.class);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION_ID, 1);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, notification);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(this, 0, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        long futureInMillis = SystemClock.elapsedRealtime() + delay;
        AlarmManager alarmManager = (AlarmManager)getSystemService(Context.ALARM_SERVICE);
        alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, futureInMillis, pendingIntent);
    }

    public Notification getNotification(String content, String bandName) {
        Log.d("Notications", "getNotification was called");

        Notification.Builder builder = new Notification.Builder(this);
        builder.setContentTitle(bandName);
        builder.setContentText(content);
        builder.setSmallIcon(R.drawable.bands_70k_icon);
        return builder.build();
    }

    public void displayNumberOfBands (){
        TextView bandCount = (TextView)findViewById(R.id.headerBandCount);
        bandCount.setText("70,0000 Tons " + bandNames.size() + " bands");
        if(staticVariables.listState != null) {
            Log.d("State Status", "restoring state during Resume");
            bandNamesList.onRestoreInstanceState(staticVariables.listState );
        } else {
            Log.d("State Status", "state is null");
        }
    }


    public void setupNoneFilterButtons() {

        Button refreshButton = (Button) findViewById(R.id.refresh);

        refreshButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                setContentView(R.layout.activity_show_bands);
                staticVariables.fileDownloaded = false;
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
                Intent showDetails = new Intent(showBands.this, showBands.class);
                startActivity(showDetails);
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
            refreshNewData(true);

        } else {
            reloadData();
        }

        displayNumberOfBands();
    }

    private void refreshNewData(Boolean twice){

        RelativeLayout showBandLayout = (RelativeLayout)findViewById(R.id.showBandsView);
        showBandLayout.invalidate();
        showBandLayout.requestLayout();

        Log.d("BandData Loaded", "from Internet");

        AsyncListViewLoader mytask = new AsyncListViewLoader();
        mytask.execute();


        BandInfo bandInfoNames = new BandInfo();
        bandNames = bandInfoNames.getBandNames();

        rankedBandNames = bandInfo.getRankedBandNames(bandNames);
        rankStore.getBandRankings();

    }


    private void reloadData (){

        if (staticVariables.fileDownloaded == true) {
            Log.d("BandData Loaded", "from Cache");

            BandInfo bandInfoNames = new BandInfo();
            bandNames = bandInfoNames.getBandNames();

            rankedBandNames = bandInfo.getRankedBandNames(bandNames);
            rankStore.getBandRankings();

            ListAdapter arrayAdapter = populateBandInfo(bandInfo, bandNames);

            bandNamesList.setAdapter(arrayAdapter);
            bandNamesList.requestLayout();

            progressBar = (ProgressBar) findViewById(R.id.progressBar);
            progressBar.setVisibility(View.INVISIBLE);

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
    }

    @Override
    public void onResume() {

        super.onResume();
        bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            // argument position gives the index of item which is clicked
            public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {

                try {
                    String selectedBand;
                    getWindow().getDecorView().findViewById(android.R.id.content).invalidate();

                    if (scheduleSortedBandNames == null) {
                        scheduleSortedBandNames = bandNames;
                    }
                    selectedBand = scheduleSortedBandNames.get(position);

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

    public void scheduleAlerts(ArrayList<String> bandList){

        if (BandInfo.scheduleRecords != null) {
            if (BandInfo.scheduleRecords.get(bandList.get(0)) != null) {
                for (String bandName : bandList) {
                    Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();
                    while (entries.hasNext()) {
                        Map.Entry thisEntry = (Map.Entry) entries.next();
                        Object key = thisEntry.getKey();

                        shipNotifications.unuiqueNumber++;
                        String alertMessage = bandName + " will go on in " + preferences.getMinBeforeToAlert() + " min";
                        Long alertTime = Long.valueOf(key.toString());



                        //if (alertTime > 0 && bandName.equals("Equilibrium") && tempAlert == true) {
                            Log.d("Notications", "Timing " + bandName + " " + alertTime);
                            SendScheduleAlert alerts = new SendScheduleAlert();
                            Context context = this.getApplicationContext();
                            alerts.setOnetimeTimer(context, alertMessage, alertTime);
                        //}
                    }
                }
            }
        }
    }

    public ListAdapter populateBandInfo(BandInfo bandInfo, ArrayList<String> bandList){

        ListAdapter arrayAdapter;

        if (BandInfo.scheduleRecords != null) {
            if (bandList.size() != 0) {
                if (BandInfo.scheduleRecords.get(bandList.get(0)) != null) {

                    sortButton = (Button) findViewById(R.id.sort);
                    sortButton.setClickable(true);
                    sortButton.setVisibility(View.VISIBLE);
                    if (staticVariables.sortBySchedule == true) {
                        sortButton.setBackground(getResources().getDrawable(android.R.drawable.ic_menu_sort_alphabetically));
                    } else {
                        sortButton.setBackground(getResources().getDrawable(android.R.drawable.ic_menu_sort_by_size));
                    }

                    ArrayList<String> scheduleBandList = new ArrayList<String>();
                    Map<String, String> sortedScheduleBandList = new TreeMap<>();
                    Map<String, String> sortedMapping = new TreeMap<>();
                    for (String bandName : bandList) {
                        Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();
                        while (entries.hasNext()) {
                            Map.Entry thisEntry = (Map.Entry) entries.next();
                            Object key = thisEntry.getKey();

                            //Do no display the time if the record is more then an hour old
                            Log.d("Comparing Epoc ", "for " + bandName + " " + key.toString() + " to " + System.currentTimeMillis());
                            if ((Long.valueOf(key.toString()) + 3600000) > System.currentTimeMillis()) {

                                if (BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType().equals("Show")) {
                                    Log.d("Comparing Epoc", key.toString() + " " + bandName + " Accepted");
                                    String line = rankStore.getRankForBand(bandName);
                                    if (!rankStore.getRankForBand(bandName).equals("")) {
                                        line += " - ";
                                    }
                                    line += bandName + " - ";
                                    line += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowDay() + " ";
                                    line += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getStartTimeString() + " ";
                                    line += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowLocation();
                                    if (staticVariables.sortBySchedule == true) {
                                        sortedScheduleBandList.put(key.toString() + bandName, line);
                                        sortedMapping.put(key.toString() + bandName, bandName);

                                        sortedScheduleBandList.remove(bandName);
                                        sortedMapping.remove(bandName);

                                    } else {
                                        sortedScheduleBandList.put(bandName, line);
                                        sortedMapping.put(bandName, bandName);
                                    }

                                    break;
                                }
                            } else {

                                String line = rankStore.getRankForBand(bandName);
                                if (!rankStore.getRankForBand(bandName).equals("")) {
                                    line += " - ";
                                }
                                line += bandName;
                                sortedScheduleBandList.put(bandName, line);
                                sortedMapping.put(bandName, bandName);
                            }
                        }
                    }
                    //take sorted TreeMap and convert to ordredList
                    Iterator entries = sortedScheduleBandList.entrySet().iterator();
                    while (entries.hasNext()) {
                        Map.Entry thisEntry = (Map.Entry) entries.next();
                        Object key = thisEntry.getKey();
                        scheduleBandList.add(sortedScheduleBandList.get(key));
                    }
                    //take sorted band list and use for click though tracking
                    entries = sortedMapping.entrySet().iterator();
                    while (entries.hasNext()) {
                        Map.Entry thisEntry = (Map.Entry) entries.next();
                        Object key = thisEntry.getKey();

                        if (scheduleSortedBandNames == null) {
                            scheduleSortedBandNames = new ArrayList<>();
                        }
                        Log.d("sortBySchedule Status", sortedMapping.get(key));
                        scheduleSortedBandNames.add(sortedMapping.get(key));
                    }

                    arrayAdapter = new ArrayAdapter<String>(showBands.this, android.R.layout.simple_list_item_1, scheduleBandList);

                } else {
                    arrayAdapter = noSchedulePopulate(bandList);
                }
            } else {
                arrayAdapter = noSchedulePopulate(bandList);
            }
        } else {
            arrayAdapter = noSchedulePopulate(bandList);
        }

        return arrayAdapter;
    }

    public ListAdapter noSchedulePopulate(ArrayList<String> bandList){

        ListAdapter arrayAdapter;

        sortButton = (Button) findViewById(R.id.sort);
        sortButton.setClickable(false);
        sortButton.setVisibility(View.GONE);
        ArrayList<String> rankedBandList = bandInfo.getRankedBandNames(bandList);
        scheduleSortedBandNames = bandList;
        Log.d("AsyncTask", "populating array list");
        arrayAdapter = new ArrayAdapter<String>(showBands.this, android.R.layout.simple_list_item_1, rankedBandList);

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

            BandInfo bandInfo = new BandInfo();
            bandInfo.DownloadBandFile();

            return result;
        }


        @Override
        protected void onPostExecute(ArrayList<String> result) {

            BandInfo bandInfo = new BandInfo();
            ArrayList<String> bandList = bandInfo.getBandNames();

            ListAdapter arrayAdapter = populateBandInfo(bandInfo, bandList);

            showBands.this.bandNamesList.setAdapter(arrayAdapter);
            progressBar.setVisibility(View.INVISIBLE);

            //scheduleAlerts(bandList);

            showBands.this.bandNamesList.requestLayout();
            staticVariables.fileDownloaded = true;
        }
    }
}