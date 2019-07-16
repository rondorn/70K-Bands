package com.Bands70k;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

/*
public class bandViewRow extends ArrayAdapter<bandCellView> {

    private static final String TAG = "FruitArrayAdapter";
    private List<bandCellView> fruitList = new ArrayList<bandCellView>();

    static class FruitViewHolder {
        ImageView fruitImg;
        TextView fruitName;
        TextView calories;
    }

    public bandViewRow(Context context, int textViewResourceId) {
        super(context, textViewResourceId);
    }

    @Override
    public void add(bandCellView object) {
        fruitList.add(object);
        super.add(object);
    }

    @Override
    public int getCount() {
        return this.fruitList.size();
    }

    @Override
    public bandCellView getItem(int index) {
        return this.fruitList.get(index);
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View row = convertView;
        FruitViewHolder viewHolder;
        if (row == null) {
            LayoutInflater inflater = (LayoutInflater) this.getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            row = inflater.inflate(R.layout.listview_row, parent, false);
            viewHolder = new FruitViewHolder();
            //viewHolder.fruitImg = (ImageView) row.findViewById(R.id);
            viewHolder.fruitName = (TextView) row.findViewById(R.id.fruitName);
            viewHolder.calories = (TextView) row.findViewById(R.id.calories);
            row.setTag(viewHolder);
        } else {
            viewHolder = (FruitViewHolder)row.getTag();
        }
        bandCellView fruit = getItem(position);
        viewHolder.fruitImg.setImageResource(R.drawable.beer_mug);
        viewHolder.fruitName.setText("test");
        viewHolder.calories.setText("Test");
        return row;
    }

    public Bitmap decodeToBitmap(byte[] decodedByte) {
        return BitmapFactory.decodeByteArray(decodedByte, 0, decodedByte.length);
    }
}
*/