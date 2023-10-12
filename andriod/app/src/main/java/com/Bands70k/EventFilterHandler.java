package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.appcompat.content.res.AppCompatResources;

public class EventFilterHandler {

    private PopupWindow popupWindow;

    public EventFilterHandler(PopupWindow value){
        popupWindow = value;
    }
    public void setupEventTypeListener(showBands showBands){

        LinearLayout meetAndGreetFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.meetAndGreetFilterAll);
        meetAndGreetFilterAll.setOnClickListener(new View.OnClickListener() {
             @Override
             public void onClick(View context) {
                 if (staticVariables.preferences.getShowMeetAndGreet() == true) {
                     staticVariables.preferences.setShowMeetAndGreet(false);
                 } else {
                     staticVariables.preferences.setShowMeetAndGreet(true);
                 }
                 staticVariables.preferences.saveData();
                 setupEventTypeFilters();
                 FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
             }
         });


        LinearLayout specialOtherEventFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.specialOtherEventFilterAll);
        specialOtherEventFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                if (staticVariables.preferences.getShowSpecialEvents() == true) {
                    staticVariables.preferences.setShowSpecialEvents(false);
                } else {
                    staticVariables.preferences.setShowSpecialEvents(true);
                }
                staticVariables.preferences.saveData();
                setupEventTypeFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });

        LinearLayout unofficalEventFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.unofficalEventFilterAll);
        unofficalEventFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                if (staticVariables.preferences.getShowUnofficalEvents() == true) {
                    staticVariables.preferences.setShowUnofficalEvents(false);
                } else {
                    staticVariables.preferences.setShowUnofficalEvents(true);
                }
                staticVariables.preferences.saveData();
                setupEventTypeFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });
    }


    public void setupEventTypeFilters(){

        TextView meetAndGreetFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.meetAndGreetFilter);
        ImageView meetAndGreetFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.meetAndGreetFilterIcon);
        Drawable meetAndGreetFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_meet_and_greet);
        Drawable meetAndGreetFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_meet_and_greet_alt);
        if (staticVariables.preferences.getShowMeetAndGreet() == true) {
            meetAndGreetFilterIcon.setImageDrawable(meetAndGreetFilterYes);
            meetAndGreetFilterText.setText(R.string.hide_meet_and_greet_events);
        } else {
            meetAndGreetFilterIcon.setImageDrawable(meetAndGreetFilterNo);
            meetAndGreetFilterText.setText(R.string.show_meet_and_greet_events);
        }

        TextView specialOtherEventFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.specialOtherEventFilter);
        ImageView specialOtherEventFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.specialOtherEventFilterIcon);
        Drawable specialOtherEventFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_all_star_jam);
        Drawable specialOtherEventFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_all_star_jam_alt);
        if (staticVariables.preferences.getShowSpecialEvents() == true) {
            specialOtherEventFilterIcon.setImageDrawable(specialOtherEventFilterYes);
            specialOtherEventFilterText.setText(R.string.hide_special_other_events);
        } else {
            specialOtherEventFilterIcon.setImageDrawable(specialOtherEventFilterNo);
            specialOtherEventFilterText.setText(R.string.show_special_other_events);
        }

        TextView unofficalEventFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.unofficalEventFilter);
        ImageView unofficalEventFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.unofficalEventFilterIcon);
        Drawable unofficalEventFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_unoffical_event);
        Drawable unofficalEventFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_unoffical_event_alt);
        if (staticVariables.preferences.getShowUnofficalEvents() == true) {
            unofficalEventFilterIcon.setImageDrawable(unofficalEventFilterYes);
            unofficalEventFilterText.setText(R.string.hide_unofficial_events);
        } else {
            unofficalEventFilterIcon.setImageDrawable(unofficalEventFilterNo);
            unofficalEventFilterText.setText(R.string.show_unofficial_events);
        }

    }
}
