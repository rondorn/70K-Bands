package com.Bands70k;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.preference.Preference;
import android.view.View;
import android.widget.CheckBox;
import android.widget.EditText;


/**
 * Created by rdorn on 8/15/15.
 */
public class preferenceLayout  extends Activity {

    preferencesHandler alertPreferences = new preferencesHandler();
    CheckBox mustSee;
    CheckBox mightSee;
    CheckBox alertForShows;
    CheckBox alertForSpecial;
    CheckBox alertForClinics;
    CheckBox alertForMeetAndGreet;
    CheckBox alertForAlbum;
    CheckBox lastYearsData;
    EditText alertMin;

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.preferences);

        alertPreferences.loadData();
        setValues();

    }

    private void setValues(){

        mustSee = (CheckBox)findViewById(R.id.mustSeecheckBox);
        mustSee.setChecked(alertPreferences.getMustSeeAlert());
        mustSee.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setMustSeeAlert(mustSee.isChecked());
            }
        });

        mightSee = (CheckBox)findViewById(R.id.mightSeecheckBox);
        mightSee.setChecked(alertPreferences.getMightSeeAlert());
        mightSee.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setMightSeeAlert(mightSee.isChecked());
            }
        });

        alertForShows = (CheckBox)findViewById(R.id.alertForShows);
        alertForShows.setChecked(alertPreferences.getAlertForShows());
        alertForShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setAlertForShows(alertForShows.isChecked());
            }
        });

        alertForSpecial = (CheckBox)findViewById(R.id.alertForSpecialEvents);
        alertForSpecial.setChecked(alertPreferences.getAlertForSpecialEvents());
        alertForSpecial.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setAlertForSpecialEvents(alertForSpecial.isChecked());
            }
        });

        alertForClinics = (CheckBox)findViewById(R.id.alertForClinics);
        alertForClinics.setChecked(alertPreferences.getAlertForClinics());
        alertForClinics.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setAlertForClinics(alertForClinics.isChecked());
            }
        });

        alertForMeetAndGreet = (CheckBox)findViewById(R.id.alertForMeetAndGreet);
        alertForMeetAndGreet.setChecked(alertPreferences.getAlertForMeetAndGreet());
        alertForMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setAlertForMeetAndGreet(alertForMeetAndGreet.isChecked());
            }
        });

        alertForAlbum = (CheckBox)findViewById(R.id.alertForAlbumListen);
        alertForAlbum.setChecked(alertPreferences.getAlertForListeningParties());
        alertForAlbum.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setAlertForListeningParties(alertForAlbum.isChecked());
            }
        });

        lastYearsData = (CheckBox)findViewById(R.id.useLastYearsData);
        lastYearsData.setChecked(alertPreferences.getUseLastYearsData());
        lastYearsData.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setUseLastYearsData(lastYearsData.isChecked());
            }
        });

        alertMin = (EditText)findViewById(R.id.minBeforeEvent);
        alertMin.setText(alertPreferences.getMinBeforeToAlert().toString());

    }


    @Override
    public void onBackPressed() {

        alertPreferences.setMinBeforeToAlert(Integer.valueOf(alertMin.getText().toString()));
        alertPreferences.saveData();
        Intent showDetails = new Intent(preferenceLayout.this, showBands.class);
        startActivity(showDetails);
    }

}