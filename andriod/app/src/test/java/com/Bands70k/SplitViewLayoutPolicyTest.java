package com.Bands70k;

import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * Split / slab vs tablet-or-fold classification.
 */
public class SplitViewLayoutPolicyTest {

    @Test
    public void tabletClassSplitsInBothOrientations() {
        assertTrue(SplitViewLayoutPolicy.shouldUseSplitView(true, true, false));
        assertTrue(SplitViewLayoutPolicy.shouldUseSplitView(true, true, true));
    }

    @Test
    public void foldClassSplitsOnlyInLandscapeWhenLarge() {
        assertFalse(
                "Open fold portrait should be list-only",
                SplitViewLayoutPolicy.shouldUseSplitView(false, true, false)
        );
        assertTrue(
                "Open fold landscape should split",
                SplitViewLayoutPolicy.shouldUseSplitView(false, true, true)
        );
    }

    @Test
    public void openDetailDoesNotKeepSplitInFoldPortrait() {
        assertFalse(
                "Rotate landscape→portrait must leave side-by-side",
                SplitViewLayoutPolicy.shouldUseSplitView(false, true, false, true)
        );
    }

    @Test
    public void compactCoverNeverSplits() {
        assertFalse(SplitViewLayoutPolicy.shouldUseSplitView(false, false, false, true));
        assertFalse(SplitViewLayoutPolicy.shouldUseSplitView(false, false, true, true));
    }

    @Test
    public void slabPhoneNeverSplitsEvenInLandscape() {
        assertFalse(SplitViewLayoutPolicy.shouldUseSplitView(false, false, false));
        assertFalse(SplitViewLayoutPolicy.shouldUseSplitView(false, false, true));
    }

    @Test
    public void unfoldedFoldIsLargeNonSlab() {
        assertTrue(SplitViewLayoutPolicy.isLargeDisplay(701, 841));
        assertTrue(SplitViewLayoutPolicy.isLargeDisplay(841, 701));
        assertFalse(SplitViewLayoutPolicy.isSlabProportions(841, 701));
    }

    @Test
    public void slabPhoneLandscapeIsNotLarge() {
        assertTrue(SplitViewLayoutPolicy.isSlabProportions(926, 428));
        assertFalse(SplitViewLayoutPolicy.isLargeDisplay(926, 428));
        assertFalse(SplitViewLayoutPolicy.isLargeDisplay(428, 926));
    }

    @Test
    public void slabPhonePortraitIsNotLarge() {
        assertTrue(SplitViewLayoutPolicy.isSlabProportions(411, 890));
        assertFalse(SplitViewLayoutPolicy.isLargeDisplay(411, 890));
    }

    @Test
    public void tabletClassThreshold() {
        assertFalse(SplitViewLayoutPolicy.isTabletClass(600));
        assertFalse(SplitViewLayoutPolicy.isTabletClass(719));
        assertTrue(SplitViewLayoutPolicy.isTabletClass(720));
        assertTrue(SplitViewLayoutPolicy.isTabletClass(834));
    }

    @Test
    public void pixelFoldOpenIsFoldClassNotTablet() {
        assertTrue(SplitViewLayoutPolicy.isLargeDisplay(841, 701));
        assertFalse(SplitViewLayoutPolicy.isTabletClass(701));
        assertTrue(SplitViewLayoutPolicy.shouldUseSplitView(false, true, true));
        assertFalse(SplitViewLayoutPolicy.shouldUseSplitView(false, true, false));
    }

    @Test
    public void pixelTabletSplitsInPortraitAndLandscape() {
        // ~800dp short side, non-slab → large; sw ≥ 720 → tablet class → both orients
        assertTrue(SplitViewLayoutPolicy.isLargeDisplay(800, 1280));
        assertTrue(SplitViewLayoutPolicy.isTabletClass(800));
        assertTrue(SplitViewLayoutPolicy.shouldUseSplitView(true, true, false));
        assertTrue(SplitViewLayoutPolicy.shouldUseSplitView(true, true, true));
    }

    @Test
    public void manualCalendarToggleOnLargeFormFactorOnly() {
        assertTrue(SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(true));
        assertFalse(
                "Slab phone stays orientation-driven",
                SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(false)
        );
    }

    @Test
    public void portraitTabletUsesCompactDetailNearMin() {
        // ~800dp portrait: list preferred 420 → detail 380 (above detail min 340)
        float ratio = SplitViewLayoutPolicy.primaryRatioForWindowWidth(800);
        int listDp = Math.round(ratio * 800);
        int detailDp = 800 - listDp;
        assertTrue("list near preferred", listDp >= 400 && listDp <= 480);
        assertTrue("detail near portrait size", detailDp >= 340 && detailDp <= 420);
    }

    @Test
    public void landscapeTabletCapsListGivesRestToDetail() {
        // ~1280dp landscape: list capped, detail gets remainder (not a stretched 55% list)
        float ratio = SplitViewLayoutPolicy.primaryRatioForWindowWidth(1280);
        int listDp = Math.round(ratio * 1280);
        int detailDp = 1280 - listDp;
        assertTrue("list not stretched", listDp <= SplitViewLayoutPolicy.SPLIT_LIST_MAX_WIDTH_DP);
        assertTrue("detail gets the wide remainder", detailDp >= 700);
        assertTrue(detailDp >= listDp);
    }

    @Test
    public void ultraWideKeepsListCapped() {
        float ratio = SplitViewLayoutPolicy.primaryRatioForWindowWidth(2000);
        int listDp = Math.round(ratio * 2000);
        assertTrue(listDp <= SplitViewLayoutPolicy.SPLIT_LIST_MAX_WIDTH_DP);
        assertTrue(2000 - listDp > listDp);
    }
}
