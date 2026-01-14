package com.Bands70k;


import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Build;
import android.text.SpannableString;
import android.text.style.BackgroundColorSpan;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

import static com.Bands70k.staticVariables.context;

/**
 * Custom ArrayAdapter for displaying a list of bands with detailed views and custom logic.
 */
public class bandListView extends ArrayAdapter<bandListItem> {

    final List<bandListItem> bandInfoList = new ArrayList<>();
    public static String previousBandName = "";
    public static String scrollingDirection = "Down";

    public static Integer previousPosition = 1;

    /**
     * ViewHolder pattern for band list item views.
     */
    static class bandListHolder{
        ImageView rankImage;
        ImageView eventTypeImage;
        ImageView attendedImage;
        ImageView rankImageNoSchedule;
        ImageView rankingIconInDayArea;

        TextView bandName;
        TextView location;
        TextView locationColor;
        TextView day;
        TextView startTime;
        TextView endTime;
        TextView dayLabel;
        TextView bandNameNoSchedule;

        TextView bottomSpacer;
    }

    /**
     * Constructor for bandListView.
     * @param context The context.
     * @param textViewResourceId The resource ID for the layout file.
     */
    public bandListView(Context context, int textViewResourceId) {
        super(context, textViewResourceId);
    }

    /**
     * Gets the bandListItem at the specified index.
     * @param index The index of the item.
     * @return The bandListItem at the given index.
     */
    @Override
    public bandListItem getItem(int index) {
        return this.bandInfoList.get(index);
    }

    /**
     * Adds a bandListItem to the adapter and internal list.
     * @param object The bandListItem to add.
     */
    @Override
    public void add(bandListItem object) {
        bandInfoList.add(object);
        super.add(object);
    }
    
    /**
     * Clears all items from the adapter.
     * Used for refreshing data without creating a new adapter instance.
     */
    public void clearAll() {
        bandInfoList.clear();
        super.clear();
    }

    /**
     * Returns the view for a specific position in the list.
     * @param position The position of the item.
     * @param convertView The old view to reuse, if possible.
     * @param parent The parent view group.
     * @return The view corresponding to the data at the specified position.
     */
    @Override
    public View getView(int position, View convertView, ViewGroup parent) {

        String nextBand = "Unknown";

        if (position == 0 && previousPosition == 1) {
            previousBandName = "Unknown";
        }

        if (position > previousPosition){
            scrollingDirection = "Down";
        } else {
            scrollingDirection = "Up";

        }

        View row = convertView;
        bandListHolder viewHolder;
        if (row == null) {
            LayoutInflater inflater = (LayoutInflater) this.getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            row = inflater.inflate(R.layout.bandlist70k, parent, false);
            viewHolder = new bandListHolder();
            viewHolder.rankImage = row.findViewById(R.id.rankingInCell);
            viewHolder.eventTypeImage = row.findViewById(R.id.eventTypeInCell);
            viewHolder.attendedImage = row.findViewById(R.id.attendedInCell);
            viewHolder.bandName = row.findViewById(R.id.bandNameInCell);
            viewHolder.location = row.findViewById(R.id.locationInCell);
            viewHolder.locationColor = row.findViewById(R.id.locationColorInCell);
            viewHolder.day = row.findViewById(R.id.dayInCell);
            viewHolder.startTime = row.findViewById(R.id.startTimeInCell);
            viewHolder.endTime = row.findViewById(R.id.endTimeInCell);
            viewHolder.dayLabel =  row.findViewById(R.id.dayLabelInCell);

            viewHolder.bottomSpacer =  row.findViewById(R.id.bottomSpacer);
            viewHolder.rankImageNoSchedule = row.findViewById(R.id.rankingInCellnoSchedule);
            viewHolder.bandNameNoSchedule =  row.findViewById(R.id.bandNameInCellNoSchedule);
            viewHolder.rankingIconInDayArea = row.findViewById(R.id.rankingIconInDayArea);
            row.setTag(viewHolder);
        } else {
            viewHolder = (bandListHolder)row.getTag();
        }

        bandListItem bandData = getItem(position);
        String currentBandName = bandData.getBandName();

        // PERFORMANCE FIX: Reduce logging in getView() - only log in debug builds or remove entirely
        // Logging in getView() is called for every visible item during scrolling, causing performance issues
        // Uncomment below only for debugging specific issues
        // Log.d("displayingList", "Working on position " + String.valueOf(position) + " previousPosition " + String.valueOf(previousPosition) + " " + currentBandName + " Scrolling is " + scrollingDirection);
        // Log.d("displayingList", "working on bandName " + currentBandName + " color " + bandData.getLocationColor());

        if (bandData.getLocation() == null){

            viewHolder.eventTypeImage.setVisibility(View.INVISIBLE);
            viewHolder.attendedImage.setVisibility(View.INVISIBLE);
            viewHolder.location.setVisibility(View.INVISIBLE);
            // PERFORMANCE FIX: Remove duplicate setVisibility call
            // viewHolder.location.setVisibility(View.INVISIBLE); // Duplicate removed
            viewHolder.locationColor.setVisibility(View.INVISIBLE);
            viewHolder.day.setVisibility(View.INVISIBLE);
            viewHolder.startTime.setVisibility(View.INVISIBLE);
            viewHolder.endTime.setVisibility(View.INVISIBLE);
            viewHolder.dayLabel.setVisibility(View.INVISIBLE);

            viewHolder.rankImage.setVisibility(View.INVISIBLE);
            viewHolder.bandName.setVisibility(View.INVISIBLE);

            viewHolder.rankImageNoSchedule.setVisibility(View.INVISIBLE);
            viewHolder.bandNameNoSchedule.setVisibility(View.VISIBLE);

            // Show ranking icon in day area for bands-only view
            viewHolder.rankingIconInDayArea.setVisibility(View.VISIBLE);
            viewHolder.rankingIconInDayArea.setImageResource(bandData.getRankImg());

            viewHolder.bandNameNoSchedule.setText(currentBandName);

            viewHolder.bottomSpacer.setVisibility(View.INVISIBLE);

            if (android.os.Build.VERSION.SDK_INT < Build.VERSION_CODES.O){
                viewHolder.bandNameNoSchedule.setTextSize(25);
            }

        } else {

            viewHolder.eventTypeImage.setVisibility(View.VISIBLE);
            viewHolder.attendedImage.setVisibility(View.VISIBLE);
            viewHolder.location.setVisibility(View.VISIBLE);
            // PERFORMANCE FIX: Remove duplicate setVisibility call
            // viewHolder.location.setVisibility(View.VISIBLE); // Duplicate removed
            viewHolder.locationColor.setVisibility(View.VISIBLE);
            viewHolder.day.setVisibility(View.VISIBLE);
            viewHolder.startTime.setVisibility(View.VISIBLE);
            viewHolder.endTime.setVisibility(View.VISIBLE);
            viewHolder.dayLabel.setVisibility(View.VISIBLE);
            viewHolder.bottomSpacer.setVisibility(View.VISIBLE);
            viewHolder.rankImage.setVisibility(View.VISIBLE);
            viewHolder.bandName.setVisibility(View.VISIBLE);

            viewHolder.rankImageNoSchedule.setVisibility(View.INVISIBLE);
            viewHolder.bandNameNoSchedule.setVisibility(View.INVISIBLE);
            
            // Hide ranking icon in day area for schedule view
            viewHolder.rankingIconInDayArea.setVisibility(View.INVISIBLE);

            if (bandData.getRankImg() == 0){
                viewHolder.rankImage.setVisibility(View.INVISIBLE);
            } else {
                // PERFORMANCE FIX: Reduce logging in getView()
                // Log.d("bandListView", "ranking image is " + bandData.getRankImg());
                if (bandData.getRankImg() != 50000000) {
                    viewHolder.rankImage.setImageResource(bandData.getRankImg());
                } else {
                    viewHolder.rankImage.setImageResource(0);
                }

                viewHolder.rankImage.setVisibility(View.VISIBLE);
            }

            if (bandData.getEventTypeImage() == 0){
                viewHolder.eventTypeImage.setVisibility(View.INVISIBLE);
            } else {
                viewHolder.eventTypeImage.setImageResource(bandData.getEventTypeImage());
                viewHolder.eventTypeImage.setVisibility(View.VISIBLE);
            }

            if (bandData.getAttendedImage() == 0){
                viewHolder.attendedImage.setVisibility(View.INVISIBLE);
            } else {
                viewHolder.attendedImage.setImageResource(bandData.getAttendedImage());
                viewHolder.attendedImage.setVisibility(View.VISIBLE);
            }

            viewHolder.location.setText(bandData.getLocation());

            String locationColorChoice = bandData.getLocationColor();

            if (locationColorChoice != null){
                viewHolder.locationColor.setBackgroundColor(Color.parseColor(locationColorChoice));

            } else {
                // Use the dynamic venue color system for unknown venues too
                String fallbackColor = staticVariables.getVenueColor("Unknown");
                viewHolder.locationColor.setBackgroundColor(Color.parseColor(fallbackColor));
            }

            viewHolder.bandName.setText(currentBandName);
            viewHolder.day.setText(bandData.getDay());
            viewHolder.startTime.setText(bandData.getStartTime());
            viewHolder.endTime.setText(bandData.getEndTime());
            if (android.os.Build.VERSION.SDK_INT < Build.VERSION_CODES.O){
                viewHolder.bandName.setTextSize(23);
            }

            // PERFORMANCE FIX: Optimize previous item access - check bounds before accessing
            if (position > 0) {
                try {
                    bandListItem bandDataNext = getItem(position - 1);
                    nextBand = bandDataNext.getBandName();
                } catch (Exception error){
                    nextBand = "Unknown";
                }
            }

            if (previousBandName.equals(currentBandName) == true  && scrollingDirection == "Down" && position != 0){
                // PERFORMANCE FIX: Reduce logging in getView()
                // Log.d("bandListViewSortName", "1 partial current band is " + currentBandName + " = " + previousBandName + " position is " + String.valueOf(position) + " direction is " + scrollingDirection);
                getCellScheduleValuePartialInfo(viewHolder, bandData, locationColorChoice);

            } else if (scrollingDirection == "Down") {

                // PERFORMANCE FIX: Reduce logging in getView()
                // Log.d("bandListViewSortName", "2 full current band is " + currentBandName + " = " + previousBandName + " position is " + String.valueOf(position) + " direction is " + scrollingDirection);
                getCellScheduleValueFullInfo(viewHolder, bandData);

            } else if (nextBand.equals(currentBandName) == false  || position == 0) {
                // PERFORMANCE FIX: Reduce logging in getView()
                // Log.d("bandListViewSortName", "3 full current band is " + currentBandName + " = " + nextBand + " position is " + String.valueOf(position) + " direction is " + scrollingDirection);
                getCellScheduleValueFullInfo(viewHolder, bandData);

            } else {
                // PERFORMANCE FIX: Reduce logging in getView()
                // Log.d("bandListViewSortName", "4 partial current band is " + currentBandName + " = " + previousBandName + " position is " + String.valueOf(position) + " direction is " + scrollingDirection);
                getCellScheduleValuePartialInfo(viewHolder, bandData, locationColorChoice);
            }

        }

        previousBandName = currentBandName;
        previousPosition = position;

        if (getScreenWidth(context) <= 480){
            viewHolder.day.setWidth(35);
            viewHolder.dayLabel.setWidth(35);

        }

        return row;
    }

    /**
     * Sets partial schedule value info for a cell.
     * @param viewHolder The view holder for the cell.
     * @param bandData The band data for the cell.
     * @param locationColorChoice The color for the location.
     */
    private void getCellScheduleValuePartialInfo(bandListHolder viewHolder, bandListItem bandData, String locationColorChoice){
        String fullLocation = bandData.getLocation();
        String venueOnly = "";
        String locationOnly = "";

        for (String venue : staticVariables.venueLocation.keySet()){
            String findVenueString = venue + " " + staticVariables.venueLocation.get(venue);
            if (findVenueString.equals(fullLocation)){
                venueOnly = venue;
                locationOnly = staticVariables.venueLocation.get(venue);
            }
        }
        if (venueOnly.isEmpty()){
            venueOnly =  fullLocation;
            locationOnly = "";
        }

        if (bandData.getEventNote().isEmpty() == false){
            locationOnly = locationOnly + " " + bandData.getEventNote();
        }

        // Define the text to have a colored background
        String locationWithColor = " " + venueOnly;
        int startIndex = 0;
        int endIndex = 1;

        SpannableString spannableString = new SpannableString(locationWithColor);

        // Set the background color for the specific portion of text
        int backgroundColor = Color.parseColor(locationColorChoice); // Replace with your desired color
        BackgroundColorSpan backgroundColorSpan = new BackgroundColorSpan(backgroundColor);
        spannableString.setSpan(backgroundColorSpan, startIndex, endIndex, 0);

        viewHolder.bandName.setText(spannableString);
        viewHolder.bandName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        viewHolder.bandName.setTypeface(null, Typeface.NORMAL);
        viewHolder.bandName.setTextColor(Color.parseColor("#D3D3D3"));

        viewHolder.rankImage.setVisibility(View.INVISIBLE);

        viewHolder.location.setText(locationOnly);
    }

    /**
     * Sets full schedule value info for a cell.
     * @param viewHolder The view holder for the cell.
     * @param bandData The band data for the cell.
     */
    private void getCellScheduleValueFullInfo(bandListHolder viewHolder, bandListItem bandData){

        String eventNote = bandData.getEventNote();
        if (eventNote != null && eventNote.isBlank() == false){
            viewHolder.location.setText(bandData.getLocation() + " " + eventNote);
        }

        viewHolder.bandName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 23);
        viewHolder.bandName.setTypeface(null, Typeface.BOLD);
        viewHolder.bandName.setTextColor(Color.parseColor("#FFFFFF"));
    }

    /**
     * Gets the screen width in pixels for the given context.
     * @param context The context.
     * @return The screen width in pixels.
     */
    private static Integer getScreenWidth(Context context)
    {
        WindowManager wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();
        DisplayMetrics metrics = new DisplayMetrics();
        display.getMetrics(metrics);
        int width = metrics.widthPixels;

        // PERFORMANCE FIX: Reduce logging - screen width doesn't change frequently
        // Log.d("screenWidth", "Screen Width is " + width);
        return width;
    }
}