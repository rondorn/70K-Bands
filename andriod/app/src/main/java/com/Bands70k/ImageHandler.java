package com.Bands70k;

import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
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
        bandImageFile = new File(FileHandler70k.imageDirectory + bandName + ".png");
        this.moveOldToNew();
    }

    private void moveOldToNew() {
        if (oldImageFile.exists()){
            oldImageFile.renameTo(bandImageFile);
        }
    }

    public URI getImage(){

        URI localURL;
        this.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
        if (this.bandName.isEmpty() == true){
            Log.d("loadImageFile", "image file already exists band null, returning");
            return null;
        }

        Log.e("loadImageFile", "does image file exist " + bandImageFile.getAbsolutePath());
        /*
        if (bandImageFile.exists() == false) {

            AsyncImageLoader myImageTask = new AsyncImageLoader();
            myImageTask.execute(bandName);

            Log.e("loadImageFile", "image file already exists Downloading image file from URL" + BandInfo.getImageUrl(this.bandName));

            URI remoteURl = null;

            if (OnlineStatus.isOnline() == true) {
                Log.e("loadImageFile", "image file already , in online mmode");
                try {
                    remoteURl = URI.create(BandInfo.getImageUrl(this.bandName));
                } catch (Exception error) {
                    remoteURl = URI.create(staticVariables.logo70kUrl);
                }
            } else {
                Log.e("loadImageFile", "image file already , in offline mmode");
            }
            Log.e("loadImageFile", "image file already existsremoteUrl is :" + remoteURl);

            if (android.os.Build.VERSION.SDK_INT < Build.VERSION_CODES.M){
                String htmlImage = String.valueOf(remoteURl);
                htmlImage = htmlImage.replace("https", "http");
                remoteURl = URI.create(htmlImage);
            }

            return remoteURl;
        }
        */
        Log.d("loadImageFile", "image file already exists from " + bandImageFile.getAbsolutePath());
        localURL = bandImageFile.toURI();
        Log.d("loadImageFile", "Local URL is  " + localURL.toString());

        if (bandImageFile.exists() == false) {
            localURL = URI.create("./");
        }
        return localURL;
    }

    public void getRemoteImage(){
        Log.e("ImageFile", "debug 1 " + bandName);
        String imageUrl = BandInfo.getImageUrl(bandName);
        Log.e("ImageFile", "debug 2");
        bandImageFile = new File( FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
        Log.e("ImageFile", "debug 3" + OnlineStatus.isOnline());
        if (OnlineStatus.isOnline() == true) {
            try {
                Log.d("ImageFile", "Trying to write to 1" + imageUrl);
                URL url = new URL(imageUrl);
                Log.d("ImageFile", "Trying to write to 2" + bandImageFile.getAbsoluteFile());
                InputStream in = new BufferedInputStream(url.openStream());
                Log.d("ImageFile", "Trying to write to 3" + bandImageFile.getAbsoluteFile());
                OutputStream out = new BufferedOutputStream(new FileOutputStream(bandImageFile.getAbsoluteFile()));
                Log.d("ImageFile", "Trying to write to 4" + bandImageFile.getAbsoluteFile());
                for (int i; (i = in.read()) != -1; ) {
                    out.write(i);
                }
                Log.d("ImageFile", "Trying to write to 4" + bandImageFile.getAbsoluteFile());
                in.close();
                out.close();
                Log.d("ImageFile", "Trying to write to 4" + bandImageFile.getAbsoluteFile());
            } catch (Exception error) {
                Log.e("ImageFile", "Unable to get band Image file " + error.getMessage());
            }
        }
    }

    public void getAllRemoteImages(){

        BandInfo bandInfo = new BandInfo();
        ArrayList<String> bandList = bandInfo.getBandNames();

        for (String bandNameTmp : staticVariables.imageUrlMap.keySet()){
            this.bandName = bandNameTmp;

            bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
            Log.d("ImageFile", "does band Imagefile exist " + bandImageFile.getAbsolutePath());
            if (bandImageFile.exists() == false) {
                Log.d("ImageFile", "does band Imagefile exist, NO " + bandImageFile.getAbsolutePath());
                this.getRemoteImage();
            }
        }

        for (String bandNameTmp : bandList){
            this.bandName = bandNameTmp;
            bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
            Log.d("ImageFile", "does band Imagefile exist " + bandImageFile.getAbsolutePath());
            if (bandImageFile.exists() == false) {
                Log.d("ImageFile", "does band Imagefile exist, NO " + bandImageFile.getAbsolutePath());
                this.getRemoteImage();
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


