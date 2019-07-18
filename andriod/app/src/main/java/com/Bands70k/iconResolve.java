package com.Bands70k;

import android.util.Log;

public class iconResolve {


    public static int getEventIcon(String eventType) {

        Integer imageId = 0;

        if (eventType == null) {
            imageId = 0;
        } else {

            if (eventType == staticVariables.unofficalEvent) {
                imageId = staticVariables.graphicUnofficalEvent;

            } else if (eventType == staticVariables.specialEvent) {
                imageId = staticVariables.graphicSpecialEvent;

            } else if (eventType == staticVariables.clinic) {
                imageId = staticVariables.graphicClinicEvent;

            } else if (eventType == staticVariables.meetAndGreet) {
                imageId = staticVariables.graphicMeetAndGreetEvent;

            } else if (eventType == staticVariables.karaoekeEvent) {
                imageId = staticVariables.graphicKaraokeEvent;
            }
        }

        return imageId;
    }

    public static int getAttendedIcon(String attendedStatus) {

        Integer imageId = 0;

        if (attendedStatus == null) {
            imageId = 0;
        } else {

            if (attendedStatus == staticVariables.sawAllIcon) {
                imageId = staticVariables.graphicAttended;

            } else if (attendedStatus == staticVariables.sawSomeStatus) {
                imageId = staticVariables.graphicPartiallyAttended;

            } else {
                imageId = 0;
            }
        }

        return imageId;
    }

    public static String getLocationColor(String location){

        String eventColor = staticVariables.unknownVenueColor;

        Log.d("colorResolve", location + " does it match " + staticVariables.poolVenueText);

        if (location.equals(staticVariables.poolVenueText)){
            eventColor = staticVariables.poolVenueColor;

        } else if (location.equals(staticVariables.theaterVenueText)){
            eventColor = staticVariables.theaterVenueColor;

        } else if (location.equals(staticVariables.loungeVenueText)){
            eventColor = staticVariables.loungeVenueColor;

        } else if (location.equals(staticVariables.rinkVenueText)) {
            eventColor = staticVariables.rinkVenueColor;

        }

        return eventColor;
    }
}
