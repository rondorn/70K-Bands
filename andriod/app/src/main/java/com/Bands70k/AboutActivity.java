package com.Bands70k;

import android.app.Activity;
import android.os.Bundle;
import android.view.MenuItem;
import android.widget.TextView;

/**
 * About Activity - Displays information about the app, team, and licensing
 * Created by Assistant on 2/5/26.
 */
public class AboutActivity extends Activity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        setTheme(R.style.AppTheme);
        super.onCreate(savedInstanceState);
        setContentView(R.layout.about_activity);
        
        // Enable the back button in the action bar
        if (getActionBar() != null) {
            getActionBar().setDisplayHomeAsUpEnabled(true);
            getActionBar().setTitle(getString(R.string.about));
        }
        
        // Replace !FESTIVALE_NAME! placeholder with actual festival name
        TextView description1TextView = findViewById(R.id.about_description1);
        if (description1TextView != null) {
            String template = getString(R.string.about_description1);
            String festivalName = FestivalConfig.getInstance().festivalName;
            String processedText = template.replace("!FESTIVALE_NAME!", festivalName);
            description1TextView.setText(processedText);
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle back button in action bar
        if (item.getItemId() == android.R.id.home) {
            finish();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    public void onBackPressed() {
        finish();
    }
}
