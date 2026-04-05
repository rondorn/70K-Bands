package com.Bands70k;

import android.content.res.ColorStateList;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.RadioGroup;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Multi-step "Plan Your Schedule" / Auto Choose Attendance wizard.
 * Port of Swift AutoChooseAttendanceWizardView.
 */
public class AutoChooseAttendanceWizardActivity extends AppCompatActivity {

    private static final String TAG = "AIWizard";

    private static final int STEP_INTRO = 0;
    private static final int STEP_UNKNOWN_BANDS = 1;
    private static final int STEP_LATEST_SHOW = 2;
    private static final int STEP_UNOFFICIAL = 3;
    private static final int STEP_MEET_GREET = 4;
    private static final int STEP_CLINICS = 5;
    private static final int STEP_SPECIAL_EVENTS = 6;
    private static final int STEP_BUILDING = 7;
    private static final int STEP_DONE = 8;

    private static final int REQUEST_BAND_DETAILS = 2001;
    /** Result code: wizard completed successfully; caller should navigate to list view. */
    public static final int RESULT_GO_TO_LIST = 100;

    private int eventYear;
    private int step = STEP_INTRO;
    private int latestShowHalfHours = 0;

    private List<EventData> events = new ArrayList<>();
    private boolean hasSpecialEvents = false;
    private boolean hasUnofficialEvents = false;
    private Set<String> selectedMeetAndGreetIds = new HashSet<>();
    private Set<String> selectedUnofficialEventIds = new HashSet<>();
    private Set<String> selectedClinicIds = new HashSet<>();
    private Set<String> selectedSpecialEventIds = new HashSet<>();
    private List<String> unknownBandNames = new ArrayList<>();
    private List<EventData> existingAttended = new ArrayList<>();
    private AIScheduleBuilder builder;
    private AIScheduleBuilder.BuildStep currentBuildStep;
    /** After attendance is cleared for a new build, finishing the activity restores from backup (unless completed). */
    private boolean pendingRestoreAttendanceOnCancel = false;

    private View stepIntroView;
    private View stepUnknownBandsView;
    private View stepLatestShowView;
    private View stepUnofficialView;
    private View stepMeetGreetView;
    private View stepClinicsView;
    private View stepSpecialEventsView;
    private View stepBuildingView;
    private TextView titleText;
    private Button nextButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        setTheme(R.style.AppTheme_NoActionBar);
        super.onCreate(savedInstanceState);

        eventYear = getIntent().getIntExtra("eventYear", staticVariables.eventYear != null ? staticVariables.eventYear : 0);
        if (eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
            eventYear = staticVariables.eventYear;
        }

        if (!AIScheduleEventLoader.hasBuildableEventsForYear(eventYear)) {
            AlertDialog blocked = new AlertDialog.Builder(this)
                    .setTitle(R.string.plan_your_schedule)
                    .setMessage(R.string.ai_schedule_no_events)
                    .setPositiveButton(R.string.Ok, (d, w) -> finish())
                    .setOnCancelListener(d -> finish())
                    .create();
            blocked.show();
            AutoScheduleWizardManager.applyDarkDialogStyle(blocked, this);
            return;
        }

        setContentView(R.layout.activity_auto_choose_attendance_wizard);

        titleText = findViewById(R.id.wizard_title);
        nextButton = findViewById(R.id.wizard_next);
        stepIntroView = findViewById(R.id.wizard_step_intro);
        stepUnknownBandsView = findViewById(R.id.wizard_step_unknown_bands);
        stepLatestShowView = findViewById(R.id.wizard_step_latest_show);
        stepUnofficialView = findViewById(R.id.wizard_step_unofficial);
        stepMeetGreetView = findViewById(R.id.wizard_step_meet_greet);
        stepClinicsView = findViewById(R.id.wizard_step_clinics);
        stepSpecialEventsView = findViewById(R.id.wizard_step_special_events);
        stepBuildingView = findViewById(R.id.wizard_step_building);

        nextButton.setOnClickListener(v -> advanceStep());
        findViewById(R.id.wizard_cancel).setOnClickListener(v -> finish());
        Button backButton = findViewById(R.id.wizard_back);
        if (backButton != null) backButton.setOnClickListener(v -> goToPreviousStep());

        findViewById(R.id.wizard_unknown_treat_wont).setOnClickListener(v -> treatUnknownAsWont());
        findViewById(R.id.wizard_unknown_next).setOnClickListener(v -> advanceFromUnknownBands());
        findViewById(R.id.wizard_unknown_ok).setOnClickListener(v -> finish());

        showStep(STEP_INTRO);
        // Force intro content visible and Next button clickable (matches iOS first screen)
        TextView introText = findViewById(R.id.wizard_intro_text);
        if (introText != null) {
            introText.setText(getString(R.string.plan_schedule_intro, FestivalConfig.getInstance().appName));
            introText.setTextColor(Color.WHITE);
            introText.setVisibility(View.VISIBLE);
        }
        if (stepIntroView != null) {
            stepIntroView.setVisibility(View.VISIBLE);
        }
        nextButton.setClickable(true);
        nextButton.setFocusable(true);
        // Run after layout so intro is definitely visible and button on top
        nextButton.post(() -> {
            if (introText != null) {
                introText.setTextColor(Color.WHITE);
                introText.invalidate();
            }
            nextButton.bringToFront();
        });
    }

    private void showStep(int s) {
        step = s;
        stepIntroView.setVisibility(step == STEP_INTRO ? View.VISIBLE : View.GONE);
        stepUnknownBandsView.setVisibility(step == STEP_UNKNOWN_BANDS ? View.VISIBLE : View.GONE);
        stepLatestShowView.setVisibility(step == STEP_LATEST_SHOW ? View.VISIBLE : View.GONE);
        stepUnofficialView.setVisibility(step == STEP_UNOFFICIAL ? View.VISIBLE : View.GONE);
        stepMeetGreetView.setVisibility(step == STEP_MEET_GREET ? View.VISIBLE : View.GONE);
        stepClinicsView.setVisibility(step == STEP_CLINICS ? View.VISIBLE : View.GONE);
        stepSpecialEventsView.setVisibility(step == STEP_SPECIAL_EVENTS ? View.VISIBLE : View.GONE);
        stepBuildingView.setVisibility(step == STEP_BUILDING ? View.VISIBLE : View.GONE);

        // Align with iOS: step title for Unknown bands / Latest show / Meet and Greets / Clinics / Special Events
        if (titleText != null) {
            if (step == STEP_UNKNOWN_BANDS) titleText.setText(R.string.unknown_bands_title);
            else if (step == STEP_LATEST_SHOW) titleText.setText(R.string.latest_show_title);
            else if (step == STEP_UNOFFICIAL) titleText.setText(R.string.aischedule_unofficial_header);
            else if (step == STEP_MEET_GREET) titleText.setText(R.string.aischedule_meet_greet_header);
            else if (step == STEP_CLINICS) titleText.setText(R.string.aischedule_clinics_header);
            else if (step == STEP_SPECIAL_EVENTS) titleText.setText(R.string.aischedule_special_events_header);
            else titleText.setText(R.string.plan_your_schedule);
        }

        if (step == STEP_UNKNOWN_BANDS) {
            loadUnknownBandsAndUpdateUI();
        }
        if (step == STEP_LATEST_SHOW) {
            Spinner spinner = findViewById(R.id.wizard_latest_show_spinner);
            if (spinner != null) {
                ensureEventsLoaded();
                configureLatestShowSpinner(spinner);
            }
        }
        if (step == STEP_MEET_GREET) {
            ensureEventsLoaded();
            populateMeetAndGreetList();
        }
        if (step == STEP_UNOFFICIAL) {
            ensureEventsLoaded();
            populateUnofficialList();
        }
        if (step == STEP_CLINICS) {
            ensureEventsLoaded();
            populateClinicsList();
        }
        if (step == STEP_SPECIAL_EVENTS) {
            populateSpecialEventsList();
        }

        nextButton.setVisibility(step == STEP_BUILDING ? View.GONE : View.VISIBLE);
        Button backBtn = findViewById(R.id.wizard_back);
        if (backBtn != null) {
            backBtn.setVisibility(step > STEP_INTRO && step != STEP_BUILDING ? View.VISIBLE : View.GONE);
        }
        String nextLabel = getString(R.string.Next);
        if (step == STEP_CLINICS) nextLabel = hasSpecialEventOptions() ? getString(R.string.Next) : getString(R.string.aischedule_build_schedule);
        else if (step == STEP_SPECIAL_EVENTS) nextLabel = getString(R.string.aischedule_build_schedule);
        else if (step == STEP_MEET_GREET || step == STEP_UNOFFICIAL) nextLabel = getString(R.string.Next);
        else if (step != STEP_INTRO) nextLabel = getString(R.string.Next);
        nextButton.setText(step == STEP_INTRO ? getString(R.string.Next) : nextLabel);
        if (step == STEP_UNKNOWN_BANDS) {
            nextButton.setVisibility(View.GONE);
        }
    }

    /**
     * Build latest-show spinner options from schedule data, matching iOS behavior:
     * offer 30-min slots from 12:00 AM up to latest late-night show start (00:00-05:59), rounded up.
     */
    private void configureLatestShowSpinner(Spinner spinner) {
        int maxHalfHours = computeLatestShowCutoffMaxFromSchedule();
        if (maxHalfHours < 0) {
            maxHalfHours = 0;
        }
        if (maxHalfHours > 11) {
            maxHalfHours = 11; // 5:30 AM max slot
        }

        // Always default to latest available option to avoid excluding shows unless user opts in.
        latestShowHalfHours = maxHalfHours;

        java.text.DateFormat timeFmt = android.text.format.DateFormat.getTimeFormat(this);
        Calendar cal = Calendar.getInstance();
        cal.set(2000, Calendar.JANUARY, 1, 0, 0, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);

        String[] labels = new String[maxHalfHours + 1];
        for (int i = 0; i <= maxHalfHours; i++) {
            int halfHour = i;
            int hour = halfHour / 2;
            int minute = (halfHour % 2) * 30;
            cal.set(Calendar.HOUR_OF_DAY, hour);
            cal.set(Calendar.MINUTE, minute);
            labels[i] = timeFmt.format(cal.getTime());
        }

        android.widget.ArrayAdapter<String> adapter = new android.widget.ArrayAdapter<String>(this, R.layout.spinner_item_white, labels);
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item_dark);
        spinner.setAdapter(adapter);
        spinner.setSelection(Math.min(latestShowHalfHours, maxHalfHours));
        spinner.setContentDescription(getString(R.string.latest_show_cutoff_content_description));

        // Make the whole field (including chevron area) open the spinner dropdown.
        View field = findViewById(R.id.wizard_latest_show_field);
        View chevron = findViewById(R.id.wizard_latest_show_chevron);
        View.OnClickListener openDropdown = v -> spinner.performClick();
        if (field != null) field.setOnClickListener(openDropdown);
        if (chevron != null) chevron.setOnClickListener(openDropdown);
    }

    /**
     * Returns max half-hour slot in late night (0=12:00 AM ... 11=5:30 AM), rounded up to next half-hour.
     */
    private int computeLatestShowCutoffMaxFromSchedule() {
        int maxHalfHours = 0;
        String showType = staticVariables.show != null ? staticVariables.show : "Show";
        for (EventData e : events) {
            if (e == null) continue;
            String et = e.eventType != null ? e.eventType : "";
            if (!showType.equals(et)) continue;
            int[] hm = parseHourMinutesFromStartTime(e.startTime);
            if (hm == null) continue;
            int hour = hm[0], minute = hm[1];
            if (hour < 0 || hour > 5) continue; // late night only (matches iOS)
            int halfHours = (hour * 2) + (minute > 0 ? 1 : 0);
            if (halfHours > maxHalfHours) {
                maxHalfHours = halfHours;
            }
        }
        return maxHalfHours;
    }

    /**
     * Parse "1:00 AM", "3:30 AM", "05:15", or "00:30" into [hour(0-23), minute(0-59)].
     */
    private int[] parseHourMinutesFromStartTime(String startTime) {
        if (startTime == null) return null;
        String trimmed = startTime.trim();
        if (trimmed.isEmpty()) return null;

        String upper = trimmed.toUpperCase();
        boolean isAM = upper.contains("AM");
        boolean isPM = upper.contains("PM");

        Pattern p = Pattern.compile("(\\d{1,2})\\s*:\\s*(\\d{1,2})");
        Matcher m = p.matcher(trimmed);
        if (!m.find()) return null;

        int hour;
        int minute;
        try {
            hour = Integer.parseInt(m.group(1));
            minute = Integer.parseInt(m.group(2));
        } catch (NumberFormatException ex) {
            return null;
        }
        if (minute < 0) minute = 0;
        if (minute > 59) minute = 59;

        if (isAM || isPM) {
            if (hour < 1 || hour > 12) return null;
            if (isPM && hour != 12) hour += 12;
            if (isAM && hour == 12) hour = 0;
        } else {
            if (hour < 0 || hour > 23) return null;
        }
        return new int[]{hour, minute};
    }

    private void ensureEventsLoaded() {
        if (events.isEmpty()) {
            events = AIScheduleEventLoader.buildEventListForYear(eventYear);
        }
        hasSpecialEvents = false;
        hasUnofficialEvents = false;
        for (EventData e : events) {
            if (staticVariables.specialEvent.equals(e.eventType != null ? e.eventType : "")) {
                hasSpecialEvents = true;
            }
            String uo = staticVariables.unofficalEvent != null ? staticVariables.unofficalEvent : "";
            String uoOld = staticVariables.unofficalEventOld != null ? staticVariables.unofficalEventOld : "";
            String et = e.eventType != null ? e.eventType : "";
            if (uo.equals(et) || uoOld.equals(et)) {
                hasUnofficialEvents = true;
            }
            if (hasSpecialEvents && hasUnofficialEvents) break;
        }
    }

    private boolean hasUnofficialOptions() {
        String uo = staticVariables.unofficalEvent != null ? staticVariables.unofficalEvent : "";
        String uoOld = staticVariables.unofficalEventOld != null ? staticVariables.unofficalEventOld : "";
        for (EventData e : events) {
            String et = e.eventType != null ? e.eventType : "";
            if (uo.equals(et) || uoOld.equals(et)) return true;
        }
        return false;
    }

    /** Meet & Greet step only offers Must bands, so skip when none are Must-ranked. */
    private boolean hasMeetAndGreetOptions() {
        String mgType = staticVariables.meetAndGreet != null ? staticVariables.meetAndGreet : "Meet and Greet";
        for (EventData e : events) {
            String et = e.eventType != null ? e.eventType : "";
            if (!mgType.equals(et)) continue;
            if (rankStore.getPriorityForBand(e.bandName) == 1) return true;
        }
        return false;
    }

    private boolean hasClinicOptions() {
        String clinicType = staticVariables.clinic != null ? staticVariables.clinic : "Clinic";
        for (EventData e : events) {
            String et = e.eventType != null ? e.eventType : "";
            if (clinicType.equals(et)) return true;
        }
        return false;
    }

    private boolean hasSpecialEventOptions() {
        String specialType = staticVariables.specialEvent != null ? staticVariables.specialEvent : "Special Event";
        for (EventData e : events) {
            String et = e.eventType != null ? e.eventType : "";
            if (specialType.equals(et)) return true;
        }
        return false;
    }

    private static String eventId(EventData e) {
        if (e == null) return "";
        return (e.bandName != null ? e.bandName : "") + "|" + (e.location != null ? e.location : "") + "|" + (e.startTime != null ? e.startTime : "") + "|" + (e.eventType != null ? e.eventType : "");
    }

    private void applyCheckboxTint(CheckBox cb) {
        int uncheckedColor = 0xFFCCCCCC;
        int checkedColor = 0xFF34C759;
        int[][] states = new int[][]{new int[]{android.R.attr.state_checked}, new int[]{}};
        int[] colors = new int[]{checkedColor, uncheckedColor};
        cb.setButtonTintList(new ColorStateList(states, colors));
    }

    private void populateMeetAndGreetList() {
        LinearLayout container = findViewById(R.id.wizard_meet_greet_list);
        if (container == null) return;
        container.removeAllViews();
        String mgType = staticVariables.meetAndGreet != null ? staticVariables.meetAndGreet : "Meet and Greet";
        for (EventData e : events) {
            if (!mgType.equals(e.eventType != null ? e.eventType : "")) continue;
            if (rankStore.getPriorityForBand(e.bandName) != 1) continue;
            String id = eventId(e);
            String band = (e.bandName != null ? e.bandName : "");
            String notesPart = (e.notes != null && !e.notes.isEmpty()) ? " — " + e.notes : "";
            String sub = (e.location != null ? e.location : "") + " · " + (e.day != null ? e.day : "") + " · " + (e.startTime != null ? e.startTime : "");
            String line = band + notesPart + " — " + sub;
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(0, 12, 0, 12);
            row.setTag(id);
            row.setGravity(android.view.Gravity.CENTER_VERTICAL);
            TextView tv = new TextView(this);
            tv.setTextColor(Color.WHITE);
            tv.setText(line);
            tv.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
            row.addView(tv);
            CheckBox cb = new CheckBox(this);
            cb.setText("");
            cb.setChecked(selectedMeetAndGreetIds.contains(id));
            cb.setTag(id);
            applyCheckboxTint(cb);
            cb.setOnCheckedChangeListener((btn, checked) -> {
                if (checked) selectedMeetAndGreetIds.add((String) btn.getTag());
                else selectedMeetAndGreetIds.remove(btn.getTag());
            });
            row.addView(cb);
            row.setOnClickListener(v -> cb.setChecked(!cb.isChecked()));
            container.addView(row);
        }
        Button allBtn = findViewById(R.id.wizard_meet_greet_all);
        if (allBtn != null) {
            allBtn.setOnClickListener(v -> {
                for (int i = 0; i < container.getChildCount(); i++) {
                    View child = container.getChildAt(i);
                    if (child instanceof LinearLayout) {
                        for (int j = 0; j < ((LinearLayout) child).getChildCount(); j++) {
                            View inner = ((LinearLayout) child).getChildAt(j);
                            if (inner instanceof CheckBox) {
                                String id = (String) ((LinearLayout) child).getTag();
                                ((CheckBox) inner).setChecked(true);
                                selectedMeetAndGreetIds.add(id);
                                break;
                            }
                        }
                    }
                }
            });
        }
        Button noneBtn = findViewById(R.id.wizard_meet_greet_none);
        if (noneBtn != null) {
            noneBtn.setOnClickListener(v -> {
                selectedMeetAndGreetIds.clear();
                for (int i = 0; i < container.getChildCount(); i++) {
                    View child = container.getChildAt(i);
                    if (child instanceof LinearLayout) {
                        for (int j = 0; j < ((LinearLayout) child).getChildCount(); j++) {
                            View inner = ((LinearLayout) child).getChildAt(j);
                            if (inner instanceof CheckBox) {
                                ((CheckBox) inner).setChecked(false);
                                break;
                            }
                        }
                    }
                }
            });
        }
    }

    private void populateUnofficialList() {
        LinearLayout container = findViewById(R.id.wizard_unofficial_list);
        if (container == null) return;
        container.removeAllViews();
        String uo = staticVariables.unofficalEvent != null ? staticVariables.unofficalEvent : "";
        String uoOld = staticVariables.unofficalEventOld != null ? staticVariables.unofficalEventOld : "";
        for (EventData e : events) {
            String et = e.eventType != null ? e.eventType : "";
            if (!uo.equals(et) && !uoOld.equals(et)) continue;
            String id = eventId(e);
            String label = (e.notes != null && !e.notes.isEmpty()) ? e.notes : (e.bandName != null ? e.bandName : "");
            String sub = (e.location != null ? e.location : "") + " · " + (e.day != null ? e.day : "") + " · " + (e.startTime != null ? e.startTime : "");
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(0, 12, 0, 12);
            row.setTag(id);
            row.setGravity(android.view.Gravity.CENTER_VERTICAL);
            TextView tv = new TextView(this);
            tv.setTextColor(Color.WHITE);
            tv.setText(label + " — " + sub);
            tv.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
            row.addView(tv);
            CheckBox cb = new CheckBox(this);
            cb.setText("");
            cb.setChecked(selectedUnofficialEventIds.contains(id));
            cb.setTag(id);
            applyCheckboxTint(cb);
            cb.setOnCheckedChangeListener((btn, checked) -> {
                if (checked) selectedUnofficialEventIds.add((String) btn.getTag());
                else selectedUnofficialEventIds.remove(btn.getTag());
            });
            row.addView(cb);
            row.setOnClickListener(v -> cb.setChecked(!cb.isChecked()));
            container.addView(row);
        }
    }

    private void populateClinicsList() {
        LinearLayout container = findViewById(R.id.wizard_clinics_list);
        if (container == null) return;
        container.removeAllViews();
        String clinicType = staticVariables.clinic != null ? staticVariables.clinic : "Clinic";
        for (EventData e : events) {
            if (!clinicType.equals(e.eventType != null ? e.eventType : "")) continue;
            String id = eventId(e);
            String label = (e.notes != null && !e.notes.isEmpty()) ? e.notes : (e.bandName != null ? e.bandName : "");
            String sub = (e.location != null ? e.location : "") + " · " + (e.day != null ? e.day : "") + " · " + (e.startTime != null ? e.startTime : "");
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(0, 12, 0, 12);
            row.setTag(id);
            row.setGravity(android.view.Gravity.CENTER_VERTICAL);
            TextView tv = new TextView(this);
            tv.setTextColor(Color.WHITE);
            tv.setText(label + " — " + sub);
            tv.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
            row.addView(tv);
            CheckBox cb = new CheckBox(this);
            cb.setText("");
            cb.setChecked(selectedClinicIds.contains(id));
            cb.setTag(id);
            applyCheckboxTint(cb);
            cb.setOnCheckedChangeListener((btn, checked) -> {
                if (checked) selectedClinicIds.add((String) btn.getTag());
                else selectedClinicIds.remove(btn.getTag());
            });
            row.addView(cb);
            row.setOnClickListener(v -> cb.setChecked(!cb.isChecked()));
            container.addView(row);
        }
    }

    private void populateSpecialEventsList() {
        LinearLayout container = findViewById(R.id.wizard_special_events_list);
        if (container == null) return;
        container.removeAllViews();
        String specialType = staticVariables.specialEvent != null ? staticVariables.specialEvent : "Special Event";
        for (EventData e : events) {
            if (!specialType.equals(e.eventType != null ? e.eventType : "")) continue;
            String id = eventId(e);
            String label = (e.notes != null && !e.notes.isEmpty()) ? e.notes : (e.bandName != null ? e.bandName : "");
            String sub = (e.location != null ? e.location : "") + " · " + (e.day != null ? e.day : "") + " · " + (e.startTime != null ? e.startTime : "");
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(0, 12, 0, 12);
            row.setTag(id);
            row.setGravity(android.view.Gravity.CENTER_VERTICAL);
            TextView tv = new TextView(this);
            tv.setTextColor(Color.WHITE);
            tv.setText(label + " — " + sub);
            tv.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
            row.addView(tv);
            CheckBox cb = new CheckBox(this);
            cb.setText("");
            cb.setChecked(selectedSpecialEventIds.contains(id));
            cb.setTag(id);
            applyCheckboxTint(cb);
            cb.setOnCheckedChangeListener((btn, checked) -> {
                if (checked) selectedSpecialEventIds.add((String) btn.getTag());
                else selectedSpecialEventIds.remove(btn.getTag());
            });
            row.addView(cb);
            row.setOnClickListener(v -> cb.setChecked(!cb.isChecked()));
            container.addView(row);
        }
    }

    /** Populates unknownBandNames (and events if needed). Call before showing STEP_UNKNOWN_BANDS or when deciding whether to skip it. */
    private void refreshUnknownBandsList() {
        if (events.isEmpty()) {
            events = AIScheduleEventLoader.buildEventListForYear(eventYear);
        }
        String showType = staticVariables.show != null ? staticVariables.show : "Show";
        Set<String> bandsWithShows = new HashSet<>();
        for (EventData e : events) {
            String et = e.eventType != null ? e.eventType : "";
            if (showType.equals(et)) {
                bandsWithShows.add(e.bandName);
            }
        }
        unknownBandNames.clear();
        for (String name : new TreeSet<>(bandsWithShows)) {
            if (rankStore.getPriorityForBand(name) == 0) {
                unknownBandNames.add(name);
            }
        }
    }

    private void loadUnknownBandsAndUpdateUI() {
        refreshUnknownBandsList();

        TextView message = findViewById(R.id.wizard_unknown_message);
        TextView hint = findViewById(R.id.wizard_unknown_hint);
        View listScroll = findViewById(R.id.wizard_unknown_list_scroll);
        LinearLayout listContainer = findViewById(R.id.wizard_unknown_list);
        View buttonsRow = findViewById(R.id.wizard_unknown_buttons);
        Button okButton = findViewById(R.id.wizard_unknown_ok);

        if (message != null) message.setVisibility(View.VISIBLE);
        if (hint != null) hint.setVisibility(View.GONE);
        if (listScroll != null) listScroll.setVisibility(View.GONE);
        if (buttonsRow != null) buttonsRow.setVisibility(View.GONE);
        if (okButton != null) okButton.setVisibility(View.GONE);

        if (unknownBandNames.isEmpty()) {
            if (message != null) message.setText(R.string.unknown_bands_all_ranked);
            if (buttonsRow != null) {
                buttonsRow.setVisibility(View.VISIBLE);
                findViewById(R.id.wizard_unknown_treat_wont).setVisibility(View.GONE);
                findViewById(R.id.wizard_unknown_next).setVisibility(View.VISIBLE);
            }
        } else if (unknownBandNames.size() > 10) {
            if (message != null) message.setText(R.string.unknown_bands_too_many);
            if (okButton != null) okButton.setVisibility(View.VISIBLE);
        } else {
            if (message != null) message.setText(getString(R.string.unknown_bands_fix_prompt, unknownBandNames.size()));
            if (hint != null) {
                hint.setVisibility(View.VISIBLE);
                hint.setText(R.string.unknown_bands_fix_hint);
            }
            if (listScroll != null) listScroll.setVisibility(View.VISIBLE);
            if (listContainer != null) {
                listContainer.removeAllViews();
                for (String bandName : unknownBandNames) {
                    LinearLayout row = new LinearLayout(this);
                    row.setOrientation(LinearLayout.HORIZONTAL);
                    row.setPadding(0, 12, 0, 12);
                    TextView tv = new TextView(this);
                    tv.setText(bandName);
                    tv.setTextColor(Color.WHITE);
                    tv.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
                    Button detailsBtn = new Button(this);
                    detailsBtn.setText(R.string.unknown_bands_details);
                    detailsBtn.setTextColor(Color.WHITE);
                    detailsBtn.setBackgroundColor(0xFF007AFF);
                    final String name = bandName;
                    detailsBtn.setOnClickListener(v -> openBandDetails(name));
                    LinearLayout.LayoutParams btnParams = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                    btnParams.setMargins(16, 0, 0, 0);
                    detailsBtn.setLayoutParams(btnParams);
                    row.addView(tv);
                    row.addView(detailsBtn);
                    listContainer.addView(row);
                }
            }
            if (buttonsRow != null) {
                buttonsRow.setVisibility(View.VISIBLE);
                findViewById(R.id.wizard_unknown_treat_wont).setVisibility(View.VISIBLE);
                findViewById(R.id.wizard_unknown_next).setVisibility(View.VISIBLE);
            }
        }
    }

    private void openBandDetails(String bandName) {
        BandInfo.setSelectedBand(bandName);
        Intent intent = new Intent(this, showBandDetails.class);
        intent.putExtra("BandName", bandName);
        intent.putExtra("showCustomBackButton", true);
        startActivityForResult(intent, REQUEST_BAND_DETAILS);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_BAND_DETAILS && step == STEP_UNKNOWN_BANDS) {
            loadUnknownBandsAndUpdateUI();
        }
    }

    private void treatUnknownAsWont() {
        for (String name : unknownBandNames) {
            rankStore.saveBandRanking(name, staticVariables.wontSeeIcon);
        }
        unknownBandNames.clear();
        showStep(STEP_LATEST_SHOW);
    }

    private void advanceFromUnknownBands() {
        loadUnknownBandsAndUpdateUI();
        if (unknownBandNames.isEmpty()) {
            showStep(STEP_LATEST_SHOW);
        }
    }

    private void advanceStep() {
        if (step == STEP_INTRO) {
            refreshUnknownBandsList();
            if (unknownBandNames.isEmpty()) {
                showStep(STEP_LATEST_SHOW);
            } else {
                showStep(STEP_UNKNOWN_BANDS);
            }
            return;
        }
        if (step == STEP_LATEST_SHOW) {
            Spinner spinner = findViewById(R.id.wizard_latest_show_spinner);
            if (spinner != null) {
                int selectedPos = spinner.getSelectedItemPosition();
                latestShowHalfHours = selectedPos >= 0 ? selectedPos : 0;
            }
            ensureEventsLoaded();
            if (hasUnofficialOptions()) {
                showStep(STEP_UNOFFICIAL);
            } else if (hasMeetAndGreetOptions()) {
                showStep(STEP_MEET_GREET);
            } else if (hasClinicOptions()) {
                showStep(STEP_CLINICS);
            } else if (hasSpecialEventOptions()) {
                showStep(STEP_SPECIAL_EVENTS);
            } else {
                startBuilding();
            }
            return;
        }
        if (step == STEP_UNOFFICIAL) {
            if (hasMeetAndGreetOptions()) {
                showStep(STEP_MEET_GREET);
            } else if (hasClinicOptions()) {
                showStep(STEP_CLINICS);
            } else if (hasSpecialEventOptions()) {
                showStep(STEP_SPECIAL_EVENTS);
            } else {
                startBuilding();
            }
            return;
        }
        if (step == STEP_MEET_GREET) {
            if (hasClinicOptions()) {
                showStep(STEP_CLINICS);
            } else if (hasSpecialEventOptions()) {
                showStep(STEP_SPECIAL_EVENTS);
            } else {
                startBuilding();
            }
            return;
        }
        if (step == STEP_CLINICS) {
            if (hasSpecialEventOptions()) {
                showStep(STEP_SPECIAL_EVENTS);
            } else {
                startBuilding();
            }
            return;
        }
        if (step == STEP_SPECIAL_EVENTS) {
            startBuilding();
            return;
        }
    }

    private void startBuilding() {
        showStep(STEP_BUILDING);
        if (events.isEmpty()) {
            events = AIScheduleEventLoader.buildEventListForYear(eventYear);
        }
        if (events.isEmpty()) {
            Toast.makeText(this, getString(R.string.ai_schedule_no_events), Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        if (staticVariables.attendedHandler == null) {
            staticVariables.attendedHandler = new showsAttended();
        }
        showsAttended attendedHandle = staticVariables.attendedHandler;
        AIScheduleStorage.saveWizardRollbackBackup(attendedHandle.getShowsAttended(), eventYear);
        attendedHandle.clearAttendanceForYear(eventYear);
        existingAttended.clear();
        pendingRestoreAttendanceOnCancel = true;

        List<EventData> selectedMeetAndGreetList = new ArrayList<>();
        List<EventData> selectedUnofficialList = new ArrayList<>();
        List<EventData> selectedClinicsList = new ArrayList<>();
        List<EventData> selectedSpecialsList = new ArrayList<>();
        for (EventData e : events) {
            String id = eventId(e);
            if (staticVariables.meetAndGreet.equals(e.eventType != null ? e.eventType : "") && selectedMeetAndGreetIds.contains(id)) {
                selectedMeetAndGreetList.add(e);
            }
            String uo = staticVariables.unofficalEvent != null ? staticVariables.unofficalEvent : "";
            String uoOld = staticVariables.unofficalEventOld != null ? staticVariables.unofficalEventOld : "";
            String et = e.eventType != null ? e.eventType : "";
            if ((uo.equals(et) || uoOld.equals(et)) && selectedUnofficialEventIds.contains(id)) {
                selectedUnofficialList.add(e);
            }
            if (staticVariables.clinic.equals(e.eventType != null ? e.eventType : "") && selectedClinicIds.contains(id)) {
                selectedClinicsList.add(e);
            }
            if (staticVariables.specialEvent.equals(e.eventType != null ? e.eventType : "") && selectedSpecialEventIds.contains(id)) {
                selectedSpecialsList.add(e);
            }
        }

        builder = new AIScheduleBuilder(false, false, eventYear, latestShowHalfHours);
        new Thread(() -> {
            currentBuildStep = builder.start(events, existingAttended, selectedClinicsList, selectedSpecialsList, selectedMeetAndGreetList, selectedUnofficialList);
            runOnUiThread(this::handleBuildStep);
        }).start();
    }

    private void handleBuildStep() {
        if (currentBuildStep == null) return;
        if (currentBuildStep.type == AIScheduleBuilder.STEP_COMPLETED) {
            writeAndFinish(currentBuildStep.completedList);
            return;
        }
        if (currentBuildStep.type == AIScheduleBuilder.STEP_NEED_MUST_CONFLICT) {
            showConflictDialog(currentBuildStep.conflictEventA, currentBuildStep.conflictEventB);
            return;
        }
    }

    /**
     * Returns "Seeing them: Nowhere else" or "Seeing them: [location] [day]" for other SHOWS of the same band only.
     * Meet and Greets, clinics, and other event types do not count—only shows.
     */
    private String seeingThemElsewhere(EventData event) {
        if (event == null || events == null) return getString(R.string.aischedule_seeing_them_nowhere_else);
        String band = event.bandName;
        if (band == null) return getString(R.string.aischedule_seeing_them_nowhere_else);
        String showType = staticVariables.show != null ? staticVariables.show : "Show";
        for (EventData other : events) {
            if (other == event) continue;
            if (!band.equals(other.bandName)) continue;
            if (!showType.equals(other.eventType != null ? other.eventType : "")) continue;
            String loc = other.location != null ? other.location : "";
            String day = other.day != null ? other.day : "";
            String place = (loc + " " + day).trim();
            if (place.isEmpty()) place = getString(R.string.aischedule_seeing_them_nowhere_else);
            else return getString(R.string.aischedule_seeing_them_format, place);
        }
        return getString(R.string.aischedule_seeing_them_nowhere_else);
    }

    /** Day and time for conflict card: "Day 1 - 5:45 PM" or just time if no day. */
    private String formatDayAndTime(EventData e) {
        if (e == null) return "";
        String day = e.day != null ? e.day.trim() : "";
        String time = e.startTime != null ? e.startTime : "";
        if (day.isEmpty()) return time;
        return day + " - " + time;
    }

    private void showConflictDialog(EventData a, EventData b) {
        View view = LayoutInflater.from(this).inflate(R.layout.dialog_schedule_conflict, null);
        TextView title = view.findViewById(R.id.conflict_title);
        TextView subtitle = view.findViewById(R.id.conflict_subtitle);
        LinearLayout optionA = view.findViewById(R.id.conflict_option_a);
        LinearLayout optionB = view.findViewById(R.id.conflict_option_b);
        TextView cancelBtn = view.findViewById(R.id.conflict_cancel);

        title.setText(R.string.aischedule_must_conflict_title);
        subtitle.setText(R.string.aischedule_must_conflict_message);

        TextView bandA = view.findViewById(R.id.conflict_option_a_band);
        TextView typeA = view.findViewById(R.id.conflict_option_a_event_type);
        TextView timeA = view.findViewById(R.id.conflict_option_a_time);
        TextView venueA = view.findViewById(R.id.conflict_option_a_venue);
        TextView genreA = view.findViewById(R.id.conflict_option_a_genre);
        TextView seeingA = view.findViewById(R.id.conflict_option_a_seeing_them);
        if (a != null) {
            bandA.setText(a.bandName);
            String eventTypeA = a.eventType != null ? a.eventType : staticVariables.show;
            boolean isShowA = staticVariables.show.equals(eventTypeA);
            if (isShowA) {
                typeA.setVisibility(View.GONE);
            } else {
                typeA.setText(Utilities.convertEventTypeToLocalLanguage(eventTypeA));
                typeA.setVisibility(View.VISIBLE);
            }
            timeA.setText(formatDayAndTime(a));
            venueA.setText(a.location != null ? a.location : "");
            String genreTextA = BandInfo.getGenre(a.bandName);
            if (genreTextA != null) genreTextA = genreTextA.trim();
            if (genreTextA != null && !genreTextA.isEmpty()) {
                genreA.setText(getString(R.string.genre) + ": " + genreTextA);
                genreA.setVisibility(View.VISIBLE);
            } else {
                genreA.setVisibility(View.GONE);
            }
            if (isShowA) {
                seeingA.setText(seeingThemElsewhere(a));
                seeingA.setVisibility(View.VISIBLE);
            } else {
                seeingA.setVisibility(View.GONE);
            }
        } else {
            typeA.setVisibility(View.GONE);
            genreA.setVisibility(View.GONE);
            seeingA.setVisibility(View.GONE);
        }
        TextView bandB = view.findViewById(R.id.conflict_option_b_band);
        TextView typeB = view.findViewById(R.id.conflict_option_b_event_type);
        TextView timeB = view.findViewById(R.id.conflict_option_b_time);
        TextView venueB = view.findViewById(R.id.conflict_option_b_venue);
        TextView genreB = view.findViewById(R.id.conflict_option_b_genre);
        TextView seeingB = view.findViewById(R.id.conflict_option_b_seeing_them);
        if (b != null) {
            bandB.setText(b.bandName);
            String eventTypeB = b.eventType != null ? b.eventType : staticVariables.show;
            boolean isShowB = staticVariables.show.equals(eventTypeB);
            if (isShowB) {
                typeB.setVisibility(View.GONE);
            } else {
                typeB.setText(Utilities.convertEventTypeToLocalLanguage(eventTypeB));
                typeB.setVisibility(View.VISIBLE);
            }
            timeB.setText(formatDayAndTime(b));
            venueB.setText(b.location != null ? b.location : "");
            String genreTextB = BandInfo.getGenre(b.bandName);
            if (genreTextB != null) genreTextB = genreTextB.trim();
            if (genreTextB != null && !genreTextB.isEmpty()) {
                genreB.setText(getString(R.string.genre) + ": " + genreTextB);
                genreB.setVisibility(View.VISIBLE);
            } else {
                genreB.setVisibility(View.GONE);
            }
            if (isShowB) {
                seeingB.setText(seeingThemElsewhere(b));
                seeingB.setVisibility(View.VISIBLE);
            } else {
                seeingB.setVisibility(View.GONE);
            }
        } else {
            typeB.setVisibility(View.GONE);
            genreB.setVisibility(View.GONE);
            seeingB.setVisibility(View.GONE);
        }

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setView(view)
                .setCancelable(false)
                .create();
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        TextView bothBtn = view.findViewById(R.id.conflict_both);
        optionA.setOnClickListener(v -> {
            dialog.dismiss();
            resolveConflict(a, false);
        });
        optionB.setOnClickListener(v -> {
            dialog.dismiss();
            resolveConflict(b, false);
        });
        if (bothBtn != null) {
            bothBtn.setOnClickListener(v -> {
                dialog.dismiss();
                // conflictEventA is the candidate (the one we're trying to add); keep both by adding candidate without removing the other
                resolveConflict(a, true);
            });
        }
        cancelBtn.setOnClickListener(v -> {
            dialog.dismiss();
            finish();
        });
        dialog.show();
    }

    private void resolveConflict(EventData chosenEvent, boolean chooseBoth) {
        if (builder == null || chosenEvent == null) return;
        new Thread(() -> {
            currentBuildStep = builder.nextStep(chosenEvent, chooseBoth);
            runOnUiThread(this::handleBuildStep);
        }).start();
    }

    private void writeAndFinish(List<EventData> toMark) {
        pendingRestoreAttendanceOnCancel = false;
        if (toMark == null) toMark = new ArrayList<>();
        if (staticVariables.attendedHandler == null) {
            staticVariables.attendedHandler = new showsAttended();
        }
        showsAttended attendedHandle = staticVariables.attendedHandler;
        String yearStr = String.valueOf(eventYear);
        android.util.Log.d("AIWizard", "writeAndFinish toMark.size()=" + toMark.size());
        for (EventData event : toMark) {
            if (event.startTime == null || event.startTime.isEmpty()) {
                android.util.Log.d("AIWizard", "WRITE_SKIP (no startTime) band=" + event.bandName + " location=" + event.location);
                continue;
            }
            String et = event.eventType != null ? event.eventType : staticVariables.show;
            if (staticVariables.unofficalEventOld.equals(et)) et = staticVariables.unofficalEvent;
            String index = event.bandName + ":" + event.location + ":" + event.startTime + ":" + et + ":" + yearStr;
            android.util.Log.d("AIWizard", "WRITE index=" + index);
            attendedHandle.addShowsAttendedWithStatus(event.bandName, event.location, event.startTime, et, yearStr,
                    staticVariables.sawAllStatus, event.day, events);
        }
        AIScheduleStorage.clearBackup(eventYear);
        AIScheduleStorage.setHasRunAI(eventYear, true);
        // Count how many will-attend entries we actually have for this year (may be < toMark.size() due to overlap clearing)
        int actualCount = 0;
        String sawAll = staticVariables.sawAllStatus;
        String sawSome = staticVariables.sawSomeStatus;
        Map<String, String> afterWrite = attendedHandle.getShowsAttended();
        for (Map.Entry<String, String> e : afterWrite.entrySet()) {
            if (e.getKey() != null && showsAttended.attendanceIndexMatchesYear(e.getKey(), yearStr) && e.getValue() != null) {
                String status = e.getValue().contains(":") ? e.getValue().split(":")[0] : e.getValue();
                if (sawAll.equals(status) || sawSome.equals(status)) actualCount++;
            }
        }
        android.util.Log.d("AIWizard", "writeAndFinish after loop: toMark.size()=" + toMark.size() + " stored_count_for_year=" + actualCount + " map_size=" + afterWrite.size());
        Intent refresh = new Intent("RefreshLandscapeSchedule");
        LocalBroadcastManager.getInstance(this).sendBroadcast(refresh);
        // Turn on Show Flagged Events Only so the list shows the new schedule
        staticVariables.preferences.setShowWillAttend(true);
        String message = getString(R.string.aischedule_done_message, actualCount) + "\n\n" + getString(R.string.aischedule_done_message_detail);
        AlertDialog doneDialog = new AlertDialog.Builder(this)
                .setTitle(R.string.aischedule_done_title)
                .setMessage(message)
                .setPositiveButton(R.string.Ok, (dialog, which) -> {
                    setResult(RESULT_GO_TO_LIST);
                    finish();
                })
                .setCancelable(false)
                .create();
        doneDialog.show();
        AutoScheduleWizardManager.applyDarkDialogStyle(doneDialog, this);
    }

    @Override
    public void finish() {
        restoreWizardAttendanceIfPendingCancel();
        super.finish();
    }

    /**
     * If the user leaves after we cleared attendance for a rebuild, put back the pre-wizard snapshot.
     * Does not call {@link AIScheduleStorage#restore(showsAttended, int)} (that clears hasRunAI).
     */
    private void restoreWizardAttendanceIfPendingCancel() {
        if (!pendingRestoreAttendanceOnCancel) {
            return;
        }
        pendingRestoreAttendanceOnCancel = false;
        if (staticVariables.attendedHandler == null) {
            staticVariables.attendedHandler = new showsAttended();
        }
        Map<String, String> backup = AIScheduleStorage.loadBackup(eventYear);
        if (backup != null) {
            staticVariables.attendedHandler.restoreFromBackup(eventYear, backup);
        }
        AIScheduleStorage.clearBackup(eventYear);
    }

    @Override
    public void onBackPressed() {
        if (step == STEP_BUILDING) {
            finish();
            return;
        }
        super.onBackPressed();
    }

    private void goToPreviousStep() {
        if (step <= STEP_INTRO || step == STEP_BUILDING) return;
        int prev;
        if (step == STEP_UNKNOWN_BANDS) prev = STEP_INTRO;
        else if (step == STEP_LATEST_SHOW) prev = unknownBandNames.isEmpty() ? STEP_INTRO : STEP_UNKNOWN_BANDS;
        else if (step == STEP_UNOFFICIAL) prev = STEP_LATEST_SHOW;
        else if (step == STEP_MEET_GREET) prev = hasUnofficialOptions() ? STEP_UNOFFICIAL : STEP_LATEST_SHOW;
        else if (step == STEP_CLINICS) {
            if (hasMeetAndGreetOptions()) prev = STEP_MEET_GREET;
            else if (hasUnofficialOptions()) prev = STEP_UNOFFICIAL;
            else prev = STEP_LATEST_SHOW;
        }
        else if (step == STEP_SPECIAL_EVENTS) {
            if (hasClinicOptions()) prev = STEP_CLINICS;
            else if (hasMeetAndGreetOptions()) prev = STEP_MEET_GREET;
            else if (hasUnofficialOptions()) prev = STEP_UNOFFICIAL;
            else prev = STEP_LATEST_SHOW;
        }
        else prev = STEP_INTRO;
        showStep(prev);
    }
}
