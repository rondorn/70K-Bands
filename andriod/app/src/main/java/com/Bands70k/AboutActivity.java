package com.Bands70k;

import android.app.Activity;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.MenuItem;
import android.widget.ImageView;
import android.widget.LinearLayout;
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
        
        bindAboutDescription(R.id.about_description1, R.string.about_description1);
        bindAboutDescription(R.id.about_description2, R.string.about_description2);
        bindAboutDescription(R.id.about_description3, R.string.about_description3);
        bindAboutDescription(R.id.about_description4, R.string.about_description4);
        bindAboutDescription(R.id.about_description5, R.string.about_description5);

        TextView suiteLabel = findViewById(R.id.suite_registry_label);
        if (suiteLabel != null) {
            suiteLabel.setText(DataIntegrityTag.suiteDisplayLabel());
        }

        populateTeamSection();
    }

    private void bindAboutDescription(int textViewId, int stringId) {
        TextView textView = findViewById(textViewId);
        if (textView == null) {
            return;
        }
        FestivalConfig config = FestivalConfig.getInstance();
        String processed = getString(stringId)
                .replace("!FESTIVAL_NAME!", config.festivalName)
                .replace("!APP_NAME!", config.appName);
        textView.setText(processed);
    }

    private void populateTeamSection() {
        AboutTeamConfig team = FestivalConfig.getInstance().aboutTeam;
        LinearLayout container = findViewById(R.id.about_team_members);
        if (container == null || team == null) {
            return;
        }
        container.removeAllViews();

        int nameSizeSp = 17;
        int roleSizeSp = 13;
        int nameBottomPaddingPx = dpToPx(2);
        int memberBottomPaddingPx = dpToPx(12);
        int lastMemberBottomPaddingPx = dpToPx(20);
        int roleToPhotoPaddingPx = dpToPx(8);
        int betweenPhotosPaddingPx = dpToPx(8);

        for (int i = 0; i < team.members.size(); i++) {
            AboutTeamMember member = team.members.get(i);
            boolean isLast = i == team.members.size() - 1;
            boolean hasPhotos = !member.photoDrawableNames.isEmpty();

            TextView nameView = new TextView(this);
            nameView.setText(member.name);
            nameView.setTextSize(TypedValue.COMPLEX_UNIT_SP, nameSizeSp);
            nameView.setTypeface(nameView.getTypeface(), android.graphics.Typeface.BOLD);
            nameView.setTextColor(0xFFFFFFFF);
            nameView.setPadding(0, 0, 0, nameBottomPaddingPx);
            container.addView(nameView);

            TextView roleView = new TextView(this);
            roleView.setText(formatMemberRole(member));
            roleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, roleSizeSp);
            roleView.setTextColor(0xFF8E8E93);
            int roleBottomPaddingPx = hasPhotos
                    ? roleToPhotoPaddingPx
                    : (isLast ? lastMemberBottomPaddingPx : memberBottomPaddingPx);
            roleView.setPadding(0, 0, 0, roleBottomPaddingPx);
            container.addView(roleView);

            for (int p = 0; p < member.photoDrawableNames.size(); p++) {
                String drawableName = member.photoDrawableNames.get(p);
                int drawableId = getResources().getIdentifier(drawableName, "drawable", getPackageName());
                if (drawableId == 0) {
                    continue;
                }

                ImageView photoView = new ImageView(this);
                photoView.setImageResource(drawableId);
                photoView.setAdjustViewBounds(true);
                photoView.setScaleType(ImageView.ScaleType.FIT_CENTER);
                photoView.setContentDescription(getString(R.string.about_team_photo));

                boolean isLastPhoto = p == member.photoDrawableNames.size() - 1;
                int photoBottomPaddingPx = isLastPhoto
                        ? (isLast ? lastMemberBottomPaddingPx : memberBottomPaddingPx)
                        : betweenPhotosPaddingPx;
                photoView.setPadding(0, 0, 0, photoBottomPaddingPx);
                container.addView(photoView);
            }
        }
    }

    private String formatMemberRole(AboutTeamMember member) {
        int roleId = getResources().getIdentifier(
                member.roleTranslationKey, "string", getPackageName());
        String role = roleId != 0 ? getString(roleId) : member.roleTranslationKey;
        if (member.photoPositionTranslationKey != null && !member.photoPositionTranslationKey.isEmpty()) {
            int posId = getResources().getIdentifier(
                    member.photoPositionTranslationKey, "string", getPackageName());
            String position = posId != 0 ? getString(posId) : member.photoPositionTranslationKey;
            return role + " (" + position + ")";
        }
        return role;
    }

    private int dpToPx(int dp) {
        return Math.round(dp * getResources().getDisplayMetrics().density);
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
