package com.Bands70k.qa;

import androidx.test.espresso.assertion.ViewAssertions;
import androidx.test.ext.junit.rules.ActivityScenarioRule;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.filters.LargeTest;

import com.Bands70k.R;
import com.Bands70k.showBands;

import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

import static androidx.test.espresso.Espresso.onData;
import static androidx.test.espresso.Espresso.onView;
import static androidx.test.espresso.action.ViewActions.click;
import static androidx.test.espresso.action.ViewActions.swipeUp;
import static androidx.test.espresso.matcher.ViewMatchers.isDisplayed;
import static androidx.test.espresso.matcher.ViewMatchers.isDescendantOfA;
import static androidx.test.espresso.matcher.ViewMatchers.withContentDescription;
import static androidx.test.espresso.matcher.ViewMatchers.withId;
import static androidx.test.espresso.matcher.ViewMatchers.withText;
import static org.hamcrest.Matchers.allOf;

/**
 * QA walkthrough Ch.1 (pointer + four-links). Parity with iOS {@code QAWalkthroughChapter1UITests}.
 * Requires instrumentation args {@code UITESTING=1} and {@code UITEST_CUSTOM_POINTER_URL} (see {@code android_qa_ui_walkthrough.sh}).
 */
@RunWith(AndroidJUnit4.class)
@LargeTest
public class QAWalkthroughChapter1UITests {

    @Rule
    public final ActivityScenarioRule<showBands> activityRule = new ActivityScenarioRule<>(showBands.class);

    @Test
    public void testChapter1_PointerBandsOnly_ShowsFixtureBand() throws Exception {
        QaUiTestHelpers.dismissPostLaunchDialogsIfPossible();
        QaUiTestHelpers.waitUntilDisplayed(onView(withText("Amorphis")), 180_000L);
    }

    @Test
    public void testChapter1_BandDetail_FourLinksOpenAndDismissWebSheet() throws Exception {
        QaUiTestHelpers.dismissPostLaunchDialogsIfPossible();

        QaUiTestHelpers.waitUntilDisplayed(onView(withId(R.id.bandNames)), 180_000L);

        scrollBandIntoView("Amorphis");

        onData(QaUiTestHelpers.bandListItemWithName("Amorphis"))
                .inAdapterView(allOf(withId(R.id.bandNames), isDisplayed()))
                .perform(click());

        QaUiTestHelpers.waitUntilDisplayed(onView(withText("Links:")), 60_000L);

        String[] linkIds = {
                "bandDetailLinkOfficial",
                "bandDetailLinkMetalArchives",
                "bandDetailLinkWikipedia",
                "bandDetailLinkYouTube",
        };
        for (String linkId : linkIds) {
            // Scope to links strip so we never match unrelated views with the same CD.
            QaUiTestHelpers.waitUntilDisplayed(
                    onView(allOf(withContentDescription(linkId), isDescendantOfA(withId(R.id.links_section)))),
                    30_000L);
            onView(allOf(withContentDescription(linkId), isDescendantOfA(withId(R.id.links_section))))
                    .perform(click());
            QaUiTestHelpers.waitUntilDisplayed(onView(withContentDescription("bandDetailWebSheetDone")), 25_000L);
            onView(withContentDescription("bandDetailWebSheetDone")).perform(click());
            QaUiTestHelpers.waitUntilDisplayed(onView(withText("Links:")), 15_000L);
        }
    }

    private void scrollBandIntoView(String bandName) throws Exception {
        long deadline = android.os.SystemClock.uptimeMillis() + 120_000L;
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            try {
                onView(withText(bandName)).check(ViewAssertions.matches(isDisplayed()));
                return;
            } catch (Throwable ignored) {
            }
            onView(withId(R.id.bandNames)).perform(swipeUp());
            Thread.sleep(350);
        }
        throw new AssertionError("Could not scroll to band row: " + bandName);
    }
}
