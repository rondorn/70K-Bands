package com.Bands70k;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import java.util.List;

/**
 * Custom adapter for displaying profiles with colored dots and checkmarks
 */
public class ProfileListAdapter extends ArrayAdapter<String> {
    private final Context context;
    private final List<String> profileKeys;
    private final List<String> displayNames;
    private final String activeProfileKey;
    
    public ProfileListAdapter(Context context, List<String> profileKeys, List<String> displayNames, String activeProfileKey) {
        super(context, R.layout.profile_list_item, displayNames);
        this.context = context;
        this.profileKeys = profileKeys;
        this.displayNames = displayNames;
        this.activeProfileKey = activeProfileKey;
    }
    
    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;
        if (view == null) {
            LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            view = inflater.inflate(R.layout.profile_list_item, parent, false);
        }
        
        String profileKey = profileKeys.get(position);
        String displayName = displayNames.get(position);
        boolean isActive = profileKey.equals(activeProfileKey);
        
        // Set profile name
        TextView nameView = view.findViewById(R.id.profile_name);
        nameView.setText(displayName);
        
        // Show/hide checkmark for active profile
        TextView checkmarkView = view.findViewById(R.id.profile_checkmark);
        checkmarkView.setVisibility(isActive ? View.VISIBLE : View.GONE);
        
        // Set color dot
        View colorDot = view.findViewById(R.id.profile_color_dot);
        int color = ProfileColorManager.getInstance().getColorInt(profileKey);
        
        // Update the background color of the circle
        GradientDrawable drawable = (GradientDrawable) colorDot.getBackground();
        if (drawable != null) {
            drawable.setColor(color);
        } else {
            // Fallback if drawable isn't loaded properly
            GradientDrawable circle = new GradientDrawable();
            circle.setShape(GradientDrawable.OVAL);
            circle.setColor(color);
            colorDot.setBackground(circle);
        }
        
        return view;
    }
}

