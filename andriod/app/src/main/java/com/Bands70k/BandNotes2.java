package com.Bands70k;

import android.text.format.Time;
import android.util.Log;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 4/16/17.
 */

public class BandNotes2 {

    private String bandName;
    private File bandNoteFile;
    private File bandCustNoteFile;

    private boolean noteIsBlank = false;

    public BandNotes2(String bandValue){

        bandName = bandValue;
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

        return bandNote;

    }

    public String getBandNoteFromFile(){

        String note = "";

        Map<String, String> notesData = FileHandler70k.readObject(bandNoteFile);

        if (notesData.containsKey("customDescription")){
            notesData.get("customDescription");

        } else {
            note = notesData.get("defaultNote");

        }

        return note;
    }

    public void saveDefaultBandNote(String notesData){

        Log.d("saveNote", "attempting to write message " + notesData);

        if (notesData.startsWith("Comment text is not available yet") == false &&
                notesData.length() > 2) {

            notesData = notesData.replaceAll("\\n", "<br>");
            notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");

            Log.d("saveNote", "writing data to " + bandNoteFile + " - " + notesData);

            Time today = new Time(Time.getCurrentTimezone());
            today.setToNow();

            Map<String, String> bandNameDataHash = new HashMap<String,String>();
            bandNameDataHash.put("defaultNote", notesData);
            bandNameDataHash.put("dateModified", String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            bandNameDataHash.put("dateWritten", String.valueOf(today));

            FileHandler70k.writeObject(bandNameDataHash, bandNoteFile);

            Log.d("saveNote", "Data saved for " + bandNoteFile);
        } else {
            bandNoteFile.delete();
        }

    }

    public void saveCustomBandNote(String notesData){

        Log.d("saveNote", "attempting to write message " + notesData);

        Map<String, String> defaultNotesData = FileHandler70k.readObject(bandNoteFile);
        String defaultNote = defaultNotesData.get("defaultNote");
        String strippedDefaultNote = defaultNote.replaceAll("\\s", "");
        String strippedCustomNote = notesData.replaceAll("\\s", "");

        Log.d("saveNote", "comparing " + strippedDefaultNote + " to " + strippedCustomNote);

        if (notesData.startsWith("Comment text is not available yet") == false &&
                notesData.length() > 2 && strippedDefaultNote != strippedCustomNote) {

            notesData = notesData.replaceAll("\\n", "<br>");
            notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");

            Log.d("saveNote", "writing data to " + bandNoteFile + " - " + notesData);

            Time today = new Time(Time.getCurrentTimezone());
            today.setToNow();

            Map<String, String> bandNameDataHash = new HashMap<String,String>();
            bandNameDataHash.put("defaultNote", "");
            bandNameDataHash.put("dateModified", String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            bandNameDataHash.put("dateWritten", String.valueOf(today));
            bandNameDataHash.put("customDescription", "notesData");

            FileHandler70k.writeObject(bandNameDataHash, bandNoteFile);
            FileHandler70k.writeObject(bandNameDataHash, bandCustNoteFile);

            Log.d("saveNote", "Data saved for " + bandNoteFile);

        } else {
            bandNoteFile.delete();
            bandCustNoteFile.delete();
        }

    }
}
