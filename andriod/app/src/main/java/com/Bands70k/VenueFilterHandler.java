package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.appcompat.content.res.AppCompatResources;

public class VenueFilterHandler {

    private PopupWindow popupWindow;

    public VenueFilterHandler(PopupWindow value){
        popupWindow = value;
    }
    public void setupVenueListener(showBands showBands){

        LinearLayout loungVenueFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.loungVenueFilterAll);
        loungVenueFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowLoungeShows() == true) {
                    staticVariables.preferences.setShowLoungeShows(false);
                    if (FilterButtonHandler.blockTurningAllFiltersOn() == true){
                        staticVariables.preferences.setShowLoungeShows(true);
                    } else {
                        message = staticVariables.context.getString(R.string.lounge_venue_filter_on);
                    }
                } else {
                    message = staticVariables.context.getString(R.string.lounge_venue_filter_off);
                    staticVariables.preferences.setShowLoungeShows(true);
                }
                staticVariables.preferences.saveData();
                setupVenueFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });

        LinearLayout poolVenueFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.poolVenueFilterAll);
        poolVenueFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowPoolShows()== true) {
                    staticVariables.preferences.setShowPoolShows(false);
                    if (FilterButtonHandler.blockTurningAllFiltersOn() == true){
                        staticVariables.preferences.setShowPoolShows(true);
                    } else {
                        message = staticVariables.context.getString(R.string.pool_venue_filter_on);
                    }
                } else {
                    message = staticVariables.context.getString(R.string.pool_venue_filter_off);
                    staticVariables.preferences.setShowPoolShows(true);
                }
                staticVariables.preferences.saveData();
                setupVenueFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });

        LinearLayout rinkVenueFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.rinkVenueFilterAll);
        rinkVenueFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowRinkShows()== true) {
                    staticVariables.preferences.setShowRinkShows(false);
                    if (FilterButtonHandler.blockTurningAllFiltersOn() == true){
                        staticVariables.preferences.setShowRinkShows(true);
                    } else {
                        message = staticVariables.context.getString(R.string.rink_venue_filter_on);
                    }
                } else {
                    message = staticVariables.context.getString(R.string.rink_venue_filter_off);
                    staticVariables.preferences.setShowRinkShows(true);
                }
                staticVariables.preferences.saveData();
                setupVenueFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });


        LinearLayout theaterVenueFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.theaterVenueFilterAll);
        theaterVenueFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowTheaterShows()== true) {
                    staticVariables.preferences.setShowTheaterShows(false);
                    if (FilterButtonHandler.blockTurningAllFiltersOn() == true){
                        staticVariables.preferences.setShowTheaterShows(true);
                    } else {
                        message = staticVariables.context.getString(R.string.theater_venue_filter_on);
                    }
                } else {
                    message = staticVariables.context.getString(R.string.theater_venue_filter_off);
                    staticVariables.preferences.setShowTheaterShows(true);
                }
                staticVariables.preferences.saveData();
                setupVenueFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });

        LinearLayout otherVenueFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.otherVenueFilterAll);
        otherVenueFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowOtherShows() == true) {
                    staticVariables.preferences.setShowOtherShows(false);
                    if (FilterButtonHandler.blockTurningAllFiltersOn() == true){
                        staticVariables.preferences.setShowOtherShows(true);
                    } else {
                        message = staticVariables.context.getString(R.string.other_venue_filter_on);
                    }
                } else {
                    message = staticVariables.context.getString(R.string.other_venue_filter_off);
                    staticVariables.preferences.setShowOtherShows(true);
                }
                staticVariables.preferences.saveData();
                setupVenueFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });
    }


    public void setupVenueFilters(){

        TextView loungVenueFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.loungVenueFilter);
        ImageView loungVenueFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.loungVenueFilterIcon);
        Drawable loungVenueFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_lounge);
        Drawable loungVenueFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_lounge_alt);
        if (staticVariables.preferences.getShowLoungeShows() == true) {
            loungVenueFilterIcon.setImageDrawable(loungVenueFilterYes);
            loungVenueFilterText.setText(R.string.hide_lounge_events);
        } else {
            loungVenueFilterIcon.setImageDrawable(loungVenueFilterNo);
            loungVenueFilterText.setText(R.string.show_lounge_events);
        }

        TextView poolVenueFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.poolVenueFilter);
        ImageView poolVenueFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.poolVenueFilterIcon);
        Drawable poolVenueFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_pool);
        Drawable poolVenueFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_pool_alt);
        if (staticVariables.preferences.getShowPoolShows() == true) {
            poolVenueFilterIcon.setImageDrawable(poolVenueFilterYes);
            poolVenueFilterText.setText(R.string.hide_pool_events);
        } else {
            poolVenueFilterIcon.setImageDrawable(poolVenueFilterNo);
            poolVenueFilterText.setText(R.string.show_pool_events);
        }

        TextView rinkVenueFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.rinkVenueFilter);
        ImageView rinkVenueFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.rinkVenueFilterIcon);
        Drawable rinkVenueFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_rink);
        Drawable rinkVenueFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_rink_alt);
        if (staticVariables.preferences.getShowRinkShows() == true) {
            rinkVenueFilterIcon.setImageDrawable(rinkVenueFilterYes);
            rinkVenueFilterText.setText(R.string.hide_rink_events);
        } else {
            rinkVenueFilterIcon.setImageDrawable(rinkVenueFilterNo);
            rinkVenueFilterText.setText(R.string.show_rink_events);
        }

        TextView theaterVenueFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.theaterVenueFilter);
        ImageView theaterVenueFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.theaterVenueFilterIcon);
        Drawable theaterVenueFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_theater);
        Drawable theaterVenueFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_theater_alt);
        if (staticVariables.preferences.getShowTheaterShows() == true) {
            theaterVenueFilterIcon.setImageDrawable(theaterVenueFilterYes);
            theaterVenueFilterText.setText(R.string.hide_theater_events);
        } else {
            theaterVenueFilterIcon.setImageDrawable(theaterVenueFilterNo);
            theaterVenueFilterText.setText(R.string.show_theater_events);
        }

        TextView otherVenueFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.otherVenueFilter);
        ImageView otherVenueFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.otherVenueFilterIcon);
        Drawable otherVenueFilterYes = AppCompatResources.getDrawable(context, R.drawable.icon_unknown);
        Drawable otherVenueFilterNo = AppCompatResources.getDrawable(context, R.drawable.icon_unknown_alt);
        if (staticVariables.preferences.getShowOtherShows() == true) {
            otherVenueFilterIcon.setImageDrawable(otherVenueFilterYes);
            otherVenueFilterText.setText(R.string.hide_other_events);
        } else {
            otherVenueFilterIcon.setImageDrawable(otherVenueFilterNo);
            otherVenueFilterText.setText(R.string.show_other_events);
        }
    }
}
