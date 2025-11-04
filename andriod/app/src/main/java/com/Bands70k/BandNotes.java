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
import java.util.concurrent.atomic.AtomicBoolean;

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
        // Use date-based filename for cache invalidation (like iOS)
        bandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + getNoteFileName());
        bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
    }
    
    /**
     * Gets the appropriate note filename based on whether a custom note exists and the date.
     * This matches the iOS implementation for cache invalidation when the descriptionMap date changes.
     * @return The filename to use for the note (with date embedded if available)
     */
    private String getNoteFileName() {
        String approvedFileName;
        String custCommentFileName = bandName + ".note_cust";
        
        // Check if we have a date for this band in the descriptionMap
        String dateModified = String.valueOf(staticVariables.descriptionMapModData.get(bandName));
        
        if (dateModified != null && !dateModified.equals("null") && !dateModified.isEmpty()) {
            // Date available - use date-based filename for cache invalidation
            String defaultCommentFileName = bandName + ".note-" + dateModified;
            
            File custCommentFile = new File(showBands.newRootDir + FileHandler70k.directoryName + custCommentFileName);
            
            if (custCommentFile.exists()) {
                // Custom note exists - use it
                approvedFileName = custCommentFileName;
                Log.d("70K_NOTE_DEBUG", "Using custom note filename: " + approvedFileName);
            } else {
                // No custom note - use date-based default filename
                approvedFileName = defaultCommentFileName;
                Log.d("70K_NOTE_DEBUG", "Using date-based default filename: " + approvedFileName);
            }
        } else {
            // No date available - fall back to custom filename
            approvedFileName = custCommentFileName;
            Log.d("70K_NOTE_DEBUG", "No date available, using custom filename: " + approvedFileName);
        }
        
        return approvedFileName;
    }

    /**
     * Cleans up obsolete cached note files with old dates.
     * When the descriptionMap date changes, this removes the old cached file
     * so a fresh version will be downloaded with the new date.
     */
    private void cleanupObsoleteCache() {
        try {
            String currentDate = String.valueOf(staticVariables.descriptionMapModData.get(bandName));
            
            if (currentDate == null || currentDate.equals("null") || currentDate.isEmpty()) {
                return; // No date info available, nothing to clean up
            }
            
            File dir = new File(showBands.newRootDir + FileHandler70k.directoryName);
            if (!dir.exists() || !dir.isDirectory()) {
                return;
            }
            
            // Find all note files for this band with different dates
            File[] files = dir.listFiles((directory, filename) -> {
                // Match: BandName.note-OLDDATE (but not the current date)
                return filename.startsWith(bandName + ".note-") && 
                       !filename.equals(bandName + ".note-" + currentDate) &&
                       !filename.endsWith(".note_cust"); // Don't delete custom notes
            });
            
            if (files != null) {
                for (File obsoleteFile : files) {
                    if (obsoleteFile.delete()) {
                        Log.d("70K_NOTE_DEBUG", "Deleted obsolete cached note: " + obsoleteFile.getName());
                    } else {
                        Log.w("70K_NOTE_DEBUG", "Failed to delete obsolete cached note: " + obsoleteFile.getName());
                    }
                }
            }
            
            // Also clean up the old static filename format if it exists
            File oldStaticFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
            if (oldStaticFile.exists()) {
                if (oldStaticFile.delete()) {
                    Log.d("70K_NOTE_DEBUG", "Deleted old static cached note: " + oldStaticFile.getName());
                }
            }
            
        } catch (Exception e) {
            Log.e("70K_NOTE_DEBUG", "Error cleaning up obsolete cache for " + bandName + ": " + e.getMessage());
        }
    }
    
    /**
     * Checks if the band note file exists.
     * Cleans up obsolete cached files before checking.
     * @return True if the note file exists, false otherwise.
     */
    public boolean fileExists(){
        cleanupObsoleteCache();
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

        if (!FestivalConfig.getInstance().isDefaultDescriptionText(notesData) &&
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

            // Note: Date is now embedded in the filename itself (bandName.note-DATE)
            // No need to create a separate date file anymore
            Log.d("70K_NOTE_DEBUG", "Default note data saved for " + bandNoteFile + " with date: " + dateModified);
            
            // Clean up any obsolete cached files with old dates
            cleanupObsoleteCache();
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
        if (defaultNote == "" || defaultNote == null){
            // Use exponential backoff instead of fixed sleep for file retry
            AtomicBoolean fileReady = new AtomicBoolean(false);
            if (SynchronizationManager.waitWithBackoff(fileReady, 3, 500)) {
                defaultNotesData = FileHandler70k.readObject(bandNoteFile);
                defaultNote = defaultNotesData.get("defaultNote");
            } else {
                Log.w("BandNotes", "Timeout waiting for note file to be ready, using empty note");
                defaultNote = "";
            }
        }

        String strippedDefaultNote = this.stripDataForCompare(defaultNote);
        String strippedCustomNote = this.stripDataForCompare(notesData);

        Log.d("70K_NOTE_DEBUG", "Comparing defaultNote (stripped): '" + strippedDefaultNote + "' to customNote (stripped): '" + strippedCustomNote + "'");

        if (!FestivalConfig.getInstance().isDefaultDescriptionText(notesData) &&
                notesData.length() > 2 && strippedDefaultNote.equals(strippedCustomNote) == false) {

            // Preserve line breaks for native TextView display
            // No longer convert to <br> tags since we're using native Android views

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
            
            // Clean up any obsolete cached files with old dates
            cleanupObsoleteCache();

        } else {
            Log.d("70K_NOTE_DEBUG", "Custom note NOT saved (conditions not met) for " + bandName);
            bandNoteFile.delete();
            bandCustNoteFile.delete();
        }
    }
}
