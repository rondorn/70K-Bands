package com.Bands70k;

import android.os.Environment;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 8/19/15.
 */
public class scheduleInfo {

    public Map<String, scheduleTimeTracker> DownloadScheduleFile(String scheduleUrl){

        Log.d("bandUrlIs", scheduleUrl);
        try {
            URL u = new URL(scheduleUrl);
            InputStream is = u.openStream();

            DataInputStream dis = new DataInputStream(is);

            byte[] buffer = new byte[1024];
            int length;

            FileOutputStream fos = new FileOutputStream(new File(Environment.getExternalStorageDirectory() + "/70kScheduleInfo.csv"));
            while ((length = dis.read(buffer))>0) {
                fos.write(buffer, 0, length);
            }

        } catch (MalformedURLException mue) {
            Log.e("SYNC getUpdate", "malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("SYNC getUpdate", "io error", ioe);
        } catch (SecurityException se) {
            Log.e("SYNC getUpdate", "security error", se);

        } catch (Exception generalError){
            Log.e("General Exception", "Downloading bandData", generalError);
        }

        Map<String, scheduleTimeTracker> bandSchedule = ParseScheduleCSV();
        return bandSchedule;
    }

    public Map <String, scheduleTimeTracker> ParseScheduleCSV(){

        Map<String, scheduleTimeTracker> bandSchedule = new HashMap<>();

        try {
            File file = new File(Environment.getExternalStorageDirectory() + "/70kScheduleInfo.csv");

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            while ((line = br.readLine()) != null) {
                Log.d("RawScheduleLine", line);
                try {
                    String[] RowData = line.split(",");
                    if (!RowData[0].equals("Band")) {
                        scheduleHandler scheduleLine = new scheduleHandler();
                        scheduleLine.setBandName(RowData[0]);
                        scheduleLine.setShowLocation(RowData[1]);
                        scheduleLine.setShowDay(RowData[3]);
                        scheduleLine.setShowType(RowData[6]);
                        scheduleLine.setShowNotes(RowData[7]);
                        scheduleLine.setStartTimeString(RowData[4]);
                        scheduleLine.setEndTimeString(RowData[5]);
                        scheduleLine.setStartTime(RowData[2], RowData[4]);
                        scheduleLine.setEndTime(RowData[2], RowData[5]);

                        if (bandSchedule.get(RowData[0]) == null){
                            Log.d("AddingBandSched", "Adding:" + RowData[0] + ":" + scheduleLine.getEpochStart() + ":" + scheduleLine);
                            scheduleTimeTracker timeTrack = new scheduleTimeTracker();
                            timeTrack.addToscheduleByTime(scheduleLine.getEpochStart(), scheduleLine);
                            bandSchedule.put(RowData[0], timeTrack);
                        } else {
                            Log.d("AddingBandSched", "Appending:" + RowData[0]);
                            bandSchedule.get(RowData[0]).addToscheduleByTime(scheduleLine.getEpochStart(), scheduleLine);
                        }


                    }

                } catch (Exception error){
                    Log.d("AddingBandSched", "Error" + error.getStackTrace());
                    //just keep going
                }
            }

        } catch (Exception e) {
            Log.e("General Exception", "Parsing bandData", e);
        }


        Log.d("Output of bandData", bandSchedule.toString());

        return bandSchedule;
    }
}
