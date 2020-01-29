package com.Bands70k;

import android.os.AsyncTask;
import android.os.Environment;
import android.os.StrictMode;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.PriorityQueue;

/**
 * Created by rdorn on 10/5/17.
 */

public class ImageHandler {

    private String bandName;
    private File bandImageFile;
    private File oldImageFile;

    public ImageHandler(){

    }

    public ImageHandler(String bandNameValue){
        this.bandName = bandNameValue;
        oldImageFile = new File(Environment.getExternalStorageDirectory() + FileHandler70k.directoryName + bandName + ".png");
        bandImageFile = new File(Environment.getExternalStorageDirectory() + FileHandler70k.imageDirectory + bandName + ".png");
        this.moveOldToNew();
    }

    private void moveOldToNew() {
        if (oldImageFile.exists()){
            oldImageFile.renameTo(bandImageFile);
        }
    }

    public URI getImage(){

        URI localURL;

        if (this.bandName.isEmpty() == true){
            return null;
        }

        if (bandImageFile.exists() == false){

            AsyncImageLoader myImageTask = new AsyncImageLoader();
            myImageTask.execute(bandName);

            Log.e("loadImageFile", "Downloading image file from URL" + BandInfo.getImageUrl(this.bandName));

            URI remoteURl = null;

            if (OnlineStatus.isOnline() == true) {
                try {
                    remoteURl = URI.create(BandInfo.getImageUrl(this.bandName));
                } catch (Exception error) {
                    remoteURl = URI.create(staticVariables.logo70kUrl);
                }
            }
            return remoteURl;
        }

        Log.e("loadImageFile", "image file already exists from " + bandImageFile.getAbsolutePath());
        localURL = bandImageFile.toURI();

        return localURL;
    }

    public void getRemoteImage(){

        String imageUrl = BandInfo.getImageUrl(bandName);

        if (OnlineStatus.isOnline() == true) {
            try {
                URL url = new URL(imageUrl);
                InputStream in = new BufferedInputStream(url.openStream());
                OutputStream out = new BufferedOutputStream(new FileOutputStream(bandImageFile.getAbsoluteFile()));

                for (int i; (i = in.read()) != -1; ) {
                    out.write(i);
                }

                in.close();
                out.close();

            } catch (Exception error) {
                Log.e("writingImageFile", "Unable to get band Image file " + error.getMessage());
            }
        }
    }

    public void getAllRemoteImages(){

        BandInfo bandInfo = new BandInfo();
        ArrayList<String> bandList = bandInfo.getBandNames();

        for (String bandName : bandList){
            bandImageFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".png");
            if (bandImageFile.exists() == false) {
                Log.e("loadImageFile", "loading all images files in background " + bandImageFile.getAbsolutePath());
                ImageHandler imageHandler = new ImageHandler(bandName);
                imageHandler.getRemoteImage();
            }
        }
    }
}

class AsyncImageLoader extends AsyncTask<String, Void, ArrayList<String>> {

    @Override
    protected ArrayList<String> doInBackground(String... params) {


        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        Log.d("AsyncTask_ImageFile", "Downloading Image data for " + params[0]);

        try {
            ImageHandler imageHandler = new ImageHandler(params[0]);
            imageHandler.getRemoteImage();

        } catch (Exception error){
            Log.d("bandInfo", error.getMessage());
        }

        return null;
    }
}


