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
    private String normalizedBandName;
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
        normalizedBandName = normalizeBandName(bandName);
        oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        // Use date-based filename for cache invalidation (like iOS)
        bandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + getNoteFileName());
        bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
    }

    /**
     * Recomputes the target note file based on the current descriptionMap date.
     *
     * IMPORTANT: The details screen may construct BandNotes before the descriptionMap has been refreshed.
     * Recomputing here ensures that if the date changes later, we start using BandName.note-NEW_DATE
     * and the old cache becomes obsolete.
     */
    private void refreshNoteFileReference() {
        normalizedBandName = normalizeBandName(bandName);
        bandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + getNoteFileName());
    }

    /**
     * Normalizes a band name by removing invisible Unicode characters and trimming whitespace.
     * IMPORTANT: Must match the normalization used when populating descriptionMapModData.
     */
    private String normalizeBandName(String bandName) {
        if (bandName == null) {
            return "";
        }

        return bandName.trim()
                .replace("⁦", "") // Remove left-to-right mark
                .replace("⁧", "") // Remove right-to-left mark
                .replace("\u200E", "") // Remove left-to-right mark
                .replace("\u200F", "") // Remove right-to-left mark
                .replace("\u202A", "") // Remove left-to-right embedding
                .replace("\u202B", "") // Remove right-to-left embedding
                .replace("\u202C", "") // Remove pop directional formatting
                .replace("\u202D", "") // Remove left-to-right override
                .replace("\u202E", "") // Remove right-to-left override
                .replace("\u2066", "") // Remove left-to-right isolate
                .replace("\u2067", "") // Remove right-to-left isolate
                .replace("\u2068", "") // Remove first strong isolate
                .replace("\u2069", ""); // Remove pop directional isolate
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
        String dateModified = String.valueOf(staticVariables.descriptionMapModData.get(normalizedBandName));
        
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
            // No date available - DO NOT fall back to .note_cust (that file must remain user-controlled).
            // Use the legacy default filename to avoid accidentally overwriting a custom note.
            approvedFileName = bandName + ".note_new";
            Log.d("70K_NOTE_DEBUG", "No date available, using legacy default filename: " + approvedFileName);
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
            String currentDate = String.valueOf(staticVariables.descriptionMapModData.get(normalizedBandName));
            
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
        refreshNoteFileReference();
        cleanupObsoleteCache();
        return bandNoteFile.exists();
    }

    /**
     * Clears the user-provided custom note so default note behavior resumes.
     *
     * IMPORTANT:
     * Custom notes are stored in TWO places:
     * - BandName.note_cust (fixed filename)
     * - BandName.note-DATE (date-based cache file) where customDescription may also be written
     *
     * To fully "clear" the custom note and allow re-download of the default note, we must delete BOTH.
     */
    public void clearCustomNote() {
        try {
            if (bandCustNoteFile != null && bandCustNoteFile.exists()) {
                boolean deleted = bandCustNoteFile.delete();
                Log.d("70K_NOTE_DEBUG", "clearCustomNote: deleted .note_cust for " + bandName + ": " + deleted);
            }

            // Delete the date-based cache file for the current descriptionMap date.
            // Otherwise, a previously-saved customDescription inside BandName.note-DATE will keep "winning"
            // even after .note_cust is removed.
            String currentDate = String.valueOf(staticVariables.descriptionMapModData.get(normalizedBandName));
            if (currentDate != null && !currentDate.equals("null") && !currentDate.trim().isEmpty()) {
                File dateBasedFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note-" + currentDate.trim());
                if (dateBasedFile.exists()) {
                    boolean deletedDateFile = dateBasedFile.delete();
                    Log.d("70K_NOTE_DEBUG", "clearCustomNote: deleted date-based note file for " + bandName + " (" + dateBasedFile.getName() + "): " + deletedDateFile);
                }
            }

            // Legacy fallback: also remove the old static cache file if present.
            File legacyDefaultFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
            if (legacyDefaultFile.exists()) {
                boolean deletedLegacy = legacyDefaultFile.delete();
                Log.d("70K_NOTE_DEBUG", "clearCustomNote: deleted legacy note file for " + bandName + " (" + legacyDefaultFile.getName() + "): " + deletedLegacy);
            }

            // Recompute note file path now that custom file is gone (should switch back to date-based default)
            refreshNoteFileReference();

            // Remove any stale cache files with old dates
            cleanupObsoleteCache();
        } catch (Exception e) {
            Log.e("70K_NOTE_DEBUG", "clearCustomNote error for " + bandName + ": " + e.getMessage());
        }
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

        // Ensure we are reading from the correct date-based file for the CURRENT descriptionMap date
        refreshNoteFileReference();
        cleanupObsoleteCache();

        Map<String, String> notesData = FileHandler70k.readObject(bandNoteFile);

        Log.d("70K_NOTE_DEBUG","Loading note from file for band: " + bandName + ", notesData: " + notesData);
        if (notesData.containsKey("customDescription")){
            note = notesData.get("customDescription");
            Log.d("70K_NOTE_DEBUG", "Returning customDescription for " + bandName + ": " + note);

            // If a custom note exists but is blank, treat it as cleared so default behavior resumes.
            // This prevents an empty .note_cust from blocking default downloads/reads.
            if (note == null || note.trim().isEmpty()) {
                Log.d("70K_NOTE_DEBUG", "Custom note is blank for " + bandName + " - clearing custom note and falling back to default");
                clearCustomNote();

                // Re-read from the (now default) note file if it exists
                Map<String, String> refreshedData = FileHandler70k.readObject(bandNoteFile);
                if (refreshedData != null) {
                    String defaultNote = refreshedData.get("defaultNote");
                    if (defaultNote != null) {
                        return defaultNote;
                    }
                }
                return "";
            }
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

            // Ensure we write to the correct date-based file for the CURRENT descriptionMap date
            refreshNoteFileReference();

            // Preserve line breaks for native TextView display instead of converting to HTML
            // notesData = notesData.replaceAll("\\n", "<br>");  // Removed - no longer needed for native TextViews
            // notesData = notesData.replaceAll("<br><br><br><br>", "<br><br>");  // Removed - no longer needed

            Log.d("70K_NOTE_DEBUG", "Writing defaultNote to " + bandNoteFile + " - " + notesData);

            Time today = new Time(Time.getCurrentTimezone());
            today.setToNow();
            String dateModified = String.valueOf(staticVariables.descriptionMapModData.get(normalizedBandName));
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

        // Ensure we write to the correct date-based file for the CURRENT descriptionMap date
        // (and always mirror custom data into the fixed .note_cust file)
        refreshNoteFileReference();

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
            bandNameDataHash.put("dateModified", String.valueOf(staticVariables.descriptionMapModData.get(normalizedBandName)));
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
