package com.Bands70k;


import android.os.Build;
import android.os.Environment;

import java.io.IOException;
import java.util.ArrayList;

import junit.framework.TestCase;
import org.junit.Before;
import org.junit.Rule;

import static android.app.ActivityManager.isRunningInTestHarness;
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


public class RankStoreTest extends TestCase {

    private rankStore rankStoreData;
    private static final String firstBand = "Aborted";
    private static final String lastBand = "Zero Theorem";


    @Rule
    TemporaryFolder tempFolder = new TemporaryFolder();

    @Before
    public void doSetup() throws IOException {
        PowerMockito.mockStatic(Environment.class);
        PowerMockito.mockStatic(Build.class);
        PowerMockito.mockStatic(OnlineStatus.class);

        when(staticVariables.context.getApplicationContext().getFilesDir().toString()).thenReturn(String.valueOf(tempFolder.newFolder()));
        when(OnlineStatus.isOnline()).thenReturn(true);

        ReflectionHelpers.setStaticField(Build.class,"HARDWARE", "golfdish");

        staticVariables.userID = "rdorn";
        staticVariables.inUnitTests = true;
        staticVariables.preferences = new preferencesHandler();
        staticVariablesInitialize();
        staticVariables.preferences.setUseLastYearsData(false);

        rankStoreData = new rankStore();
    }

    public void testRankStoreConfirmEmpty() {

        String firstBandRank = rankStoreData.getRankForBand(firstBand);
        String lastBandRank = rankStoreData.getRankForBand(lastBand);

        assertEquals("", firstBandRank);
        assertEquals("", lastBandRank);

    }


    public void testRankStoreConfirmAfterSet() {

        rankStoreData.saveBandRanking(firstBand, staticVariables.mustSeeKey);
        rankStoreData.saveBandRanking(lastBand, staticVariables.wontSeeKey);

        String firstBandRank = rankStoreData.getRankForBand(firstBand);
        String lastBandRank = rankStoreData.getRankForBand(lastBand);

        assertEquals(staticVariables.mustSeeIcon, firstBandRank);
        assertEquals(staticVariables.wontSeeIcon, lastBandRank);

    }
}
