package com.Bands70k.qa;

import androidx.test.espresso.Espresso;
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
import static androidx.test.espresso.action.ViewActions.longClick;
import static androidx.test.espresso.action.ViewActions.scrollTo;
import static androidx.test.espresso.action.ViewActions.swipeLeft;
import static androidx.test.espresso.matcher.ViewMatchers.isDisplayed;
import static androidx.test.espresso.matcher.ViewMatchers.withContentDescription;
import static androidx.test.espresso.matcher.ViewMatchers.withId;
import static androidx.test.espresso.matcher.ViewMatchers.withText;
import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;

/**
 * QA walkthrough Ch.1 ranking. Parity with iOS {@code QAWalkthroughChapter1RankingUITests}.
 */
@RunWith(AndroidJUnit4.class)
@LargeTest
public class QAWalkthroughChapter1RankingUITests {

    private static final String BAND_SWIPE_MUST = "Abysmal Dawn";
    private static final String BAND_LONG_PRESS_MIGHT = "Amorphis";
    private static final String BAND_DETAIL_WONT = "Angra";

    @Rule
    public final ActivityScenarioRule<showBands> activityRule = new ActivityScenarioRule<>(showBands.class);

    @Test
    public void testChapter1_NarrativeRankingThreeBands_StepwiseVerified() throws Exception {
        QaUiTestHelpers.dismissPostLaunchDialogsIfPossible();

        QaUiTestHelpers.waitUntilDisplayed(onView(withId(R.id.bandNames)), 180_000L);

        waitForHeaderBandCount(60, 35_000L);
        onView(withId(R.id.bandNames)).check(ViewAssertions.matches(QaUiTestHelpers.adapterViewHasCount(60)));

        // 1) Swipe → Must (scope to this row: every row's swipe menu uses the same qa* descriptions → ambiguous with onView)
        onData(QaUiTestHelpers.bandListItemWithName(BAND_SWIPE_MUST))
                .inAdapterView(allOf(withId(R.id.bandNames), isDisplayed()))
                .perform(swipeLeft());
        Thread.sleep(500);
        onData(QaUiTestHelpers.bandListItemWithName(BAND_SWIPE_MUST))
                .inAdapterView(allOf(withId(R.id.bandNames), isDisplayed()))
                .onChildView(withContentDescription("qaSwipeMust"))
                .perform(click());
        assertPriorityIcon(BAND_SWIPE_MUST, "Must");

        // 2) Long-press → Might
        onData(QaUiTestHelpers.bandListItemWithName(BAND_LONG_PRESS_MIGHT))
                .inAdapterView(allOf(withId(R.id.bandNames), isDisplayed()))
                .perform(longClick());
        QaUiTestHelpers.waitUntilDisplayed(onView(withContentDescription("qaLongPressMight")), 10_000L);
        onView(withContentDescription("qaLongPressMight")).perform(click());
        assertPriorityIcon(BAND_LONG_PRESS_MIGHT, "Might");

        // 3) Detail → Wont
        onData(QaUiTestHelpers.bandListItemWithName(BAND_DETAIL_WONT))
                .inAdapterView(allOf(withId(R.id.bandNames), isDisplayed()))
                .perform(click());
        QaUiTestHelpers.waitUntilDisplayed(onView(withId(R.id.wont_button)), 20_000L);
        onView(withId(R.id.wont_button)).perform(click());
        Espresso.pressBack();
        QaUiTestHelpers.waitUntilDisplayed(onView(withId(R.id.bandNames)), 15_000L);
        assertPriorityIcon(BAND_DETAIL_WONT, "Wont");

        waitForHeaderBandCount(60, 35_000L);
        onView(withId(R.id.bandNames)).check(ViewAssertions.matches(QaUiTestHelpers.adapterViewHasCount(60)));

        // Filters: only Wont visible (Angra)
        onView(withId(R.id.FilerMenu)).perform(click());
        QaUiTestHelpers.waitUntilDisplayed(onView(withContentDescription("qaFilterToggleUnknownSee")), 15_000L);

        onView(withContentDescription("qaFilterToggleUnknownSee")).perform(scrollTo(), click());
        onView(withContentDescription("qaFilterToggleMustSee")).perform(scrollTo(), click());
        onView(withContentDescription("qaFilterToggleMightSee")).perform(scrollTo(), click());

        onView(withContentDescription("qaFilterSheetDone")).perform(click());

        QaUiTestHelpers.waitUntilDisplayed(onView(withId(R.id.bandNames)), 15_000L);
        waitForHeaderBandCount(1, 35_000L);
        onView(withId(R.id.bandNames)).check(ViewAssertions.matches(QaUiTestHelpers.adapterViewHasCount(1)));
        QaUiTestHelpers.waitUntilDisplayed(onView(withText(BAND_DETAIL_WONT)), 10_000L);

        onView(withText(BAND_SWIPE_MUST)).check(ViewAssertions.doesNotExist());
        onView(withText(BAND_LONG_PRESS_MIGHT)).check(ViewAssertions.doesNotExist());
    }

    private void assertPriorityIcon(String bandName, String expectedLabel) throws Exception {
        onData(QaUiTestHelpers.bandListItemWithName(bandName))
                .inAdapterView(allOf(withId(R.id.bandNames), isDisplayed()))
                .onChildView(withId(R.id.rankingIconInDayArea))
                .check(ViewAssertions.matches(withContentDescription(expectedLabel)));
    }

    private void waitForHeaderBandCount(int exact, long timeoutMs) throws Exception {
        long deadline = android.os.SystemClock.uptimeMillis() + timeoutMs;
        AssertionError last = null;
        final String needle = " " + exact + " ";
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            try {
                onView(allOf(withContentDescription("qaMasterListCountTitle"), withText(containsString(needle))))
                        .check(ViewAssertions.matches(isDisplayed()));
                return;
            } catch (AssertionError | RuntimeException e) {
                last = new AssertionError(e);
            }
            Thread.sleep(400);
        }
        if (last != null) {
            throw last;
        }
        throw new AssertionError("Timeout waiting for band count " + exact);
    }
}
