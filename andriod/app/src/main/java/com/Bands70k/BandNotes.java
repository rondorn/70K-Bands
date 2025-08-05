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
 * Handles reading, writing, and converting band notes for a specific band.
 */

public class BandNotes {

    private String bandName;
    private File bandNoteFile;
    private File oldBandNoteFile;
    private File bandCustNoteFile;

    private boolean noteIsBlank = false;

    /**
     * Constructs a BandNotes handler for the given band.
     * @param bandValue The name of the band.
     */
    public BandNotes(String bandValue){

        bandName = bandValue;
        oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        bandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
        bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
    }

    /**
     * Checks if the band note file exists.
     * @return True if the note file exists, false otherwise.
     */
    public boolean fileExists(){
        return bandNoteFile.exists();
    }

    /**
     * Returns whether the note is blank.
     * @return True if the note is blank, false otherwise.
     */
    public boolean getNoteIsBlank(){
        return noteIsBlank;
    }

    /**
     * Gets the band note, converting URLs to clickable links.
     * @return The band note as a string.
     */
    public String getBandNote(){
        CustomerDescriptionHandler noteHandler = CustomerDescriptionHandler.getInstance();
        String bandNote = noteHandler.getDescription(bandName);

        if (bandNote.contains("!!!!https://")){
            bandNote = bandNote.replaceAll("!!!!https://([^\\s]+)", "<a  target='_blank' style='color: lightblue' href=https://$1>$1</a>");
        }

        return bandNote;

    }

    /**
     * Gets the band note immediately, bypassing background loading pause.
     * This method is used when the details screen needs to load a note immediately.
     * @return The band note as a string.
     */
    public String getBandNoteImmediate(){
        CustomerDescriptionHandler noteHandler = CustomerDescriptionHandler.getInstance();
        String bandNote = noteHandler.getDescriptionImmediate(bandName);

        if (bandNote.contains("!!!!https://")){
            bandNote = bandNote.replaceAll("!!!!https://([^\\s]+)", "<a  target='_blank' style='color: lightblue' href=https://$1>$1</a>");
        }

        return bandNote;

    }

    /**
     * Converts an old band note file to the new format and saves it.
     */
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

        CustomerDescriptionHandler noteHandler = CustomerDescriptionHandler.getInstance();
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

    /**
     * Strips whitespace and HTML tags for comparison.
     * @param dataString The string to strip.
     * @return The stripped string.
     */
    private String stripDataForCompare(String dataString){

        String strippedDataString = "";
        if (dataString != null) {
            strippedDataString = dataString.replaceAll("\\s", "");
            strippedDataString = strippedDataString.replaceAll("<br>", "");
            strippedDataString = strippedDataString.replaceAll("\n", "");
        }
        return strippedDataString;
    }

    /**
     * Gets the band note from the file, converting old notes if needed.
     * @return The band note as a string.
     */
    public String getBandNoteFromFile(){

        String note = "";

        if (oldBandNoteFile.exists() == true){
            Log.d("70K_NOTE_DEBUG", "Converting old band note for " + bandName);
            convertOldBandNote();
        }

        Map<String, String> notesData = FileHandler70k.readObject(bandNoteFile);

        Log.d("70K_NOTE_DEBUG","Loading note from file for band: " + bandName + ", notesData: " + notesData);
        if (notesData.containsKey("customDescription")){
            note = notesData.get("customDescription");
            Log.d("70K_NOTE_DEBUG", "Returning customDescription for " + bandName + ": " + note);
        } else {
            note = notesData.get("defaultNote");
            Log.d("70K_NOTE_DEBUG", "Returning defaultNote for " + bandName + ": " + note);
        }

        return note;
    }

    /**
     * Saves the default band note to the file.
     * @param notesData The note data to save.
     */
    public void saveDefaultBandNote(String notesData){

        Log.d("70K_NOTE_DEBUG", "saveDefaultBandNote called for " + bandName + ", data: " + notesData);

        if (notesData.startsWith("Comment text is not available yet") == false &&
                notesData.length() > 2 && bandCustNoteFile.exists() == false) {

            // Preserve line breaks for native TextView display instead of converting to HTML
            // notesData = notesData.replaceAll("\\n", "<br>");  // Removed - no longer needed for native TextViews
            // notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");  // Removed - no longer needed

            Log.d("70K_NOTE_DEBUG", "Writing defaultNote to " + bandNoteFile + " - " + notesData);

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
            Log.d("70K_NOTE_DEBUG", "Default note data saved for " + bandNoteFile);
        } else {
            Log.d("70K_NOTE_DEBUG", "Default note NOT saved (conditions not met) for " + bandName);
            bandNoteFile.delete();
        }

    }

    /**
     * Saves a custom band note to the file.
     * @param notesData The custom note data to save.
     */
    public void saveCustomBandNote(String notesData){

        Log.d("70K_NOTE_DEBUG", "saveCustomBandNote called for " + bandName + ", data: " + notesData);

        Map<String, String> defaultNotesData = FileHandler70k.readObject(bandNoteFile);
        String defaultNote = defaultNotesData.get("defaultNote");
        if (defaultNote == ""){
            SystemClock.sleep(1000);
            defaultNotesData = FileHandler70k.readObject(bandNoteFile);
            defaultNote = defaultNotesData.get("defaultNote");
        }

        String strippedDefaultNote = this.stripDataForCompare(defaultNote);
        String strippedCustomNote = this.stripDataForCompare(notesData);

        Log.d("70K_NOTE_DEBUG", "Comparing defaultNote (stripped): '" + strippedDefaultNote + "' to customNote (stripped): '" + strippedCustomNote + "'");

        if (notesData.startsWith("Comment text is not available yet") == false &&
                notesData.length() > 2 && strippedDefaultNote.equals(strippedCustomNote) == false) {

            notesData = notesData.replaceAll("\\n", "<br>");
            notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");

            Log.d("70K_NOTE_DEBUG", "Writing customDescription to " + bandNoteFile + " and " + bandCustNoteFile + " - " + notesData);

            Time today = new Time(Time.getCurrentTimezone());
            today.setToNow();

            Map<String, String> bandNameDataHash = new HashMap<String, String>();
            bandNameDataHash.put("defaultNote", "");
            bandNameDataHash.put("dateModified", String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            bandNameDataHash.put("dateWritten", String.valueOf(today));
            bandNameDataHash.put("customDescription", notesData);

            FileHandler70k.writeObject(bandNameDataHash, bandNoteFile);
            FileHandler70k.writeObject(bandNameDataHash, bandCustNoteFile);

            Log.d("70K_NOTE_DEBUG", "Custom note data saved for " + bandNoteFile + " and " + bandCustNoteFile);

        } else {
            Log.d("70K_NOTE_DEBUG", "Custom note NOT saved (conditions not met) for " + bandName);
            bandNoteFile.delete();
            bandCustNoteFile.delete();
        }
    }
}
