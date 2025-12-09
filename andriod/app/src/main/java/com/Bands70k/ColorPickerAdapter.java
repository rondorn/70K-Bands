package com.Bands70k;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

/**
 * Custom adapter for color picker with color sample dots
 */
public class ColorPickerAdapter extends ArrayAdapter<String> {
    private final Context context;
    private final String[] colorNames;
    private final int[] colorValues;
    
    public ColorPickerAdapter(Context context, String[] colorNames, int[] colorValues) {
        super(context, R.layout.color_picker_item, colorNames);
        this.context = context;
        this.colorNames = colorNames;
        this.colorValues = colorValues;
    }
    
    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;
        if (view == null) {
            LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            view = inflater.inflate(R.layout.color_picker_item, parent, false);
        }
        
        String colorName = colorNames[position];
        int colorValue = colorValues[position];
        
        // Set color name
        TextView nameView = view.findViewById(R.id.color_name_text);
        nameView.setText(colorName);
        
        // Set color sample dot
        View colorDot = view.findViewById(R.id.color_sample_dot);
        
        // Update the background color of the circle
        GradientDrawable drawable = (GradientDrawable) colorDot.getBackground();
        if (drawable != null) {
            drawable.setColor(colorValue);
        } else {
            // Fallback if drawable isn't loaded properly
            GradientDrawable circle = new GradientDrawable();
            circle.setShape(GradientDrawable.OVAL);
            circle.setColor(colorValue);
            colorDot.setBackground(circle);
        }
        
        return view;
    }
}

