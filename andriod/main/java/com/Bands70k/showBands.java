package com.Bands70k;

import android.app.Activity;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.StrictMode;
import android.os.Bundle;
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
import android.widget.ToggleButton;

import java.util.ArrayList;

public class showBands extends Activity {

    private ArrayList<String> bandNames;
    private ListView bandNamesList;

    private ArrayList<String> rankedBandNames;
    private ArrayAdapter<String> arrayAdapter;

    private ProgressBar progressBar;
    private BandInfo bandInfo;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_show_bands);

        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        setContentView(R.layout.activity_show_bands);
        bandInfo = new BandInfo();

        populateBandList();
    }


    public void displayNumberOfBands (){
        TextView bandCount = (TextView)findViewById(R.id.headerBandCount);
        bandCount.setText("70,0000 Tons " + bandNames.size() + " bands");
    }


    public void setupNoneFilterButtons(){

        Button refreshButton = (Button)findViewById(R.id.refresh);

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

        Button preferencesButton = (Button)findViewById(R.id.preferences);

        preferencesButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                Intent showPreferences = new Intent(showBands.this, preferenceLayout.class);
                startActivity(showPreferences);
            }
        });
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

            ListAdapter arrayAdapter = new ArrayAdapter<String>(showBands.this, android.R.layout.simple_list_item_1, rankedBandNames);

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
    public void onResume() {

        super.onResume();
        bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            // argument position gives the index of item which is clicked
            public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {

                try {
                    getWindow().getDecorView().findViewById(android.R.id.content).invalidate();
                    String selectedBand = bandNames.get(position);
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

        setupNoneFilterButtons();
        setupButtonFilters();
        displayNumberOfBands();
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
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
            ArrayList<String> bandList  = bandInfo.DownloadBandFile();

            return result;
        }


        @Override
        protected void onPostExecute(ArrayList<String> result) {

            BandInfo bandInfo = new BandInfo();
            ArrayList<String> bandList = bandInfo.getBandNames();
            ArrayList<String> rankedBandList = bandInfo.getRankedBandNames(bandList);

            Log.d("AsyncTask", "populating array list");
            ListAdapter arrayAdapter = new ArrayAdapter<String>(showBands.this, android.R.layout.simple_list_item_1, rankedBandList);

            showBands.this.bandNamesList.setAdapter(arrayAdapter);
            progressBar.setVisibility(View.INVISIBLE);

            showBands.this.bandNamesList.requestLayout();
            staticVariables.fileDownloaded = true;
        }
    }
}