package com.Bands70k;

import android.graphics.Color;
import android.os.SystemClock;
import android.text.format.Time;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 4/16/17.
 */

public class BandNotes {

    private String bandName;
    private File bandNoteFile;
    private File oldBandNoteFile;
    private File bandCustNoteFile;

    private boolean noteIsBlank = false;

    public BandNotes(String bandValue){

        bandName = bandValue;
        oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        bandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
        bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
    }

    public boolean fileExists(){
        return bandNoteFile.exists();
    }

    public boolean getNoteIsBlank(){
        return noteIsBlank;
    }

    public String getBandNote(){
        CustomerDescriptionHandler noteHandler = new CustomerDescriptionHandler();
        String bandNote = noteHandler.getDescription(bandName);

        if (bandNote.contains("!!!!https://")){
            bandNote = bandNote.replaceAll("!!!!https://([^\\s]+)", "<a  target='_blank' style='color: lightblue' href=https://$1>$1</a>");
        }

        return bandNote;

    }

    public void convertOldBandNote() {

        String oldNoteText = "";
        try {
            BufferedReader br = new BufferedReader(new FileReader(oldBandNoteFile));

            String line;
            while ((line = br.readLine()) != null) {
                oldNoteText += line + "<br>";
            }
        } catch (Exception error) {

        }

        oldBandNoteFile.delete();

        CustomerDescriptionHandler noteHandler = new CustomerDescriptionHandler();
        noteHandler.loadNoteFromURL(bandName);
        Map<String, String> notesData = FileHandler70k.readObject(bandNoteFile);
        String newBandNote = notesData.get("defaultNote");

        String newBandNoteStripped = this.stripDataForCompare(newBandNote);
        String oldBandNoteStripped = this.stripDataForCompare(oldNoteText);

        if (newBandNoteStripped.equals(oldBandNoteStripped) == false){
            saveCustomBandNote(oldNoteText);
        } else {
            saveDefaultBandNote(newBandNote);
        }

    }

    private String stripDataForCompare(String dataString){

        String strippedDataString = "";
        if (dataString != null) {
            strippedDataString = dataString.replaceAll("\\s", "");
            strippedDataString = strippedDataString.replaceAll("<br>", "");
            strippedDataString = strippedDataString.replaceAll("\n", "");
        }
        return strippedDataString;
    }

    public String getBandNoteFromFile(){

        String note = "";

        if (oldBandNoteFile.exists() == true){
            convertOldBandNote();
        }

        Map<String, String> notesData = FileHandler70k.readObject(bandNoteFile);

        Log.d("getDescription","Loading note from file, notesData is  " + notesData);
        if (notesData.containsKey("customDescription")){
            note = notesData.get("customDescription");

        } else {
            note = notesData.get("defaultNote");

        }

        return note;
    }

    public void saveDefaultBandNote(String notesData){

        Log.d("saveNote", "attempting to write message " + notesData);

        if (notesData.startsWith("Comment text is not available yet") == false &&
                notesData.length() > 2 && bandCustNoteFile.exists() == false) {

            notesData = notesData.replaceAll("\\n", "<br>");
            notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");

            Log.d("saveNote", "writing data to " + bandNoteFile + " - " + notesData);

            Time today = new Time(Time.getCurrentTimezone());
            today.setToNow();
            String dateModified = String.valueOf(staticVariables.descriptionMapModData.get(bandName));
            Map<String, String> bandNameDataHash = new HashMap<String, String>();
            bandNameDataHash.put("defaultNote", notesData);
            bandNameDataHash.put("dateModified", dateModified);
            bandNameDataHash.put("dateWritten", String.valueOf(today));

            FileHandler70k.writeObject(bandNameDataHash, bandNoteFile);

            File bandNoteDateFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + "-" + dateModified);
            FileHandler70k.saveData(dateModified, bandNoteDateFile);
            Log.d("saveNote", "Data saved for " + bandNoteFile);
        } else {
            bandNoteFile.delete();
        }

    }

    public void saveCustomBandNote(String notesData){

        Log.d("saveNote", "attempting to write message " + notesData);

        Map<String, String> defaultNotesData = FileHandler70k.readObject(bandNoteFile);
        String defaultNote = defaultNotesData.get("defaultNote");
        if (defaultNote == ""){
            SystemClock.sleep(1000);
            defaultNotesData = FileHandler70k.readObject(bandNoteFile);
            defaultNote = defaultNotesData.get("defaultNote");
        }

        String strippedDefaultNote = this.stripDataForCompare(defaultNote);
        String strippedCustomNote = this.stripDataForCompare(notesData);

        Log.d("saveNote", "comparing " + strippedDefaultNote + " to " + strippedCustomNote);

        if (notesData.startsWith("Comment text is not available yet") == false &&
                notesData.length() > 2 && strippedDefaultNote.equals(strippedCustomNote) == false) {

            notesData = notesData.replaceAll("\\n", "<br>");
            notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");

            Log.d("saveNote", "writing data to " + bandNoteFile + " - " + notesData);

            Time today = new Time(Time.getCurrentTimezone());
            today.setToNow();

            Map<String, String> bandNameDataHash = new HashMap<String, String>();
            bandNameDataHash.put("defaultNote", "");
            bandNameDataHash.put("dateModified", String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            bandNameDataHash.put("dateWritten", String.valueOf(today));
            bandNameDataHash.put("customDescription", notesData);

            FileHandler70k.writeObject(bandNameDataHash, bandNoteFile);
            FileHandler70k.writeObject(bandNameDataHash, bandCustNoteFile);

            Log.d("saveNote", "Data saved for " + bandNoteFile);

        } else {
            bandNoteFile.delete();
            bandCustNoteFile.delete();
        }
    }
}
