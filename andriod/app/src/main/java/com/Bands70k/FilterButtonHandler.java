package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.media.Image;
import android.os.Bundle;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.style.ImageSpan;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;

import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.PopupMenu;

import android.widget.ImageView;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.widget.Toast;


import java.lang.reflect.Field;

//public class FilterButtonHandler {
public class FilterButtonHandler  {
    public Button filterMenuButton;

    public void setUpFiltersButton(showBands showBands){

        filterMenuButton = (Button) showBands.findViewById(R.id.FilerMenu);

        filterMenuButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View context) {

                PopupWindow popupWindow = new PopupWindow(showBands);
                LayoutInflater inflater = (LayoutInflater) staticVariables.context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);

                View view = inflater.inflate(R.layout.filter_choices_menu_layout, null);

                popupWindow.setFocusable(true);
                popupWindow.setWidth(WindowManager.LayoutParams.WRAP_CONTENT);
                popupWindow.setHeight(WindowManager.LayoutParams.WRAP_CONTENT);
                popupWindow.setContentView(view);

                popupWindow.showAsDropDown(filterMenuButton, 0, 0);
            }
        });
    }

}
