package com.Bands70k.qa;

import android.os.SystemClock;
import android.view.View;
import android.widget.AdapterView;

import androidx.test.espresso.ViewInteraction;
import androidx.test.espresso.assertion.ViewAssertions;
import androidx.test.espresso.matcher.BoundedMatcher;
import androidx.test.espresso.matcher.ViewMatchers;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject;
import androidx.test.uiautomator.UiSelector;

import com.Bands70k.bandListItem;

import org.hamcrest.Description;
import org.hamcrest.Matcher;
import org.hamcrest.TypeSafeMatcher;

/**
 * Shared helpers for QA walkthrough Espresso tests (parity with iOS XCUITest flows).
 */
public final class QaUiTestHelpers {

    private QaUiTestHelpers() {}

    public static Matcher<Object> bandListItemWithName(String bandName) {
        return new BoundedMatcher<Object, bandListItem>(bandListItem.class) {
            @Override
            public void describeTo(Description description) {
                description.appendText("bandListItem with bandName=" + bandName);
            }

            @Override
            protected boolean matchesSafely(bandListItem item) {
                return bandName != null && bandName.equals(item.getBandName());
            }
        };
    }

    /** Matches {@link AdapterView} whose adapter reports {@code count} items. */
    public static Matcher<View> adapterViewHasCount(final int count) {
        return new TypeSafeMatcher<View>() {
            @Override
            public void describeTo(Description description) {
                description.appendText("adapterViewHasCount " + count);
            }

            @Override
            protected boolean matchesSafely(View view) {
                if (!(view instanceof AdapterView)) {
                    return false;
                }
                AdapterView<?> av = (AdapterView<?>) view;
                if (av.getAdapter() == null) {
                    return false;
                }
                return av.getAdapter().getCount() == count;
            }
        };
    }

    /**
     * Polls Espresso until the view is displayed or timeout (for slow network + CSV loads).
     */
    public static void waitUntilDisplayed(ViewInteraction interaction, long timeoutMs) throws InterruptedException {
        long deadline = SystemClock.uptimeMillis() + timeoutMs;
        AssertionError last = null;
        while (SystemClock.uptimeMillis() < deadline) {
            try {
                interaction.check(ViewAssertions.matches(ViewMatchers.isDisplayed()));
                return;
            } catch (AssertionError | RuntimeException e) {
                last = new AssertionError(e);
            }
            Thread.sleep(400);
        }
        if (last != null) {
            throw last;
        }
        throw new AssertionError("Timeout waiting for view");
    }

    /** Best-effort dismissal of permission / generic blocking dialogs (mirrors iOS loop). */
    public static void dismissPostLaunchDialogsIfPossible() {
        UiDevice device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        long deadline = SystemClock.uptimeMillis() + 25_000L;
        while (SystemClock.uptimeMillis() < deadline) {
            boolean clicked = false;
            String[] labels = {
                    "OK", "Continue", "Dismiss", "Close", "Allow", "ALLOW",
                    "Don't Allow", "Don’t Allow", "Got it", "Later"
            };
            for (String label : labels) {
                UiObject btn = device.findObject(new UiSelector().text(label));
                if (btn.exists()) {
                    try {
                        btn.click();
                        clicked = true;
                        SystemClock.sleep(350);
                        break;
                    } catch (Exception ignored) {
                    }
                }
            }
            if (!clicked) {
                break;
            }
        }
    }
}
