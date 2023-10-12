package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.appcompat.content.res.AppCompatResources;

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
                 FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
             }
         });


        LinearLayout onlyShowAttendedAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.onlyShowAttendedAll);
        onlyShowAttendedAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                if (staticVariables.preferences.getShowWillAttend() == true) {
                    staticVariables.preferences.setShowWillAttend(false);
                } else {
                    staticVariables.preferences.setShowWillAttend(true);
                }
                staticVariables.preferences.saveData();
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });

        LinearLayout sortOptionAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.sortOptionAll);
        sortOptionAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                if (staticVariables.preferences.getSortByTime() == true) {
                    staticVariables.preferences.setSortByTime(false);
                } else {
                    staticVariables.preferences.setSortByTime(true);
                }
                staticVariables.preferences.saveData();
                setupOtherFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });
    }


    public void setupOtherFilters(){

        TextView clearFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilter);
        TextView clearFilterHeader = (TextView) popupWindow.getContentView().findViewById(R.id.clearFilterHeader);
        TextView clearFilterbreak1 = (TextView) popupWindow.getContentView().findViewById(R.id.break1);

        if (staticVariables.preferences.getShowAlbumListen() == false ||
            staticVariables.preferences.getShowClinicEvents() == false ||
            staticVariables.preferences.getShowMeetAndGreet() == false ||
            staticVariables.preferences.getShowSpecialEvents() == false ||
            staticVariables.preferences.getShowUnofficalEvents() == false ||

            staticVariables.preferences.getShowMust() == false ||
            staticVariables.preferences.getShowMight() == false ||
            staticVariables.preferences.getShowWont() == false ||
            staticVariables.preferences.getShowUnknown() == false ||

            staticVariables.preferences.getShowLoungeShows() == false ||
            staticVariables.preferences.getShowPoolShows() == false ||
            staticVariables.preferences.getShowRinkShows() == false ||
            staticVariables.preferences.getShowOtherShows() == false ||
            staticVariables.preferences.getShowMeetAndGreet() == false ||
                staticVariables.preferences.getAlertOnlyForShowWillAttend() == true
        ) {


            clearFilterText.setVisibility(View.VISIBLE);
            clearFilterHeader.setVisibility(View.VISIBLE);
            clearFilterbreak1.setVisibility(View.VISIBLE);

        } else {
            clearFilterText.setVisibility(View.GONE);
            clearFilterHeader.setVisibility(View.GONE);
            clearFilterbreak1.setVisibility(View.GONE);

        }



        TextView onlyShowAttendedText = (TextView) popupWindow.getContentView().findViewById(R.id.onlyShowAttended);
        ImageView onlyShowAttendedIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.onlyShowAttendedIcon);
        Drawable onlyShowAttendedYes = AppCompatResources.getDrawable(context, R.drawable.icon_seen);
        Drawable onlyShowAttendedNo = AppCompatResources.getDrawable(context, R.drawable.icon_seen_alt);
        if (staticVariables.preferences.getShowWillAttend() == false) {
            onlyShowAttendedIcon.setImageDrawable(onlyShowAttendedYes);
            onlyShowAttendedText.setText(R.string.show_only_flagged_as_attended);
        } else {
            onlyShowAttendedIcon.setImageDrawable(onlyShowAttendedNo);
            onlyShowAttendedText.setText(R.string.show_all_events);
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
