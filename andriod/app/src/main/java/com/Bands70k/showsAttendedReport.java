package com.Bands70k;

import android.util.Log;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class showsAttendedReport {

    private Map<String,Map<String,Integer>> eventCounts = new HashMap<String,Map<String,Integer>>();
    private Map<String,Map<String,Map<String,Integer>>> bandCounts = new HashMap<String,Map<String,Map<String,Integer>>>();

    public void assembleReport() {

        showsAttended attendedHandler = new showsAttended();
        Map<String, String> showsAttendedArray = attendedHandler.getShowsAttended();

        for (String index : showsAttendedArray.keySet()) {

            String[] indexArray = index.split(":");

            String bandName = indexArray[0];
            String eventType = indexArray[4];

            Log.d("ShareMessag", "index is " + index);
            Log.d("ShareMessag", "eventType is " + eventType);

            getEventTypeCounts(eventType, showsAttendedArray.get(index));
            getBandCounts(eventType, bandName,  showsAttendedArray.get(index));

        }
    }

    public String addPlural(Integer count){

        String message = "";

        if (count >= 2){
            message += "s";
        }
        message += "\n";

        return message;

    }

    public String buildMessage() {

        String message = "";

        Map<String, Boolean> eventCountExists = new HashMap<String, Boolean>();

        Set<String> sortedBandEvents = eventCounts.keySet();
        List<String> sortedBandEventsArray = new ArrayList<String>();
        sortedBandEventsArray.addAll(sortedBandEvents);
        Collections.sort(sortedBandEventsArray);

        for (String eventType : sortedBandEventsArray) {

            Integer sawAllCount = eventCounts.get(eventType).get(staticVariables.sawAllStatus);
            Integer sawSomeCount = eventCounts.get(eventType).get(staticVariables.sawSomeStatus);

            Log.d("ShareMessag", "sawAllCount is " + sawAllCount);

            if (sawAllCount != null && sawAllCount >= 1) {
                eventCountExists.put(eventType, true);
                String sawAllCountString = sawAllCount.toString();
                message += "Saw " + sawAllCountString + " " + eventType + addPlural(sawAllCount);
            }
            if (sawSomeCount != null && sawSomeCount >= 1) {
                eventCountExists.put(eventType, true);
                String sawSomeCountString = sawSomeCount.toString();
                message += "Saw part of " + sawSomeCountString + " " + eventType + addPlural(sawSomeCount);
            }
        }

        message += "\n";

        for (String eventType : bandCounts.keySet()) {

            Integer sawSomeCount = 0;

            Set<String> sortedBandNames = bandCounts.get(eventType).keySet();
            List<String> sortedBandNamesArray = new ArrayList<String>();
            sortedBandNamesArray.addAll(sortedBandNames);
            Collections.sort(sortedBandNamesArray);

            if (eventCountExists.containsKey(eventType) == true){

                message += "For " + eventType + "s\n";

                for (String bandName : sortedBandNamesArray){

                    Integer sawCount = 0;
                    if (bandCounts.get(eventType).get(bandName).get(staticVariables.sawAllStatus) != null){
                        sawCount = sawCount + bandCounts.get(eventType).get(bandName).get(staticVariables.sawAllStatus);
                    }
                    if (bandCounts.get(eventType).get(bandName).get(staticVariables.sawSomeStatus) != null){
                        sawSomeCount = sawCount + bandCounts.get(eventType).get(bandName).get(staticVariables.sawSomeStatus);
                    }

                    if (sawCount >= 1){
                        String sawCountString = sawCount.toString();
                        if (eventType.equals(staticVariables.show)){
                            message += "     " + bandName + " " + sawCountString + " time" + addPlural(sawCount);
                        } else {
                            message += "      " + bandName + "\n";
                        }
                    }
                }
                if (sawSomeCount >= 1){
                    String sawSomeCountString = sawSomeCount.toString();
                    message += "\n" + sawSomeCountString + " of those were partial shows";
                }
            }

        }

        return message;
    }

    public void getEventTypeCounts (String eventType, String sawStatus){

        if (eventCounts.containsKey(eventType) == false){
            eventCounts.put(eventType, new HashMap<String,Integer>());
        }

        if (eventCounts.get(eventType).containsKey(sawStatus) == false){
            eventCounts.get(eventType).put(sawStatus, 1);

        } else {
            Integer newCount = eventCounts.get(eventType).get(sawStatus) + 1;
            eventCounts.get(eventType).put(sawStatus, newCount);
        }
    }

    public void getBandCounts (String eventType,String bandName, String sawStatus){

        Log.d("ShareMessag", "getBandCounts" + eventType + "-" + bandName + "-" + sawStatus);

        if (bandCounts.containsKey(eventType) == false){
            bandCounts.put(eventType, new HashMap<String, Map<String, Integer>>());
        }

        if (bandCounts.get(eventType).containsKey(bandName) == false){
            bandCounts.get(eventType).put(bandName, new HashMap<String,Integer>());
        }

        if (bandCounts.get(eventType).get(bandName).containsKey(sawStatus) == false){
            bandCounts.get(eventType).get(bandName).put(sawStatus, 1);
        } else {

            Log.d("ShareMessag", "adding to " + bandCounts.get(eventType).get(bandName).get(sawStatus));
            Integer newCount = bandCounts.get(eventType).get(bandName).get(sawStatus) + 1;
            bandCounts.get(eventType).get(bandName).put(sawStatus, newCount);
        }
    }
}