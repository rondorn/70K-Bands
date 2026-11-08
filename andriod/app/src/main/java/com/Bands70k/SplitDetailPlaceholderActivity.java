package com.Bands70k;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.TextView;

/**
 * Empty secondary pane for Activity Embedding while no band is selected.
 * Replaced by {@link showBandDetails} when the user taps a list row.
 */
public class SplitDetailPlaceholderActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        setTheme(R.style.AppTheme);
        super.onCreate(savedInstanceState);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        root.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        TextView placeholder = new TextView(this);
        placeholder.setText(R.string.split_detail_placeholder);
        placeholder.setTextColor(0xFFABABAB);
        placeholder.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f);
        placeholder.setGravity(Gravity.CENTER);
        root.addView(placeholder, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        setContentView(root);
    }
}
