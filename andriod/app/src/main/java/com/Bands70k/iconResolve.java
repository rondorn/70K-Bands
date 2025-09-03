package com.Bands70k;

import android.util.Log;

public class iconResolve {


    public static int getEventIcon(String eventType, String eventName) {

        Integer imageId = 0;

        Log.d("getEventIcon", eventType + " does it match " + staticVariables.graphicClinicEvent);

        if (eventType == null) {
            imageId = 0;
        } else {

            if (eventType.equals(staticVariables.unofficalEvent)) {
                imageId = staticVariables.graphicUnofficalEvent;

            } else if (eventType.equals(staticVariables.specialEvent)) {
                if (eventName.equals("All Star Jam")){
                    imageId = staticVariables.graphicSpecialEvent;

                } else if (eventName.contains("Karaoke")){
                    imageId = staticVariables.graphicKaraokeEvent;

                } else {
                    imageId = staticVariables.graphicGeneralEvent;
                }

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
        // Use the centralized venue color system from staticVariables which now uses FestivalConfig
        return staticVariables.getVenueColor(location);
    }
}
