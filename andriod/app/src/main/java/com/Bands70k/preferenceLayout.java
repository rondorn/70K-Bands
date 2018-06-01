package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.os.Bundle;
import android.preference.Preference;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;


/**
 * Created by rdorn on 8/15/15.
 */
public class preferenceLayout  extends Activity {

    private CheckBox mustSee;
    private CheckBox mightSee;
    private CheckBox alertForShows;
    private CheckBox alertForSpecial;
    private CheckBox alertForClinics;
    private CheckBox alertForMeetAndGreet;
    private CheckBox alertForAlbum;
    private CheckBox lastYearsData;

    private EditText alertMin;

    private EditText bandsUrl;
    private EditText scheduleUrl;
    private String versionString = "";

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.preferences);

        //staticVariables.preferences.loadData();
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
                        staticVariables.preferences.saveData();

                        //delete band file
                        Log.d("preferenceLayout", "Deleting band file");
                        File fileBandFile = FileHandler70k.bandInfo;
                        fileBandFile.delete();

                        //delete current schedule file
                        Log.d("preferenceLayout", "Deleting schedule file");
                        File fileSchedule = FileHandler70k.schedule;
                        fileSchedule.delete();

                        //erase existing alerts
                        Log.d("preferenceLayout", "Erasing alerts");

                        scheduleAlertHandler alerts = new scheduleAlertHandler();
                        alerts.clearAlerts();

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
                        staticVariables.preferences.setUseLastYearsData(lastYearsData.isChecked());
                    }
                });

        // Showing Alert Dialog
        restartDialog.show();
    }

    private void setValues(){

        mustSee = (CheckBox)findViewById(R.id.mustSeecheckBox);
        mustSee.setChecked(staticVariables.preferences.getMustSeeAlert());
        mustSee.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setMustSeeAlert(mustSee.isChecked());
            }
        });

        mightSee = (CheckBox)findViewById(R.id.mightSeecheckBox);
        mightSee.setChecked(staticVariables.preferences.getMightSeeAlert());
        mightSee.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setMightSeeAlert(mightSee.isChecked());
            }
        });

        alertForShows = (CheckBox)findViewById(R.id.alertForShows);
        alertForShows.setChecked(staticVariables.preferences.getAlertForShows());
        alertForShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForShows(alertForShows.isChecked());
            }
        });

        alertForSpecial = (CheckBox)findViewById(R.id.alertForSpecialEvents);
        alertForSpecial.setChecked(staticVariables.preferences.getAlertForSpecialEvents());
        alertForSpecial.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForSpecialEvents(alertForSpecial.isChecked());
            }
        });

        alertForClinics = (CheckBox)findViewById(R.id.alertForClinics);
        alertForClinics.setChecked(staticVariables.preferences.getAlertForClinics());
        alertForClinics.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForClinics(alertForClinics.isChecked());
            }
        });

        alertForMeetAndGreet = (CheckBox)findViewById(R.id.alertForMeetAndGreet);
        alertForMeetAndGreet.setChecked(staticVariables.preferences.getAlertForMeetAndGreet());
        alertForMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForMeetAndGreet(alertForMeetAndGreet.isChecked());
            }
        });

        alertForAlbum = (CheckBox)findViewById(R.id.alertForAlbumListen);
        alertForAlbum.setChecked(staticVariables.preferences.getAlertForListeningParties());
        alertForAlbum.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForListeningParties(alertForAlbum.isChecked());
            }
        });

        lastYearsData = (CheckBox)findViewById(R.id.useLastYearsData);
        lastYearsData.setChecked(staticVariables.preferences.getUseLastYearsData());
        lastYearsData.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setUseLastYearsData(lastYearsData.isChecked());
                buildRebootDialog();
            }
        });

        alertMin = (EditText)findViewById(R.id.minBeforeEvent);
        alertMin.setText(staticVariables.preferences.getMinBeforeToAlert().toString());

        bandsUrl = (EditText)findViewById(R.id.bandsUrl);
        bandsUrl.setText(staticVariables.preferences.getArtsistsUrl().toString());

        scheduleUrl = (EditText)findViewById(R.id.scheduleUrl);
        scheduleUrl.setText(staticVariables.preferences.getScheduleUrl().toString());
    }


    @Override
    public void onBackPressed() {

        staticVariables.preferences.setMinBeforeToAlert(Integer.valueOf(alertMin.getText().toString()));
        staticVariables.preferences.setArtsistsUrl(bandsUrl.getText().toString());
        staticVariables.preferences.setScheduleUrl(scheduleUrl.getText().toString());

        staticVariables.preferences.saveData();
        setResult(RESULT_OK, null);
        finish();

    }

}