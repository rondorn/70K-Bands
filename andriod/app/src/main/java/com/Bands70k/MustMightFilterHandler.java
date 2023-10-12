package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.appcompat.content.res.AppCompatResources;

public class MustMightFilterHandler {

    private PopupWindow popupWindow;

    public MustMightFilterHandler(PopupWindow value){
        popupWindow = value;
    }
    public void setupMustMightListener(showBands showBands){
        LinearLayout mustFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.mustSeeFilterAll);
        mustFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String status = "None";
                if (staticVariables.preferences.getShowMust() == true) {
                    status = "On";
                    staticVariables.preferences.setshowMust(false);
                } else {
                    staticVariables.preferences.setshowMust(true);
                    status = "Off";
                }
                staticVariables.preferences.saveData();
                setupMustMightFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });

        LinearLayout mightFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.mightSeeFilterAll);
        mightFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String status = "None";
                if (staticVariables.preferences.getShowMight() == true) {
                    status = "On";
                    staticVariables.preferences.setshowMight(false);
                } else {
                    staticVariables.preferences.setshowMight(true);
                    status = "Off";
                }
                staticVariables.preferences.saveData();
                setupMustMightFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });

        LinearLayout wontFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.wontSeeFilterAll);
        wontFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String status = "None";
                if (staticVariables.preferences.getShowWont() == true) {
                    status = "On";
                    staticVariables.preferences.setshowWont(false);
                } else {
                    staticVariables.preferences.setshowWont(true);
                    status = "Off";
                }
                staticVariables.preferences.saveData();
                setupMustMightFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });


        LinearLayout unknownFilterAll = (LinearLayout) popupWindow.getContentView().findViewById(R.id.UnknownSeeFilterAll);
        unknownFilterAll.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View context) {
                String status = "None";
                if (staticVariables.preferences.getShowUnknown() == true) {
                    status = "On";
                    staticVariables.preferences.setshowUnknown(false);
                } else {
                    staticVariables.preferences.setshowUnknown(true);
                    status = "Off";
                }
                staticVariables.preferences.saveData();
                setupMustMightFilters();
                FilterButtonHandler.refreshAfterButtonClick(popupWindow, showBands);
            }
        });
    }


    public void setupMustMightFilters(){

        TextView mustFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.mustSeeFilter);
        ImageView mustFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.mustSeeFilterIcon);
        Drawable mustSeeYes = AppCompatResources.getDrawable(context, R.drawable.icon_going_yes);
        Drawable mustSeeYesAlt = AppCompatResources.getDrawable(context, R.drawable.icon_going_yes_alt);
        if (staticVariables.preferences.getShowMust() == true) {
            mustFilterIcon.setImageDrawable(mustSeeYes);
            mustFilterText.setText(R.string.hide_must_see_items);
        } else {
            mustFilterIcon.setImageDrawable(mustSeeYesAlt);
            mustFilterText.setText(R.string.show_must_see_items);
        }

        TextView mightFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.mightSeeFilter);
        ImageView mightFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.mightSeeFilterIcon);
        Drawable mightSeeYes = AppCompatResources.getDrawable(context, R.drawable.icon_going_maybe);
        Drawable mightSeeYesAlt = AppCompatResources.getDrawable(context, R.drawable.icon_going_maybe_alt);
        if (staticVariables.preferences.getShowMight() == true) {
            mightFilterIcon.setImageDrawable(mightSeeYes);
            mightFilterText.setText(R.string.hide_might_see_items);
        } else {
            mightFilterIcon.setImageDrawable(mightSeeYesAlt);
            mightFilterText.setText(R.string.show_might_see_items);
        }

        TextView wontFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.wontSeeFilter);
        ImageView wontFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.wontSeeFilterIcon);
        Drawable wontSeeYes = AppCompatResources.getDrawable(context, R.drawable.icon_going_no);
        Drawable wontSeeYesAlt = AppCompatResources.getDrawable(context, R.drawable.icon_going_no_alt);
        if (staticVariables.preferences.getShowWont() == true) {
            wontFilterIcon.setImageDrawable(wontSeeYes);
            wontFilterText.setText(R.string.hide_wont_see_items);
        } else {
            wontFilterIcon.setImageDrawable(wontSeeYesAlt);
            wontFilterText.setText(R.string.show_wont_see_items);
        }

        TextView unknownFilterText = (TextView) popupWindow.getContentView().findViewById(R.id.unknownSeeFilter);
        ImageView unknownFilterIcon = (ImageView) popupWindow.getContentView().findViewById(R.id.unknownSeeFilterIcon);
        Drawable unknownSeeYes = AppCompatResources.getDrawable(context, R.drawable.icon_unknown);
        Drawable unknownSeeYesAlt = AppCompatResources.getDrawable(context, R.drawable.icon_unknown_alt);
        if (staticVariables.preferences.getShowUnknown() == true) {
            unknownFilterIcon.setImageDrawable(unknownSeeYes);
            unknownFilterText.setText(R.string.hide_unknown_items);
        } else {
            unknownFilterIcon.setImageDrawable(unknownSeeYesAlt);
            unknownFilterText.setText(R.string.show_unknown_items);
        }
    }
}
