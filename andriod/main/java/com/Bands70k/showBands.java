package com.Bands70k;

import android.app.Activity;
import android.content.Intent;
import android.os.StrictMode;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.ToggleButton;

import com.parse.Parse;
import com.parse.ParsePush;
import com.parse.SaveCallback;
import com.parse.ParseException;

import com.Bands70k.R;

import java.util.ArrayList;

public class showBands extends Activity {

    private ArrayList<String> bandNames;
    private ListView bandNamesList;

    private getBandInfo bandInfo;
    private ArrayList<String> rankedBandNames;
    private ArrayAdapter<String> arrayAdapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_show_bands);

        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        setupButtonFilters();
    }

    public void displayNumberOfBands (){
        TextView bandCount = (TextView)findViewById(R.id.headerBandCount);
        bandCount.setText("70,0000 Tons " + bandNames.size() + " bands");
    }

    public void setupButtonFilters(){


        Button refreshButton = (Button)findViewById(R.id.refresh);

        refreshButton.setOnClickListener(new Button.OnClickListener() {
            // argument position gives the index of item which is clicked
            public void onClick(View v) {
                Intent showDetails = new Intent(showBands.this, showBands.class);
                startActivity(showDetails);

            }
        });

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

        bandInfo = new getBandInfo();

        bandInfo.DownloadBandFile();
        bandInfo.ParseBandCSV();

        bandNames = bandInfo.getBandNames();

        rankedBandNames = bandInfo.getRankedBandNames();

        Log.d("Last of ranked in populateBandList", rankedBandNames.toString());

        bandNamesList = (ListView)findViewById(R.id.bandNames);

        arrayAdapter = new ArrayAdapter<String>(this,android.R.layout.simple_list_item_1, rankedBandNames);

        bandNamesList.setAdapter(arrayAdapter);

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
        setContentView(R.layout.activity_show_bands);

        rankStore.getBandRankings();
        populateBandList();
        bandNamesList.setAdapter(arrayAdapter);

        bandNamesList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            // argument position gives the index of item which is clicked
            public void onItemClick(AdapterView<?> arg0, View v, int position, long arg3) {

                getWindow().getDecorView().findViewById(android.R.id.content).invalidate();
                String selectedBand = bandNames.get(position);
                Log.d("The follow band was clicked ", selectedBand);

                getBandInfo.setSelectedBand(selectedBand);

                Intent showDetails = new Intent(showBands.this, showBandDetails.class);
                startActivity(showDetails);

            }
        });

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
}
