package com.Bands70k;

import android.text.format.DateFormat;
import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Created by rdorn on 5/29/18.
 */

public class dateTimeFormatter {

    public static String formatScheduleTime(String timeValue){

        if (DateFormat.is24HourFormat(staticVariables.context) == false){
            try {

                SimpleDateFormat _24HourSDF = new SimpleDateFormat("HH:mm");

                SimpleDateFormat _12HourSDF = new SimpleDateFormat("hh:mm a");
                Date _24HourDt = _24HourSDF.parse(timeValue);

                timeValue = (_12HourSDF.format(_24HourDt));
            } catch (Exception error) {
                Log.e("error", "unable to parse time value  " + error.getMessage());
            }
        }

        timeValue = timeValue.replace(" AM", "am").replace(" PM","pm");
        timeValue = timeValue.replace(" a. m.", "am").replace(" p. m.","pm");
        return timeValue;
    }
}
