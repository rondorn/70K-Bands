package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.os.Bundle;
import android.preference.Preference;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;


/**
 * Created by rdorn on 8/15/15.
 */
public class preferenceLayout  extends Activity {

    private preferencesHandler alertPreferences = new preferencesHandler();
    private CheckBox mustSee;
    private CheckBox mightSee;
    private CheckBox alertForShows;
    private CheckBox alertForSpecial;
    private CheckBox alertForClinics;
    private CheckBox alertForMeetAndGreet;
    private CheckBox alertForAlbum;
    private CheckBox lastYearsData;

    private CheckBox hideSpecialEvents;
    private CheckBox hideMeetAndGreet;
    private CheckBox hideClinicEvents;
    private CheckBox hideAlbumListen;

    private EditText alertMin;

    private EditText bandsUrl;
    private EditText scheduleUrl;
    private String versionString = "";

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.preferences);

        alertPreferences.loadData();
        setValues();
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);

        try {
            PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            versionString = pInfo.versionName;
        } catch (Exception error){
            //do nothing
        }

        TextView headerText = (TextView) this.findViewById(R.id.headerText);
        headerText.setText("Alert Preferences - Build:" + versionString);
    }

    private void buildRebootDialog(){

        AlertDialog.Builder restartDialog = new AlertDialog.Builder(preferenceLayout.this);

        // Setting Dialog Title
        restartDialog.setTitle("Confirm Restart");

        // Setting Dialog Message
        restartDialog.setMessage(getResources().getString(R.string.restartMessage));

        // Setting Icon to Dialog
        restartDialog.setIcon(R.drawable.alert_icon);

        // Setting Positive "Yes" Btn
        restartDialog.setPositiveButton(getResources().getString(R.string.Ok),
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        // Write your code here to execute after dialog
                        alertPreferences.saveData();

                        BandInfo bandInfo = new BandInfo();
                        ArrayList<String> bandList  = bandInfo.DownloadBandFile();

                        Intent intent = new Intent(preferenceLayout.this, showBands.class);
                        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                        startActivity(intent);
                        finish();

                    }
                });
        // Setting Negative "NO" Btn
        restartDialog.setNegativeButton(getResources().getString(R.string.Cancel),
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        if (lastYearsData.isChecked() == true) {
                            lastYearsData.setChecked(false);
                        } else {
                            lastYearsData.setChecked(true);
                        }
                        alertPreferences.setUseLastYearsData(lastYearsData.isChecked());
                    }
                });

        // Showing Alert Dialog
        restartDialog.show();
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

        hideSpecialEvents = (CheckBox)findViewById(R.id.hideSpecialEvents);
        hideSpecialEvents.setChecked(alertPreferences.getHideSpecialEvents());
        hideSpecialEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setHideSpecialEvents(hideSpecialEvents.isChecked());
            }
        });

        hideMeetAndGreet = (CheckBox)findViewById(R.id.hideMeetAndGreet);
        hideMeetAndGreet.setChecked(alertPreferences.getHideMeetAndGreet());
        hideMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setHideMeetAndGreet(hideMeetAndGreet.isChecked());
            }
        });

        hideClinicEvents = (CheckBox)findViewById(R.id.hideClinicEvents);
        hideClinicEvents.setChecked(alertPreferences.getHideClinicEvents());
        hideClinicEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setHideClinicEvents(hideClinicEvents.isChecked());
            }
        });

        hideAlbumListen = (CheckBox)findViewById(R.id.hideAlbumListen);
        hideAlbumListen.setChecked(alertPreferences.getHideAlbumListen());
        hideAlbumListen.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setHideAlbumListen(hideAlbumListen.isChecked());
            }
        });

        lastYearsData = (CheckBox)findViewById(R.id.useLastYearsData);
        lastYearsData.setChecked(alertPreferences.getUseLastYearsData());
        lastYearsData.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setUseLastYearsData(lastYearsData.isChecked());
                buildRebootDialog();
            }
        });

        alertMin = (EditText)findViewById(R.id.minBeforeEvent);
        alertMin.setText(alertPreferences.getMinBeforeToAlert().toString());

        bandsUrl = (EditText)findViewById(R.id.bandsUrl);
        bandsUrl.setText(alertPreferences.getArtsistsUrl().toString());

        scheduleUrl = (EditText)findViewById(R.id.scheduleUrl);
        scheduleUrl.setText(alertPreferences.getScheduleUrl().toString());
    }


    @Override
    public void onBackPressed() {

        alertPreferences.setMinBeforeToAlert(Integer.valueOf(alertMin.getText().toString()));
        alertPreferences.setArtsistsUrl(bandsUrl.getText().toString());
        alertPreferences.setScheduleUrl(scheduleUrl.getText().toString());

        alertPreferences.saveData();
        Intent showDetails = new Intent(preferenceLayout.this, showBands.class);
        startActivity(showDetails);
    }

}