package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.text.Layout;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.ListAdapter;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.ImageView;

import com.google.firebase.database.collection.LLRBNode;

import java.util.ArrayList;
import java.util.List;

import static java.lang.Thread.sleep;

public class bandListView extends ArrayAdapter<bandListItem> {

    protected LayoutInflater inflater;
    protected int layout;
    private List<bandListItem> bandInfoList = new ArrayList<bandListItem>();


    static class bandListHolder{
        ImageView rankImage;
        ImageView eventTypeImage;
        ImageView attendedImage;
        TextView bandName;
        TextView location;
        TextView locationColor;
        TextView day;
        TextView time;

    }

    public void setBandInfoList(List<bandListItem> bandInfoList){
        this.bandInfoList = bandInfoList;
    }

    public bandListView(Context context, int textViewResourceId) {
        super(context, textViewResourceId);
    }

    @Override
    public bandListItem getItem(int index) {
        return this.bandInfoList.get(index);
    }

    @Override
    public void add(bandListItem object) {
        bandInfoList.add(object);
        super.add(object);
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {

        View row = convertView;
        bandListHolder viewHolder;
        if (row == null) {
            LayoutInflater inflater = (LayoutInflater) this.getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            row = inflater.inflate(R.layout.bandlist70k, parent, false);
            viewHolder = new bandListHolder();
            viewHolder.rankImage = (ImageView) row.findViewById(R.id.rankingInCell);
            viewHolder.eventTypeImage = (ImageView) row.findViewById(R.id.eventTypeInCell);
            viewHolder.attendedImage = (ImageView) row.findViewById(R.id.attendedInCell);
            viewHolder.bandName = (TextView) row.findViewById(R.id.bandNameInCell);
            viewHolder.location = (TextView) row.findViewById(R.id.locationInCell);
            viewHolder.locationColor = (TextView) row.findViewById(R.id.locationColorInCell);
            viewHolder.day = (TextView) row.findViewById(R.id.dayInCell);
            viewHolder.time = (TextView) row.findViewById(R.id.timeInCell);
            row.setTag(viewHolder);
        } else {
            viewHolder = (bandListHolder)row.getTag();
        }

        bandListItem bandData = getItem(position);

        //Log.d("displayingList", "working on bandName " + bandData.getBandName() + " position " + String.valueOf(position));
        Log.d("displayingList", "working on bandName " + bandData.getBandName() + " color " + bandData.getLocationColor());

        viewHolder.rankImage.setImageResource(bandData.getRankImg());
        viewHolder.eventTypeImage.setImageResource(bandData.getEventTypeImage());
        viewHolder.attendedImage.setImageResource(bandData.getAttendedImage());
        viewHolder.bandName.setText(bandData.getBandName());
        viewHolder.location.setText(bandData.getLocation());

        String locationColorChoice = bandData.getLocationColor();

        if (locationColorChoice != null){
            viewHolder.locationColor.setBackgroundColor(Color.parseColor(locationColorChoice));

        } else {
            viewHolder.locationColor.setBackgroundColor(Color.parseColor(staticVariables.unknownVenueColor));
        }

        viewHolder.day.setText(bandData.getDay());
        viewHolder.time.setText(bandData.getStartTime());

        return row;

    }
}