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


public class BandInfoTest extends TestCase {

    private BandInfo bandInfo;
    private static final String firstBand = "Aborted";
    private static final String lastBand = "Zero Theorem";
    private static final String bandWithNote = "Archon Angel";
    private static final Integer lastBandNumber = 61;

    private static final String firstBandExpectedWebLink = "http://www.facebook.com/Abortedofficial/";
    private static final String lastBandExpectedWebLink = "http://zerotheoremband.com/about/";

    private static final String firstBandExpectedImageUrl= "https://70000tons.com/wp-content/uploads/2019/11/3542FVSDF34563vfdvdsafL345_WEdfg.png";
    private static final String lastBandExpectedImageUrl = "https://70000tons.com/wp-content/uploads/2020/01/ZERO_THEOREM_LOGO_WEB.png";

    private static final String firstBandExpectedWikipediaWebLink= "https://en.wikipedia.org/wiki/Special:Search/insource:album%20insource:band%20intitle:Aborted";
    private static final String lastBandExpectedWikipediaWebLink = "https://en.wikipedia.org/wiki/Special:Search/insource:album%20insource:band%20intitle:Zero%20Theorem";

    private static final String firstBandExpectedYouTubeWebLink= "https://www.youtube.com/results?search_query=official+music%20video+Aborted";
    private static final String lastBandExpectedYouTubeWebLink = "https://www.youtube.com/results?search_query=official+music%20video+Zero%20Theorem";

    private static final String firstBandExpectedMetalArchivesWebLink= "http://www.metal-archives.com/search?searchString=Aborted&type=band_name";
    private static final String lastBandExpectedMetalArchivesWebLink = "http://www.metal-archives.com/search?searchString=Zero%20Theorem&type=band_name";

    private static final String firstBandExpectedCountry = "Belgium";
    private static final String lastBandExpectedCountry = "United States";

    private static final String firstBandExpectedGenre = "Death Metal";
    private static final String lastBandExpectedGenre = "Hard Rock-Metal";

    private static final String expectedBandNote = "First Ever Performance";

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

   @Rule
    TemporaryFolder tempFolder = new TemporaryFolder();

    @Before
    public void doSetup() throws IOException {
        PowerMockito.mockStatic(Environment.class);
        PowerMockito.mockStatic(Build.class);
        PowerMockito.mockStatic(OnlineStatus.class);

        when(Environment.getExternalStorageDirectory()).thenReturn(tempFolder.newFolder());
        when(OnlineStatus.isOnline()).thenReturn(true);

        ReflectionHelpers.setStaticField(Build.class,"HARDWARE", "golfdish");

        staticVariables.userID = "rdorn";
        staticVariables.inUnitTests = true;
        staticVariables.preferences = new preferencesHandler();
        staticVariablesInitialize();
        staticVariables.preferences.setUseLastYearsData(false);

        bandInfo = new BandInfo();
    }

    public void testGetDownloadtUrls(){

        preferencesHandler preferences = new preferencesHandler();
        preferences.loadData();

        System.out.println(preferences.getArtsistsUrl());
        bandInfo.DownloadBandFile();
        ArrayList<String> bandList = bandInfo.getBandNames();

        assertEquals(firstBand, bandList.get(0));
        assertEquals(lastBand, bandList.get(61));
        assertEquals((lastBandNumber + 1), bandList.size());

    }

    public void testGetOfficalWebLink(){

        String firstBandWebLink = bandInfo.getOfficalWebLink(firstBand);
        String lastBandWebLink = bandInfo.getOfficalWebLink(lastBand);

        assertEquals(firstBandExpectedWebLink, firstBandWebLink);
        assertEquals(lastBandExpectedWebLink, lastBandWebLink);
    }

    public void testGetImageUrl(){

        String firstBandImageUrl = bandInfo.getImageUrl(firstBand);
        String lastBandImageUrl = bandInfo.getImageUrl(lastBand);

        assertEquals(firstBandExpectedImageUrl, firstBandImageUrl);
        assertEquals(lastBandExpectedImageUrl, lastBandImageUrl);
    }

    public void testGetWikipediaWebLink(){

        String firstBandWikipediaWebLink = bandInfo.getWikipediaWebLink(firstBand);
        String lastBandWikipediaWebLink = bandInfo.getWikipediaWebLink(lastBand);

        assertEquals(firstBandExpectedWikipediaWebLink, firstBandWikipediaWebLink);
        assertEquals(lastBandExpectedWikipediaWebLink, lastBandWikipediaWebLink);
    }

    public void testGetYouTubeWebLink(){

        String firstBandYouTubeWebLink = bandInfo.getYouTubeWebLink(firstBand);
        String lastBandYouTubeWebLink = bandInfo.getYouTubeWebLink(lastBand);

        assertEquals(firstBandExpectedYouTubeWebLink, firstBandYouTubeWebLink);
        assertEquals(lastBandExpectedYouTubeWebLink, lastBandYouTubeWebLink);
    }

    public void testGetMetalArchivesWebLink(){

        String firstBandMetalArchivesWebLink = bandInfo.getMetalArchivesWebLink(firstBand);
        String lastBandMetalArchivesWebLink = bandInfo.getMetalArchivesWebLink(lastBand);

        assertEquals(firstBandExpectedMetalArchivesWebLink, firstBandMetalArchivesWebLink);
        assertEquals(lastBandExpectedMetalArchivesWebLink, lastBandMetalArchivesWebLink);
    }

    public void testGetCountry(){

        String firstBandCountry = bandInfo.getCountry(firstBand);
        String lastBandCountry = bandInfo.getCountry(lastBand);

        assertEquals(firstBandExpectedCountry, firstBandCountry);
        assertEquals(lastBandExpectedCountry, lastBandCountry);
    }

    public void testGetGenre(){

        String firstBandGenre = bandInfo.getGenre(firstBand);
        String lastBandGenre = bandInfo.getGenre(lastBand);

        assertEquals(firstBandExpectedGenre, firstBandGenre);
        assertEquals(lastBandExpectedGenre, lastBandGenre);
    }

    public void testGetNote(){

        String bandNote = bandInfo.getNote(bandWithNote);

        assertEquals(expectedBandNote, bandNote);

    }


    public void testGetSchedule(){

        Map<String, scheduleTimeTracker> scheduleData = BandInfo.scheduleRecords;

        scheduleTimeTracker firstBandSchedule = scheduleData.get(firstBand);
        List<Long> eventIndexes = firstBandSchedule.getEventIndexes();

        Long firstEventIndex = eventIndexes.get(0);
        scheduleHandler firstEventFirstBand = firstBandSchedule.getEvents(firstEventIndex);

        String firstLocation = firstEventFirstBand.getShowLocation();
        String firstStartTime = firstEventFirstBand.getStartTimeString();
        String firstEndTime = firstEventFirstBand.getEndTimeString();
        String firstDay = firstEventFirstBand.getShowDay();
        String firstEventType = firstEventFirstBand.getShowType();
        Long firstEpochStartTime = firstEventFirstBand.getEpochStart();

        assertEquals(firstExpectedLocation, firstLocation);
        assertEquals(firstExpectedStartTime, firstStartTime);
        assertEquals(firstExpectedEndTime, firstEndTime);
        assertEquals(firstExpectedDay, firstDay);
        assertEquals(firstExpectedEventType, firstEventType);
        assertEquals(firstExpectedEpochStartTime, firstEpochStartTime);

        Long lastEventIndex = eventIndexes.get(2);
        scheduleHandler lastEventFirstBand = firstBandSchedule.getEvents(lastEventIndex);

        String lastLocation = lastEventFirstBand.getShowLocation();
        String lastStartTime = lastEventFirstBand.getStartTimeString();
        String lastEndTime = lastEventFirstBand.getEndTimeString();
        String lastDay = lastEventFirstBand.getShowDay();
        String lastEventType = lastEventFirstBand.getShowType();
        Long lastEpochStartTime = lastEventFirstBand.getEpochStart();

        assertEquals(lastExpectedLocation, lastLocation);
        assertEquals(lastExpectedStartTime, lastStartTime);
        assertEquals(lastExpectedEndTime, lastEndTime);
        assertEquals(lastExpectedDay, lastDay);
        assertEquals(lastExpectedEventType, lastEventType);
        assertEquals(lastExpectedEpochStartTime, lastEpochStartTime);
    }
}

