package com.Bands70k;

import android.app.Activity;
import android.os.Bundle;
import android.view.MenuItem;

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
            getActionBar().setTitle("About");
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
