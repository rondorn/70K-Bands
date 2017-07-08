package com.Bands70k;

import android.os.Environment;
import android.test.ActivityInstrumentationTestCase2;
import android.test.ActivityUnitTestCase;
import android.test.AndroidTestCase;
import android.test.suitebuilder.annotation.SmallTest;
import android.util.Log;

import java.io.File;
import java.util.ArrayList;
import com.Bands70k.*;

import junit.framework.TestCase;

import org.junit.Test;

public class BandInfoTest extends TestCase {


    @SmallTest
    public void testGetDownloadtUrls(){


        BandInfo bandInfo = new BandInfo();

        preferencesHandler preferences = new preferencesHandler();
        preferences.loadData();

        preferences.setArtsistsUrl("https://www.dropbox.com/s/nd2qibrjvnoguk4/artistLineup2016.csv?dl=1");

        System.out.println(preferences.getArtsistsUrl());
        bandInfo.DownloadBandFile();
        ArrayList<String> bandList = bandInfo.DownloadBandFile();

        System.out.println("Array size is " + String.valueOf(bandList.size()));
        for (String bandName : bandList){
            System.out.println(bandName);
        }

        assertTrue(bandList.size() == 0);

    }

}
