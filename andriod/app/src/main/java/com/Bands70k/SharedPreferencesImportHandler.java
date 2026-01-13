package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.util.Log;
import android.widget.EditText;

import androidx.localbroadcastmanager.content.LocalBroadcastManager;

/**
 * SharedPreferencesImportHandler
 * Handles importing shared preference files when opened in the app
 * 
 * When a user receives a .70kshare or .mdfshare file (via email, messaging, etc.)
 * and opens it, this handler processes the file, validates it, and prompts the
 * user to name and import the shared preferences.
 */
public class SharedPreferencesImportHandler {
    private static final String TAG = "SharedPrefImport";
    private static SharedPreferencesImportHandler instance;
    
    private SharedPreferencesManager sharingManager;
    private SharedPreferenceSet pendingImportSet;
    private Context context;
    
    private SharedPreferencesImportHandler() {
        this.sharingManager = SharedPreferencesManager.getInstance();
        this.context = Bands70k.getAppContext();
    }
    
    public static synchronized SharedPreferencesImportHandler getInstance() {
        if (instance == null) {
            instance = new SharedPreferencesImportHandler();
        }
        return instance;
    }
    
    /**
     * Handles an incoming file URI (called from Activity onCreate/onNewIntent)
     * @param uri URI of the file to import
     * @param activity The activity context for showing dialogs
     * @return true if handled successfully
     */
    public boolean handleIncomingFile(Uri uri, Activity activity) {
        Log.d(TAG, "📥 Handling incoming file: " + uri.toString());
        Log.d(TAG, "📥 URI scheme: " + uri.getScheme());
        Log.d(TAG, "📥 URI path: " + uri.getPath());
        
        // Validate and parse the file
        SharedPreferenceSet preferenceSet = sharingManager.validateImportedFile(uri);
        if (preferenceSet == null) {
            showErrorAlert(activity, context.getString(R.string.invalid_share_file));
            return false;
        }
        
        // Store temporarily and show import dialog
        pendingImportSet = preferenceSet;
        
        // Schedule dialog to show after a brief delay to ensure UI is ready
        new Handler().postDelayed(() -> {
            showImportDialog(preferenceSet, activity);
        }, 500);
        
        return true;
    }
    
    /**
     * Shows dialog to accept and name the imported share
     * - For new profiles: Prompt for name with senderName as default (editable)
     * - For existing profiles: Show confirmation dialog (name not editable)
     */
    private void showImportDialog(SharedPreferenceSet preferenceSet, Activity activity) {
        // Check if this UserID already exists
        ProfileMetadata existingProfile = SQLiteProfileManager.getInstance()
                .getProfile(preferenceSet.senderUserId);
        
        if (existingProfile != null) {
            // Profile exists - show confirmation dialog (no name change)
            Log.d(TAG, "📥 [IMPORT] Existing profile found: " + existingProfile.label + 
                    " (" + preferenceSet.senderUserId + ")");
            showUpdateConfirmationDialog(preferenceSet, existingProfile, activity);
            return;
        }
        
        // New profile - prompt for name with senderName as default
        Log.d(TAG, "📥 [IMPORT] New profile, prompting for name");
        showNewProfileDialog(preferenceSet, activity);
    }
    
    /**
     * Shows confirmation dialog for updating an existing profile
     * Name is not editable - just confirm or cancel
     */
    private void showUpdateConfirmationDialog(SharedPreferenceSet preferenceSet, 
                                               ProfileMetadata existingProfile, 
                                               Activity activity) {
        activity.runOnUiThread(() -> {
            AlertDialog.Builder builder = new AlertDialog.Builder(activity);
            builder.setTitle(R.string.update_profile);
            
            // Create message
            String message = context.getString(R.string.update_existing_profile_message)
                    .replace("{profileName}", existingProfile.label) + "\n\n" +
                    preferenceSet.priorities.size() + " " + 
                    context.getString(R.string.band_priorities) + "\n" +
                    preferenceSet.attendance.size() + " " + 
                    context.getString(R.string.scheduled_events) + "\n\n" +
                    "⚠️ " + context.getString(R.string.alert_warning_import);
            builder.setMessage(message);
            
            // Cancel button
            builder.setNegativeButton(R.string.Cancel, (dialog, which) -> {
                pendingImportSet = null;
                dialog.cancel();
            });
            
            // Update button
            builder.setPositiveButton(R.string.Update, (dialog, which) -> {
                completeImport(preferenceSet, existingProfile.label, true, activity);
            });
            
            AlertDialog dialog = builder.create();
            dialog.show();
        });
    }
    
    /**
     * Shows dialog for naming a new profile
     * Uses senderName as default, allows user to change
     */
    private void showNewProfileDialog(SharedPreferenceSet preferenceSet, Activity activity) {
        activity.runOnUiThread(() -> {
            AlertDialog.Builder builder = new AlertDialog.Builder(activity);
            builder.setTitle(R.string.import_shared_preferences);
            
            // Create message
            String message = context.getString(R.string.new_profile_received) + "\n\n" +
                    preferenceSet.priorities.size() + " " + 
                    context.getString(R.string.band_priorities) + "\n" +
                    preferenceSet.attendance.size() + " " + 
                    context.getString(R.string.scheduled_events) + "\n\n" +
                    "⚠️ " + context.getString(R.string.alert_warning_import) + "\n\n" +
                    context.getString(R.string.choose_profile_name);
            builder.setMessage(message);
            
            // Add text input field with senderName as default
            final EditText input = new EditText(activity);
            input.setHint("e.g., Friend's Picks");
            // Use senderName from the imported file as default
            String defaultName = (preferenceSet.senderName != null && !preferenceSet.senderName.isEmpty()) ? 
                    preferenceSet.senderName : "Shared Profile";
            input.setText(defaultName);
            input.selectAll();
            builder.setView(input);
            
            // Cancel button
            builder.setNegativeButton(R.string.Cancel, (dialog, which) -> {
                pendingImportSet = null;
                dialog.cancel();
            });
            
            // Import button
            builder.setPositiveButton(R.string.import_button, (dialog, which) -> {
                String customName = input.getText().toString().trim();
                if (customName.isEmpty()) {
                    customName = defaultName;
                }
                completeImport(preferenceSet, customName, false, activity);
            });
            
            AlertDialog dialog = builder.create();
            dialog.show();
        });
    }
    
    /**
     * Completes the import with the user's chosen name
     */
    private void completeImport(SharedPreferenceSet preferenceSet, String customName, 
                               boolean isUpdate, Activity activity) {
        Log.d(TAG, "📥 [IMPORT_HANDLER] completeImport called with name: " + customName);
        Log.d(TAG, "📥 [IMPORT_HANDLER] preferenceSet userId: " + preferenceSet.senderUserId);
        
        boolean importSuccess = sharingManager.importPreferenceSet(preferenceSet, customName);
        Log.d(TAG, "📥 [IMPORT_HANDLER] importPreferenceSet returned: " + importSuccess);
        
        if (importSuccess) {
            Log.d(TAG, "✅ [IMPORT_HANDLER] Import successful, switching to imported profile");
            
            // CRITICAL: Switch to the imported profile (using UserID as the profile key)
            String profileKey = preferenceSet.senderUserId;
            sharingManager.setActivePreferenceSource(profileKey);
            
            Log.d(TAG, "✅ [IMPORT_HANDLER] Switched to profile: " + profileKey);
            
            // CRITICAL: Reload profile-specific data (same as manual profile switching)
            // This ensures the UI shows the correct profile data, not just the color
            rankStore.reloadForActiveProfile();
            if (staticVariables.attendedHandler != null) {
                staticVariables.attendedHandler.reloadForActiveProfile();
            }
            Log.d(TAG, "✅ [IMPORT_HANDLER] Reloaded priority and attendance data for profile: " + customName);
            
            // Update header color and refresh UI if this is the showBands activity
            if (activity instanceof showBands) {
                showBands showBandsActivity = (showBands) activity;
                showBandsActivity.updateHeaderColorForCurrentProfile();
                Log.d(TAG, "✅ [IMPORT_HANDLER] Updated header color for new profile");
                
                // CRITICAL: Refresh the band list with new profile data
                // This ensures the UI displays the imported profile's data, not just the color
                showBandsActivity.refreshNewData();
                Log.d(TAG, "✅ [IMPORT_HANDLER] Refreshed band list with new profile data");
            }
            
            // Different message for update vs new import
            String message;
            if (isUpdate) {
                message = context.getString(R.string.updated) + " '" + customName + "' " +
                        context.getString(R.string.with_new_data) + "\n\n" +
                        context.getString(R.string.showing_preferences_from) + " '" + customName + "'.";
            } else {
                message = context.getString(R.string.successfully_imported) + " '" + customName + "'!\n\n" +
                        context.getString(R.string.showing_preferences_from) + " '" + customName + "'.";
            }
            
            showSuccessAlert(activity, message, isUpdate);
            
        } else {
            showErrorAlert(activity, context.getString(R.string.failed_to_import));
        }
        
        pendingImportSet = null;
    }
    
    /**
     * Shows success alert
     */
    private void showSuccessAlert(Activity activity, String message, boolean isUpdate) {
        activity.runOnUiThread(() -> {
            AlertDialog.Builder builder = new AlertDialog.Builder(activity);
            String title = isUpdate ? 
                    context.getString(R.string.profile_updated) : 
                    context.getString(R.string.import_successful);
            builder.setTitle(title);
            builder.setMessage(message);
            
            builder.setPositiveButton(R.string.Ok, (dialog, which) -> {
                dialog.dismiss();
                
                // Show tutorial overlay for NEW profiles only (not updates)
                // This helps users discover the profile switcher
                if (!isUpdate) {
                    showProfileSwitchTutorial(activity);
                }
                // Could show tutorial overlay here if desired
            });
            
            AlertDialog dialog = builder.create();
            dialog.show();
        });
    }
    
    /**
     * Shows tutorial overlay pointing to the profile switcher
     * Helps users discover they can tap the band count header to switch profiles
     */
    private void showProfileSwitchTutorial(Activity activity) {
        // Delay slightly to allow the success dialog to fully dismiss
        activity.runOnUiThread(() -> {
            new android.os.Handler().postDelayed(() -> {
                ProfileTutorialOverlay.show(activity);
            }, 500);
        });
    }
    
    /**
     * Shows error alert
     */
    private void showErrorAlert(Activity activity, String message) {
        activity.runOnUiThread(() -> {
            AlertDialog.Builder builder = new AlertDialog.Builder(activity);
            builder.setTitle(R.string.import_failed);
            builder.setMessage(message);
            builder.setPositiveButton(R.string.Ok, null);
            
            AlertDialog dialog = builder.create();
            dialog.show();
        });
    }
}

