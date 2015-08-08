package com.Bands70k;

import android.content.Context;
import android.graphics.Typeface;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.ArrayList;

/**
 * Created by rdorn on 8/6/15.
 */

class CustomArrayAdapter extends ArrayAdapter<String> {
    private final Context context;
    private final ArrayList<String> values;

    public CustomArrayAdapter(Context context, ArrayList<String> values) {
        super(context, R.layout.activity_show_bands, values);
        this.context = context;
        this.values = values;
    }


    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        LayoutInflater inflater = (LayoutInflater) context
                .getSystemService(Context.LAYOUT_INFLATER_SERVICE);

        View rowView = inflater.inflate(R.layout.activity_show_bands, parent, false);
        //TextView textView = (TextView) rowView.findViewById(R.id.bandNames);
        //ImageView imageView = (ImageView) rowView.findViewById(R.id.logo);

        // Customization to your textView here
        //textView.setTextColor(0);


        return rowView;
    }
}
