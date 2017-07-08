package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import java.util.List;

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
        //TextView tv = (TextView)v.findViewById(R.id.refresh);
        //tv.setText(getItem(position));
        return v;
    }
}