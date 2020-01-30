package com.Bands70k;

import android.os.Environment;
import android.os.Looper;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * Created by rdorn on 8/19/15.
 */
public class scheduleInfo {

    public Map<String, scheduleTimeTracker> DownloadScheduleFile(String scheduleUrl){

        Log.d("ScheduleLine", "DownloadScheduleFile - 1");
        //Log.d("bandUrlIs", scheduleUrl);

        if (OnlineStatus.isOnline() == true && Looper.myLooper() != Looper.getMainLooper()) {
            try {
                Log.d("ScheduleLine", "DownloadScheduleFile - 2");
                URL u = new URL(scheduleUrl);
                InputStream is = u.openStream();

                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                FileOutputStream fos = new FileOutputStream(FileHandler70k.schedule);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }
                Log.d("ScheduleLine", "DownloadScheduleFile - 3");
            } catch (MalformedURLException mue) {
                Log.e("SYNC getUpdate", "DownloadScheduleFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("SYNC getUpdate", "DownloadScheduleFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("SYNC getUpdate", "DownloadScheduleFile security error", se);

            } catch (Exception generalError) {
                Log.e("General Exception", "DownloadScheduleFile Downloading bandData", generalError);
            }
        }

        Log.d("ScheduleLine", "DownloadScheduleFile - 4");
        Map<String, scheduleTimeTracker> bandSchedule = ParseScheduleCSV();
        Log.d("ScheduleLine", "DownloadScheduleFile - 5");
        return bandSchedule;
    }

    public Map <String, scheduleTimeTracker> ParseScheduleCSV(){

        Map<String, scheduleTimeTracker> bandSchedule = new HashMap<>();

        Log.d("ParseScheduleCSV", "ParseScheduleCSV - 1");
        try {
            File file = FileHandler70k.schedule;

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            boolean labelRow = true;
            Map<String, Integer> labelKeys = new HashMap<>();

            Log.d("ParseScheduleCSV", "ParseScheduleCSV - 2");
            while ((line = br.readLine()) != null) {
                Log.d("ScheduleLine", line);
                try {
                    Log.d("ParseScheduleCSV", "ParseScheduleCSV - 3");
                    String[] RowData = line.split(",");
                    if (labelRow == true){
                        Integer subCounter = 0;
                        for (String row : RowData){
                            labelKeys.put(row,subCounter);
                            subCounter = subCounter + 1;
                        }
                        labelRow = false;
                    } else {
                        scheduleHandler scheduleLine = new scheduleHandler();

                        String bandName = RowData[labelKeys.get(staticVariables.schedBandRow)];

                        if (labelKeys.containsKey(staticVariables.schedStartTimeRow)) {
                            staticVariables.schedulePresent = true;
                            scheduleLine.setBandName(RowData[labelKeys.get(staticVariables.schedBandRow)]);
                            scheduleLine.setShowLocation(RowData[labelKeys.get(staticVariables.schedLocationRow)]);
                            scheduleLine.setShowDay(RowData[labelKeys.get(staticVariables.schedDayRow)]);
                            scheduleLine.setShowType(RowData[labelKeys.get(staticVariables.schedTypeRow)]);

                            scheduleLine.setStartTimeString(RowData[labelKeys.get(staticVariables.schedStartTimeRow)]);
                            scheduleLine.setEndTimeString(RowData[labelKeys.get(staticVariables.schedEndTimeRow)]);

                            scheduleLine.setStartTime(RowData[labelKeys.get(staticVariables.schedDateRow)],
                                    RowData[labelKeys.get(staticVariables.schedStartTimeRow)]);
                            scheduleLine.setEndTime(RowData[labelKeys.get(staticVariables.schedDateRow)],
                                    RowData[labelKeys.get(staticVariables.schedEndTimeRow)]);
                        }

                        if (RowData.length > labelKeys.get(staticVariables.schedDescriptionURLRow)) {
                            if (RowData[labelKeys.get(staticVariables.schedDescriptionURLRow)].length() > 5) {
                                staticVariables.showNotesMap.put(bandName, RowData[labelKeys.get(staticVariables.schedDescriptionURLRow)]);
                            }
                        }

                        if (RowData.length > labelKeys.get(staticVariables.schedNotesRow)) {
                            Log.d("ScheduleLine2", staticVariables.schedNotesRow + " RowData.length = " + RowData.length);
                            scheduleLine.setShowNotes(RowData[labelKeys.get(staticVariables.schedNotesRow)]);
                        }

                        if (RowData.length > labelKeys.get(staticVariables.schedImageURLRow)) {
                            if (RowData[labelKeys.get(staticVariables.schedImageURLRow)].length() > 5) {
                                staticVariables.imageUrlMap.put(bandName, RowData[labelKeys.get(staticVariables.schedImageURLRow)]);
                            }
                        }

                        Log.d("ScheduleLine 1", scheduleLine.toString());
                        if (bandSchedule.get(bandName) == null){
                            Log.d("ScheduleLine2", "Adding:" +bandName + ":" + scheduleLine.getEpochStart() + ":" + scheduleLine);
                            scheduleTimeTracker timeTrack = new scheduleTimeTracker();
                            timeTrack.addToscheduleByTime(scheduleLine.getEpochStart(), scheduleLine);
                            bandSchedule.put(bandName, timeTrack);
                        } else {
                            //Log.d("ScheduleLine 3", "Appending:" + RowData[0]);
                            bandSchedule.get(bandName).addToscheduleByTime(scheduleLine.getEpochStart(), scheduleLine);
                        }


                    }

                } catch (Exception error) {
                    Log.d("ParseScheduleCSV", "ParseScheduleCSV - 5");
                    Log.d("ScheduleLine", "Error" + error.toString() + "-" + error.getMessage());
                    //just keep going
                }

            }

        } catch (Exception e) {
            Log.d("ParseScheduleCSV", "ParseScheduleCSV - 6");
            Log.e("ScheduleLine Exception", "Parsing bandData", e);

        }
        //Log.d("Output of bandData", bandSchedule.toString());

        Log.d("ParseScheduleCSV", "ParseScheduleCSV - 7");
        return bandSchedule;
    }

}
