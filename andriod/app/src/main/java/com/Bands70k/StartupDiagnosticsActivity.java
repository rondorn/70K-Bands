package com.Bands70k;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;

/**
 * StartupDiagnosticsActivity
 *
 * Runs in a separate process (see manifest) so it can open even if the main app process
 * is stuck during startup.
 */
public class StartupDiagnosticsActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_startup_diagnostics);

        TextView diagnosticsText = findViewById(R.id.startupDiagnosticsText);
        Button shareButton = findViewById(R.id.startupDiagnosticsShare);
        Button closeButton = findViewById(R.id.startupDiagnosticsClose);

        // IMPORTANT: We want the "main process" breadcrumbs (where the splash hang occurs),
        // even though this activity runs in the :diag process.
        final String report = StartupTracker.buildMainDiagnosticsReport(getApplicationContext());
        diagnosticsText.setText(report);

        shareButton.setOnClickListener(v -> {
            Intent sendIntent = new Intent(Intent.ACTION_SEND);
            sendIntent.setType("text/plain");
            sendIntent.putExtra(Intent.EXTRA_SUBJECT, getString(R.string.startup_diag_share_subject));
            sendIntent.putExtra(Intent.EXTRA_TEXT, report);
            startActivity(Intent.createChooser(sendIntent, getString(R.string.startup_diag_share)));
        });

        closeButton.setOnClickListener(v -> finish());
    }
}

