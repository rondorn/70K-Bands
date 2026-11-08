package com.Bands70k;

/**
 * Layout rules for phones, tablets, and foldables.
 *
 * <p>Split (list | detail) is only for <em>non-slab</em> surfaces:
 * <ul>
 *   <li>Tablet / iPad-class ({@code sw ≥ 720}): both orientations</li>
 *   <li>Unfolded foldable (large, non-slab, not tablet-class): landscape only</li>
 * </ul>
 *
 * <p>Slab phones (tall rectangles, including landscape) never split — they keep
 * orientation-driven calendar / wide list behavior.
 *
 * <p><b>Size rule:</b> large when shortest side ≥ {@link #LARGE_DISPLAY_MIN_DP} (600dp) and
 * not {@link #isSlabProportions(int, int)}. Landscape slab phones stay below 600dp on the
 * short side, so they never qualify.
 */
public final class SplitViewLayoutPolicy {

    /**
     * Minimum window dimension (dp) for tablet / unfolded-fold surfaces.
     * Aligns with Android {@code sw600dp}. Slab phones stay below this on the short side.
     */
    public static final int LARGE_DISPLAY_MIN_DP = 600;

    /**
     * Aspect ratio (longer / shorter) at or above this is "slab phone" shaped.
     * Typical phones ~1.8–2.2; tablets / open folds usually ~1.0–1.5 (16:10 tablets ~1.6).
     */
    public static final float SLAB_ASPECT_RATIO_MIN = 1.7f;

    /**
     * Smallest width (dp) for tablet / iPad-class (split in both orientations).
     * Open folds often sit in 600–719 and stay fold-class (landscape split only).
     */
    public static final int TABLET_CLASS_SMALLEST_WIDTH_DP = 720;

    /**
     * Preferred list column width (dp). Keeps schedule rows readable without stretching
     * name↔time gaps on wide tablets.
     */
    public static final int SPLIT_LIST_PREFERRED_WIDTH_DP = 420;

    /** Floor for the list column when the window is tight. */
    public static final int SPLIT_LIST_MIN_WIDTH_DP = 360;

    /** Cap for the list column — leftover width goes to details. */
    public static final int SPLIT_LIST_MAX_WIDTH_DP = 480;

    /**
     * Minimum detail column width (dp) — similar to a comfortable portrait split pane.
     * Shrinks the right side when the overall window is narrower.
     */
    public static final int SPLIT_DETAIL_MIN_WIDTH_DP = 340;

    /**
     * Soft maximum detail column width (dp) before the pane looks sparse/spread out.
     * On ultra-wide displays, detail may exceed this so the list stays capped.
     */
    public static final int SPLIT_DETAIL_MAX_WIDTH_DP = 800;

    /** Fallback ratio when width is unknown. */
    public static final float SPLIT_PRIMARY_RATIO = 0.45f;

    private SplitViewLayoutPolicy() {}

    /**
     * Primary (list) fraction of the window for Activity Embedding.
     * Sizes the list near {@link #SPLIT_LIST_PREFERRED_WIDTH_DP} and gives remaining
     * space to details, clamped by detail min/max (and list min/max).
     */
    public static float primaryRatioForWindowWidth(int windowWidthDp) {
        if (windowWidthDp <= 0) {
            return SPLIT_PRIMARY_RATIO;
        }

        int listDp = SPLIT_LIST_PREFERRED_WIDTH_DP;
        int detailDp = windowWidthDp - listDp;

        if (detailDp < SPLIT_DETAIL_MIN_WIDTH_DP) {
            // Narrow window (typical tablet portrait): shrink list so detail stays usable.
            detailDp = SPLIT_DETAIL_MIN_WIDTH_DP;
            listDp = windowWidthDp - detailDp;
        } else if (detailDp > SPLIT_DETAIL_MAX_WIDTH_DP) {
            // Wide window: grow detail only up to max; list takes the rest for now.
            detailDp = SPLIT_DETAIL_MAX_WIDTH_DP;
            listDp = windowWidthDp - detailDp;
        }

        if (listDp < SPLIT_LIST_MIN_WIDTH_DP) {
            listDp = SPLIT_LIST_MIN_WIDTH_DP;
            detailDp = windowWidthDp - listDp;
        } else if (listDp > SPLIT_LIST_MAX_WIDTH_DP) {
            // Prefer a compact list; give overflow to details (may exceed detail max on ultra-wide).
            listDp = SPLIT_LIST_MAX_WIDTH_DP;
            detailDp = windowWidthDp - listDp;
        }

        if (listDp < 1 || listDp >= windowWidthDp) {
            return SPLIT_PRIMARY_RATIO;
        }
        return listDp / (float) windowWidthDp;
    }

    /**
     * Slab proportions: long and skinny like a phone (any orientation).
     */
    public static boolean isSlabProportions(int windowWidthDp, int windowHeightDp) {
        int min = Math.min(windowWidthDp, windowHeightDp);
        int max = Math.max(windowWidthDp, windowHeightDp);
        if (min <= 0) {
            return true;
        }
        return ((float) max / (float) min) >= SLAB_ASPECT_RATIO_MIN;
    }

    /**
     * Whether the window is a non-slab large surface (tablet or unfolded foldable).
     * Requires short side ≥ 600dp — landscape slab phones do not qualify.
     */
    public static boolean isLargeDisplay(int windowWidthDp, int windowHeightDp) {
        if (windowWidthDp <= 0 || windowHeightDp <= 0) {
            return false;
        }
        int min = Math.min(windowWidthDp, windowHeightDp);
        if (min < LARGE_DISPLAY_MIN_DP) {
            return false;
        }
        return !isSlabProportions(windowWidthDp, windowHeightDp);
    }

    /**
     * Tablet / iPad-class: remains large enough in both orientations (smallest width stays high).
     */
    public static boolean isTabletClass(int smallestWidthDp) {
        return smallestWidthDp >= TABLET_CLASS_SMALLEST_WIDTH_DP;
    }

    /**
     * Whether master/detail should sit side by side.
     *
     * @param isTabletClass  iPad-class device (always split when large)
     * @param isLargeDisplay current window is non-slab large
     * @param isLandscape    current orientation is landscape
     */
    public static boolean shouldUseSplitView(
            boolean isTabletClass,
            boolean isLargeDisplay,
            boolean isLandscape
    ) {
        if (!isLargeDisplay) {
            return false;
        }
        if (isTabletClass) {
            return true;
        }
        // Fold-class large surface: landscape only.
        return isLandscape;
    }

    /**
     * Portrait fold-class never keeps side-by-side for an open detail.
     */
    public static boolean shouldUseSplitView(
            boolean isTabletClass,
            boolean isLargeDisplay,
            boolean isLandscape,
            boolean hasOpenDetail
    ) {
        if (hasOpenDetail && !isTabletClass && !isLandscape) {
            return false;
        }
        return shouldUseSplitView(isTabletClass, isLargeDisplay, isLandscape);
    }

    /**
     * Manual calendar/list nav toggle (icon) instead of orientation switching.
     * Large non-slab form factors only; slab phones stay orientation-driven.
     */
    public static boolean shouldOfferManualScheduleCalendarToggle(boolean isLargeFormFactor) {
        return isLargeFormFactor;
    }
}
