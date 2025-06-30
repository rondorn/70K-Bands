package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.RelativeLayout;
import android.widget.TextView;

import java.util.List;

/**
 * Custom ArrayAdapter for displaying a list of strings with a custom layout.
 */
public class CustomArrayAdapter extends ArrayAdapter<String> {
    protected LayoutInflater inflater;
    protected int layout;

    /**
     * Constructs a CustomArrayAdapter.
     * @param activity The activity context.
     * @param resourceId The resource ID for the layout file.
     * @param objects The list of strings to display.
     */
    public CustomArrayAdapter(Activity activity, int resourceId, List<String> objects){
        super(activity, resourceId, objects);
        layout = resourceId;
        inflater = (LayoutInflater)activity.getSystemService(Context.LAYOUT_INFLATER_SERVICE);


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

        View v = inflater.inflate(layout, parent, false);

        return v;
    }
}