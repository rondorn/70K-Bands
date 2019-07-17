package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.text.Layout;
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

import java.util.List;

import static java.lang.Thread.sleep;

public class CustomArrayAdapter extends ArrayAdapter<String> {

    protected LayoutInflater inflater;
    protected int layout;

    public CustomArrayAdapter(Activity activity, int resourceId, List<String> objects){
        super(activity, resourceId, objects);
        layout = resourceId;
        inflater = (LayoutInflater)activity.getSystemService(Context.LAYOUT_INFLATER_SERVICE);


    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {

        View v = inflater.inflate(layout, parent, false);

        TextView bandNameCell = (TextView) v.findViewById(R.id.bandNameInCell);
        TextView locationInCell = (TextView) v.findViewById(R.id.locationInCell);
        TextView timeInCell = (TextView) v.findViewById(R.id.timeInCell);

        TextView dayLableInCell = (TextView) v.findViewById(R.id.dayLabelInCell);
        TextView dayInCell = (TextView) v.findViewById(R.id.dayInCell);

        ImageView rankInCell = (ImageView) v.findViewById(R.id.rankingInCell);
        ImageView eventTypeInCell = (ImageView) v.findViewById(R.id.eventTypeInCell);
        ImageView attednedInCell = (ImageView) v.findViewById(R.id.attendedInCell);

        bandNameCell.setText("Amon Amarth");
        locationInCell.setText("Theater Deck 3/4");
        timeInCell.setText("10:00 pm");
        dayInCell.setText("1");
        
        eventTypeInCell.setImageResource(R.drawable.icon_all_star_jam);

        return v;
    }
}