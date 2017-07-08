package com.Bands70k;

import java.util.HashMap;
import java.util.Map;
import java.util.TreeMap;

/**
 * Created by rdorn on 8/19/15.
 */
public class scheduleTimeTracker {

    public Map<Long, scheduleHandler> scheduleByTime = new TreeMap<>();

    public void addToscheduleByTime(Long dateValue, scheduleHandler scheduleValue){
        scheduleByTime.put(dateValue, scheduleValue);
    }
}
