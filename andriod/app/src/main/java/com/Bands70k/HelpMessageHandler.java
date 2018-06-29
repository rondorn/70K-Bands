package com.Bands70k;

import android.view.Gravity;
import android.widget.Toast;

public class HelpMessageHandler {

    private static Toast mytoast;
    public static void showMessage(String message){

        if (mytoast != null) {
            mytoast.cancel();
        }

        mytoast = Toast.makeText(staticVariables.context, message, Toast.LENGTH_LONG);
        mytoast.setGravity(Gravity.CENTER|Gravity.CENTER_HORIZONTAL, 0, 0);
        mytoast.show();
    }
}
