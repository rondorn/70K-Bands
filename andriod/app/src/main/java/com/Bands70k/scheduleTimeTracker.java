package com.Bands70k;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Created by rdorn on 8/19/15.
 */
public class scheduleTimeTracker {

    public Map<Long, scheduleHandler> scheduleByTime = new TreeMap<>();
    public List<Long> eventIndexes = new ArrayList<Long>();

    public void addToscheduleByTime(Long dateValue, scheduleHandler scheduleValue){
        scheduleByTime.put(dateValue, scheduleValue);
        eventIndexes.add(dateValue);
    }

    public List<Long> getEventIndexes(){

        Collections.sort(eventIndexes);
        return eventIndexes;
    }

    public scheduleHandler getEvents(Long index){

        return scheduleByTime.get(index);
    }
}
