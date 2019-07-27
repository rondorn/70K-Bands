package com.Bands70k;

import android.util.Log;

public class iconResolve {


    public static int getEventIcon(String eventType) {

        Integer imageId = 0;

        Log.d("getEventIcon", eventType + " does it match " + staticVariables.graphicClinicEvent);

        if (eventType == null) {
            imageId = 0;
        } else {

            if (eventType.equals(staticVariables.unofficalEvent)) {
                imageId = staticVariables.graphicUnofficalEvent;

            } else if (eventType.equals(staticVariables.specialEvent)) {
                imageId = staticVariables.graphicSpecialEvent;

            } else if (eventType.equals(staticVariables.clinic)) {
                imageId = staticVariables.graphicClinicEvent;

            } else if (eventType.equals(staticVariables.meetAndGreet)) {
                imageId = staticVariables.graphicMeetAndGreetEvent;

            } else if (eventType.equals(staticVariables.karaoekeEvent)) {
                imageId = staticVariables.graphicKaraokeEvent;
            }
        }

        return imageId;
    }

    public static int getAttendedIcon(String attendedStatus) {

        Integer imageId = 0;

        Log.d("getAttendedIcon", attendedStatus + " does it match " + staticVariables.sawSomeStatus);

        if (attendedStatus == null) {
            imageId = 0;
        } else {

            if (attendedStatus.equals(staticVariables.sawAllIcon)) {
                imageId = staticVariables.graphicAttended;

            } else if (attendedStatus.equals(staticVariables.sawSomeIcon)) {
                imageId = staticVariables.graphicPartiallyAttended;

            } else {
                imageId = 0;
            }
        }

        Log.d("getAttendedIcon", attendedStatus + " returned " + imageId);

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
