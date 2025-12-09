package com.Bands70k;

import android.content.Context;
import android.graphics.Color;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import java.util.List;

/**
 * Custom adapter for action menu items with special styling for delete option
 */
public class ActionMenuAdapter extends ArrayAdapter<String> {
    private final Context context;
    private final List<String> actions;
    private final boolean hasDeleteAction;
    
    public ActionMenuAdapter(Context context, List<String> actions, boolean hasDeleteAction) {
        super(context, R.layout.action_menu_item, actions);
        this.context = context;
        this.actions = actions;
        this.hasDeleteAction = hasDeleteAction;
    }
    
    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;
        if (view == null) {
            LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            view = inflater.inflate(R.layout.action_menu_item, parent, false);
        }
        
        String action = actions.get(position);
        TextView textView = view.findViewById(R.id.action_menu_text);
        textView.setText(action);
        
        // Style the delete action in red (iOS style)
        boolean isDeleteAction = hasDeleteAction && position == actions.size() - 1;
        if (isDeleteAction) {
            textView.setTextColor(Color.parseColor("#FF3B30")); // iOS red
        } else {
            textView.setTextColor(Color.WHITE);
        }
        
        return view;
    }
}

