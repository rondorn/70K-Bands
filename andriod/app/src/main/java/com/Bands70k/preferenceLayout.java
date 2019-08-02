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

import static android.app.PendingIntent.getActivity;


/**
 * Created by rdorn on 8/15/15.
 */
public class preferenceLayout  extends Activity {


    private CheckBox showSpecialEvents;
    private CheckBox showMeetAndGreet;
    private CheckBox showClinicEvents;
    private CheckBox showAlbumListen;
    private CheckBox showUnoffical;

    private CheckBox showPoolShows;
    private CheckBox showTheaterShows;
    private CheckBox showRinkShows;
    private CheckBox showLoungeShows;
    private CheckBox showOtherShows;

    private CheckBox hideExpiredEvents;

    private CheckBox mustSee;
    private CheckBox mightSee;
    private CheckBox alertForShows;
    private CheckBox alertForSpecial;
    private CheckBox alertForClinics;
    private CheckBox alertForMeetAndGreet;
    private CheckBox alertForAlbum;
    private CheckBox alertUnofficalEvents;
    private CheckBox lastYearsData;
    private CheckBox onlyForShowWillAttend;

    private EditText alertMin;

    private EditText bandsUrl;
    private EditText scheduleUrl;
    private EditText pointerUrl;
    private String versionString = "";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.preferences);

        //staticVariables.preferences.loadData();
        setValues();
        setLabels();
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);

        try {
            PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            versionString = pInfo.versionName;
        } catch (Exception error){
            //do nothing
        }

        disableAlertButtonsIfNeeded();
        TextView headerText = (TextView) this.findViewById(R.id.preferenceHeader);
        headerText.setText("70K Bands Preferences - Build:" + versionString);
    }

    private void setLabels(){
        TextView poolVenueLable = (TextView)findViewById(R.id.poolVenueLable);
        poolVenueLable.setText(getResources().getString(R.string.PoolVenue) + " " + staticVariables.poolVenueIcon);

        TextView theaterVenueLable = (TextView)findViewById(R.id.theaterVenueLable);
        theaterVenueLable.setText(getResources().getString(R.string.TheaterVenue) + " " + staticVariables.theaterVenueIcon);

        TextView rinkVenueLable = (TextView)findViewById(R.id.rinkVenueLable);
        rinkVenueLable.setText(getResources().getString(R.string.RinkVenue) + " " + staticVariables.rinkVenueIcon);

        TextView loungeVenueLable = (TextView)findViewById(R.id.loungeVenueLable);
        loungeVenueLable.setText(getResources().getString(R.string.LoungeVenue) + " " + staticVariables.loungeVenueIcon);

        TextView specialEventLable = (TextView)findViewById(R.id.specialEventLable);
        specialEventLable.setText(getResources().getString(R.string.SpecialEvents));

        TextView meetAndGreetEventLable = (TextView)findViewById(R.id.meetAndGreetEventLable);
        meetAndGreetEventLable.setText(getResources().getString(R.string.MeetAndGreet));

        TextView clinicEventLable = (TextView)findViewById(R.id.clinicEventLable);
        clinicEventLable.setText(getResources().getString(R.string.ClinicEvents));

        TextView albumListeningEventLable = (TextView)findViewById(R.id.albumListeningEventLable);
        albumListeningEventLable.setText(getResources().getString(R.string.AlbumListeningEvents));

        TextView unofficalEventLable = (TextView)findViewById(R.id.unofficalEventLable);
        unofficalEventLable.setText(getResources().getString(R.string.unofficalEventLable));
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
                        staticVariables.preferences.resetMainFilters();
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

                        finish();

                        finishAffinity();
                        System.exit(0);

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

    private void disableAlertButtonsIfNeeded(){

        if (onlyForShowWillAttend.isChecked() == true){
            mustSee.setEnabled(false);
            mightSee.setEnabled(false);
            alertForShows.setEnabled(false);
            alertForSpecial.setEnabled(false);
            alertForMeetAndGreet.setEnabled(false);
            alertForClinics.setEnabled(false);
            alertForAlbum.setEnabled(false);
            alertUnofficalEvents.setEnabled(false);

        } else {
            mustSee.setEnabled(true);
            mightSee.setEnabled(true);
            alertForShows.setEnabled(true);
            alertForSpecial.setEnabled(true);
            alertForMeetAndGreet.setEnabled(true);
            alertForClinics.setEnabled(true);
            alertForAlbum.setEnabled(true);
            alertUnofficalEvents.setEnabled(true);

        }

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

        onlyForShowWillAttend = (CheckBox)findViewById(R.id.alertOnlyForShowWillAttendCheckBox);
        onlyForShowWillAttend.setChecked(staticVariables.preferences.getAlertOnlyForShowWillAttend());
        onlyForShowWillAttend.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertOnlyForShowWillAttend(onlyForShowWillAttend.isChecked());
                disableAlertButtonsIfNeeded();
                if (onlyForShowWillAttend.isChecked() == true){
                    HelpMessageHandler.showMessage(getString(R.string.OnlyAlertForShowsYouWillAttend));
                } else {
                    HelpMessageHandler.showMessage(getString(R.string.AlertForShowsAccordingToSelection));
                }
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

        alertUnofficalEvents = (CheckBox)findViewById(R.id.alertForUnofficalEvents);
        alertUnofficalEvents.setChecked(staticVariables.preferences.getAlertForUnofficalEvents());
        alertUnofficalEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForUnofficalEvents(alertUnofficalEvents.isChecked());
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

        pointerUrl = (EditText)findViewById(R.id.pointerUrl);
        pointerUrl.setText(staticVariables.preferences.getPointerUrl().toString());

        showSpecialEvents = (CheckBox)findViewById(R.id.showSpecialEvent);
        showSpecialEvents.setChecked(staticVariables.preferences.getShowSpecialEvents());
        showSpecialEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowSpecialEvents(showSpecialEvents.isChecked());
            }
        });

        showMeetAndGreet = (CheckBox)findViewById(R.id.showMeetAndGreet);
        showMeetAndGreet.setChecked(staticVariables.preferences.getShowMeetAndGreet());
        showMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowMeetAndGreet(showMeetAndGreet.isChecked());
            }
        });

        showClinicEvents = (CheckBox)findViewById(R.id.showClinic);
        showClinicEvents.setChecked(staticVariables.preferences.getShowClinicEvents());
        showClinicEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowClinicEvents(showClinicEvents.isChecked());
            }
        });

        showAlbumListen = (CheckBox)findViewById(R.id.showListeningEvent);
        showAlbumListen.setChecked(staticVariables.preferences.getShowAlbumListen());
        showAlbumListen.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowAlbumListen(showAlbumListen.isChecked());
            }
        });

        showUnoffical = (CheckBox)findViewById(R.id.unofficalEvent);
        showUnoffical.setChecked(staticVariables.preferences.getShowUnofficalEvents());
        showUnoffical.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowUnofficalEvents(showUnoffical.isChecked());
            }
        });

        showPoolShows = (CheckBox)findViewById(R.id.showPool);
        showPoolShows.setChecked(staticVariables.preferences.getShowPoolShows());
        showPoolShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowPoolShows(showPoolShows.isChecked());
            }
        });

        showTheaterShows = (CheckBox)findViewById(R.id.showTheater);
        showTheaterShows.setChecked(staticVariables.preferences.getShowTheaterShows());
        showTheaterShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowTheaterShows(showTheaterShows.isChecked());
            }
        });

        showRinkShows = (CheckBox)findViewById(R.id.showRink);
        showRinkShows.setChecked(staticVariables.preferences.getShowRinkShows());
        showRinkShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowRinkShows(showRinkShows.isChecked());
            }
        });

        showLoungeShows = (CheckBox)findViewById(R.id.showLounge);
        showLoungeShows.setChecked(staticVariables.preferences.getShowLoungeShows());
        showLoungeShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowLoungeShows(showLoungeShows.isChecked());
            }
        });

        showOtherShows = (CheckBox)findViewById(R.id.showOther);
        showOtherShows.setChecked(staticVariables.preferences.getShowOtherShows());
        showOtherShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowOtherShows(showOtherShows.isChecked());
            }
        });

        hideExpiredEvents = (CheckBox)findViewById(R.id.hideExpiredEvents);
        hideExpiredEvents.setChecked(staticVariables.preferences.getHideExpiredEvents());
        hideExpiredEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setHideExpiredEvents(hideExpiredEvents.isChecked());
            }
        });
    }

    @Override
    public void onBackPressed() {

        staticVariables.preferences.setMinBeforeToAlert(Integer.valueOf(alertMin.getText().toString()));
        staticVariables.preferences.setArtsistsUrl(bandsUrl.getText().toString());
        staticVariables.preferences.setScheduleUrl(scheduleUrl.getText().toString());
        staticVariables.preferences.setPointerUrl(pointerUrl.getText().toString());
        staticVariables.preferences.saveData();
        setResult(RESULT_OK, null);
        finish();

    }

}