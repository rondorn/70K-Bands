package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

//import com.google.android.material.snackbar.BaseTransientBottomBar;
//import com.google.android.material.snackbar.Snackbar;

/**
 * Utility class for displaying help and toast messages to the user.
 */
public class HelpMessageHandler {

    private static Toast mytoast;
    /**
     * Shows a toast message centered on the screen.
     * @param message The message to display.
     */
    public static void showMessage(String message){

        if (mytoast != null) {
            mytoast.cancel();
        }
        if (staticVariables.context != null) {
            mytoast = Toast.makeText(staticVariables.context, message, Toast.LENGTH_LONG);
            mytoast.setGravity(Gravity.CENTER | Gravity.CENTER_HORIZONTAL, 0, 0);
            mytoast.show();
        }
    }

    /**
     * Shows a toast message and (optionally) a snackbar on the provided view.
     * @param message The message to display.
     * @param mainView The main view to anchor the snackbar (currently unused).
     */
    public static void showMessage(String message, View mainView){

        HelpMessageHandler.showMessage(message);

        /*
        Snackbar snack = Snackbar.make(mainView, message, Snackbar.LENGTH_SHORT);
        View view = snack.getView();
        FrameLayout.LayoutParams params =(FrameLayout.LayoutParams)view.getLayoutParams();
        params.gravity = Gravity.CENTER;
        params.setMargins(50,10,50,10);
        view.setLayoutParams(params);
        snack.setAnimationMode(BaseTransientBottomBar.ANIMATION_MODE_FADE);
        snack.show();
        */
    }
}
