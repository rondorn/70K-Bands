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
public class FilterButtonHandler extends AppCompatActivity implements PopupMenu.OnMenuItemClickListener {
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
                //popupWindow.setBackgroundDrawable(null);

                popupWindow.showAsDropDown(filterMenuButton, 0, 0);


                //Drawable mustSeeFilerIcon = getDrawable(R.drawable.icon_going_yes);
                //ImageView mustSeeFilerIconViewer = (ImageView) findViewById(R.id.mustSeeFilterIcon);

                //mustSeeFilerIconViewer.setImageDrawable(mustSeeFilerIcon);

                /*
                PopupMenu popup = new PopupMenu(showBands, filterMenuButton);

                popup.getMenuInflater().inflate(R.menu.filters_menu, popup.getMenu());

                //popup.show();//showing popup menu

                //popup.inflate(R.menu.filters_menu);

                if (android.os.Build.VERSION.SDK_INT >= 29) {
                    popup.setForceShowIcon(true);
                }
                popup.show();

                Integer counter = 0;
                Log.d("FilterpopupMenuChoice", "Starting Work on menu item" + popup.getMenu().getItem(counter) );
                try {
                    while (popup.getMenu().getItem(counter) != null) {
                        MenuItem menu_item = popup.getMenu().getItem(counter);
                        String optiontitle = String.valueOf(menu_item.getTitle());
                        Log.d("FilterpopupMenuChoice", "Working on menu item" + optiontitle);
                        onMenuItemClick(menu_item);
                        SpannableString newMenuItemTitle = new SpannableString(menu_item.getTitle() + "\n       ");
                        Drawable icon = menu_item.getIcon();
                        if (icon != null) {
                            icon.setBounds(0, 0, icon.getIntrinsicWidth(), icon.getIntrinsicHeight());
                            ImageSpan span = new ImageSpan(icon, ImageSpan.ALIGN_BASELINE);
                            Integer startPoint = menu_item.getTitle().length() + 3;
                            Integer endPoint = startPoint + 3;
                            newMenuItemTitle.setSpan(span, startPoint, endPoint, Spannable.SPAN_INCLUSIVE_EXCLUSIVE);
                            Log.d("FilterpopupMenuChoice", "new menu title is " + newMenuItemTitle + " " + String.valueOf(startPoint) + " " + String.valueOf(endPoint));

                            //menu_item.setTitle(newMenuItemTitle);
                            //menu_item.setIcon(null);

                        }

                        counter = counter + 1;
                    }
                }catch (Exception error){
                    Log.d("FilterpopupMenuChoice", "It blew up " + error.getMessage() + " " + error.getStackTrace());
                }
                */
            }


        });
    }


    public void establishedChoiceListener(MenuItem menu_item){

        menu_item.setOnMenuItemClickListener(new MenuItem.OnMenuItemClickListener() {
            @Override
            public boolean onMenuItemClick(MenuItem item) {
                //FilterButtonHandler.onFilterMenuSelect(menu_item);
                return true;
            }
        });
    }
    public void testMethod2(showBands showBands){

            // Initialize the PopupMenu

        filterMenuButton.setBackgroundColor(Color.BLACK);
        filterMenuButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View context) {

            }
        });

    }

    public void testMethod(showBands showBands){

        filterMenuButton = (Button) showBands.findViewById(R.id.FilerMenu);
        PopupWindow popup;

        LayoutInflater mInflater = (LayoutInflater) showBands
                .getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View layout = mInflater.inflate(R.layout.filter_choices_menu_layout, null); //popup row is item xml

        //layout.measure(View.MeasureSpec.UNSPECIFIED,
        //        View.MeasureSpec.UNSPECIFIED);
        popup = new PopupWindow(layout, FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,true);

        //final TextView popupMenuitem = (TextView) layout.findViewById(R.id.FilerMenu);
        // set click on listner on item where you can close the popup by dismiss()

        popup.showAsDropDown(filterMenuButton,0,0); // filtericon is button name , clicking

        //popup.dismiss();  // to close popup call this
    }


    @Override
    public boolean onMenuItemClick(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.mustSeeFilter:
                Toast.makeText(context,
                        "Must See Chosen", Toast.LENGTH_SHORT).show();
            case R.id.mightSeeFilter:
                Toast.makeText(context,
                        "Might See Chosen", Toast.LENGTH_SHORT).show();
            default:
                //do nothing
        }

        return true;
    }
}
