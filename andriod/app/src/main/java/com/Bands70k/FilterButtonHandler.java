package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.content.Context;
import android.graphics.drawable.Drawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import androidx.appcompat.content.res.AppCompatResources;
import androidx.coordinatorlayout.widget.CoordinatorLayout;

import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.widget.Toast;


import com.google.android.material.snackbar.Snackbar;

import java.lang.reflect.Field;

//public class FilterButtonHandler {
public class FilterButtonHandler  {
    public Button filterMenuButton;
    private PopupWindow popupWindow;
    private static View messageView;
    public void setUpFiltersButton(showBands showBands){

        filterMenuButton = (Button) showBands.findViewById(R.id.FilerMenu);
        messageView = showBands.findViewById(R.id.showBandsView);
        filterMenuButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View context) {
                popupWindow = new PopupWindow(showBands);
                LayoutInflater inflater = (LayoutInflater) staticVariables.context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);

                View view = inflater.inflate(R.layout.filter_choices_menu_layout, null);

                popupWindow.setFocusable(true);
                popupWindow.setWidth(WindowManager.LayoutParams.WRAP_CONTENT);
                popupWindow.setHeight(WindowManager.LayoutParams.WRAP_CONTENT);
                popupWindow.setContentView(view);

                popupWindow.showAsDropDown(filterMenuButton, 0, 0);

                MustMightFilterHandler mustMightHandle = new MustMightFilterHandler(popupWindow);
                mustMightHandle.setupMustMightFilters();
                mustMightHandle.setupMustMightListener(showBands);

                EventFilterHandler eventFilterHandle = new EventFilterHandler(popupWindow);
                eventFilterHandle.setupEventTypeFilters();
                eventFilterHandle.setupEventTypeListener(showBands);

                VenueFilterHandler venueFilterHandle = new VenueFilterHandler(popupWindow);
                venueFilterHandle.setupVenueFilters();
                venueFilterHandle.setupVenueListener(showBands);

                OtherFilterHandler otherFilterHandle = new OtherFilterHandler(popupWindow);
                otherFilterHandle.setupOtherFilters();
                otherFilterHandle.setupEventTypeListener(showBands);
            }
        });
    }

    public static void refreshAfterButtonClick(PopupWindow popupWindow, showBands showBands, String message){

        if (message.isEmpty() == false) {
            HelpMessageHandler.showMessage(message, messageView);
        }
        showBands.refreshData();
        popupWindow.dismiss();
    }

    public static void hideMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if (sectionType == "TextView") {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.GONE);
        }
        if (sectionType == "LinearLayout") {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.GONE);
        }
    }

    public static void showMenuSection(Integer sectionName, String sectionType, PopupWindow popupWindow){

        if (sectionType == "TextView") {
            TextView menuSection = (TextView) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.VISIBLE);
        }
        if (sectionType == "LinearLayout") {
            LinearLayout menuSection = (LinearLayout) popupWindow.getContentView().findViewById(sectionName);
            menuSection.setVisibility(View.VISIBLE);
        }
    }

    public static Boolean blockTurningAllFiltersOn(){

        Boolean blockChange = false;
        if (staticVariables.preferences.getShowPoolShows() == false &&
                staticVariables.preferences.getShowRinkShows() == false &&
                staticVariables.preferences.getShowOtherShows() == false &&
                staticVariables.preferences.getShowLoungeShows() == false &&
                staticVariables.preferences. getShowTheaterShows() == false){
            blockChange = true;
            HelpMessageHandler.showMessage(context.getResources().getString(R.string.can_not_hide_all_venues), messageView);
        }

        if (staticVariables.preferences.getShowMust() == false &&
                staticVariables.preferences.getShowMight() == false &&
                staticVariables.preferences.getShowWont() == false &&
                staticVariables.preferences.getShowUnknown() == false ){
            blockChange = true;
            HelpMessageHandler.showMessage(context.getResources().getString(R.string.can_not_hide_all_statuses), messageView);
        }

        return blockChange;
    }

}
