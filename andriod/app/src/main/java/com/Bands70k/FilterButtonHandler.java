package com.Bands70k;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.PopupMenu;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.widget.Toast;

import androidx.core.view.MenuCompat;

public class FilterButtonHandler {

    public Button filterMenuButton;

    public void setUpFiltersButton(showBands showBands){

        filterMenuButton = (Button) showBands.findViewById(R.id.FilerMenu);
        filterMenuButton.setOnClickListener(new Button.OnClickListener() {
            public void onClick(View context) {

                PopupMenu popup = new PopupMenu(context.getContext(), filterMenuButton);
                popup.inflate(R.menu.filters_menu);
                if (android.os.Build.VERSION.SDK_INT >= 29) {
                    popup.setForceShowIcon(true);
                }

                //popup.getMenu().add(Menu.NONE, 1, Menu.NONE, "test");
                //popup.getMenu().add(Menu.NONE, 2, Menu.NONE, "test3");
                //popup.setOnMenuItemClickListener(popup);
                popup.show();

                popup.show();
                MenuCompat.setGroupDividerEnabled(popup.getMenu(), true);

                MenuItem item = popup.getMenu().getItem(0);
                //item.getActionView().setBackgroundResource(R.drawable.default_text_color);

                //setBackgroundResource(R.color.common_google_signin_btn_text_dark_disabled);

                Toast.makeText(context.getContext(),
                        item.getTitle() + " ", Toast.LENGTH_SHORT).show();


                //testMethod(showBands);
            }
        });

    }

    public void testMethod2(showBands showBands){
        /*
        final showBands.WindowManager windowManager = (WindowManager) mContext.getSystemService(
                Context.WINDOW_SERVICE);
        final Display display = windowManager.getDefaultDisplay();
        final Point displaySize = new Point();

        if (Build.VERSION.SDK_INT >= 17) {
            display.getRealSize(displaySize);
        } else if (Build.VERSION.SDK_INT >= 13) {
            display.getSize(displaySize);
        } else {
            displaySize.set(display.getWidth(), display.getHeight());
        }

        final int smallestWidth = Math.min(displaySize.x, displaySize.y);
        final int minSmallestWidthCascading = mContext.getResources().getDimensionPixelSize(
                R.dimen.abc_cascading_menus_min_smallest_width);
        final boolean enableCascadingSubmenus = smallestWidth >= minSmallestWidthCascading;

        final MenuPopup popup;
        if (enableCascadingSubmenus) {
            popup = new CascadingMenuPopup(mContext, mAnchorView, mPopupStyleAttr,
                    mPopupStyleRes, mOverflowOnly);
        } else {
            popup = new StandardMenuPopup(mContext, mMenu, mAnchorView, mPopupStyleAttr,
                    mPopupStyleRes, mOverflowOnly);
        }

        // Assign immutable properties.
        popup.addMenu(mMenu);
        popup.setOnDismissListener(mInternalOnDismissListener);

        // Assign mutable properties. These may be reassigned later.
        popup.setAnchorView(mAnchorView);
        popup.setCallback(mPresenterCallback);
        popup.setForceShowIcon(mForceShowIcon);
        popup.setGravity(mDropDownGravity);

        return popup;
        */

    }
    public void testMethod(showBands showBands){

        filterMenuButton = (Button) showBands.findViewById(R.id.FilerMenu);
        PopupWindow popup;

        LayoutInflater mInflater = (LayoutInflater) showBands
                .getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View layout = mInflater.inflate(R.layout.activity_show_bands, null); //popup row is item xml

        layout.measure(View.MeasureSpec.UNSPECIFIED,
                View.MeasureSpec.UNSPECIFIED);
        popup = new PopupWindow(layout, FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,true);

        final TextView popupMenuitem = (TextView) layout.findViewById(R.id.FilerMenu);
        // set click on listner on item where you can close the popup by dismiss()

        popup.showAsDropDown(filterMenuButton,5,5); // filtericon is button name , clicking

        //popup.dismiss();  // to close popup call this
    }
}
