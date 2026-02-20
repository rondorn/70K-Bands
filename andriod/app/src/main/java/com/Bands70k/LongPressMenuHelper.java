package com.Bands70k;

import android.content.DialogInterface;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.res.Configuration;
import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.appcompat.view.ContextThemeWrapper;

/**
 * Shows the long-press menu (Priority + Attended) for list and calendar.
 * Portrait = list layout, landscape = 2 columns.
 */
public class LongPressMenuHelper {

    public static void show(Activity activity, String bandName, String currentAttendedStatus,
                            String location, String rawStartTime, String eventType, Runnable onRefresh,
                            Runnable onDismiss) {
        boolean isEvent = location != null && rawStartTime != null && eventType != null && currentAttendedStatus != null;
        String currentRank = rankStore.getRankForBand(bandName);
        boolean isMust = staticVariables.mustSeeIcon.equals(currentRank);
        boolean isMight = staticVariables.mightSeeIcon.equals(currentRank);
        boolean isWont = staticVariables.wontSeeIcon.equals(currentRank);
        boolean isUnknown = staticVariables.unknownIcon.equals(currentRank) || currentRank == null || currentRank.isEmpty();
        final String currentAttendedFinal = currentAttendedStatus;
        boolean isLandscape = activity.getResources().getConfiguration().orientation == Configuration.ORIENTATION_LANDSCAPE;
        float density = activity.getResources().getDisplayMetrics().density;
        int pad = (int) (16 * density);
        int rowHeight = (int) (40 * density);
        int textSizeSp = 16;

        ScrollView scroll = new ScrollView(activity);
        scroll.setPadding(pad, pad, pad, pad);
        scroll.setBackgroundColor(Color.parseColor("#1C1C1E"));
        LinearLayout root = new LinearLayout(activity);
        root.setOrientation(isLandscape && isEvent ? LinearLayout.HORIZONTAL : LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#1C1C1E"));
        if (isLandscape && isEvent) {
            root.setPadding(0, 0, (int)(16 * density), 0);
        }
        scroll.addView(root);

        LinearLayout prioritySection = new LinearLayout(activity);
        prioritySection.setOrientation(LinearLayout.VERTICAL);
        if (isLandscape && isEvent) {
            LinearLayout.LayoutParams colLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
            root.addView(prioritySection, colLp);
        } else {
            root.addView(prioritySection);
        }
        prioritySection.addView(addSectionHeader(activity, activity.getString(R.string.band_priority), density));

        final AlertDialog[] dialogHolder = new AlertDialog[1];

        View.OnClickListener mustClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
            @Override public void onClick(View v) {
                rankStore.saveBandRanking(bandName, staticVariables.mustSeeIcon);
                if (onRefresh != null) onRefresh.run();
            }
        });
        View.OnClickListener mightClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
            @Override public void onClick(View v) {
                rankStore.saveBandRanking(bandName, staticVariables.mightSeeIcon);
                if (onRefresh != null) onRefresh.run();
            }
        });
        View.OnClickListener wontClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
            @Override public void onClick(View v) {
                rankStore.saveBandRanking(bandName, staticVariables.wontSeeIcon);
                if (onRefresh != null) onRefresh.run();
            }
        });
        View.OnClickListener unknownClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
            @Override public void onClick(View v) {
                rankStore.saveBandRanking(bandName, staticVariables.unknownIcon);
                if (onRefresh != null) onRefresh.run();
            }
        });
        prioritySection.addView(addRow(activity, staticVariables.graphicMustSee != null ? staticVariables.graphicMustSee : 0, activity.getString(R.string.must), isMust, mustClick, density, rowHeight, textSizeSp));
        prioritySection.addView(addRow(activity, staticVariables.graphicMightSee != null ? staticVariables.graphicMightSee : 0, activity.getString(R.string.might), isMight, mightClick, density, rowHeight, textSizeSp));
        prioritySection.addView(addRow(activity, staticVariables.graphicWontSee != null ? staticVariables.graphicWontSee : 0, activity.getString(R.string.wont), isWont, wontClick, density, rowHeight, textSizeSp));
        prioritySection.addView(addRow(activity, R.drawable.icon_empty, activity.getString(R.string.unknown), isUnknown, unknownClick, density, rowHeight, textSizeSp));

        if (isEvent && currentAttendedFinal != null) {
            final String loc = location;
            final String raw = rawStartTime;
            final String evType = eventType;
            if (isLandscape) {
                LinearLayout attendedSection = new LinearLayout(activity);
                attendedSection.setOrientation(LinearLayout.VERTICAL);
                LinearLayout.LayoutParams colLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
                root.addView(attendedSection, colLp);
                attendedSection.addView(addSectionHeader(activity, activity.getString(R.string.event_attendance), density));
                View.OnClickListener allClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        setAttended(activity, bandName, loc, raw, evType, staticVariables.sawAllStatus);
                        if (onRefresh != null) onRefresh.run();
                    }
                });
                View.OnClickListener partClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        setAttended(activity, bandName, loc, raw, evType, staticVariables.sawSomeStatus);
                        if (onRefresh != null) onRefresh.run();
                    }
                });
                View.OnClickListener noneClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        setAttended(activity, bandName, loc, raw, evType, staticVariables.sawNoneStatus);
                        if (onRefresh != null) onRefresh.run();
                    }
                });
                attendedSection.addView(addRow(activity, 0, activity.getString(R.string.EventAttendanceAll), staticVariables.sawAllStatus.equals(currentAttendedFinal), allClick, density, rowHeight, textSizeSp));
                attendedSection.addView(addRow(activity, 0, activity.getString(R.string.EventAttendancePartial), staticVariables.sawSomeStatus.equals(currentAttendedFinal), partClick, density, rowHeight, textSizeSp));
                attendedSection.addView(addRow(activity, 0, activity.getString(R.string.EventAttendanceNone), staticVariables.sawNoneStatus.equals(currentAttendedFinal), noneClick, density, rowHeight, textSizeSp));
            } else {
                root.addView(addSectionHeader(activity, activity.getString(R.string.event_attendance), density));
                View.OnClickListener allClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        setAttended(activity, bandName, loc, raw, evType, staticVariables.sawAllStatus);
                        if (onRefresh != null) onRefresh.run();
                    }
                });
                View.OnClickListener partClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        setAttended(activity, bandName, loc, raw, evType, staticVariables.sawSomeStatus);
                        if (onRefresh != null) onRefresh.run();
                    }
                });
                View.OnClickListener noneClick = wrapDismiss(dialogHolder, new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        setAttended(activity, bandName, loc, raw, evType, staticVariables.sawNoneStatus);
                        if (onRefresh != null) onRefresh.run();
                    }
                });
                root.addView(addRow(activity, 0, activity.getString(R.string.EventAttendanceAll), staticVariables.sawAllStatus.equals(currentAttendedFinal), allClick, density, rowHeight, textSizeSp));
                root.addView(addRow(activity, 0, activity.getString(R.string.EventAttendancePartial), staticVariables.sawSomeStatus.equals(currentAttendedFinal), partClick, density, rowHeight, textSizeSp));
                root.addView(addRow(activity, 0, activity.getString(R.string.EventAttendanceNone), staticVariables.sawNoneStatus.equals(currentAttendedFinal), noneClick, density, rowHeight, textSizeSp));
            }
        }

        AlertDialog dialog = new AlertDialog.Builder(new ContextThemeWrapper(activity, R.style.AlertDialog))
                .setTitle(bandName)
                .setView(scroll)
                .setNegativeButton(activity.getString(R.string.Cancel), null)
                .create();
        if (onDismiss != null) {
            dialog.setOnDismissListener(new DialogInterface.OnDismissListener() {
                @Override
                public void onDismiss(DialogInterface dialogInterface) {
                    onDismiss.run();
                }
            });
        }
        dialogHolder[0] = dialog;
        dialog.show();
    }

    private static void setAttended(Activity activity, String bandName, String location, String rawStartTime, String eventType, String desiredStatus) {
        if (staticVariables.attendedHandler == null) {
            staticVariables.attendedHandler = new showsAttended();
        }
        staticVariables.attendedHandler.addShowsAttended(bandName, location, rawStartTime, eventType, desiredStatus);
        staticVariables.attendedHandler.setShowsAttendedStatus(desiredStatus);
    }

    private static View.OnClickListener wrapDismiss(final AlertDialog[] holder, final View.OnClickListener action) {
        return new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (holder[0] != null) holder[0].dismiss();
                action.onClick(v);
            }
        };
    }

    private static TextView addSectionHeader(Activity activity, String text, float density) {
        TextView h = new TextView(activity);
        h.setText(text);
        h.setTextSize(12);
        h.setTextColor(0xFF8E8E93);
        h.setPadding(0, (int)(8 * density), 0, (int)(4 * density));
        h.setAllCaps(true);
        return h;
    }

    private static LinearLayout addRow(Activity act, int iconRes, String label, boolean selected, View.OnClickListener click, float density, int rowHeight, int textSizeSp) {
        LinearLayout row = new LinearLayout(act);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(rowHeight);
        row.setPadding(0, (int)(4 * density), 0, (int)(4 * density));
        row.setOnClickListener(click);
        row.setBackgroundResource(android.R.drawable.list_selector_background);
        if (iconRes != 0) {
            ImageView iv = new ImageView(act);
            iv.setImageResource(iconRes);
            int iconSize = (int)(24 * density);
            iv.setLayoutParams(new LinearLayout.LayoutParams(iconSize, iconSize));
            iv.setPadding(0, 0, (int)(12 * density), 0);
            row.addView(iv);
        }
        TextView labelView = new TextView(act);
        labelView.setText(label);
        labelView.setTextSize(textSizeSp);
        labelView.setTextColor(Color.WHITE);
        row.addView(labelView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        if (selected) {
            TextView check = new TextView(act);
            check.setText(" ✓");
            check.setTextColor(Color.parseColor("#34C759"));
            check.setTextSize(textSizeSp);
            check.setPadding((int)(8 * density), 0, 0, 0);
            row.addView(check, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        }
        View spacer = new View(act);
        row.addView(spacer, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        return row;
    }
}
