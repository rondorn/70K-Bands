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
        TextView bandName;
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

    /*
    public bandListView(Activity activity, int resourceId, List<String> objects){
        super(activity, resourceId, objects);
        layout = resourceId;
        inflater = (LayoutInflater)activity.getSystemService(Context.LAYOUT_INFLATER_SERVICE);


    }
    */

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {

        View row = convertView;
        bandListHolder viewHolder;
        if (row == null) {
            LayoutInflater inflater = (LayoutInflater) this.getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            row = inflater.inflate(R.layout.bandlist70k, parent, false);
            viewHolder = new bandListHolder();
            viewHolder.rankImage = (ImageView) row.findViewById(R.id.rankingInCell);
            viewHolder.bandName = (TextView) row.findViewById(R.id.bandNameInCell);
            row.setTag(viewHolder);
        } else {
            viewHolder = (bandListHolder)row.getTag();
        }

        bandListItem bandData = getItem(position);

        Log.d("displayingList", "working on bandName " + bandData.getBandName() + " position " + String.valueOf(position));

        viewHolder.rankImage.setImageResource(bandData.getRankImg());
        viewHolder.bandName.setText(bandData.getBandName());

        return row;

    }
}