package com.Bands70k;

import static com.Bands70k.staticVariables.context;

import android.view.Gravity;
import android.view.View;
import android.widget.Toast;

import com.google.android.material.snackbar.Snackbar;

public class HelpMessageHandler {

    private static Toast mytoast;
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

    public static void showSnackMessage(String message, View mainView, Integer anchoreView){

        Snackbar snackbar = Snackbar.make(mainView, message, Snackbar.LENGTH_SHORT);
        snackbar.setAnchorView(anchoreView);
        snackbar.show();

    }
}
