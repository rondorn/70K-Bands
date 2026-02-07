package com.Bands70k.landscape;

import android.app.Activity;
import android.content.Intent;
import android.content.res.Configuration;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.Bands70k.R;
import com.Bands70k.showBandDetails;

/**
 * Activity that displays the landscape schedule view
 * All implementation in Java using traditional Android Views
 */
public class LandscapeScheduleActivity extends Activity {
    
    private static final String TAG = "LandscapeSchedule";
    public static final String EXTRA_INITIAL_DAY = "initial_day";
    public static final String EXTRA_HIDE_EXPIRED_EVENTS = "hide_expired_events";
    public static final String EXTRA_IS_SPLIT_VIEW_CAPABLE = "is_split_view_capable";
    public static final int REQUEST_CODE_BAND_DETAILS = 1001;
    
    private LandscapeScheduleView scheduleView;
    private String currentViewingDay;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Ensure system UI doesn't interfere with touches
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );
        
        // Get parameters from intent
        String initialDay = getIntent().getStringExtra(EXTRA_INITIAL_DAY);
        boolean hideExpiredEvents = getIntent().getBooleanExtra(EXTRA_HIDE_EXPIRED_EVENTS, false);
        boolean isSplitViewCapable = getIntent().getBooleanExtra(EXTRA_IS_SPLIT_VIEW_CAPABLE, false);
        
        Log.d(TAG, "Creating LandscapeScheduleActivity - initialDay: " + initialDay + 
              ", hideExpiredEvents: " + hideExpiredEvents + 
              ", isSplitViewCapable: " + isSplitViewCapable);
        
        currentViewingDay = initialDay;
        
        // Create the schedule view
        scheduleView = new LandscapeScheduleView(this, initialDay, hideExpiredEvents, isSplitViewCapable);
        scheduleView.setBandTappedListener(new LandscapeScheduleView.OnBandTappedListener() {
            @Override
            public void onBandTapped(String bandName, String currentDay) {
                Log.d(TAG, "Band tapped: " + bandName + " on day: " + currentDay);
                
                // Save the current day for when we return
                if (currentDay != null) {
                    currentViewingDay = currentDay;
                    Log.d(TAG, "Saved current viewing day: " + currentDay);
                }
                
                // CRITICAL: Set the selected band before launching - showBandDetails uses BandInfo.getSelectedBand()
                com.Bands70k.BandInfo.setSelectedBand(bandName);
                Log.d(TAG, "Set selected band to: " + bandName);
                
                // Launch detail activity
                Intent intent = new Intent(LandscapeScheduleActivity.this, showBandDetails.class);
                intent.putExtra("BandName", bandName);
                intent.putExtra("showCustomBackButton", true);
                startActivityForResult(intent, REQUEST_CODE_BAND_DETAILS);
            }
        });
        
        setContentView(scheduleView);
    }
    
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == REQUEST_CODE_BAND_DETAILS) {
            // Detail screen was closed, refresh data if needed
            String bandName = data != null ? data.getStringExtra("bandName") : null;
            if (bandName != null) {
                Log.d(TAG, "Returned from detail screen for band: " + bandName);
                scheduleView.refreshEventData(bandName);
            }
        }
    }
    
    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        Log.d(TAG, "Configuration changed - orientation: " + newConfig.orientation);
        
        // If rotated back to portrait, close this activity
        if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
            Log.d(TAG, "Rotated to portrait - closing landscape schedule activity");
            finish();
        }
    }
    
    @Override
    public void onBackPressed() {
        Log.d(TAG, "Back button pressed");
        super.onBackPressed();
        finish();
    }
}
