package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.appcompat.content.res.AppCompatResources;

import java.util.ArrayList;
import java.util.List;

public class OtherFilterHandler {

    private PopupWindow popupWindow;

    public OtherFilterHandler(PopupWindow value){
        popupWindow = value;
    }
    public void setupEventTypeListener(showBands showBands){

        TextView clearFilter = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilter);
        clearFilter.setOnClickListener(new View.OnClickListener() {
             @Override
             public void onClick(View context) {

                 String message = staticVariables.context.getResources().getString(R.string.clear_all_filters);

                 staticVariables.preferences.setShowAlbumListen(true);
                 staticVariables.preferences.setShowClinicEvents(true);
                 staticVariables.preferences.setShowMeetAndGreet(true);
                 staticVariables.preferences.setShowSpecialEvents(true);
                 staticVariables.preferences.setShowUnofficalEvents(true);

                 staticVariables.preferences.setshowMust(true);
                 staticVariables.preferences.setshowMight(true);
                 staticVariables.preferences.setshowWont(true);
                 staticVariables.preferences.setshowUnknown(true);

                 staticVariables.preferences.setShowLoungeShows(true);
                 staticVariables.preferences.setShowPoolShows(true);
                 staticVariables.preferences.setShowRinkShows(true);
                 staticVariables.preferences.setShowTheaterShows(true);
                 staticVariables.preferences.setShowOtherShows(true);

                 staticVariables.preferences.setShowWillAttend(false);

                 staticVariables.preferences.saveData();
                 setupOtherFilters();
                 FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
             }
         });


        LinearLayout onlyShowAttendedAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.onlyShowAttendedAll);
        onlyShowAttendedAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getShowWillAttend() == true) {
                    message = staticVariables.context.getResources().getString(R.string.show_all_events);
                    staticVariables.preferences.setShowWillAttend(false);
                } else {
                    message = staticVariables.context.getResources().getString(R.string.show_only_events_flagged_as_attending);
                    staticVariables.preferences.setShowWillAttend(true);
                }
                staticVariables.preferences.saveData();
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });

        LinearLayout sortOptionAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.sortOptionAll);
        sortOptionAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String message = "";
                if (staticVariables.preferences.getSortByTime() == true) {
                    staticVariables.preferences.setSortByTime(false);
                    message = staticVariables.context.getString(R.string.SortingAlphabetically);
                } else {
                    staticVariables.preferences.setSortByTime(true);
                    message = staticVariables.context.getString(R.string.SortingChronologically);
                }
                staticVariables.preferences.saveData();
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands, message);
            }
        });
    }


    public void setupOtherFilters(){

        if (staticVariables.showEventButtons == true){
            FilterButtonHandler.showMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake6, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.loungVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.poolVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.rinkVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.theaterVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.otherVenueFilterAll, "LinearLayout", popupWindow);

            FilterButtonHandler.showMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake3, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);

            FilterButtonHandler.showMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake4, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);

        } else {
            FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake6, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.loungVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.poolVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.rinkVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.theaterVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.otherVenueFilterAll, "LinearLayout", popupWindow);

            FilterButtonHandler.hideMenuSection(R.id.showOnlyAttendedHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake3, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.onlyShowAttendedAll, "LinearLayout", popupWindow);

            FilterButtonHandler.hideMenuSection(R.id.sortOptionHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake4, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.sortOptionAll, "LinearLayout", popupWindow);
        }
        //if (staticVariables.showUnofficalEventButtons == true){
            FilterButtonHandler.showMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
        //} else {
            //FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            //FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            //FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
        //}

        TextView clearFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilter);
        TextView clearFilterHeader = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilterHeader);
        TextView clearFilterBrake1 = (TextView) popupWindow.getContentView().findViewById(R.id.Brake1);

        if (staticVariables.filteringInPlace == true) {
            clearFilterText.setVisibility(View.VISIBLE);
            clearFilterHeader.setVisibility(View.VISIBLE);
            clearFilterBrake1.setVisibility(View.VISIBLE);

        } else {
            clearFilterText.setVisibility(View.GONE);
            clearFilterHeader.setVisibility(View.GONE);
            clearFilterBrake1.setVisibility(View.GONE);

        }



        TextView onlyShowAttendedText = (TextView) popupWindow.getContentView().findViewById(R.id.onlyShowAttended);
        ImageView onlyShowAttendedIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.onlyShowAttendedIcon);
        Drawable onlyShowAttendedYes = AppCompatResources.getDrawable(context, R.drawable.icon_seen);
        Drawable onlyShowAttendedNo = AppCompatResources.getDrawable(context, R.drawable.icon_seen_alt);

        if (staticVariables.preferences.getShowWillAttend() == false && staticVariables.showEventButtons == true) {
            onlyShowAttendedIcon.setImageDrawable(onlyShowAttendedYes);
            onlyShowAttendedText.setText(R.string.show_only_flagged_as_attended);

            FilterButtonHandler.showMenuSection(R.id.bandRankingHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake2, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.mustSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.mightSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.wontSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.UnknownSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.Brake6, "TextView", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.loungVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.poolVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.rinkVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.theaterVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.showMenuSection(R.id.otherVenueFilterAll, "LinearLayout", popupWindow);

        } else if (staticVariables.showEventButtons == true){
            onlyShowAttendedIcon.setImageDrawable(onlyShowAttendedNo);
            onlyShowAttendedText.setText(R.string.show_all_events);

            FilterButtonHandler.hideMenuSection(R.id.bandRankingHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake2, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.mustSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.mightSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.wontSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.UnknownSeeFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.eventTypeHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake5, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.meetAndGreetFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.specialOtherEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.unofficalEventFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.locationFilterHeader, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.Brake6, "TextView", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.loungVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.poolVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.rinkVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.theaterVenueFilterAll, "LinearLayout", popupWindow);
            FilterButtonHandler.hideMenuSection(R.id.otherVenueFilterAll, "LinearLayout", popupWindow);
        }

        TextView sortOptionText = (TextView) popupWindow.getContentView().findViewById(R.id.sortOption);
        ImageView sortOptionIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.sortOptionIcon);
        Drawable sortOptionName = AppCompatResources.getDrawable(context, R.drawable.icon_sort_az);
        Drawable sortOptionTime = AppCompatResources.getDrawable(context, R.drawable.icon_sort_time);
        if (staticVariables.preferences.getSortByTime()== false) {
            sortOptionIcon.setImageDrawable(sortOptionTime);
            sortOptionText.setText(R.string.sort_by_time);
        } else {
            sortOptionIcon.setImageDrawable(sortOptionName);
            sortOptionText.setText(R.string.sort_by_name);
        }

    }
}
