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

//import com.google.android.gms.wallet.wobs.LabelValue;

import java.util.ArrayList;


/**
 * Created by rdorn on 8/15/15.
 */
public class filterMenu extends Activity {

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

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.filter_menu);

        //staticVariables.preferences.loadData();
        setValues();
        setLabels();
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);
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
        specialEventLable.setText(getResources().getString(R.string.SpecialEvents) + " " + staticVariables.specialEventTypeIcon);

        TextView meetAndGreetEventLable = (TextView)findViewById(R.id.meetAndGreetEventLable);
        meetAndGreetEventLable.setText(getResources().getString(R.string.MeetAndGreet) + " " + staticVariables.mAndmEventTypeIcon);

        TextView clinicEventLable = (TextView)findViewById(R.id.clinicEventLable);
        clinicEventLable.setText(getResources().getString(R.string.ClinicEvents) + " " + staticVariables.clinicEventTypeIcon);

        TextView albumListeningEventLable = (TextView)findViewById(R.id.albumListeningEventLable);
        albumListeningEventLable.setText(getResources().getString(R.string.AlbumListeningEvents) + " " + staticVariables.listeningEventTypeIcon);

        TextView unofficalEventLable = (TextView)findViewById(R.id.unofficalEventLable);
        unofficalEventLable.setText(getResources().getString(R.string.unofficalEventLable) + " " + staticVariables.unofficalEventTypeIcon);
    }

    private void setValues(){

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

        staticVariables.preferences.saveData();

        setResult(RESULT_OK, null);
        finish();

    }

}