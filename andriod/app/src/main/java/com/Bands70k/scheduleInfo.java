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

        if ((OnlineStatus.isOnline() == true && Looper.myLooper() != Looper.getMainLooper())
                ||  staticVariables.inUnitTests == true
                || FileHandler70k.schedule.exists() == false) {
                
            // CRITICAL FIX: Validate URL before attempting download
            if (scheduleUrl == null || scheduleUrl.trim().isEmpty()) {
                Log.e("ScheduleLine", "Schedule URL is null or empty, cannot download schedule data");
                return new HashMap<String, scheduleTimeTracker>(); // Return empty map
            }
                
            CacheHashManager cacheManager = CacheHashManager.getInstance();
            // Create temp file for hash comparison
            File tempSchedule = new File(showBands.newRootDir + FileHandler70k.directoryName + "70kScheduleInfo.csv.temp");
            boolean downloadSuccessful = false;
            
            try {
                Log.d("ScheduleLine", "DownloadScheduleFile - 2 URL=" + scheduleUrl);
                URL u = new URL(scheduleUrl);
                java.net.HttpURLConnection connection = (java.net.HttpURLConnection) u.openConnection();
                connection.setInstanceFollowRedirects(true);
                HttpConnectionHelper.applyTimeouts(connection);
                InputStream is = connection.getInputStream();

                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                // Download to temp file first
                FileOutputStream fos = new FileOutputStream(tempSchedule);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }
                fos.close();
                dis.close();
                is.close();
                try { connection.disconnect(); } catch (Exception ignored) {}
                
                downloadSuccessful = true;
                Log.d("ScheduleLine", "DownloadScheduleFile - 3 - Downloaded to temp file");
                
            } catch (MalformedURLException mue) {
                Log.e("SYNC getUpdate", "DownloadScheduleFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("SYNC getUpdate", "DownloadScheduleFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("SYNC getUpdate", "DownloadScheduleFile security error", se);
            } catch (Exception generalError) {
                Log.e("General Exception", "DownloadScheduleFile Downloading bandData", generalError);
            }
            
            // Process temp file only if download was successful and content changed
            if (downloadSuccessful) {
                boolean dataChanged = cacheManager.processIfChanged(tempSchedule, FileHandler70k.schedule, "scheduleInfo");
                if (dataChanged) {
                    Log.i("ScheduleInfo", "Schedule data has changed, processed new file");
                } else {
                    Log.i("ScheduleInfo", "Schedule data unchanged, using cached version");
                }
            } else {
                // Clean up temp file on download failure
                if (tempSchedule.exists()) {
                    tempSchedule.delete();
                }
            }
        }

        Log.d("ScheduleLine", "DownloadScheduleFile - 4");
        Map<String, scheduleTimeTracker> bandSchedule = ParseScheduleCSV();
        Log.d("ScheduleLine", "DownloadScheduleFile - 5");
        Log.d("FILTER_DEBUG", "🔍 SCHEDULE DATA LOADING: DownloadScheduleFile returning " + bandSchedule.size() + " schedule records");
        return bandSchedule;
    }

    public Map <String, scheduleTimeTracker> ParseScheduleCSV(){

        Map<String, scheduleTimeTracker> bandSchedule = new HashMap<>();

        Log.d("ParseScheduleCSV", "ParseScheduleCSV - 1");
        Log.d("FILTER_DEBUG", "🔍 SCHEDULE PARSING: Starting to parse schedule CSV");
        try {
            File file = FileHandler70k.schedule;
            Log.d("FILTER_DEBUG", "🔍 SCHEDULE FILE: file exists=" + file.exists() + ", path=" + file.getAbsolutePath() + ", length=" + file.length());

            if (!file.exists()) {
                Log.d("FILTER_DEBUG", "🔍 SCHEDULE FILE: File does not exist, returning empty schedule");
                return bandSchedule;
            }

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            boolean labelRow = true;
            Map<String, Integer> labelKeys = new HashMap<>();
            int lineCount = 0;

            Log.d("ParseScheduleCSV", "ParseScheduleCSV - 2");
            while ((line = br.readLine()) != null) {
                lineCount++;
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
                            scheduleLine.setShowNotes(RowData[labelKeys.get(staticVariables.schedNotesRow)]);
                        }

                        if (RowData.length > labelKeys.get(staticVariables.schedImageURLRow)) {
                            if (RowData[labelKeys.get(staticVariables.schedImageURLRow)].length() > 5) {
                                staticVariables.imageUrlMap.put(bandName, RowData[labelKeys.get(staticVariables.schedImageURLRow)]);
                                
                                // Parse and store ImageDate if available (for cache invalidation)
                                if (labelKeys.containsKey(staticVariables.schedImageDateRow) && 
                                    RowData.length > labelKeys.get(staticVariables.schedImageDateRow)) {
                                    String imageDate = RowData[labelKeys.get(staticVariables.schedImageDateRow)];
                                    if (imageDate != null && !imageDate.trim().isEmpty()) {
                                        staticVariables.imageDateMap.put(bandName, imageDate.trim());
                                        Log.d("ScheduleImageDate", "Parsed ImageDate '" + imageDate.trim() + "' for band '" + bandName + "'");
                                    }
                                }
                            }
                        }

                        if (bandSchedule.get(bandName) == null){
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
            try { br.close(); } catch (Exception ignored) {}

        } catch (Exception e) {
            Log.d("ParseScheduleCSV", "ParseScheduleCSV - 6");
            Log.e("ScheduleLine Exception", "Parsing bandData", e);

        }
        //Log.d("Output of bandData", bandSchedule.toString());

        Log.d("ParseScheduleCSV", "ParseScheduleCSV - 7");
        Log.d("ScheduleInfo", "Parsed schedule CSV: " + bandSchedule.size() + " bands");
        return bandSchedule;
    }

}
