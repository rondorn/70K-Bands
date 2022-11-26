package com.Bands70k;


import android.os.Build;
import android.os.Environment;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import junit.framework.TestCase;
import org.junit.Before;
import org.junit.Rule;

import static com.Bands70k.staticVariables.staticVariablesInitialize;
import static org.mockito.Mockito.when;

import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.powermock.api.mockito.PowerMockito;
import org.powermock.core.classloader.annotations.PrepareForTest;
import org.powermock.modules.junit4.PowerMockRunner;
import org.robolectric.util.ReflectionHelpers;

@RunWith(PowerMockRunner.class)
@PrepareForTest({Environment.class,Build.class,OnlineStatus.class})


public class ShowsAttendedTest extends TestCase {

    private BandInfo bandInfo;
    private showsAttended attendedHandler;

    private static final String firstBand = "Aborted";
    private static final String lastBand = "Zero Theorem";

    private static final String firstExpectedLocation = "Boleros Lounge";
    private static final String firstExpectedStartTime = "15:00";
    private static final String firstExpectedEndTime = "16:00";
    private static final String firstExpectedDay = "Day 2";
    private static final String firstExpectedEventType = "Meet and Greet";
    private static final Long firstExpectedEpochStartTime = Long.parseLong("1578524400000");

    private static final String lastExpectedLocation = "Rink";
    private static final String lastExpectedStartTime = "20:30";
    private static final String lastExpectedEndTime = "21:15";
    private static final String lastExpectedDay = "Day 4";
    private static final String lastExpectedEventType = "Show";
    private static final Long lastExpectedEpochStartTime = Long.parseLong("1578717000000");

    /*
    @Rule
    TemporaryFolder tempFolder = new TemporaryFolder();

    @Before
    public void doSetup() throws IOException {
        PowerMockito.mockStatic(Environment.class);
        PowerMockito.mockStatic(Build.class);
        PowerMockito.mockStatic(OnlineStatus.class);

        //when(staticVariables.context.getApplicationContext().getFilesDir().toString()).thenReturn(String.valueOf(tempFolder.newFolder()));
        when(OnlineStatus.isOnline()).thenReturn(true);

        //when(staticVariables.context.getApplicationContext().getFilesDir().toString()).thenReturn(String.valueOf(tempFolder.newFolder()));
        when(OnlineStatus.isOnline()).thenReturn(true);

        ReflectionHelpers.setStaticField(Build.class,"HARDWARE", "golfdish");

        staticVariables.userID = "rdorn";
        staticVariables.inUnitTests = true;
        staticVariables.preferences = new preferencesHandler();
        staticVariablesInitialize();
        staticVariables.preferences.setUseLastYearsData(false);

        bandInfo = new BandInfo();

        preferencesHandler preferences = new preferencesHandler();
        preferences.loadData();

        bandInfo.DownloadBandFile();

        attendedHandler = new showsAttended();
    }

    public void testGetSchedule(){

        Map<String, scheduleTimeTracker> scheduleData = BandInfo.scheduleRecords;

        scheduleTimeTracker firstBandSchedule = scheduleData.get(firstBand);
        List<Long> eventIndexes = firstBandSchedule.getEventIndexes();

        Long firstEventIndex = eventIndexes.get(0);
        scheduleHandler firstEventFirstBand = firstBandSchedule.getEvents(firstEventIndex);

        String showAttendedStatus = attendedHandler.getShowAttendedStatus(firstEventFirstBand.getBandName(),
                firstEventFirstBand.getShowLocation(),
                firstEventFirstBand.getStartTimeString(),
                firstEventFirstBand.getShowType(),
                staticVariables.eventYear.toString());

        assertEquals(staticVariables.sawNoneStatus, showAttendedStatus);

        attendedHandler.addShowsAttended(   firstEventFirstBand.getBandName(),
                                            firstEventFirstBand.getShowLocation(),
                                            firstEventFirstBand.getStartTimeString(),
                                            firstEventFirstBand.getShowType(),
                                            staticVariables.sawAllStatus);

        showAttendedStatus = attendedHandler.getShowAttendedStatus(   firstEventFirstBand.getBandName(),
                firstEventFirstBand.getShowLocation(),
                firstEventFirstBand.getStartTimeString(),
                firstEventFirstBand.getShowType(),
                staticVariables.eventYear.toString());


        assertEquals(staticVariables.sawAllStatus, showAttendedStatus);

        Long lastEventIndex = eventIndexes.get(2);
        scheduleHandler lastEventFirstBand = firstBandSchedule.getEvents(lastEventIndex);

        showAttendedStatus = attendedHandler.getShowAttendedStatus(lastEventFirstBand.getBandName(),
                lastEventFirstBand.getShowLocation(),
                lastEventFirstBand.getStartTimeString(),
                lastEventFirstBand.getShowType(),
                staticVariables.eventYear.toString());

        assertEquals(staticVariables.sawNoneStatus, showAttendedStatus);

        attendedHandler.addShowsAttended(   lastEventFirstBand.getBandName(),
                lastEventFirstBand.getShowLocation(),
                lastEventFirstBand.getStartTimeString(),
                lastEventFirstBand.getShowType(),
                staticVariables.sawSomeStatus);

        showAttendedStatus = attendedHandler.getShowAttendedStatus(   lastEventFirstBand.getBandName(),
                lastEventFirstBand.getShowLocation(),
                lastEventFirstBand.getStartTimeString(),
                lastEventFirstBand.getShowType(),
                staticVariables.eventYear.toString());


        assertEquals(staticVariables.sawSomeStatus, showAttendedStatus);
    }

     */
}