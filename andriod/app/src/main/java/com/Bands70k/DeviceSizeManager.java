package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Rect;
import android.util.Log;

import androidx.window.layout.WindowMetrics;
import androidx.window.layout.WindowMetricsCalculator;

/**
 * Centralized manager for display size classification and list|detail split decisions.
 *
 * <p>Mirrors iOS {@code DeviceSizeManager} / {@code SplitViewLayoutPolicy}:
 * <ul>
 *   <li>Tablet (iPad-class): split in portrait and landscape</li>
 *   <li>Large phone / unfolded foldable (Duo-class): split in landscape only</li>
 *   <li>Compact phone / folded cover: never split</li>
 * </ul>
 *
 * <p>Important: Activity Embedding resizes the list activity to ~half width. Current-window
 * size then looks "phone-sized" even on a Fold/tablet. Calendar-toggle and form-factor checks
 * therefore prefer {@link WindowMetricsCalculator#computeMaximumWindowMetrics} so the icon
 * stays available whenever the <em>device</em> can host a large UI.
 */
public class DeviceSizeManager {
    private static final String TAG = "DeviceSizeManager";

    private static DeviceSizeManager instance;
    private final Context context;

    private boolean isLargeDisplay = false;
    private boolean isLargeFormFactor = false;
    private boolean isTabletClass = false;
    private boolean isLandscape = false;
    private int windowWidthDp;
    private int windowHeightDp;
    private int smallestWidthDp;

    private DeviceSizeManager(Context context) {
        this.context = context.getApplicationContext();
        updateDeviceSize();
    }

    public static synchronized DeviceSizeManager getInstance(Context context) {
        if (instance == null) {
            instance = new DeviceSizeManager(context);
        }
        return instance;
    }

    /**
     * Recalculates from application configuration (may be the embedded activity's bounds).
     */
    public void updateDeviceSize() {
        if (context == null) {
            return;
        }
        applyConfiguration(context.getResources().getConfiguration(), null);
    }

    /**
     * Prefer this from Activities: uses max window metrics so embedding half-width does not
     * drop a Fold/tablet back into "phone" calendar/orientation mode.
     */
    public void updateFromActivity(Activity activity) {
        if (activity == null) {
            updateDeviceSize();
            return;
        }
        applyConfiguration(activity.getResources().getConfiguration(), activity);
    }

    private void applyConfiguration(Configuration config, Activity activity) {
        windowWidthDp = config.screenWidthDp;
        windowHeightDp = config.screenHeightDp;
        smallestWidthDp = config.smallestScreenWidthDp;
        isLandscape = config.orientation == Configuration.ORIENTATION_LANDSCAPE
                || (windowWidthDp > 0 && windowHeightDp > 0 && windowWidthDp > windowHeightDp);

        boolean newLarge = calculateIsLargeDisplay(config, activity);
        boolean newFormFactor = calculateIsLargeFormFactor(config, activity);
        boolean newTablet = calculateIsTabletClass(config, activity);

        if (newLarge != isLargeDisplay || newTablet != isTabletClass || newFormFactor != isLargeFormFactor) {
            Log.d(TAG, "Device size updated: large=" + newLarge
                    + " formFactor=" + newFormFactor
                    + " tabletClass=" + newTablet
                    + " landscape=" + isLandscape
                    + " window=" + windowWidthDp + "x" + windowHeightDp + "dp"
                    + " sw=" + smallestWidthDp + "dp");
        }

        isLargeDisplay = newLarge;
        isLargeFormFactor = newFormFactor;
        isTabletClass = newTablet;
    }

    private boolean calculateIsLargeDisplay(Configuration config, Activity activity) {
        int width = config.screenWidthDp;
        int height = config.screenHeightDp;
        if (width > 0 && height > 0 && SplitViewLayoutPolicy.isLargeDisplay(width, height)) {
            return true;
        }

        // Max window (full Fold inner / tablet) — stable under Activity Embedding.
        int[] max = maxWindowDp(activity);
        if (max != null && SplitViewLayoutPolicy.isLargeDisplay(max[0], max[1])) {
            return true;
        }

        int screenSize = config.screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK;
        return screenSize == Configuration.SCREENLAYOUT_SIZE_LARGE
                || screenSize == Configuration.SCREENLAYOUT_SIZE_XLARGE;
    }

    /**
     * Device can host large UI (tablet or unfolded foldable), independent of the current
     * activity column width after embedding.
     */
    private boolean calculateIsLargeFormFactor(Configuration config, Activity activity) {
        if (calculateIsTabletClass(config, activity)) {
            return true;
        }
        int[] max = maxWindowDp(activity);
        if (max != null && SplitViewLayoutPolicy.isLargeDisplay(max[0], max[1])) {
            return true;
        }
        // Fallback when no Activity: sw often still reflects the foldable inner when open.
        return config.smallestScreenWidthDp >= SplitViewLayoutPolicy.LARGE_DISPLAY_MIN_DP;
    }

    private boolean calculateIsTabletClass(Configuration config, Activity activity) {
        if (SplitViewLayoutPolicy.isTabletClass(config.smallestScreenWidthDp)) {
            return true;
        }
        int[] max = maxWindowDp(activity);
        if (max != null) {
            int min = Math.min(max[0], max[1]);
            if (SplitViewLayoutPolicy.isTabletClass(min)) {
                return true;
            }
        }
        int screenSize = config.screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK;
        return screenSize == Configuration.SCREENLAYOUT_SIZE_XLARGE
                && config.smallestScreenWidthDp >= SplitViewLayoutPolicy.LARGE_DISPLAY_MIN_DP;
    }

    /** @return int[]{widthDp, heightDp} or null */
    private int[] maxWindowDp(Activity activity) {
        if (activity == null) {
            return null;
        }
        try {
            WindowMetrics metrics = WindowMetricsCalculator.getOrCreate()
                    .computeMaximumWindowMetrics(activity);
            Rect bounds = metrics.getBounds();
            float density = activity.getResources().getDisplayMetrics().density;
            if (density <= 0f) {
                return null;
            }
            return new int[]{
                    Math.round(bounds.width() / density),
                    Math.round(bounds.height() / density)
            };
        } catch (Throwable t) {
            Log.w(TAG, "max window metrics unavailable", t);
            return null;
        }
    }

    public boolean isLargeDisplay() {
        return isLargeDisplay;
    }

    /**
     * Tablet / open-fold class device (stable across Activity Embedding column resize).
     * Use for calendar icon vs orientation switching.
     */
    public boolean isLargeFormFactor() {
        return isLargeFormFactor;
    }

    /** iPad-class: split in both orientations when the window is large. */
    public boolean isTabletClass() {
        return isTabletClass;
    }

    public boolean isLandscape() {
        return isLandscape;
    }

    public int getWindowWidthDp() {
        return windowWidthDp;
    }

    public int getWindowHeightDp() {
        return windowHeightDp;
    }

    public int getSmallestWidthDp() {
        return smallestWidthDp;
    }

    /**
     * Whether list|detail should be side-by-side right now.
     * Tablet-class: both orientations. Fold-class large: landscape only. Slab phone: never.
     */
    public boolean shouldUseSplitView() {
        updateDeviceSize();
        return SplitViewLayoutPolicy.shouldUseSplitView(isTabletClass, isLargeDisplay, isLandscape);
    }

    public boolean shouldUseSplitView(Activity activity) {
        updateFromActivity(activity);
        boolean large = isLargeDisplay || isLargeFormFactor;
        return SplitViewLayoutPolicy.shouldUseSplitView(isTabletClass, large, isLandscape);
    }

    /** Calendar/list icon instead of orientation — large tablets and open foldables. */
    public boolean shouldOfferManualScheduleCalendarToggle() {
        return SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(isLargeFormFactor);
    }

    public boolean shouldOfferManualScheduleCalendarToggle(Activity activity) {
        updateFromActivity(activity);
        return SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(isLargeFormFactor);
    }

    public static boolean isLargeDisplay(Context context) {
        return getInstance(context).isLargeDisplay();
    }

    public static boolean shouldUseSplitView(Context context) {
        if (context instanceof Activity) {
            return getInstance(context).shouldUseSplitView((Activity) context);
        }
        return getInstance(context).shouldUseSplitView();
    }
}
