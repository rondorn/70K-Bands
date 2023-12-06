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

        try {
            if (dateString.contains("29/10") == true && dateValue.contains("Day") == false){
                newDateValue =  monthDayValues[1] + "/" +   monthDayValues[0];
            }
        } catch (Exception error){
            newDateValue = dateValue;
        }

        Log.d("monthDateRegional", "Converting " + dateValue + " to " + newDateValue  + " using " + dateString);
        return newDateValue;
    }

    public static String convertEventTypeToLocalLanguage(String eventType){

        String localEventType = eventType;

        if (eventType.equals("Cruiser Organized")) {
            localEventType = staticVariables.context.getString(R.string.unofficalEventLable);

        } else if (eventType.equals("Listening Party")) {
            localEventType = staticVariables.context.getString(R.string.AlbumListeningEvents);

        } else if (eventType.equals("Clinic")) {
            localEventType = staticVariables.context.getString(R.string.ClinicEvents);

        } else if (eventType.equals("Meet and Greet")) {
            localEventType = staticVariables.context.getString(R.string.MeetAndGreet);

        } else if (eventType.equals("Special Event")) {
            localEventType = staticVariables.context.getString(R.string.SpecialEvents);
        }

        return localEventType;

    }
}
