package com.Bands70k;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Rect;
import android.util.Log;
import android.view.View;

import androidx.window.embedding.ActivityFilter;
import androidx.window.embedding.ActivityRule;
import androidx.window.embedding.EmbeddingAspectRatio;
import androidx.window.embedding.RuleController;
import androidx.window.embedding.SplitAttributes;
import androidx.window.embedding.SplitController;
import androidx.window.embedding.SplitPairFilter;
import androidx.window.embedding.SplitPairRule;
import androidx.window.embedding.SplitPlaceholderRule;
import androidx.window.embedding.SplitRule;
import androidx.window.layout.WindowMetrics;

import com.Bands70k.landscape.LandscapeScheduleActivity;

import java.util.HashSet;

/**
 * Android-native list|detail via Jetpack Activity Embedding.
 *
 * <p>Slab phones: calculator returns {@link SplitAttributes.SplitType#SPLIT_TYPE_EXPAND}, so
 * {@link showBandDetails} launches full-screen exactly as before.
 *
 * <p>Tablets / foldables when {@link SplitViewLayoutPolicy} allows: system places list and
 * detail side-by-side. Portrait split is allowed when the window is large enough (iPad Pro–class);
 * Duo/fold-class stays landscape-only per policy.
 */
public final class ListDetailSplitManager {
    private static final String TAG = "ListDetailSplit";


    private static boolean rulesRegistered = false;

    private ListDetailSplitManager() {}

    /**
     * Install embedding rules once per process. Call from {@link android.app.Application#onCreate()}.
     */
    public static synchronized void registerEmbeddingRules(Context context) {
        if (rulesRegistered || context == null) {
            return;
        }
        Context app = context.getApplicationContext();
        try {
            SplitController splitController = SplitController.getInstance(app);
            Log.d(TAG, "splitSupportStatus=" + splitController.getSplitSupportStatus());

            ComponentName list = new ComponentName(app, showBands.class);
            ComponentName details = new ComponentName(app, showBandDetails.class);
            ComponentName placeholder = new ComponentName(app, SplitDetailPlaceholderActivity.class);

            HashSet<SplitPairFilter> pairFilters = new HashSet<>();
            pairFilters.add(new SplitPairFilter(list, details, null));

            // min* = 0 so our calculator (not static thresholds) decides when to split.
            // ALWAYS_ALLOW aspect ratios so large tablets can split in portrait.
            SplitPairRule pairRule = new SplitPairRule.Builder(pairFilters)
                    .setMinWidthDp(0)
                    .setMinHeightDp(0)
                    .setMinSmallestWidthDp(0)
                    .setMaxAspectRatioInPortrait(EmbeddingAspectRatio.ALWAYS_ALLOW)
                    .setMaxAspectRatioInLandscape(EmbeddingAspectRatio.ALWAYS_ALLOW)
                    .setFinishPrimaryWithSecondary(SplitRule.FinishBehavior.NEVER)
                    .setFinishSecondaryWithPrimary(SplitRule.FinishBehavior.ALWAYS)
                    .setClearTop(true)
                    .setDefaultSplitAttributes(defaultSplitAttributes())
                    .build();

            HashSet<ActivityFilter> placeholderFilters = new HashSet<>();
            placeholderFilters.add(new ActivityFilter(list, null));

            Intent placeholderIntent = new Intent(app, SplitDetailPlaceholderActivity.class);
            placeholderIntent.setComponent(placeholder);

            SplitPlaceholderRule placeholderRule = new SplitPlaceholderRule.Builder(
                    placeholderFilters,
                    placeholderIntent
            )
                    .setMinWidthDp(0)
                    .setMinHeightDp(0)
                    .setMinSmallestWidthDp(0)
                    .setMaxAspectRatioInPortrait(EmbeddingAspectRatio.ALWAYS_ALLOW)
                    .setMaxAspectRatioInLandscape(EmbeddingAspectRatio.ALWAYS_ALLOW)
                    .setSticky(false)
                    .setFinishPrimaryWithPlaceholder(SplitRule.FinishBehavior.ALWAYS)
                    .setDefaultSplitAttributes(defaultSplitAttributes())
                    .build();

            // Calendar must break out of the list|detail split to full screen.
            HashSet<ActivityFilter> alwaysExpandFilters = new HashSet<>();
            alwaysExpandFilters.add(new ActivityFilter(
                    new ComponentName(app, LandscapeScheduleActivity.class), null));

            ActivityRule alwaysExpandRule = new ActivityRule.Builder(alwaysExpandFilters)
                    .setAlwaysExpand(true)
                    .build();

            RuleController rules = RuleController.getInstance(app);
            rules.addRule(pairRule);
            rules.addRule(placeholderRule);
            rules.addRule(alwaysExpandRule);

            splitController.setSplitAttributesCalculator(params -> {
                Configuration config = params.getParentConfiguration();
                WindowMetrics metrics = params.getParentWindowMetrics();
                Rect bounds = metrics.getBounds();
                float density = config.densityDpi / 160f;
                int widthDp = density > 0
                        ? Math.round(bounds.width() / density)
                        : config.screenWidthDp;
                int heightDp = density > 0
                        ? Math.round(bounds.height() / density)
                        : config.screenHeightDp;
                boolean landscape = widthDp > heightDp
                        || config.orientation == Configuration.ORIENTATION_LANDSCAPE;
                boolean large = SplitViewLayoutPolicy.isLargeDisplay(widthDp, heightDp);
                boolean tablet = SplitViewLayoutPolicy.isTabletClass(config.smallestScreenWidthDp);
                boolean useSplit = SplitViewLayoutPolicy.shouldUseSplitView(tablet, large, landscape);

                Log.d(TAG, "calculator useSplit=" + useSplit
                        + " tablet=" + tablet
                        + " large=" + large
                        + " landscape=" + landscape
                        + " window=" + widthDp + "x" + heightDp + "dp"
                        + " sw=" + config.smallestScreenWidthDp);

                if (useSplit) {
                    float ratio = SplitViewLayoutPolicy.primaryRatioForWindowWidth(widthDp);
                    Log.d(TAG, "split ratio=" + ratio
                            + " list~" + Math.round(ratio * widthDp) + "dp"
                            + " detail~" + Math.round((1f - ratio) * widthDp) + "dp");
                    return splitAttributesForRatio(ratio);
                }
                // Phone / folded cover / Duo-class portrait: full-screen secondary.
                return new SplitAttributes.Builder()
                        .setSplitType(SplitAttributes.SplitType.SPLIT_TYPE_EXPAND)
                        .build();
            });

            rulesRegistered = true;
            Log.d(TAG, "Activity Embedding rules registered");
        } catch (Throwable t) {
            Log.w(TAG, "Activity Embedding unavailable — phone full-screen navigation only", t);
        }
    }

    private static SplitAttributes splitAttributesForRatio(float primaryRatio) {
        return new SplitAttributes.Builder()
                .setSplitType(SplitAttributes.SplitType.ratio(primaryRatio))
                .setLayoutDirection(SplitAttributes.LayoutDirection.LEFT_TO_RIGHT)
                .build();
    }

    private static SplitAttributes defaultSplitAttributes() {
        return splitAttributesForRatio(SplitViewLayoutPolicy.SPLIT_PRIMARY_RATIO);
    }

    /** Whether the current window should present list|detail side-by-side. */
    public static boolean shouldUseSplitView(Context context) {
        return context != null && DeviceSizeManager.getInstance(context).shouldUseSplitView();
    }

    /**
     * After orientation / fold changes, force Activity Embedding to re-apply split attributes
     * and relayout. Avoids stale landscape pane sizes when rotating to portrait.
     */
    public static void refreshSplitAfterConfigurationChange(Activity activity) {
        if (activity == null) {
            return;
        }
        try {
            SplitController.getInstance(activity).invalidateTopVisibleSplitAttributes();
        } catch (Throwable t) {
            Log.w(TAG, "invalidateTopVisibleSplitAttributes failed", t);
        }
        try {
            View decor = activity.getWindow() != null ? activity.getWindow().getDecorView() : null;
            if (decor != null) {
                decor.requestLayout();
                decor.invalidate();
            }
        } catch (Throwable t) {
            Log.w(TAG, "split relayout failed", t);
        }
    }
}
