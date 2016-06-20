package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;

import java.util.ArrayList;


/**
 * Created by rdorn on 8/15/15.
 */
public class filterMenu extends Activity {

    private preferencesHandler alertPreferences = new preferencesHandler();

    private CheckBox showSpecialEvents;
    private CheckBox showMeetAndGreet;
    private CheckBox showClinicEvents;
    private CheckBox showAlbumListen;

    private CheckBox showPoolShows;
    private CheckBox showTheaterShows;
    private CheckBox showRinkShows;
    private CheckBox showLoungeShows;
    private CheckBox showOtherShows;


    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.filter_menu);

        alertPreferences.loadData();
        setValues();

        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);
    }

    private void setValues(){

        showSpecialEvents = (CheckBox)findViewById(R.id.showSpecialEvent);
        showSpecialEvents.setChecked(alertPreferences.getShowSpecialEvents());
        showSpecialEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowSpecialEvents(showSpecialEvents.isChecked());
            }
        });

        showMeetAndGreet = (CheckBox)findViewById(R.id.showMeetAndGreet);
        showMeetAndGreet.setChecked(alertPreferences.getShowMeetAndGreet());
        showMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowMeetAndGreet(showMeetAndGreet.isChecked());
            }
        });

        showClinicEvents = (CheckBox)findViewById(R.id.showClinic);
        showClinicEvents.setChecked(alertPreferences.getShowClinicEvents());
        showClinicEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowClinicEvents(showClinicEvents.isChecked());
            }
        });

        showAlbumListen = (CheckBox)findViewById(R.id.showListeningEvent);
        showAlbumListen.setChecked(alertPreferences.getShowAlbumListen());
        showAlbumListen.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowAlbumListen(showAlbumListen.isChecked());
            }
        });

        showPoolShows = (CheckBox)findViewById(R.id.showPool);
        showPoolShows.setChecked(alertPreferences.getShowPoolShows());
        showPoolShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowPoolShows(showPoolShows.isChecked());
            }
        });

        showTheaterShows = (CheckBox)findViewById(R.id.showTheater);
        showTheaterShows.setChecked(alertPreferences.getShowTheaterShows());
        showTheaterShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowTheaterShows(showTheaterShows.isChecked());
            }
        });

        showRinkShows = (CheckBox)findViewById(R.id.showRink);
        showRinkShows.setChecked(alertPreferences.getShowRinkShows());
        showRinkShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowRinkShows(showRinkShows.isChecked());
            }
        });

        showLoungeShows = (CheckBox)findViewById(R.id.showLounge);
        showLoungeShows.setChecked(alertPreferences.getShowLoungeShows());
        showLoungeShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowLoungeShows(showLoungeShows.isChecked());
            }
        });

        showOtherShows = (CheckBox)findViewById(R.id.showOther);
        showOtherShows.setChecked(alertPreferences.getShowOtherShows());
        showOtherShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                alertPreferences.setShowOtherShows(showOtherShows.isChecked());
            }
        });
    }


    @Override
    public void onBackPressed() {

        alertPreferences.saveData();

        setResult(RESULT_OK, null);
        finish();

    }

}