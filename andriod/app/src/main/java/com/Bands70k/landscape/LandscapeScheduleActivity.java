package com.Bands70k.landscape;

import android.app.Activity;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;

import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.Bands70k.R;
import com.Bands70k.showBandDetails;
import com.Bands70k.DeviceSizeManager;

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
    private boolean initialIsSplitViewCapable; // Store initial value for reference
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Receive window insets so we can apply Theme A vs Theme B only when needed
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );

        // CRITICAL: Update DeviceSizeManager on activity creation (handles foldable devices)
        DeviceSizeManager.getInstance(this).updateDeviceSize();
        
        // Get parameters from intent
        String initialDay = getIntent().getStringExtra(EXTRA_INITIAL_DAY);
        boolean hideExpiredEvents = getIntent().getBooleanExtra(EXTRA_HIDE_EXPIRED_EVENTS, false);
        // Use dynamic device size check instead of static Intent extra
        boolean isSplitViewCapable = DeviceSizeManager.getInstance(this).isLargeDisplay();
        initialIsSplitViewCapable = isSplitViewCapable; // Store for reference
        
        Log.d(TAG, "Creating LandscapeScheduleActivity - initialDay: " + initialDay + 
              ", hideExpiredEvents: " + hideExpiredEvents + 
              ", isSplitViewCapable: " + isSplitViewCapable + " (dynamic)");
        
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
                
                // Launch detail activity.
                // Use dynamic device size check (handles foldable devices)
                boolean currentIsSplitViewCapable = DeviceSizeManager.getInstance(LandscapeScheduleActivity.this).isLargeDisplay();
                Intent intent = new Intent(LandscapeScheduleActivity.this, showBandDetails.class);
                intent.putExtra("BandName", bandName);
                intent.putExtra("showCustomBackButton", true);
                intent.putExtra("showAllDetailsInDetails", currentIsSplitViewCapable);
                startActivityForResult(intent, REQUEST_CODE_BAND_DETAILS);
            }
        });
        
        // Set dismiss listener for tablets (return to list view) - use dynamic check
        setupDismissListener(isSplitViewCapable);
        
        setContentView(scheduleView);
        // Theme A (full display): no insets → no padding, full screen.
        // Theme B (nav/status bar present): insets > 0 → translucent bar + padding so content doesn't sit under bar.
        ViewCompat.setOnApplyWindowInsetsListener(scheduleView, (v, windowInsets) -> {
            var insets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars());
            boolean hasSystemBars = insets.top > 0 || insets.bottom > 0 || insets.left > 0 || insets.right > 0;
            if (hasSystemBars) {
                // Theme B: navigation elements present – make nav bar translucent and inset content
                getWindow().setNavigationBarColor(Color.TRANSPARENT);
                getWindow().setStatusBarColor(Color.TRANSPARENT);
                v.setPadding(insets.left, insets.top, insets.right, insets.bottom);
                Log.d(TAG, "Theme B: system bars present, applied insets padding and translucent bars");
                // Rebuild grid with padded width so content does not draw under the bar
                scheduleView.post(() -> scheduleView.refreshCurrentDayContent());
            } else {
                // Theme A: full display – no padding, use full screen
                getWindow().setNavigationBarColor(Color.BLACK);
                getWindow().setStatusBarColor(Color.BLACK);
                v.setPadding(0, 0, 0, 0);
                Log.d(TAG, "Theme A: full display, no insets padding");
                scheduleView.post(() -> scheduleView.refreshCurrentDayContent());
            }
            return windowInsets;
        });
        ViewCompat.requestApplyInsets(scheduleView);
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
        Log.d(TAG, "Configuration changed - orientation: " + newConfig.orientation + 
              " (ORIENTATION_PORTRAIT=" + Configuration.ORIENTATION_PORTRAIT + 
              ", ORIENTATION_LANDSCAPE=" + Configuration.ORIENTATION_LANDSCAPE + ")");
        
        // CRITICAL: Recalculate device size on configuration change (handles foldable devices)
        DeviceSizeManager.getInstance(this).updateDeviceSize();
        boolean isSplitViewCapable = DeviceSizeManager.getInstance(this).isLargeDisplay();
        
        Log.d(TAG, "Device size after config change - isSplitViewCapable: " + isSplitViewCapable + 
              " (was: " + initialIsSplitViewCapable + ")");
        
        // Update the view's behavior if device size changed
        if (scheduleView != null) {
            scheduleView.updateSplitViewCapable(isSplitViewCapable);
            // Update dismiss listener if needed
            setupDismissListener(isSplitViewCapable);
        }
        
        // For tablets/master-detail view: don't auto-close on portrait rotation
        // Landscape view is controlled by button, not rotation
        if (isSplitViewCapable) {
            Log.d(TAG, "Tablet mode - ignoring portrait rotation (button-controlled)");
            return;
        }
        
        // CRITICAL FIX: Use multiple methods to detect portrait orientation
        // On Pixel Fold front display, display metrics may be stale - use window dimensions instead
        android.util.DisplayMetrics displayMetrics = getResources().getDisplayMetrics();
        int displayWidth = displayMetrics.widthPixels;
        int displayHeight = displayMetrics.heightPixels;
        
        // Get actual window dimensions (more reliable on foldable devices)
        android.view.View decorView = getWindow().getDecorView();
        int windowWidth = decorView.getWidth();
        int windowHeight = decorView.getHeight();
        
        // Use window dimensions if available, otherwise fall back to display metrics
        int width = (windowWidth > 0) ? windowWidth : displayWidth;
        int height = (windowHeight > 0) ? windowHeight : displayHeight;
        
        boolean isPortraitBySize = height > width;
        boolean isPortrait = (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) || isPortraitBySize;
        
        Log.d(TAG, "Orientation check - config: " + newConfig.orientation + 
              ", display metrics: " + displayWidth + "x" + displayHeight +
              ", window size: " + windowWidth + "x" + windowHeight +
              ", using: " + width + "x" + height +
              ", size-based portrait: " + isPortraitBySize + ", isPortrait: " + isPortrait);
        
        // Phone mode: If rotated back to portrait, close this activity immediately
        if (isPortrait) {
            Log.d(TAG, "🚫 Rotated to portrait - closing landscape schedule activity (portrait never shows calendar on phone)");
            finish();
        }
    }
    
    /**
     * Setup dismiss listener based on current device size (handles foldable devices)
     */
    private void setupDismissListener(boolean isSplitViewCapable) {
        if (scheduleView == null) return;
        
        if (isSplitViewCapable) {
            // Set or update dismiss listener for tablets
            scheduleView.setDismissRequestedListener(new LandscapeScheduleView.OnDismissRequestedListener() {
                @Override
                public void onDismissRequested() {
                    Log.d(TAG, "📱 [TABLET_TOGGLE] Dismiss requested - returning to list view");
                    finish();
                }
            });
        } else {
            // Remove dismiss listener for phones
            scheduleView.setDismissRequestedListener(null);
        }
    }
    
    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        
        // CRITICAL FIX: Also check orientation when window gains focus
        // This catches cases where onConfigurationChanged might not fire
        if (hasFocus) {
            // Use dynamic device size check (handles foldable devices)
            DeviceSizeManager.getInstance(this).updateDeviceSize();
            boolean isSplitViewCapable = DeviceSizeManager.getInstance(this).isLargeDisplay();
            
            if (!isSplitViewCapable) {
                // Check orientation using window dimensions (more reliable on foldable devices)
                android.util.DisplayMetrics displayMetrics = getResources().getDisplayMetrics();
                int displayWidth = displayMetrics.widthPixels;
                int displayHeight = displayMetrics.heightPixels;
                
                // Get actual window dimensions
                android.view.View decorView = getWindow().getDecorView();
                int windowWidth = decorView.getWidth();
                int windowHeight = decorView.getHeight();
                
                // Use window dimensions if available, otherwise fall back to display metrics
                int width = (windowWidth > 0) ? windowWidth : displayWidth;
                int height = (windowHeight > 0) ? windowHeight : displayHeight;
                boolean isPortrait = height > width;
                
                Log.d(TAG, "Window focus check - display: " + displayWidth + "x" + displayHeight +
                      ", window: " + windowWidth + "x" + windowHeight +
                      ", using: " + width + "x" + height + ", isPortrait: " + isPortrait);
                
                if (isPortrait) {
                    Log.d(TAG, "🚫 Window focus gained in portrait - closing landscape schedule activity");
                    finish();
                }
            }
        }
    }
    
    @Override
    public void onBackPressed() {
        Log.d(TAG, "Back button pressed");
        super.onBackPressed();
        finish();
    }
}
