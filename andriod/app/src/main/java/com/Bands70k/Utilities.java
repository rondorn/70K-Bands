package com.Bands70k;

import android.util.Log;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class Utilities {


    public static String monthDateRegionalFormatting(String dateValue){

        String newDateValue = dateValue;

        String[] monthDayValues = dateValue.split("/");

        String sampleDate = "10/29/2019";
        SimpleDateFormat sdf = new SimpleDateFormat("MM/dd/yyyy");
        Date date = null;
        try {
            date = sdf.parse(sampleDate);
        } catch (ParseException e) {
            Log.d("Error", e.getMessage());
            return dateValue;
        }

        //DateFormat format = DateFormat.getDateInstance(DateFormat.SHORT, Locale.getDefault());
        String dateString = DateFormat.getDateInstance(DateFormat.SHORT,Locale.getDefault()).format(date);

        if (dateString.contains("29/10") == true && dateValue.contains("Day") == false){
            newDateValue =  monthDayValues[1] + "/" +   monthDayValues[0];
        }

        Log.d("monthDateRegional", "Converting " + dateValue + " to " + newDateValue  + " using " + dateString);
        return newDateValue;
    }

}
