package com.Bands70k;

/**
 * Created by rdorn on 7/25/15.
 */

import android.app.Activity;

import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;

import android.net.Uri;
import android.os.Bundle;

import android.os.SystemClock;

import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;

import androidx.core.app.NavUtils;
import android.util.DisplayMetrics;
import android.util.Log;
import android.widget.Toast;

import android.view.Display;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

import android.widget.ProgressBar;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Button;
import android.view.LayoutInflater;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ColorDrawable;
import android.app.AlertDialog;
import android.widget.EditText;
import android.content.DialogInterface;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.view.animation.TranslateAnimation;
import android.view.animation.AnimationSet;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.content.Context;

import java.util.Iterator;
import java.util.Map;
import java.io.File;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.style.ClickableSpan;
import android.text.style.ForegroundColorSpan;
import android.text.method.LinkMovementMethod;

import static com.Bands70k.staticVariables.context;


public class showBandDetails extends Activity {
    /** Called when the activity is first created. */

    private String mustButtonColor;
    private String mightButtonColor;
    private String wontButtonColor;
    private String unknownButtonColor;
    private Boolean inLink = false;
    
    // INFINITE LOOP FIX: Flag to prevent repeated cache cleanup attempts
    private boolean cacheCleanupAttempted = false;
    
    // Native view components
    private TextView bandNameText;
    private ImageView bandLogoImage;
    private LinearLayout scheduleSection;
    private LinearLayout linksSection;
    private LinearLayout linksIconContainer;
    private LinearLayout extraDataSection;
    private LinearLayout userNotesSection;
    private TextView userNotesText;
    private TextView linksLabel;
    private ImageView websiteLink, metalArchivesLink, wikipediaLink, youtubeLink;
    private TextView countryValue, genreValue, lastCruiseValue, noteValue;
    private LinearLayout countryRow, genreRow, lastCruiseRow, noteRow;
    private Button unknownButton, mustButton, mightButton, wontButton;
    
    // Translation components
    private LinearLayout translationButtonContainer;
    private Button translationButton;
    private BandDescriptionTranslator translator;
    private String originalEnglishText;
    private String currentTranslatedText;
    private ImageView rankingIcon;
    private ProgressBar loadingProgressBar;
    private ScrollView contentScrollView;
    private LinearLayout contentContainer;
    private String orientation;
    private String bandNote;
    private String bandName;
    private BandNotes bandHandler;
    private Boolean clickedOnEvent = false;

    private String rankIconLocation = "";
    
    // WebView components for in-app external link browsing
    private WebView inAppWebView;
    private ProgressBar webViewProgressBar;
    
    // Swipe gesture detection
    private GestureDetector swipeGestureDetector;

    public void onCreate(Bundle savedInstanceState) {

        setTheme(R.style.AppTheme);

        super.onCreate(savedInstanceState);
        
            setContentView(R.layout.band_details_native);
        
        // Initialize swipe gesture detector
        initializeSwipeGestureDetector();

        // Background loading is now properly managed at the Application level
        // Individual descriptions and images can still be loaded as needed for this specific band
        Log.d("DetailsScreen", "Details screen opened - background loading managed at Application level");

        View view = getWindow().getDecorView();

        int orientationNum = getResources().getConfiguration().orientation;
        if (Configuration.ORIENTATION_LANDSCAPE == orientationNum) {
            orientation = "landscape";
        } else {
            orientation = "portrait";
        }

        Log.d("detailsForBand",  "determining bandName");
        bandName = BandInfo.getSelectedBand();

        Log.d("detailsForBand",  "bandName is " + bandName);

        if (bandName == null) {
            onBackPressed();
        } else if (bandName.isEmpty() == false) {
            bandHandler = new BandNotes(bandName);
            bandNote = ""; // Start with blank - content will load progressively
            
            // IMMEDIATE SCREEN LOADING: Initialize UI components only (no data processing)
            Log.d("PerformanceTrack", "Using IMMEDIATE loading path for " + bandName);
            initializeUIComponentsOnly();
            
            // PROGRESSIVE LOADING: Load all data in background and update UI as ready
            loadAllContentProgressively();
            } else {
            onBackPressed();
        }

    }

    /**
     * PROGRESSIVE LOADING: Load all content in background with UI updates as ready.
     * Replaces both loadContentAsync and immediate heavy processing.
     * CRASH-SAFE with comprehensive error handling and lifecycle checks.
     */
    private void loadAllContentProgressively() {
        Log.d("ProgressiveLoading", "Starting progressive content loading for " + bandName);
        
        // Single background thread handles all data loading and UI updates
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    // CRASH PREVENTION: Check activity state before starting phases
                    if (isFinishing() || isDestroyed()) {
                        Log.d("ProgressiveLoading", "Activity destroyed before progressive loading for " + bandName);
                        return;
                    }
                    
                    // PHASE 1: Load cached note immediately if available
                    loadCachedNoteIfAvailable();
                    
                    // Check activity state between phases
                    if (isFinishing() || isDestroyed()) {
                        Log.d("ProgressiveLoading", "Activity destroyed after Phase 1 for " + bandName);
                        return;
                    }
                    
                    // PHASE 2: Load and display cached image
                    loadAndDisplayCachedImage();
                    
                    // Check activity state between phases
                    if (isFinishing() || isDestroyed()) {
                        Log.d("ProgressiveLoading", "Activity destroyed after Phase 2 for " + bandName);
                        return;
                    }
                    
                    // PHASE 3: Populate schedule, links, and other data
                    populateStaticDataSections();
                    
                    // Check activity state between phases
                    if (isFinishing() || isDestroyed()) {
                        Log.d("ProgressiveLoading", "Activity destroyed after Phase 3 for " + bandName);
                        return;
                    }
                    
                    // PHASE 4: Download missing note if needed
                    downloadMissingNoteIfNeeded();
                    
                    // Check activity state between phases
                    if (isFinishing() || isDestroyed()) {
                        Log.d("ProgressiveLoading", "Activity destroyed after Phase 4 for " + bandName);
                        return;
                    }
                    
                    // PHASE 5: Download missing image if needed  
                    downloadMissingImageIfNeeded();
                    
                    // Check activity state before final phase
                    if (isFinishing() || isDestroyed()) {
                        Log.d("ProgressiveLoading", "Activity destroyed after Phase 5 for " + bandName);
                        return;
                    }
                    
                    // PHASE 6: Final UI cleanup
                    finalizeUILoading();
                    
                } catch (OutOfMemoryError oom) {
                    Log.e("ProgressiveLoading", "OutOfMemoryError in progressive loading for " + bandName, oom);
                    // Force garbage collection to try to recover
                    System.gc();
                    // CRASH PREVENTION: Safe cleanup
                    if (!isFinishing() && !isDestroyed()) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    if (!isFinishing() && !isDestroyed() && loadingProgressBar != null) {
                                        loadingProgressBar.setVisibility(View.GONE);
                                    }
                                } catch (Exception e2) {
                                    Log.e("ProgressiveLoading", "Error in OOM cleanup for " + bandName, e2);
                                }
                            }
                        });
                    }
                } catch (Exception e) {
                    Log.e("ProgressiveLoading", "Error in progressive loading for " + bandName, e);
                    // CRASH PREVENTION: Safe cleanup
                    if (!isFinishing() && !isDestroyed()) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    if (!isFinishing() && !isDestroyed() && loadingProgressBar != null) {
                                        loadingProgressBar.setVisibility(View.GONE);
                                    }
                                } catch (Exception e2) {
                                    Log.e("ProgressiveLoading", "Error in cleanup for " + bandName, e2);
                                }
                            }
                        });
                    }
                }
            }
        }).start();
    }
    
    /**
     * LEGACY METHOD: Loads band content (note and image) asynchronously and refreshes the UI when ready.
     */
    private void loadContentAsync() {
        // Load content in background thread to avoid blocking UI
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Log.d("AsyncContent", "Starting async content loading for " + bandName);
                    
                    // Load note - only if not already cached
                    String loadedNote = null;
                    boolean noteNeedsUpdate = false;
                    boolean imageNeedsUpdate = false;
                    try {
                        // Check if note is already cached
                        String cachedNote = bandHandler.getBandNoteFromFile();
                        if (cachedNote != null && !cachedNote.trim().isEmpty()) {
                            // Note is already cached, no download needed
                            Log.d("AsyncContent", "Note already cached for " + bandName + ", skipping download");
                        } else {
                            // Download note immediately if not cached
                            Log.d("AsyncContent", "Note not cached, downloading for " + bandName);
                            loadedNote = bandHandler.getBandNoteImmediate();
                            noteNeedsUpdate = true;
                            if (loadedNote != null && !loadedNote.trim().isEmpty()) {
                                Log.d("AsyncContent", "Note downloaded successfully for " + bandName);
                            } else {
                                Log.d("AsyncContent", "Note download returned empty for " + bandName);
                                loadedNote = "No note available for this band.";
                            }
                        }
                    } catch (Exception e) {
                        Log.e("AsyncContent", "Error loading note for " + bandName, e);
                        loadedNote = "Note could not be loaded.";
                        noteNeedsUpdate = true;
                    }
                    
                    // Load image only if not already cached
                    try {
                        ImageHandler bandImageHandler = new ImageHandler(bandName);
                        // Check if image is already cached  
                        java.net.URI existingImage = bandImageHandler.getImage();
                        if (existingImage != null) {
                            Log.d("AsyncContent", "Image already cached for " + bandName + ", skipping download");
                        } else {
                            Log.d("AsyncContent", "Image not cached, downloading for " + bandName);
                            java.net.URI downloadedImage = bandImageHandler.getImageImmediate();
                            if (downloadedImage != null) {
                                imageNeedsUpdate = true;
                                Log.d("AsyncContent", "Image download completed successfully for " + bandName);
                            } else {
                                Log.d("AsyncContent", "Image download failed for " + bandName);
                            }
                        }
                    } catch (Exception e) {
                        Log.e("AsyncContent", "Error loading image for " + bandName, e);
                    }
                    
                    // Update UI on main thread if content changed (note or image)
                    final String finalNote = loadedNote;
                    final boolean needsNoteUpdate = noteNeedsUpdate;
                    final boolean needsImageUpdate = imageNeedsUpdate;
                    final boolean needsUpdate = needsNoteUpdate || needsImageUpdate;
                    if (needsUpdate) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                // Update note if needed
                                if (needsNoteUpdate && finalNote != null) {
                                    bandNote = finalNote;
                                    Log.d("AsyncContent", "Updating note content for " + bandName);
                                }
                                
                                // Refresh UI if anything changed (note or image)
                                if (needsNoteUpdate || needsImageUpdate) {
                                    Log.d("AsyncContent", "Refreshing UI with updated content for " + bandName + 
                                          " (note: " + needsNoteUpdate + ", image: " + needsImageUpdate + ")");
                                        refreshNativeContent();
                                }
                            }
                        });
                                    } else {
                        Log.d("AsyncContent", "No UI refresh needed for " + bandName + " - note and image already cached");
                    }
                    
                } catch (Exception e) {
                    Log.e("AsyncContent", "Error in async content loading for " + bandName, e);
                }
            }
        }).start();
    }
    
    // ==================== PROGRESSIVE LOADING PHASES ====================
    
    /**
     * PHASE 1: Load cached note immediately if available (CRASH-SAFE with lifecycle checks)
     */
    private void loadCachedNoteIfAvailable() {
        try {
            // Check if activity is still valid before proceeding
            if (isFinishing() || isDestroyed()) {
                Log.d("ProgressiveLoading", "Phase 1: Activity destroyed, skipping cached note for " + bandName);
                return;
            }
            
            String cachedNote = bandHandler.getBandNoteFromFile();
            if (cachedNote != null && !cachedNote.trim().isEmpty()) {
                Log.d("ProgressiveLoading", "Phase 1: Cached note found for " + bandName);
                final String formattedNote = bandHandler.getBandNote(); // Apply URL formatting
                
                // CRASH PREVENTION: Check activity state before UI update
                if (!isFinishing() && !isDestroyed()) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                // Final check before UI update
                                if (!isFinishing() && !isDestroyed() && noteValue != null) {
                                    bandNote = formattedNote;
                                    setupExtraDataSection(); // Update note display immediately (this is where notes are actually shown)
                                    Log.d("ProgressiveLoading", "Phase 1: Cached note UI updated for " + bandName);
                                }
                            } catch (Exception e) {
                                Log.e("ProgressiveLoading", "Phase 1: Error updating UI for " + bandName, e);
                            }
                        }
                    });
                                    }
                                } else {
                Log.d("ProgressiveLoading", "Phase 1: No cached note for " + bandName);
            }
        } catch (Exception e) {
            Log.e("ProgressiveLoading", "Phase 1: Error loading cached note for " + bandName, e);
        }
    }
    
    /**
     * PHASE 2: Load and display cached image (CRASH-SAFE with memory management)
     */
    private void loadAndDisplayCachedImage() {
        try {
            // Check if activity is still valid before proceeding
            if (isFinishing() || isDestroyed()) {
                Log.d("ProgressiveLoading", "Phase 2: Activity destroyed, skipping image load for " + bandName);
                return;
            }
            
            ImageHandler imageHandler = new ImageHandler(bandName);
            java.net.URI imageURI = imageHandler.getImage();
            
            if (imageURI != null) {
                Log.d("ProgressiveLoading", "Phase 2: Cached image found for " + bandName);
                java.io.File imageFile = new java.io.File(imageURI);
                if (imageFile.exists() && imageFile.length() > 0) {
                    // CRASH PREVENTION: Use safe bitmap decoding with memory limits
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inJustDecodeBounds = true;
                    BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
                    
                    // Check if image dimensions are valid and calculate appropriate sample size
                    if (options.outWidth > 0 && options.outHeight > 0) {
                        
                        // Calculate sample size to fit within memory constraints (max 2048x2048)
                        int maxDimension = 2048;
                        int sampleSize = 1;
                        
                        if (options.outWidth > maxDimension || options.outHeight > maxDimension) {
                            int widthRatio = options.outWidth / maxDimension;
                            int heightRatio = options.outHeight / maxDimension;
                            sampleSize = Math.max(widthRatio, heightRatio);
                            Log.d("ProgressiveLoading", "Phase 2: Scaling down large image for " + bandName + 
                                  " (" + options.outWidth + "x" + options.outHeight + ") with sample size " + sampleSize);
                        }
                        
                        options.inJustDecodeBounds = false;
                        options.inSampleSize = sampleSize;
                        options.inPreferredConfig = Bitmap.Config.RGB_565; // Use less memory
                        
                        Bitmap bitmap = BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
                        if (bitmap != null && !bitmap.isRecycled()) {
                            // CRASH PREVENTION: Check activity state before UI update
                            if (!isFinishing() && !isDestroyed()) {
                                runOnUiThread(new Runnable() {
                                    @Override
                                    public void run() {
                                        try {
                                            // Final check before UI update
                                            if (!isFinishing() && !isDestroyed() && bandLogoImage != null) {
                                                displayBandImage(bitmap);
                                            } else {
                                                // Activity destroyed, recycle bitmap to prevent memory leak
                                                if (!bitmap.isRecycled()) {
                                                    bitmap.recycle();
                                                }
                                            }
                                        } catch (Exception e) {
                                            Log.e("ProgressiveLoading", "Phase 2: Error updating UI for " + bandName, e);
                                }
                            }
                        });
                    } else {
                                // Activity destroyed, recycle bitmap to prevent memory leak
                                bitmap.recycle();
                            }
                        }
                    } else {
                        Log.w("ProgressiveLoading", "Phase 2: Invalid image dimensions for " + bandName + 
                              " (" + options.outWidth + "x" + options.outHeight + ")");
                    }
                }
            } else {
                Log.d("ProgressiveLoading", "Phase 2: No cached image for " + bandName);
            }
        } catch (OutOfMemoryError oom) {
            Log.e("ProgressiveLoading", "Phase 2: OutOfMemoryError loading image for " + bandName, oom);
            // Force garbage collection to try to recover
            System.gc();
        } catch (Exception e) {
            Log.e("ProgressiveLoading", "Phase 2: Error loading cached image for " + bandName, e);
        }
    }
    
    /**
     * PHASE 3: Populate schedule, links, and other static data (CRASH-SAFE with lifecycle checks)
     */
    private void populateStaticDataSections() {
        try {
            // Check if activity is still valid before proceeding
            if (isFinishing() || isDestroyed()) {
                Log.d("ProgressiveLoading", "Phase 3: Activity destroyed, skipping static data for " + bandName);
                return;
            }
            
            Log.d("ProgressiveLoading", "Phase 3: Populating static data for " + bandName);
            
            // CRASH PREVENTION: Check activity state before UI update
            if (!isFinishing() && !isDestroyed()) {
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            // Final check before UI update
                            if (!isFinishing() && !isDestroyed() && scheduleSection != null) {
                                setupScheduleSection();
                                setupLinksSection();
                                setupExtraDataSection();
                                setupRankingButtons();
                            }
                } catch (Exception e) {
                            Log.e("ProgressiveLoading", "Phase 3: Error updating UI for " + bandName, e);
                        }
                    }
                });
            }
        } catch (Exception e) {
            Log.e("ProgressiveLoading", "Phase 3: Error populating static data for " + bandName, e);
        }
    }
    
    /**
     * PHASE 4: Download missing note if needed (CRASH-SAFE with lifecycle checks)
     */
    private void downloadMissingNoteIfNeeded() {
        try {
            // Check if activity is still valid before proceeding
            if (isFinishing() || isDestroyed()) {
                Log.d("ProgressiveLoading", "Phase 4: Activity destroyed, skipping note download for " + bandName);
                return;
            }
            
            String cachedNote = bandHandler.getBandNoteFromFile();
            if (cachedNote == null || cachedNote.trim().isEmpty()) {
                Log.d("ProgressiveLoading", "Phase 4: Downloading missing note for " + bandName);
                
                // CRASH PREVENTION: Check activity state before expensive download
                if (isFinishing() || isDestroyed()) {
                    Log.d("ProgressiveLoading", "Phase 4: Activity destroyed during download check for " + bandName);
                    return;
                }
                
                String downloadedNote = bandHandler.getBandNoteImmediate();
                if (downloadedNote != null && !downloadedNote.trim().isEmpty()) {
                    // Apply proper formatting to the downloaded note
                    final String formattedNote = bandHandler.getBandNote(); // This applies URL formatting
                    
                    // CRASH PREVENTION: Check activity state before UI update
                    if (!isFinishing() && !isDestroyed()) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    // Final check before UI update
                                    if (!isFinishing() && !isDestroyed() && noteValue != null) {
                                        bandNote = formattedNote;
                                        setupExtraDataSection(); // Update with properly formatted note (this is where notes are actually shown)
                                        Log.d("ProgressiveLoading", "Phase 4: Note UI updated for " + bandName);
                                    }
                                } catch (Exception e) {
                                    Log.e("ProgressiveLoading", "Phase 4: Error updating UI for " + bandName, e);
                                }
                            }
                        });
                    }
                } else {
                    // CRASH PREVENTION: Check activity state before UI update
                    if (!isFinishing() && !isDestroyed()) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    if (!isFinishing() && !isDestroyed() && noteValue != null) {
                                        bandNote = "No note available for this band.";
                                        setupExtraDataSection(); // Update note display (this is where notes are actually shown)
                                    }
                                } catch (Exception e) {
                                    Log.e("ProgressiveLoading", "Phase 4: Error updating UI for " + bandName, e);
                                }
                            }
                        });
                    }
                }
            } else {
                Log.d("ProgressiveLoading", "Phase 4: Note already cached, skipping download for " + bandName);
            }
        } catch (Exception e) {
            Log.e("ProgressiveLoading", "Phase 4: Error downloading note for " + bandName, e);
            // CRASH PREVENTION: Check activity state before UI update
            if (!isFinishing() && !isDestroyed()) {
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            if (!isFinishing() && !isDestroyed() && noteValue != null) {
                                bandNote = "Note could not be loaded.";
                                setupExtraDataSection(); // Update note display (this is where notes are actually shown)
                            }
                        } catch (Exception e2) {
                            Log.e("ProgressiveLoading", "Phase 4: Error updating error UI for " + bandName, e2);
                        }
                    }
                });
            }
        }
    }
    
    /**
     * PHASE 5: Download missing image if needed (CRASH-SAFE with memory management)
     */
    private void downloadMissingImageIfNeeded() {
        try {
            // Check if activity is still valid before proceeding
            if (isFinishing() || isDestroyed()) {
                Log.d("ProgressiveLoading", "Phase 5: Activity destroyed, skipping image download for " + bandName);
                return;
            }
            
            ImageHandler imageHandler = new ImageHandler(bandName);
            java.net.URI existingImage = imageHandler.getImage();
            if (existingImage == null) {
                Log.d("ProgressiveLoading", "Phase 5: Downloading missing image for " + bandName);
                
                // CRASH PREVENTION: Check activity state before expensive download
                if (isFinishing() || isDestroyed()) {
                    Log.d("ProgressiveLoading", "Phase 5: Activity destroyed during download check for " + bandName);
                    return;
                }
                
                // CRASH PREVENTION: Wrap network download in try-catch for stability
                java.net.URI downloadedImage = null;
                try {
                    downloadedImage = imageHandler.getImageImmediate();
                } catch (OutOfMemoryError oom) {
                    Log.e("ProgressiveLoading", "Phase 5: OutOfMemoryError during image download for " + bandName, oom);
                    System.gc(); // Request garbage collection
                    return; // Skip this image to prevent crash
                } catch (Exception e) {
                    Log.e("ProgressiveLoading", "Phase 5: Exception during image download for " + bandName, e);
                    return; // Skip this image to prevent crash
                }
                if (downloadedImage != null) {
                    java.io.File imageFile = new java.io.File(downloadedImage);
                    if (imageFile.exists() && imageFile.length() > 0) {
                        // CRASH PREVENTION: Use safe bitmap decoding with memory limits
                        BitmapFactory.Options options = new BitmapFactory.Options();
                        options.inJustDecodeBounds = true;
                        BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
                        
                        // Check if image dimensions are valid and calculate appropriate sample size
                        if (options.outWidth > 0 && options.outHeight > 0) {
                            
                            // Calculate sample size to fit within memory constraints (max 2048x2048)
                            int maxDimension = 2048;
                            int sampleSize = 1;
                            
                            if (options.outWidth > maxDimension || options.outHeight > maxDimension) {
                                int widthRatio = options.outWidth / maxDimension;
                                int heightRatio = options.outHeight / maxDimension;
                                sampleSize = Math.max(widthRatio, heightRatio);
                                Log.d("ProgressiveLoading", "Phase 5: Scaling down large downloaded image for " + bandName + 
                                      " (" + options.outWidth + "x" + options.outHeight + ") with sample size " + sampleSize);
                            }
                            
                            options.inJustDecodeBounds = false;
                            options.inSampleSize = sampleSize;
                            options.inPreferredConfig = Bitmap.Config.RGB_565; // Use less memory
                            
                            Bitmap bitmap = BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
                            if (bitmap != null && !bitmap.isRecycled()) {
                                // CRASH PREVENTION: Check activity state before UI update
                                if (!isFinishing() && !isDestroyed()) {
                                    runOnUiThread(new Runnable() {
                                        @Override
                                        public void run() {
                                            try {
                                                // Final check before UI update
                                                if (!isFinishing() && !isDestroyed() && bandLogoImage != null) {
                                                    displayBandImage(bitmap);
                                                } else {
                                                    // Activity destroyed, recycle bitmap to prevent memory leak
                                                    if (!bitmap.isRecycled()) {
                                                        bitmap.recycle();
                                                    }
                                                }
                                            } catch (Exception e) {
                                                Log.e("ProgressiveLoading", "Phase 5: Error updating UI for " + bandName, e);
                                            }
                                        }
                                    });
                                } else {
                                    // Activity destroyed, recycle bitmap to prevent memory leak
                                    bitmap.recycle();
                                }
                            }
                        } else {
                            Log.w("ProgressiveLoading", "Phase 5: Invalid downloaded image dimensions for " + bandName + 
                                  " (" + options.outWidth + "x" + options.outHeight + ")");
                        }
                    }
                } else {
                    Log.d("ProgressiveLoading", "Phase 5: Image download failed for " + bandName);
                }
            } else {
                Log.d("ProgressiveLoading", "Phase 5: Image already cached, skipping download for " + bandName);
            }
        } catch (OutOfMemoryError oom) {
            Log.e("ProgressiveLoading", "Phase 5: OutOfMemoryError downloading image for " + bandName, oom);
            // Force garbage collection to try to recover
            System.gc();
        } catch (Exception e) {
            Log.e("ProgressiveLoading", "Phase 5: Error downloading image for " + bandName, e);
        }
    }
    
    /**
     * PHASE 6: Final UI cleanup (CRASH-SAFE with lifecycle checks)
     */
    private void finalizeUILoading() {
        try {
            Log.d("ProgressiveLoading", "Phase 6: Finalizing UI for " + bandName);
            
            // CRASH PREVENTION: Check activity state before UI update
            if (!isFinishing() && !isDestroyed()) {
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            // Final check before UI update
                            if (!isFinishing() && !isDestroyed() && loadingProgressBar != null) {
                                loadingProgressBar.setVisibility(View.GONE);
                                Log.d("ProgressiveLoading", "Progressive loading complete for " + bandName);
                            }
                        } catch (Exception e) {
                            Log.e("ProgressiveLoading", "Phase 6: Error finalizing UI for " + bandName, e);
                        }
                    }
                });
            } else {
                Log.d("ProgressiveLoading", "Phase 6: Activity destroyed, skipping finalization for " + bandName);
            }
        } catch (Exception e) {
            Log.e("ProgressiveLoading", "Phase 6: Error in finalization for " + bandName, e);
        }
    }
    
    /**
     * Helper method to display band image with proper scaling (CRASH-SAFE)
     */
    private void displayBandImage(Bitmap bitmap) {
        try {
            // CRASH PREVENTION: Null checks before processing
            if (bitmap == null || bitmap.isRecycled() || bandLogoImage == null) {
                Log.w("displayBandImage", "Invalid bitmap or view for " + bandName);
                return;
            }
            
            bandLogoImage.setImageBitmap(bitmap);
            bandLogoImage.setVisibility(View.VISIBLE);
            
            // Set appropriate scaling based on aspect ratio
            int width = bitmap.getWidth();
            int height = bitmap.getHeight();
            if (width > 0 && height > 0) {
                int ratio = width / height;
                if (ratio > 5) {
                    // Wide image - use width constraint
                    bandLogoImage.getLayoutParams().width = (int) (getResources().getDisplayMetrics().widthPixels * 0.7);
                    bandLogoImage.getLayoutParams().height = ViewGroup.LayoutParams.WRAP_CONTENT;
                } else {
                    // Tall or square image - use height constraint  
                    bandLogoImage.getLayoutParams().width = ViewGroup.LayoutParams.WRAP_CONTENT;
                    bandLogoImage.getLayoutParams().height = (int) (getResources().getDisplayMetrics().heightPixels * 0.1);
                }
            }
            Log.d("displayBandImage", "Image displayed successfully for " + bandName);
        } catch (Exception e) {
            Log.e("displayBandImage", "Error displaying image for " + bandName, e);
            // CRASH PREVENTION: Recycle bitmap if there's an error to prevent memory leaks
            if (bitmap != null && !bitmap.isRecycled()) {
                bitmap.recycle();
            }
        }
    }
    
    /**
     * WEBVIEW EXIT FIX: Immediately restores cached image to prevent disappearing after WebView exit.
     * This method runs synchronously on the main thread to instantly restore the image that was already displayed.
     */
    private void restoreCachedImageImmediately() {
        try {
            Log.d("WebViewImageFix", "Attempting to restore cached image for " + bandName);
            
            // Check if we have a cached image file
            ImageHandler imageHandler = new ImageHandler(bandName);
            java.net.URI imageURI = imageHandler.getImage();
            
            if (imageURI != null) {
                java.io.File imageFile = new java.io.File(imageURI);
                if (imageFile.exists() && imageFile.length() > 0) {
                    Log.d("WebViewImageFix", "Found cached image file, loading immediately");
                    
                    // Use safe bitmap decoding with memory limits (same as progressive loading)
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inJustDecodeBounds = true;
                    BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
                    
                    // Check if image dimensions are valid and calculate appropriate sample size
                    if (options.outWidth > 0 && options.outHeight > 0) {
                        
                        // Calculate sample size to fit within memory constraints (max 2048x2048)
                        int maxDimension = 2048;
                        int sampleSize = 1;
                        
                        if (options.outWidth > maxDimension || options.outHeight > maxDimension) {
                            int widthRatio = options.outWidth / maxDimension;
                            int heightRatio = options.outHeight / maxDimension;
                            sampleSize = Math.max(widthRatio, heightRatio);
                            Log.d("WebViewImageFix", "Scaling down large cached image for " + bandName + 
                                  " (" + options.outWidth + "x" + options.outHeight + ") with sample size " + sampleSize);
                        }
                        
                        options.inJustDecodeBounds = false;
                        options.inSampleSize = sampleSize;
                        options.inPreferredConfig = Bitmap.Config.RGB_565; // Use less memory
                        
                        Bitmap bitmap = BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
                        if (bitmap != null && !bitmap.isRecycled() && bandLogoImage != null) {
                            displayBandImage(bitmap);
                            Log.d("WebViewImageFix", "Cached image restored successfully for " + bandName);
                        }
                    } else {
                        Log.w("WebViewImageFix", "Invalid cached image dimensions for " + bandName + 
                              " (" + options.outWidth + "x" + options.outHeight + ")");
                    }
                } else {
                    Log.d("WebViewImageFix", "No cached image file found for " + bandName);
                }
            } else {
                Log.d("WebViewImageFix", "No cached image URI for " + bandName);
            }
        } catch (OutOfMemoryError oom) {
            Log.e("WebViewImageFix", "OutOfMemoryError restoring cached image for " + bandName, oom);
            System.gc(); // Request garbage collection
        } catch (Exception e) {
            Log.e("WebViewImageFix", "Error restoring cached image for " + bandName, e);
        }
    }
    
    // ==================== END PROGRESSIVE LOADING ====================

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);

        // Checks the orientation of the screen
        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            orientation = "landscape";
        } else if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
            orientation = "portrait";
        }

        Log.d("RotationChange", "'" + orientation + "'");

        if (inLink == false){
            recreate();
        } else {
            // If we're in WebView mode during rotation, exit back to details
            Log.d("WebView", "Configuration changed while in WebView, exiting to details");
            exitInAppWebView();
        }
    }

    private void changeBand(String currentBand, String direction){
        BandInfo.setSelectedBand(currentBand);
        
        // Update the band name and refresh content with slide animation
        bandName = currentBand;
        
        // CRITICAL FIX: Recreate bandHandler with new band name so descriptions update properly
        bandHandler = new BandNotes(bandName);
        
        // Update activity title immediately to show new band name
        setTitle(bandName);
        
        // Update band name TextView in the UI immediately
        updateBandNameInUI();
        
        animateContentTransition(direction);
    }
    
    /**
     * Animates the transition between band content with smooth slide effects
     */
    private void animateContentTransition(String direction) {
        if (contentContainer == null) {
            // Fallback to progressive loading if container not available
            Log.d("SwipeAnimation", "Container not available, using progressive loading for " + bandName);
            loadAllContentProgressively();
            return;
        }
        
        Log.d("SwipeAnimation", "Starting smooth slide animation for direction: " + direction);
        
        // Determine slide direction based on swipe
        boolean slideLeft = direction.equals("Next");
        float screenWidth = contentContainer.getWidth();
        
        // Use ViewPropertyAnimator for smoother, hardware-accelerated animations
        contentContainer.animate()
            .translationX(slideLeft ? -screenWidth : screenWidth)
            .alpha(0.7f) // Slight fade during transition
            .setDuration(280)
            .setInterpolator(new AccelerateDecelerateInterpolator())
            .withEndAction(new Runnable() {
                @Override
                public void run() {
                    Log.d("SwipeAnimation", "Slide-out completed, updating content with progressive loading");
                    
                    // FIXED: Use progressive loading instead of heavy refresh
                    loadAllContentProgressively();
                    
                    // Set up for slide-in from opposite direction
                    contentContainer.setTranslationX(slideLeft ? screenWidth : -screenWidth);
                    contentContainer.setAlpha(0.7f);
                    
                    // Animate slide-in with easing
                    contentContainer.animate()
                        .translationX(0f)
                        .alpha(1.0f)
                        .setDuration(280)
                        .setInterpolator(new DecelerateInterpolator(1.2f))
                        .withEndAction(new Runnable() {
                            @Override
                            public void run() {
                                Log.d("SwipeAnimation", "Slide-in animation completed");
                                // Ensure final state is clean
                                contentContainer.setTranslationX(0f);
                                contentContainer.setAlpha(1.0f);
                                
                                // Ensure title and band name TextView are updated after animation completes
                                setTitle(bandName);
                                updateBandNameInUI();
                            }
                        })
                        .start();
                }
            })
            .start();
    }
    
    /**
     * Alternative animation method using traditional Animation classes for compatibility
     */
    private void animateContentTransitionClassic(String direction) {
        if (contentContainer == null) {
            Log.d("SwipeAnimation", "Container not available, using progressive loading for " + bandName);
            loadAllContentProgressively();
            return;
        }
        
        Log.d("SwipeAnimation", "Starting classic slide animation for direction: " + direction);
        
        // Determine slide direction based on swipe
        boolean slideLeft = direction.equals("Next");
        
        // Create slide-out animation (current content slides out)
        TranslateAnimation slideOut = new TranslateAnimation(
            Animation.RELATIVE_TO_SELF, 0.0f,           // Start X
            Animation.RELATIVE_TO_SELF, slideLeft ? -1.0f : 1.0f, // End X
            Animation.RELATIVE_TO_SELF, 0.0f,           // Start Y  
            Animation.RELATIVE_TO_SELF, 0.0f            // End Y
        );
        slideOut.setDuration(250);
        slideOut.setFillAfter(true);
        
        // Create slide-in animation (new content slides in)
        TranslateAnimation slideIn = new TranslateAnimation(
            Animation.RELATIVE_TO_SELF, slideLeft ? 1.0f : -1.0f, // Start X (opposite direction)
            Animation.RELATIVE_TO_SELF, 0.0f,           // End X
            Animation.RELATIVE_TO_SELF, 0.0f,           // Start Y
            Animation.RELATIVE_TO_SELF, 0.0f            // End Y
        );
        slideIn.setDuration(250);
        
        // Set up animation listener to update content at the right time
        slideOut.setAnimationListener(new Animation.AnimationListener() {
            @Override
            public void onAnimationStart(Animation animation) {
                Log.d("SwipeAnimation", "Classic slide-out animation started");
            }
            
            @Override
            public void onAnimationEnd(Animation animation) {
                Log.d("SwipeAnimation", "Classic slide-out animation ended, updating content with progressive loading");
                // FIXED: Use progressive loading instead of heavy refresh
                loadAllContentProgressively();
                contentContainer.startAnimation(slideIn);
            }
            
            @Override
            public void onAnimationRepeat(Animation animation) {}
        });
        
        slideIn.setAnimationListener(new Animation.AnimationListener() {
            @Override
            public void onAnimationStart(Animation animation) {
                Log.d("SwipeAnimation", "Classic slide-in animation started");
            }
            
            @Override
            public void onAnimationEnd(Animation animation) {
                Log.d("SwipeAnimation", "Classic slide-in animation completed");
                contentContainer.clearAnimation();
                
                // Ensure title and band name TextView are updated after animation completes
                setTitle(bandName);
                updateBandNameInUI();
            }
            
            @Override
            public void onAnimationRepeat(Animation animation) {}
        });
        
        // Start the slide-out animation
        contentContainer.startAnimation(slideOut);
    }


    private void nextRecord(String direction){

        Log.d("SwipeNavigation", "nextRecord called with direction: " + direction + 
              ", current position: " + staticVariables.currentListPosition + 
              ", list size: " + staticVariables.currentListForDetails.size());

        String directionMessage = "";
        String currentBand = "";
        String oldBandValue = staticVariables.currentListForDetails.get(staticVariables.currentListPosition);

        if (staticVariables.currentListPosition == 0 && direction.equals("Previous")){
            Log.d("SwipeNavigation", "Already at start of list");
            HelpMessageHandler.showMessage(getResources().getString(R.string.AlreadyAtStart));
            return;

        } else if (staticVariables.currentListPosition >= (staticVariables.currentListForDetails.size() - 1) &&
                    direction.equals("Next")) {
            Log.d("SwipeNavigation", "Already at end of list");
            HelpMessageHandler.showMessage(getResources().getString(R.string.EndofList));
            return;

        } else if (direction.equals("Next")){
            staticVariables.currentListPosition = staticVariables.currentListPosition + 1;
            directionMessage = getResources().getString(R.string.Next);

        } else {
            staticVariables.currentListPosition = staticVariables.currentListPosition - 1;
            directionMessage = getResources().getString(R.string.Previous);
        }

        //sometime the list is not as long as is advertised
        try {
            currentBand = staticVariables.currentListForDetails.get(staticVariables.currentListPosition);
            Log.d("NextRecord", "Old Record is " + oldBandValue + " new record is " + currentBand);
            if (oldBandValue.equals(currentBand)){
                nextRecord(direction);
                return;
            }
        } catch (Exception error){
            staticVariables.currentListPosition = staticVariables.currentListPosition - 1;
            HelpMessageHandler.showMessage(getResources().getString(R.string.EndofList));
            return;
        }

        Log.d("SwipeNavigation", "Navigation successful to: " + currentBand + " at position: " + staticVariables.currentListPosition);
        HelpMessageHandler.showMessage(directionMessage + " " + currentBand);
        changeBand(currentBand, direction);

    }
    
    /**
     * Updates the band name TextView in the UI
     */
    private void updateBandNameInUI() {
        try {
            TextView bandNameText = findViewById(R.id.band_name_text);
            if (bandNameText != null && bandName != null) {
                bandNameText.setText(bandName);
                Log.d("UIUpdate", "Band name TextView updated to: " + bandName);
            }
        } catch (Exception e) {
            Log.e("UIUpdate", "Error updating band name TextView", e);
        }
    }
    
    /**
     * Initializes the native Android view content instead of WebView
     */
    private void initializeNativeContent() {
        Log.w("PerformanceTrack", "WARNING: Using HEAVY loading path - this causes delays!");
        Log.d("initializeNativeContent", "Start"); 
        
        // Initialize all view references
        bandNameText = findViewById(R.id.band_name_text);
        bandLogoImage = findViewById(R.id.band_logo_image);
        scheduleSection = findViewById(R.id.schedule_section);
        linksSection = findViewById(R.id.links_section);
        linksIconContainer = findViewById(R.id.links_icon_container);
        extraDataSection = findViewById(R.id.extra_data_section);
        userNotesSection = findViewById(R.id.user_notes_section);
        userNotesText = findViewById(R.id.user_notes_text);
        linksLabel = findViewById(R.id.links_label);
        
        // Link buttons
        websiteLink = findViewById(R.id.website_link);
        metalArchivesLink = findViewById(R.id.metal_archives_link);
        wikipediaLink = findViewById(R.id.wikipedia_link);
        youtubeLink = findViewById(R.id.youtube_link);
        
        // Extra data views
        countryValue = findViewById(R.id.country_value);
        genreValue = findViewById(R.id.genre_value);
        lastCruiseValue = findViewById(R.id.last_cruise_value);
        noteValue = findViewById(R.id.note_value);
        countryRow = findViewById(R.id.country_row);
        genreRow = findViewById(R.id.genre_row);
        lastCruiseRow = findViewById(R.id.last_cruise_row);
        noteRow = findViewById(R.id.note_row);
        
        // Ranking buttons
        unknownButton = findViewById(R.id.unknown_button);
        mustButton = findViewById(R.id.must_button);
        mightButton = findViewById(R.id.might_button);
        wontButton = findViewById(R.id.wont_button);
        rankingIcon = findViewById(R.id.ranking_icon);
        
        // Other components
        loadingProgressBar = findViewById(R.id.loading_progress_bar);
        contentScrollView = findViewById(R.id.content_scroll_view);
        contentContainer = findViewById(R.id.content_container);
        
        // Initialize translation components
        initializeTranslationComponents();
        
        // Swipe gestures are handled at the activity level via dispatchTouchEvent
        
        // Set up click listeners
        setupNativeClickListeners();
        
        // Populate content
        populateNativeContent();
        
        loadingProgressBar.setVisibility(View.GONE);
        Log.d("initializeNativeContent", "Done");
    }
    
    /**
     * IMMEDIATE LOADING: Initialize UI components only with minimal processing.
     * NO data processing or heavy operations - screen loads instantly.
     */
    private void initializeUIComponentsOnly() {
        Log.d("initializeUIComponents", "Starting immediate UI setup");
        
        // Initialize all view references (fast findViewById calls)
        bandNameText = findViewById(R.id.band_name_text);
        bandLogoImage = findViewById(R.id.band_logo_image);
        scheduleSection = findViewById(R.id.schedule_section);
        linksSection = findViewById(R.id.links_section);
        linksIconContainer = findViewById(R.id.links_icon_container);
        extraDataSection = findViewById(R.id.extra_data_section);
        userNotesSection = findViewById(R.id.user_notes_section);
        userNotesText = findViewById(R.id.user_notes_text);
        linksLabel = findViewById(R.id.links_label);
        
        // Link buttons
        websiteLink = findViewById(R.id.website_link);
        metalArchivesLink = findViewById(R.id.metal_archives_link);
        wikipediaLink = findViewById(R.id.wikipedia_link);
        youtubeLink = findViewById(R.id.youtube_link);
        
        // Extra data views
        countryValue = findViewById(R.id.country_value);
        genreValue = findViewById(R.id.genre_value);
        lastCruiseValue = findViewById(R.id.last_cruise_value);
        noteValue = findViewById(R.id.note_value);
        countryRow = findViewById(R.id.country_row);
        genreRow = findViewById(R.id.genre_row);
        lastCruiseRow = findViewById(R.id.last_cruise_row);
        noteRow = findViewById(R.id.note_row);
        
        // Ranking buttons
        unknownButton = findViewById(R.id.unknown_button);
        mustButton = findViewById(R.id.must_button);
        mightButton = findViewById(R.id.might_button);
        wontButton = findViewById(R.id.wont_button);
        rankingIcon = findViewById(R.id.ranking_icon);
        
        // Other components
        loadingProgressBar = findViewById(R.id.loading_progress_bar);
        contentScrollView = findViewById(R.id.content_scroll_view);
        contentContainer = findViewById(R.id.content_container);
        
        // Set up click listeners (fast)
        setupNativeClickListeners();
        
        // IMMEDIATE: Show band name and loading state
        bandNameText.setText(bandName);
        bandLogoImage.setVisibility(View.GONE); // Will load progressively
        loadingProgressBar.setVisibility(View.VISIBLE);
        
        // Clear dynamic content sections - will be populated progressively
        scheduleSection.removeAllViews();
        // NOTE: Don't clear linksIconContainer - it contains static link icons that are managed by findViewById
        
        // Show loading placeholders for key sections
        if (noteValue != null) {
            noteValue.setText("Loading notes...");
            // Apply font size preference
            applyNoteFontSize();
        }
        
        Log.d("initializeUIComponents", "Immediate UI setup complete - screen ready");
    }
    
    /**
     * Applies the font size preference to the note TextView.
     * When Note Font Size Large is enabled, increases font size by 2sp from default.
     */
    private void applyNoteFontSize() {
        if (noteValue != null && staticVariables.preferences != null) {
            boolean useLargeFont = staticVariables.preferences.getNoteFontSizeLarge();
            
            // Default font size for notes (can be adjusted if needed)
            float defaultFontSize = 16f; // sp
            float largeFontSize = defaultFontSize + 2f; // +2sp as requested
            
            float fontSize = useLargeFont ? largeFontSize : defaultFontSize;
            noteValue.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, fontSize);
            
            Log.d("NoteFontSize", "Applied font size: " + fontSize + "sp (Large font: " + useLargeFont + ")");
        }
    }
    
    /**
     * Sets up swipe gesture detection that works properly with ScrollView
     */
    private void setupSwipeGestureListener() {
        final GestureDetector gestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            private static final int SWIPE_MIN_DISTANCE = 120;
            private static final int SWIPE_MAX_OFF_PATH = 250;
            private static final int SWIPE_THRESHOLD_VELOCITY = 200;

            @Override
            public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
                if (e1 == null || e2 == null) return false;
                
                float deltaX = e2.getX() - e1.getX();
                float deltaY = e2.getY() - e1.getY();
                
                Log.d("SwipeGesture", "onFling - deltaX: " + deltaX + ", deltaY: " + deltaY + 
                      ", velocityX: " + velocityX + ", velocityY: " + velocityY);
                
                // Check if this is primarily a horizontal swipe
                if (Math.abs(deltaX) > Math.abs(deltaY) && 
                    Math.abs(deltaY) < SWIPE_MAX_OFF_PATH && 
                    Math.abs(deltaX) > SWIPE_MIN_DISTANCE && 
                    Math.abs(velocityX) > SWIPE_THRESHOLD_VELOCITY) {
                    
                    if (deltaX > 0) {
                        Log.d("SwipeGesture", "Right swipe detected - moving to previous record");
                        nextRecord("Previous");
                    } else {
                        Log.d("SwipeGesture", "Left swipe detected - moving to next record");
                nextRecord("Next");
            }
                    return true;
                }
                return false;
            }
        });

        // Apply the gesture detector to the main scroll view
        contentScrollView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                // Let the gesture detector try to handle the event first
                boolean gestureHandled = gestureDetector.onTouchEvent(event);
                
                // If no horizontal swipe was detected, let the ScrollView handle it normally
                if (!gestureHandled) {
                    // Return false to allow ScrollView to handle vertical scrolling
                    return false;
                }
                
                return true; // Consumed the horizontal swipe event
            }
        });
        
        Log.d("SwipeGesture", "Swipe gesture listener set up successfully");
    }
    
    /**
     * Initializes the main swipe gesture detector for the activity
     */
    private void initializeSwipeGestureDetector() {
        swipeGestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            private static final int SWIPE_MIN_DISTANCE = 100;
            private static final int SWIPE_MAX_OFF_PATH = 300;
            private static final int SWIPE_THRESHOLD_VELOCITY = 150;

            @Override
            public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
                if (e1 == null || e2 == null) return false;
                
                // Don't process swipes if we're in WebView mode
                if (inLink && inAppWebView != null) {
                    return false;
                }
                
                float deltaX = e2.getX() - e1.getX();
                float deltaY = e2.getY() - e1.getY();
                
                Log.d("ActivitySwipe", "onFling - deltaX: " + deltaX + ", deltaY: " + deltaY + 
                      ", velocityX: " + velocityX + ", velocityY: " + velocityY);
                
                // Check if this is primarily a horizontal swipe
                if (Math.abs(deltaX) > Math.abs(deltaY) && 
                    Math.abs(deltaY) < SWIPE_MAX_OFF_PATH && 
                    Math.abs(deltaX) > SWIPE_MIN_DISTANCE && 
                    Math.abs(velocityX) > SWIPE_THRESHOLD_VELOCITY) {
                    
                    // Add haptic feedback and visual feedback for swipe gesture
                    provideSwipeFeedback();
                    
                    if (deltaX > 0) {
                        Log.d("ActivitySwipe", "Right swipe detected - moving to previous record");
                nextRecord("Previous");
                    } else {
                        Log.d("ActivitySwipe", "Left swipe detected - moving to next record");
                        nextRecord("Next");
                    }
                    return true;
                }
                return false;
            }
        });
        
        Log.d("ActivitySwipe", "Activity-level swipe gesture detector initialized");
    }
    
    /**
     * Provides haptic and visual feedback when a swipe gesture is detected
     */
    private void provideSwipeFeedback() {
        // Haptic feedback
        try {
            Vibrator vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE));
                } else {
                    vibrator.vibrate(50);
                }
            }
        } catch (Exception e) {
            Log.w("SwipeFeedback", "Could not provide haptic feedback", e);
        }
        
        // Visual feedback - subtle scale animation with easing
        if (contentContainer != null) {
            contentContainer.animate()
                .scaleX(0.97f)
                .scaleY(0.97f)
                .setDuration(120)
                .setInterpolator(new DecelerateInterpolator(1.5f))
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        contentContainer.animate()
                            .scaleX(1.0f)
                            .scaleY(1.0f)
                            .setDuration(150)
                            .setInterpolator(new DecelerateInterpolator(1.0f))
                            .start();
                    }
                })
                .start();
        }
    }
    
    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        // Only process swipes when we're showing band details (not in WebView)
        if (!inLink && swipeGestureDetector != null) {
            boolean swipeHandled = swipeGestureDetector.onTouchEvent(event);
            if (swipeHandled) {
                return true; // Consume the swipe event
            }
        }
        
        // Let the normal touch event processing continue
        return super.dispatchTouchEvent(event);
    }
    
    /**
     * Sets up click listeners for native views
     */
    private void setupNativeClickListeners() {
        // Link click listeners
        websiteLink.setOnClickListener(v -> handleLinkClick("webPage"));
        metalArchivesLink.setOnClickListener(v -> handleLinkClick("metalArchives"));
        wikipediaLink.setOnClickListener(v -> handleLinkClick("wikipedia"));
        youtubeLink.setOnClickListener(v -> handleLinkClick("youTube"));
        
        // Ranking button click listeners
        unknownButton.setOnClickListener(v -> handleRankingClick(staticVariables.unknownKey));
        mustButton.setOnClickListener(v -> handleRankingClick(staticVariables.mustSeeKey));
        mightButton.setOnClickListener(v -> handleRankingClick(staticVariables.mightSeeKey));
        wontButton.setOnClickListener(v -> handleRankingClick(staticVariables.wontSeeKey));
        
        // Translation button click listener is handled in initializeTranslationComponents()
        
        // Notes edit listener - make note content double-tap in native view
        if (noteValue != null) {
            setupNoteDoubleTapListener();
        }
        
        // Set online status for links
        boolean isOnline = OnlineStatus.isOnline();
        websiteLink.setEnabled(isOnline);
        metalArchivesLink.setEnabled(isOnline);
        wikipediaLink.setEnabled(isOnline);
        youtubeLink.setEnabled(isOnline);
        
        if (!isOnline) {
            websiteLink.setAlpha(0.5f);
            metalArchivesLink.setAlpha(0.5f);
            wikipediaLink.setAlpha(0.5f);
            youtubeLink.setAlpha(0.5f);
        }
    }
    
    /**
     * Handles link clicks for native views
     */
    private void handleLinkClick(String linkType) {
        Log.d("webLink", "Going to weblinks kind of " + linkType);
        staticVariables.webHelpMessage = setWebHelpMessage(linkType);
        Log.d("webHelpMessage", staticVariables.webHelpMessage);
        inLink = true;

        String webUrl = getWebUrl(linkType);
        Log.d("webLink", "Going to weblinks Start " + webUrl);

        // Show in-app WebView for external link browsing
        showInAppWebView(webUrl, linkType);
    }
    

    
    /**
     * Shows a web URL in an in-app WebView using the normal screen area
     */
    private void showInAppWebView(String url, String linkType) {
        Log.d("WebView", "showInAppWebView() called with URL: " + url);
        // Create container for WebView with progress bar
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setBackgroundColor(Color.BLACK); // Match app theme
        container.setLayoutParams(new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            ViewGroup.LayoutParams.MATCH_PARENT
        ));
        
        // Ensure container fits within system windows (respects status bar, navigation bar, etc.)
        container.setFitsSystemWindows(true);
        
        // Create progress bar
        webViewProgressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        webViewProgressBar.setLayoutParams(new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            8  // Fixed height for progress bar
        ));
        webViewProgressBar.setIndeterminate(false);
        webViewProgressBar.setMax(100);
        webViewProgressBar.setProgress(0);
        webViewProgressBar.setVisibility(View.VISIBLE);
        container.addView(webViewProgressBar);
        
        // Create WebView - takes remaining space in LinearLayout
        inAppWebView = new WebView(this);
        LinearLayout.LayoutParams webViewParams = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            0  // Height 0 with weight 1 = takes remaining space
        );
        webViewParams.weight = 1.0f;  // Takes all remaining vertical space
        inAppWebView.setLayoutParams(webViewParams);
        inAppWebView.getSettings().setJavaScriptEnabled(true);
        inAppWebView.getSettings().setLoadWithOverviewMode(true);
        inAppWebView.getSettings().setUseWideViewPort(true);
        inAppWebView.getSettings().setBuiltInZoomControls(true);
        inAppWebView.getSettings().setDisplayZoomControls(false);
        inAppWebView.getSettings().setDomStorageEnabled(true);
        inAppWebView.getSettings().setSupportZoom(true);
        
        // Enable history tracking for proper back navigation
        inAppWebView.getSettings().setCacheMode(WebSettings.LOAD_DEFAULT);
        
        // SECURITY FIX: Restrict file access to prevent cross-app scripting
        inAppWebView.getSettings().setAllowFileAccess(false);  // Disable file:// URL access
        inAppWebView.getSettings().setAllowContentAccess(true);  // Keep content:// access
        
        // SECURITY FIX: Prevent universal file access (API 16+)
        if (android.os.Build.VERSION.SDK_INT >= 16) {
            inAppWebView.getSettings().setAllowUniversalAccessFromFileURLs(false);
            inAppWebView.getSettings().setAllowFileAccessFromFileURLs(false);
        }
        
        // Enable navigation history
        inAppWebView.clearHistory(); // Start with clean history
        Log.d("WebView", "WebView history cleared, ready for navigation");
        
        // Set WebView client to handle page loading
        inAppWebView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                Log.d("WebView", "Page started: " + url + ", canGoBack: " + view.canGoBack());
                webViewProgressBar.setVisibility(View.VISIBLE);
                if (!staticVariables.webHelpMessage.isEmpty()) {
                    HelpMessageHandler.showMessage(staticVariables.webHelpMessage);
                    staticVariables.webHelpMessage = "";
                }
            }
            
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                Log.d("WebView", "Page finished: " + url + ", canGoBack: " + view.canGoBack());
                webViewProgressBar.setVisibility(View.GONE);
            }
            
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                Log.d("WebView", "Loading URL: " + url);
                // SECURITY FIX: Validate URL before allowing navigation
                // Inline URL validation to avoid method resolution issues
                boolean urlSafe = false;
                if (url != null && !url.trim().isEmpty()) {
                    try {
                        java.net.URI uri = java.net.URI.create(url.trim());
                        String scheme = uri.getScheme();
                        if (scheme != null) {
                            scheme = scheme.toLowerCase();
                            if (scheme.equals("http") || scheme.equals("https")) {
                                String lowerUrl = url.toLowerCase();
                                if (!lowerUrl.contains("javascript:") && 
                                    !lowerUrl.contains("data:") && 
                                    !lowerUrl.contains("file:") &&
                                    !lowerUrl.contains("content:") &&
                                    !lowerUrl.contains("android_asset:") &&
                                    !lowerUrl.contains("android_res:")) {
                                    String host = uri.getHost();
                                    if (host != null && !host.trim().isEmpty() &&
                                        !host.equals("localhost") && 
                                        !host.equals("127.0.0.1") && 
                                        !host.startsWith("192.168.") && 
                                        !host.startsWith("10.") && 
                                        !host.startsWith("172.")) {
                                        urlSafe = true;
                                    }
                                }
                            }
                        }
                    } catch (Exception e) {
                        Log.w("WebView", "URL validation failed: " + e.getMessage());
                    }
                }
                
                if (urlSafe) {
                    // Allow the WebView to handle the URL normally for proper history tracking
                    return false;
                } else {
                    Log.w("WebView", "Blocked potentially unsafe URL: " + url);
                    Toast.makeText(showBandDetails.this, "URL blocked for security reasons", Toast.LENGTH_SHORT).show();
                    return true; // Block the navigation
                }
            }
        });
        
        // Set WebChrome client for progress updates
        inAppWebView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                webViewProgressBar.setProgress(newProgress);
                if (newProgress == 100) {
                    webViewProgressBar.setVisibility(View.GONE);
                }
            }
            
            @Override
            public void onReceivedTitle(WebView view, String title) {
                super.onReceivedTitle(view, title);
                // Update activity title with web page title
                if (title != null && !title.isEmpty()) {
                    setTitle(title);
                }
            }
        });
        
        container.addView(inAppWebView);
        
        // Replace current content with WebView (respects system UI)
        setContentView(container);
        
        // Load the URL
        Log.d("WebView", "Loading initial URL: " + url);
        // SECURITY FIX: Validate URL before loading - inline validation
        boolean urlSafe = false;
        if (url != null && !url.trim().isEmpty()) {
            try {
                java.net.URI uri = java.net.URI.create(url.trim());
                String scheme = uri.getScheme();
                if (scheme != null) {
                    scheme = scheme.toLowerCase();
                    if (scheme.equals("http") || scheme.equals("https")) {
                        String lowerUrl = url.toLowerCase();
                        if (!lowerUrl.contains("javascript:") && 
                            !lowerUrl.contains("data:") && 
                            !lowerUrl.contains("file:") &&
                            !lowerUrl.contains("content:") &&
                            !lowerUrl.contains("android_asset:") &&
                            !lowerUrl.contains("android_res:")) {
                            String host = uri.getHost();
                            if (host != null && !host.trim().isEmpty() &&
                                !host.equals("localhost") && 
                                !host.equals("127.0.0.1") && 
                                !host.startsWith("192.168.") && 
                                !host.startsWith("10.") && 
                                !host.startsWith("172.")) {
                                urlSafe = true;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                Log.w("WebView", "URL validation failed: " + e.getMessage());
            }
        }
        
        if (urlSafe) {
            inAppWebView.loadUrl(url);
        } else {
            Log.w("WebView", "Blocked unsafe initial URL: " + url);
            Toast.makeText(this, "URL blocked for security reasons", Toast.LENGTH_SHORT).show();
            exitInAppWebView(); // Exit back to details view
        }
        
        // Set flag that we're in web link mode
        inLink = true;
        Log.d("WebView", "inLink flag set to true");
    }
    
    /**
     * Debug method to log WebView history state
     */
    private void debugWebViewHistory() {
        if (inAppWebView != null) {
            try {
                boolean canGoBack = inAppWebView.canGoBack();
                boolean canGoForward = inAppWebView.canGoForward();
                String currentUrl = inAppWebView.getUrl();
                
                Log.d("WebView", "=== WebView History Debug ===");
                Log.d("WebView", "Current URL: " + currentUrl);
                Log.d("WebView", "Can go back: " + canGoBack);
                Log.d("WebView", "Can go forward: " + canGoForward);
                Log.d("WebView", "============================");
            } catch (Exception e) {
                Log.e("WebView", "Error debugging WebView history", e);
            }
        }
    }
    
    /**
     * Exits WebView and returns to band details content
     */
    private void exitInAppWebView() {
        Log.d("WebView", "exitInAppWebView() called");
        
        if (inAppWebView != null) {
            Log.d("WebView", "Destroying WebView");
            inAppWebView.destroy();
            inAppWebView = null;
        }
        
        if (webViewProgressBar != null) {
            webViewProgressBar = null;
        }
        
        // Reset link state first
        inLink = false;
        
        // Reset any window modifications
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
        
        // Restore original band details content
        Log.d("WebView", "Restoring band details content");
            setContentView(R.layout.band_details_native);
        
        // Reinitialize components after setContentView
        initializeTranslationComponents();
        
        // Reinitialize swipe gesture detector
        initializeSwipeGestureDetector();
        
        // IMMEDIATE LOADING: Use fast UI setup instead of heavy initialization
        initializeUIComponentsOnly();
        
        // WEBVIEW EXIT FIX: Immediately restore cached image if available to prevent disappearing image
        restoreCachedImageImmediately();
        
        // PROGRESSIVE LOADING: Load content in background (content likely cached by now)
        loadAllContentProgressively();
        
        // Reset activity title
        setTitle(bandName);
        
        Log.d("WebView", "exitInAppWebView() completed");
    }

    
    /**
     * Gets user-friendly title for link type
     */
    private String getLinkTypeTitle(String linkType) {
        switch (linkType) {
            case "webPage":
                return "Official Website";
            case "metalArchives":
                return "Metal Archives";
            case "wikipedia":
                return "Wikipedia";
            case "youTube":
                return "YouTube";
            default:
                return "Web Link";
        }
    }
    
    /**
     * Handles ranking button clicks
     */
    private void handleRankingClick(String rankingKey) {
        // Save the ranking
        rankStore.saveBandRanking(BandInfo.getSelectedBand(), resolveValue(rankingKey));
        
        // Update the button states immediately without restarting activity
        setupRankingButtons();
    }
    
    /**
     * Handles translation button clicks
     */
    private void handleTranslationButtonClick() {
        Log.d("Translation", "=== TRANSLATION BUTTON CLICKED ===");
        
        if (translator == null) {
            Log.e("Translation", "Translator not initialized");
            showToast("Translation not available");
            return;
        }
        
        String currentText = noteValue.getText().toString();
        Log.d("Translation", "Current text length: " + currentText.length());
        Log.d("Translation", "Current text preview: " + (currentText.length() > 100 ? currentText.substring(0, 100) + "..." : currentText));
        
        // Check if we need to translate or restore
        boolean isTranslated = translator.isCurrentTextTranslated(currentText, originalEnglishText);
        Log.d("Translation", "Is current text translated: " + isTranslated);
        
        if (isTranslated) {
            // Restore to English
            Log.d("Translation", "Restoring to English");
            if (originalEnglishText != null && !originalEnglishText.isEmpty()) {
                noteValue.setText(originalEnglishText);
                
                // Save user preference for English
                String bandName = BandInfo.getSelectedBand();
                translator.saveUserLanguagePreference(bandName, "en");
                
                updateTranslationButton();
                String toastMessage = translator.getLocalizedRestoreCompleteMessage(translator.getCurrentLanguageCode());
                showToast(toastMessage);
            } else {
                Log.e("Translation", "No original English text stored!");
                showToast("Error: No original text available");
            }
        } else {
            // Translate to local language
            Log.d("Translation", "Starting translation process");
            originalEnglishText = currentText; // Store original
            String bandName = BandInfo.getSelectedBand();
            String languageCode = translator.getCurrentLanguageCode();
            
            Log.d("Translation", "Band name: " + bandName);
            Log.d("Translation", "Target language: " + languageCode);
            
            // Check if we have a cached translation first
            if (translator.hasCachedTranslation(bandName)) {
                Log.d("Translation", "Using cached translation for " + bandName);
            } else {
                Log.d("Translation", "No cached translation found, translating online for " + bandName);
            }
            
            translator.translateTextDirectly(currentText, languageCode, bandName, new BandDescriptionTranslator.TranslationCallback() {
                @Override
                public void onTranslationComplete(String translatedText) {
                    Log.d("Translation", "Translation completed: " + (translatedText != null ? translatedText.substring(0, Math.min(100, translatedText.length())) : "null"));
                    runOnUiThread(() -> {
                        if (translatedText != null && !translatedText.isEmpty()) {
                            currentTranslatedText = translatedText;
                            
                            // Don't apply additional formatting cleanup that might strip newlines
                            // Just add translation header 
                            String translationHeader = translator.getLocalizedTranslationHeaderText(languageCode);
                            String formattedText = translationHeader + "\n\n" + translatedText;
                            
                            // Debug: Log the final text with visible newlines
                            Log.d("Translation", "Final formatted text with newlines: " + formattedText.replace("\n", "[\\n]").substring(0, Math.min(300, formattedText.length())));
                            
                            noteValue.setText(formattedText);
                            
                            // Save user preference for translated language
                            translator.saveUserLanguagePreference(bandName, languageCode);
                            
                            updateTranslationButton();
                            
                            // Show simple toast in native language
                            String toastMessage = translator.getLocalizedTranslationCompleteMessage(languageCode);
                            showToast(toastMessage);
                        } else {
                            Log.e("Translation", "Translation returned empty result");
                            showToast("Translation failed - empty result");
                        }
                    });
                }
                
                @Override
                public void onTranslationError(String error) {
                    Log.e("Translation", "Translation error: " + error);
                    runOnUiThread(() -> {
                        showToast("Translation error: " + error);
                    });
                }
            });
        }
    }
    
    /**
     * Initializes translation components after setContentView
     */
    private void initializeTranslationComponents() {
        // Translation components
        translationButtonContainer = findViewById(R.id.translation_button_container);
        translationButton = findViewById(R.id.translation_button);
        
        Log.d("Translation", "Translation components initialized:");
        Log.d("Translation", "translationButtonContainer: " + translationButtonContainer);
        Log.d("Translation", "translationButton: " + translationButton);
        
        // Initialize translation functionality if not already done
        if (translator == null) {
            // Early check: Only initialize translator if we might need translation
            // Check device language first to avoid unnecessary initialization
            String deviceLanguage = java.util.Locale.getDefault().getLanguage();
            Log.d("Translation", "Device language: " + deviceLanguage);
            
            // Only initialize if device language is potentially supported
            if ("de".equals(deviceLanguage) || "es".equals(deviceLanguage) || "fr".equals(deviceLanguage) || 
                "pt".equals(deviceLanguage) || "da".equals(deviceLanguage) || "fi".equals(deviceLanguage)) {
                
                translator = BandDescriptionTranslator.getInstance(this);
                Log.d("Translation", "translator initialized for supported language: " + translator);
                
                // Test translation support immediately
                if (translator != null) {
                    Log.d("Translation", "Testing translation support:");
                    translator.isTranslationSupported();
                }
            } else {
                Log.d("Translation", "Device language not supported for translation, skipping initialization");
                return; // Exit early, no need to set up UI components
            }
        }
        
        // Set up click listener
        if (translationButton != null) {
            Log.d("Translation", "Setting up translation button click listener");
            translationButton.setOnClickListener(v -> {
                Log.d("Translation", "Click listener triggered!");
                handleTranslationButtonClick();
            });
        } else {
            Log.e("Translation", "Translation button is null, cannot set click listener");
        }
    }
    
    /**
     * Updates the translation button text and visibility
     */
    private void updateTranslationButton() {
        if (translator == null || translationButton == null || translationButtonContainer == null) {
            Log.d("Translation", "updateTranslationButton: Missing components - translator=" + translator + 
                  ", translationButton=" + translationButton + ", translationButtonContainer=" + translationButtonContainer);
            // Hide the button container if translation is not supported/available
            if (translationButtonContainer != null) {
                translationButtonContainer.setVisibility(View.GONE);
            }
            return;
        }
        
        // Debug logging
        String deviceLanguage = java.util.Locale.getDefault().getLanguage().toLowerCase();
        String currentLang = translator.getCurrentLanguageCode();
        boolean isSupported = translator.isTranslationSupported();
        
        Log.d("Translation", "Device language: " + deviceLanguage);
        Log.d("Translation", "Current language code: " + currentLang);
        Log.d("Translation", "Translation supported: " + isSupported);
        
        // Always show the container for now (since we know the UI works)
        Log.d("Translation", "Showing translation button container");
        translationButtonContainer.setVisibility(View.VISIBLE);
        
        // Update button text based on current state
        String currentText = noteValue.getText().toString();
        String languageCode = translator.getCurrentLanguageCode();
        
        Log.d("Translation", "Current text starts with: " + (currentText.length() > 50 ? currentText.substring(0, 50) + "..." : currentText));
        Log.d("Translation", "Is current text translated: " + translator.isCurrentTextTranslated(currentText, originalEnglishText));
        
        if (translator.isCurrentTextTranslated(currentText, originalEnglishText)) {
            String restoreText = translator.getLocalizedRestoreButtonText(languageCode);
            Log.d("Translation", "Setting restore button text: " + restoreText);
            translationButton.setText(restoreText);
            translationButton.setBackgroundColor(getResources().getColor(android.R.color.holo_orange_dark));
        } else {
            String translateText = translator.getLocalizedTranslateButtonText(languageCode);
            Log.d("Translation", "Setting translate button text: " + translateText);
            translationButton.setText(translateText);
            translationButton.setBackgroundColor(getResources().getColor(android.R.color.holo_blue_dark));
        }
    }
    
    /**
     * Auto-loads the user's preferred language for this band
     */
    private void autoLoadUserPreferredLanguage() {
        if (translator == null || !translator.isTranslationSupported()) {
            Log.d("Translation", "Translation not supported, skipping auto-load");
            return;
        }
        
        String bandName = BandInfo.getSelectedBand();
        if (bandName == null || bandName.trim().isEmpty()) {
            Log.d("Translation", "No band selected, skipping auto-load");
            return;
        }
        
        // Check if user prefers translated content for this band
        if (translator.shouldShowTranslatedContent(bandName)) {
            Log.d("Translation", "Auto-loading translated content for " + bandName);
            
            String currentText = noteValue.getText().toString();
            String languageCode = translator.getCurrentLanguageCode();
            
            // Check if we already have a cached translation
            if (translator.hasCachedTranslation(bandName)) {
                Log.d("Translation", "Loading cached translation for " + bandName);
                
                // Store original English text
                originalEnglishText = currentText;
                
                // Load cached translation directly
                translator.translateTextDirectly(currentText, languageCode, bandName, new BandDescriptionTranslator.TranslationCallback() {
                    @Override
                    public void onTranslationComplete(String translatedText) {
                        runOnUiThread(() -> {
                            if (translatedText != null && !translatedText.isEmpty()) {
                                currentTranslatedText = translatedText;
                                
                                                            // Don't apply additional formatting cleanup that might strip newlines
                            // Just add translation header
                            String translationHeader = translator.getLocalizedTranslationHeaderText(languageCode);
                            String formattedText = translationHeader + "\n\n" + translatedText;
                            
                            // Debug: Log the final text with visible newlines
                            Log.d("Translation", "Auto-load final text with newlines: " + formattedText.replace("\n", "[\\n]").substring(0, Math.min(300, formattedText.length())));
                            
                            noteValue.setText(formattedText);
                                
                                updateTranslationButton();
                                Log.d("Translation", "Auto-loaded cached translation for " + bandName);
                            }
                        });
                    }
                    
                    @Override
                    public void onTranslationError(String error) {
                        Log.e("Translation", "Error auto-loading translation: " + error);
                    }
                });
            } else {
                Log.d("Translation", "No cached translation available for auto-load of " + bandName);
                // Don't auto-translate if no cache - user can manually translate if they want
            }
        } else {
            Log.d("Translation", "User prefers English for " + bandName + ", showing original content");
        }
    }
    
    /**
     * Shows a toast message
     */
    private void showToast(String message) {
        runOnUiThread(() -> {
            android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show();
        });
    }
    
    /**
     * Handles notes editing
     */
    private void handleNotesEdit() {
        Log.d("Variable is", "Variable is -  Lets run this code to edit notes");
        showEditNoteDialog(BandInfo.getSelectedBand());
    }
    
    /**
     * Shows dialog for editing notes
     */
    private void showEditNoteDialog(String bandName) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Edit Note for " + bandName);
        
        final EditText input = new EditText(this);
        input.setTextColor(getResources().getColor(android.R.color.white));
        input.setBackgroundColor(getResources().getColor(android.R.color.black));
        
        String currentNote = bandNote;
        if (bandHandler.getNoteIsBlank() == true) {
            currentNote = "";
        }
        currentNote = currentNote.replaceAll("<br>", "\n");
        currentNote = currentNote.replaceAll("<[^>]*>", ""); // Remove HTML tags
        input.setText(currentNote);
        
        builder.setView(input);
        
        builder.setPositiveButton("Save Note", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                String noteText = input.getText().toString().trim();
                
                // If note is empty or whitespace only, revert to original default content
                if (noteText.isEmpty()) {
                    // Get the original default note (not custom note) by checking the default note file directly
                    String originalDefaultNote = getOriginalDefaultNote(bandName);
                    
                    if (originalDefaultNote != null && !originalDefaultNote.trim().isEmpty() && 
                        !originalDefaultNote.contains("Comment text is not available yet")) {
                        // Use the original default comment
                        noteText = originalDefaultNote;
                    } else {
                        // Use the exact same waiting message as CustomerDescriptionHandler
                        noteText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";
                    }
                }
                
                bandHandler.saveCustomBandNote(noteText);
                
                // Update the note content and refresh display without restarting activity
                bandNote = noteText;
                // IMAGE PRESERVATION FIX: Only refresh note section, not entire content
                setupExtraDataSection(); // This will update the note display without affecting the image
            }
        });
        
        builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                dialog.cancel();
            }
        });
        
        builder.show();
    }
    
    /**
     * Populates native content views with band data
     */
    private void populateNativeContent() {
        setupBandTitleAndLogo();
        setupScheduleSection();
        setupLinksSection();
        setupExtraDataSection();
        setupNotesSection();
        setupRankingButtons();
    }
    
    /**
     * Refreshes native content with updated data (HEAVY - avoid during progressive loading)
     */
    private void refreshNativeContent() {
        if (bandNameText != null) {
            Log.d("RefreshContent", "Refreshing native content for " + bandName);
            populateNativeContent(); // This is heavy - includes schedule processing and image loading
            Log.d("RefreshContent", "Native content refreshed for " + bandName);
        }
    }
    
    /**
     * Lightweight refresh for progressive loading - only updates specific sections
     */
    private void refreshNativeContentLight() {
        if (bandNameText != null) {
            Log.d("RefreshContent", "Light refresh for " + bandName);
            // Only refresh the sections that were actually updated
            // Individual setup methods are called directly by progressive loading phases
        }
    }
    
    /**
     * Sets up double-tap listener for note editing
     */
    private void setupNoteDoubleTapListener() {
        GestureDetector gestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onDoubleTap(MotionEvent e) {
                handleNotesEdit();
                return true;
            }
        });
        
        noteValue.setOnTouchListener((v, event) -> {
            // Handle double-tap for editing
            boolean doubleTapHandled = gestureDetector.onTouchEvent(event);
            
            // If double-tap was handled, consume the event to prevent link clicks
            if (doubleTapHandled) {
                return true;
            }
            
            // For single taps on links, let the LinkMovementMethod handle it
            if (noteValue.getMovementMethod() != null) {
                return noteValue.getMovementMethod().onTouchEvent(noteValue, (Spannable) noteValue.getText(), event);
            }
            
            return false; // Allow other touch events to be processed
        });
    }
    
    /**
     * Gets the original default note (not custom note) by reading directly from the default note file
     */
    private String getOriginalDefaultNote(String bandName) {
        try {
            // Read directly from the .note_new file to get the original default note
            File defaultNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
            
            if (!defaultNoteFile.exists()) {
                Log.d("OriginalDefaultNote", "No default note file exists for " + bandName);
                return null;
            }
            
            // Read the note file (it's a serialized HashMap)
            Map<String, String> noteData = (Map<String, String>) FileHandler70k.readObject(defaultNoteFile);
            if (noteData != null && noteData.containsKey("defaultNote")) {
                String originalNote = noteData.get("defaultNote");
                Log.d("OriginalDefaultNote", "Found original default note for " + bandName + ": " + originalNote);
                return originalNote;
            } else {
                Log.d("OriginalDefaultNote", "No defaultNote key found in file for " + bandName);
                return null;
            }
            
        } catch (Exception e) {
            Log.e("OriginalDefaultNote", "Error reading original default note for " + bandName, e);
            return null;
        }
    }
    
    /**
     * Gets raw band note data without HTML conversion - directly from CustomerDescriptionHandler
     */
    private String getRawBandNote(String bandName) {
        try {
            // First check for custom note
            BandNotes bandHandler = new BandNotes(bandName);
            String customNote = bandHandler.getBandNoteFromFile();
            if (customNote != null && !customNote.trim().isEmpty() && 
                !customNote.contains("Comment text is not available yet")) {
                Log.d("RawBandNote", "Returning custom note for " + bandName);
                return customNote;
            }
            
            // Get default note directly without HTML conversion
            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
            // This calls the full getDescription but we'll strip HTML if present
            String note = descHandler.getDescription(bandName);
            Log.d("RawBandNote", "Got note from CustomerDescriptionHandler: " + note);
            return note;
            
        } catch (Exception e) {
            Log.e("RawBandNote", "Error getting raw band note for " + bandName, e);
            return "Comment text is not available yet. Please wait for Aaron to add his description.";
        }
    }
    
    /**
     * Converts text with URLs (both !!!! format and HTML <a> tags) to clickable spannable text for native TextView
     */
    private SpannableString makeUrlsClickable(String text) {
        Log.d("LinkProcessing", "Original text: " + text);
        String cleanText = text;
        
        // Handle already-converted HTML <a> tags from BandNotes.java
        // Pattern: <a target='_blank' style='color: lightblue' href=https://URL>DISPLAY_TEXT</a>
        // More flexible pattern to handle various href formats
        String beforeHtml = cleanText;
        cleanText = cleanText.replaceAll("<a[^>]*href=([^\\s>]+)[^>]*>([^<]+)</a>", "$1");
        Log.d("LinkProcessing", "After HTML processing: " + cleanText);
        
        // Handle original !!!! format URLs
        String beforeExclamation = cleanText;
        cleanText = cleanText.replaceAll("!!!!https://([^\\s]+)", "https://$1");
        Log.d("LinkProcessing", "After !!!! processing: " + cleanText);
        
        SpannableString spannableString = new SpannableString(cleanText);
        
        // Pattern to find all https:// URLs in the cleaned text
        Pattern urlPattern = Pattern.compile("https://[^\\s]+");
        Matcher matcher = urlPattern.matcher(cleanText);
        
        while (matcher.find()) {
            final String url = matcher.group(0); // Full URL with https://
            
            int start = matcher.start();
            int end = matcher.end();
            
            // Create clickable span that opens in in-app WebView
            ClickableSpan clickableSpan = new ClickableSpan() {
                @Override
                public void onClick(View widget) {
                    Log.d("ClickableLink", "Clicked URL: " + url);
                    // Open in in-app WebView
                    showInAppWebView(url, "customLink");
                }
                
                @Override
                public void updateDrawState(android.text.TextPaint ds) {
                    super.updateDrawState(ds);
                    ds.setUnderlineText(false); // Remove underline to match original style
                }
            };
            
            // Apply clickable span
            spannableString.setSpan(clickableSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
            
            // Make the link light blue like the original HTML version
            ForegroundColorSpan colorSpan = new ForegroundColorSpan(Color.parseColor("#ADD8E6")); // Light blue
            spannableString.setSpan(colorSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        
        return spannableString;
    }
    
    /**
     * Sets up the band title and logo section.
     * FIXED: Removed competing thread - now only sets title, image handled by progressive loading.
     */
    private void setupBandTitleAndLogo() {
        // Set band name immediately (no blocking)
        if (bandNameText != null) {
        bandNameText.setText(bandName);
        }
        
        // Hide image initially - will be loaded by progressive loading thread
        // NOTE: This should only be called during initial setup, not during refresh operations
        if (bandLogoImage != null) {
                bandLogoImage.setVisibility(View.GONE);
            }
        
        // NOTE: Image loading is handled by progressive loading phases to prevent thread conflicts
        Log.d("setupBandTitleAndLogo", "Title set, image loading handled by progressive loading for " + bandName);
    }
    
    /**
     * Sets up the schedule section with show times and venues.
     * PERFORMANCE OPTIMIZED: Reduces redundant map lookups and uses cached references.
     */
    private void setupScheduleSection() {
        // Clear existing schedule items
        scheduleSection.removeAllViews();
        
        try {
            scheduleTimeTracker bandSchedule = BandInfo.scheduleRecords.get(bandName);
            if (bandSchedule != null) {
                // Cache the schedule map to avoid repeated lookups
                Map<Long, scheduleHandler> scheduleByTime = bandSchedule.scheduleByTime;
                Iterator entries = scheduleByTime.entrySet().iterator();
                
                while (entries.hasNext()) {
                    Map.Entry thisEntry = (Map.Entry) entries.next();
                    Long key = (Long) thisEntry.getKey();
                    
                    // Cache the schedule info to avoid repeated map lookups
                    scheduleHandler scheduleItem = scheduleByTime.get(key);
                    
                    // Create schedule item view
                    View scheduleItemView = LayoutInflater.from(this).inflate(R.layout.schedule_item, scheduleSection, false);
                    
                    // Get schedule data (using cached references)
                    String location = scheduleItem.getShowLocation();
                    String locationColor = staticVariables.getVenueColor(location);
                    String rawStartTime = scheduleItem.getStartTimeString();
                    String startTime = dateTimeFormatter.formatScheduleTime(rawStartTime);
                    String endTime = dateTimeFormatter.formatScheduleTime(scheduleItem.getEndTimeString());
                    String dayNumber = scheduleItem.getShowDay();
                    dayNumber = dayNumber.replaceFirst("Day ", "");
                    String eventType = scheduleItem.getShowType();
                    String eventNote = scheduleItem.getShowNotes();
                    
                    String attendIndex = bandName + ":" + location + ":" + rawStartTime + ":" + eventType + ":" + String.valueOf(staticVariables.eventYear);
                    String eventTypeImage = showBandDetails.getEventTypeImage(eventType, bandName);
                    String attendedImage = showBandDetails.getAttendedImage(attendIndex);
                    
                    // Don't display "show" as event type since it's default
                    if (eventType.equals(staticVariables.show)) {
                        eventType = "";
                    }
                    
                    // Append venue location if available
                    String venueLocation = staticVariables.venueLocation.get(location);
                    if (venueLocation != null) {
                        location = location + " " + venueLocation;
                    }
                    
                    // Set up the schedule item views
                    setupScheduleItemViews(scheduleItemView, location, locationColor, startTime, endTime, 
                                         dayNumber, eventType, eventNote, attendedImage, eventTypeImage, attendIndex);
                    
                    scheduleSection.addView(scheduleItemView);
                }
            }
        } catch (Exception error) {
            Log.e("setupScheduleSection", "Error setting up schedule", error);
        }
    }
    
    /**
     * Helper method to set up individual schedule item views
     */
    private void setupScheduleItemViews(View scheduleItemView, String location, String locationColor, 
                                      String startTime, String endTime, String dayNumber, String eventType, 
                                      String eventNote, String attendedImage, String eventTypeImage, String attendIndex) {
        
        // Set venue color bars
        View venueColorBar1 = scheduleItemView.findViewById(R.id.venue_color_bar);
        View venueColorBar2 = scheduleItemView.findViewById(R.id.venue_color_bar_2);
        int color = Color.parseColor(locationColor);
        venueColorBar1.setBackgroundColor(color);
        venueColorBar2.setBackgroundColor(color);
        
        // Set location text
        TextView locationText = scheduleItemView.findViewById(R.id.location_text);
        locationText.setText(location);
        
        // Set attended icon
        ImageView attendedIcon = scheduleItemView.findViewById(R.id.attended_icon);
        if (!attendedImage.isEmpty()) {
            setImageFromResource(attendedIcon, attendedImage);
            attendedIcon.setVisibility(View.VISIBLE);
        } else {
            attendedIcon.setVisibility(View.GONE);
        }
        
        // Set times
        TextView startTimeText = scheduleItemView.findViewById(R.id.start_time_text);
        TextView endTimeText = scheduleItemView.findViewById(R.id.end_time_text);
        startTimeText.setText(startTime);
        endTimeText.setText(endTime);
        
        // Set day number
        TextView dayNumberText = scheduleItemView.findViewById(R.id.day_number_text);
        dayNumberText.setText(dayNumber);
        
        // Set event type and notes
        TextView eventTypeText = scheduleItemView.findViewById(R.id.event_type_text);
        TextView eventNotesText = scheduleItemView.findViewById(R.id.event_notes_text);
        
        if (!eventType.isEmpty()) {
            eventTypeText.setText(Utilities.convertEventTypeToLocalLanguage(eventType));
            eventTypeText.setVisibility(View.VISIBLE);
        } else {
            eventTypeText.setVisibility(View.GONE);
        }
        eventNotesText.setText(eventNote);
        
        // Set event type icon
        ImageView eventTypeIcon = scheduleItemView.findViewById(R.id.event_type_icon);
        if (!eventTypeImage.isEmpty()) {
            setImageFromResource(eventTypeIcon, eventTypeImage);
            eventTypeIcon.setVisibility(View.VISIBLE);
        } else {
            eventTypeIcon.setVisibility(View.GONE);
        }
        
        // Set click listener for attendance tracking
        scheduleItemView.setOnClickListener(v -> handleScheduleItemClick(attendIndex));
    }
    
    /**
     * Helper method to set image from Android resource path
     */
    private void setImageFromResource(ImageView imageView, String resourcePath) {
        try {
            // Extract resource name from path like "file:///android_res/drawable/icon_seen.png"
            String resourceName = resourcePath.substring(resourcePath.lastIndexOf("/") + 1);
            resourceName = resourceName.substring(0, resourceName.lastIndexOf(".")); // Remove extension
            
            int resourceId = getResources().getIdentifier(resourceName, "drawable", getPackageName());
            if (resourceId != 0) {
                imageView.setImageResource(resourceId);
            }
        } catch (Exception e) {
            Log.e("setImageFromResource", "Error setting image from resource: " + resourcePath, e);
        }
    }
    
    /**
     * Handles schedule item clicks for attendance tracking
     */
    private void handleScheduleItemClick(String attendIndex) {
        if (clickedOnEvent == false) {
            clickedOnEvent = true;
            Log.d("showAttended", "Lets set this value of " + attendIndex);
            String status = staticVariables.attendedHandler.addShowsAttended(attendIndex, "");
            String message = staticVariables.attendedHandler.setShowsAttendedStatus(status);
            HelpMessageHandler.showMessage(message);

            // IMAGE PRESERVATION FIX: Only refresh schedule section, not entire content
            setupScheduleSection(); // This will update attendance icons without affecting the image
            clickedOnEvent = false; // Reset flag for targeted refresh
        }
    }
    
    /**
     * Sets up the links section for external websites with dynamic spacing
     */
    private void setupLinksSection() {
        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal")) {
            linksLabel.setText("Links:");
            linksSection.setVisibility(View.VISIBLE);
            
            // Set up dynamic spacing for link icons
            setupDynamicLinkSpacing();
        } else {
            linksSection.setVisibility(View.GONE);
        }
    }
    
    /**
     * Sets up dynamic spacing for link icons based on screen width
     */
    private void setupDynamicLinkSpacing() {
        // Get screen width
        android.util.DisplayMetrics displayMetrics = new android.util.DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        int screenWidth = displayMetrics.widthPixels;
        
        // Convert dp to pixels for calculations
        float density = getResources().getDisplayMetrics().density;
        int labelWidth = (int) (120 * density); // Links label width: 120dp
        int sectionMargins = (int) (32 * density); // Total left/right margins: 16dp each
        int iconWidth = (int) (43 * density); // Each icon width: 43dp
        int totalIconsWidth = iconWidth * 4; // 4 icons total
        
        // Calculate available space for spacing
        int availableSpace = screenWidth - labelWidth - sectionMargins - totalIconsWidth;
        
        // Calculate spacing between icons (distribute evenly, but make last icon closer to edge)
        int spacingBetweenIcons = Math.max((int) (12 * density), availableSpace / 4); // Minimum 12dp, or dynamic
        int lastIconMargin = Math.max((int) (8 * density), availableSpace / 6); // Less margin for last icon
        
        Log.d("DynamicSpacing", "Screen width: " + screenWidth + ", Available space: " + availableSpace + 
              ", Icon spacing: " + spacingBetweenIcons + ", Last margin: " + lastIconMargin);
        
        // Apply dynamic margins to icons
        setIconMargin(websiteLink, 0, spacingBetweenIcons);
        setIconMargin(metalArchivesLink, 0, spacingBetweenIcons);
        setIconMargin(wikipediaLink, 0, spacingBetweenIcons);
        setIconMargin(youtubeLink, 0, lastIconMargin); // Last icon has smaller right margin
    }
    
    /**
     * Helper method to set margins for an icon
     */
    private void setIconMargin(ImageView icon, int leftMargin, int rightMargin) {
        if (icon != null && icon.getLayoutParams() instanceof LinearLayout.LayoutParams) {
            LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) icon.getLayoutParams();
            params.setMargins(leftMargin, params.topMargin, rightMargin, params.bottomMargin);
            icon.setLayoutParams(params);
        }
    }
    
    /**
     * Helper method to process text and ensure proper line break handling
     */
    private String processLineBreaks(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        
        // Since we fixed the root cause in CustomerDescriptionHandler,
        // the text should now come with proper line breaks preserved
        String processed = text;
        
        // Handle any remaining HTML br tags (for backward compatibility)
        processed = processed.replace("<br><br>", "\n\n");
        processed = processed.replace("<br>", "\n");
        processed = processed.replace("<br/>", "\n");
        
        // Convert single line breaks to double line breaks for better paragraph separation
        processed = processed.replaceAll("\n", "\n\n");
        
        // Clean up any excessive spacing (max 2 consecutive newlines)
        processed = processed.replaceAll("\n{3,}", "\n\n");
        processed = processed.trim(); // Remove leading/trailing whitespace
        
        return processed;
    }
    
    /**
     * Clears cached note data to force refresh with new line break processing and updates display
     */
    private void clearCachedNoteData(String bandName) {
        try {
            Log.d("LineBreakDebug", "Clearing cached note data for " + bandName);
            
            // Delete cached note files to force refresh
            java.io.File bandNoteFile = new java.io.File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
            java.io.File bandCustNoteFile = new java.io.File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".custNote");
            
            if (bandNoteFile.exists()) {
                bandNoteFile.delete();
                Log.d("LineBreakDebug", "Deleted cached note file: " + bandNoteFile.getPath());
            }
            
            if (bandCustNoteFile.exists()) {
                bandCustNoteFile.delete();
                Log.d("LineBreakDebug", "Deleted cached custom note file: " + bandCustNoteFile.getPath());
            }
            
            // Force re-download of note data in background with UI refresh
            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
            new Thread(() -> {
                try {
                    Log.d("LineBreakDebug", "Re-downloading note data for " + bandName);
                    descHandler.loadNoteFromURL(bandName);
                    
                    // Wait a moment for the download to complete
                    Thread.sleep(2000);
                    
                    // Refresh the UI on the main thread
                    runOnUiThread(() -> {
                        Log.d("LineBreakDebug", "Refreshing display for " + bandName);
                        // IMAGE PRESERVATION FIX: Only refresh the note section, not the entire content
                        setupExtraDataSection(); // This will process the new note data
                        Log.d("LineBreakDebug", "Display refreshed - line breaks should now be visible");
                    });
                } catch (Exception e) {
                    Log.e("LineBreakDebug", "Error during background refresh for " + bandName, e);
                }
            }).start();
            
            Log.d("LineBreakDebug", "Cache clearing and refresh initiated for " + bandName);
        } catch (Exception e) {
            Log.e("LineBreakDebug", "Error clearing cached note data for " + bandName, e);
        }
    }
    
    /**
     * Sets up the extra data section (country, genre, etc.)
     */
    private void setupExtraDataSection() {
        Log.d("PerformanceDebug", "setupExtraDataSection called for " + bandName + " (cleanup attempted: " + cacheCleanupAttempted + ")");
        
        boolean hasExtraData = false;
        
        // Country
        if (!BandInfo.getCountry(bandName).isEmpty()) {
            countryValue.setText(BandInfo.getCountry(bandName));
            countryRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            countryRow.setVisibility(View.GONE);
        }
        
        // Genre
        if (!BandInfo.getGenre(bandName).isEmpty()) {
            genreValue.setText(BandInfo.getGenre(bandName));
            genreRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            genreRow.setVisibility(View.GONE);
        }
        
        // Last on cruise
        if (!BandInfo.getPriorYears(bandName).isEmpty()) {
            lastCruiseValue.setText(BandInfo.getPriorYears(bandName));
            lastCruiseRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
        } else {
            lastCruiseRow.setVisibility(View.GONE);
        }
        
        // Note - Get note data without HTML conversion for native TextView
        String rawNote = "";
        if (bandNote != null && !bandNote.trim().isEmpty()) {
            rawNote = bandNote;
        } else {
            // Get raw note data without HTML conversion by directly accessing BandNotes file
            rawNote = getRawBandNote(bandName);
        }
        
        if (!rawNote.isEmpty()) {
            // INFINITE LOOP FIX: Only clear cache once per activity instance to prevent continuous refresh
            if (rawNote.contains("<br>") && !cacheCleanupAttempted) {
                Log.d("LineBreakDebug", "Found <br> tags in note, clearing cache once for " + bandName);
                cacheCleanupAttempted = true;
                clearCachedNoteData(bandName);
                return; // Exit early to prevent processing the old note
            }
            
            String noteText = processLineBreaks(rawNote);
            
            // Configure TextView for proper multiline display
            noteValue.setSingleLine(false);
            noteValue.setMaxLines(Integer.MAX_VALUE);
            noteValue.setHorizontallyScrolling(false);
            
            // Apply font size preference before setting text
            applyNoteFontSize();
            
            // Process URLs and make them clickable (handles both !!!! format and HTML <a> tags)
            if (noteText.contains("!!!!https://") || noteText.contains("<a ") || noteText.contains("https://")) {
                SpannableString clickableText = makeUrlsClickable(noteText);
                noteValue.setText(clickableText);
                noteValue.setMovementMethod(LinkMovementMethod.getInstance());
            } else {
                noteValue.setText(noteText);
            }
            
            noteRow.setVisibility(View.VISIBLE);
            hasExtraData = true;
            
            // Update translation button after note content is set
            updateTranslationButton();
            
            // Auto-load user's preferred language for this band
            autoLoadUserPreferredLanguage();
        } else {
            noteRow.setVisibility(View.GONE);
            // Even if no note content, still check if we should show translation button
            updateTranslationButton();
        }
        
        // Show/hide the entire extra data section
        if (hasExtraData && !orientation.equals("landscape")) {
            extraDataSection.setVisibility(View.VISIBLE);
        } else {
            extraDataSection.setVisibility(View.GONE);
        }
    }
    
    /**
     * Sets up the user notes section (personal user notes, not band descriptions)
     */
    private void setupNotesSection() {
        // Always hide user notes section to prevent duplication
        // User notes functionality can be re-enabled later if needed for personal notes
        userNotesSection.setVisibility(View.GONE);
    }
    
    /**
     * Sets up the ranking buttons at the bottom
     */
    private void setupRankingButtons() {
        SetButtonColors(); // This sets the color variables
        
        // Set button text from resources
        unknownButton.setText(getResources().getString(R.string.unknown));
        mustButton.setText(getResources().getString(R.string.must));
        mightButton.setText(getResources().getString(R.string.might));
        wontButton.setText(getResources().getString(R.string.wont));
        
        // Apply button colors (convert from HTML color names to Android colors)
        unknownButton.setBackgroundColor(getColorFromString(unknownButtonColor));
        mustButton.setBackgroundColor(getColorFromString(mustButtonColor));
        mightButton.setBackgroundColor(getColorFromString(mightButtonColor));
        wontButton.setBackgroundColor(getColorFromString(wontButtonColor));
        
        // Set ranking icon
        if (!rankIconLocation.isEmpty()) {
            setImageFromResource(rankingIcon, rankIconLocation);
            rankingIcon.setVisibility(View.VISIBLE);
        } else {
            rankingIcon.setVisibility(View.GONE);
        }
    }
    
    /**
     * Helper method to convert color string to Android color
     */
    private int getColorFromString(String colorString) {
        switch (colorString.toLowerCase()) {
            case "silver":
                return Color.parseColor("#808080"); // Darker grey instead of silver
            case "black":
            default:
                return Color.BLACK;
        }
    }




    private String setWebHelpMessage(String linkType){

        String webHelpMessage = "";

        if (linkType.equals("webPage")) {
            webHelpMessage = getResources().getString(R.string.officialWebSiteLinkHelp);

        } else if (linkType.equals("wikipedia")) {
            webHelpMessage = getResources().getString(R.string.WikipediaLinkHelp);

        } else if (linkType.equals("youTube")) {
            webHelpMessage = getResources().getString(R.string.YouTubeLinkHelp);

        } else if (linkType.equals("metalArchives")) {
            webHelpMessage = getResources().getString(R.string.MetalArchiveLinkHelp);
        }

        return webHelpMessage;
    }

    private String getWebUrl(String linkType){

        String urlString = "";

        if (linkType.equals("webPage")) {
            urlString = BandInfo.getOfficalWebLink(bandName);

        } else if (linkType.equals("wikipedia")) {
            urlString = BandInfo.getWikipediaWebLink (bandName);

        } else if (linkType.equals("youTube")) {
            urlString = BandInfo.getYouTubeWebLink(bandName);

        } else if (linkType.equals("metalArchives")) {
            urlString = BandInfo.getMetalArchivesWebLink(bandName);
        }

        urlString = urlString.replace("http://","https://");

        return urlString;
    }

    @Override
    protected void onPause() {
        super.onPause();
        
        // Background loading is managed by main activity lifecycle only
    }

    @Override
    public void onResume() {
        super.onResume();
            setContentView(R.layout.band_details_native);
        
        // Reinitialize components after setContentView
        initializeTranslationComponents();
        
        // Reinitialize swipe gesture detector
        initializeSwipeGestureDetector();
        
        // IMMEDIATE LOADING: Use fast UI setup instead of heavy initialization
        initializeUIComponentsOnly();
        
        // ONRESUME FIX: Immediately restore cached image if available to prevent disappearing image
        restoreCachedImageImmediately();
        
        // PROGRESSIVE LOADING: Load content in background (likely cached by now)
        loadAllContentProgressively();
        inLink = false;
        
        // Background loading is managed by main activity lifecycle only
    }

    @Override
    public void onBackPressed() {

        Log.d("WebView", "Back button pressed - inLink=" + inLink + ", inAppWebView=" + (inAppWebView != null));
        
        // If we're in WebView mode, check history first
        if (inLink && inAppWebView != null) {
            // Debug WebView history state
            debugWebViewHistory();
            
            if (inAppWebView.canGoBack()) {
                Log.d("WebView", "Going back in WebView history");
                inAppWebView.goBack();
                return;
            } else {
                Log.d("WebView", "No WebView history, exiting to band details");
                exitInAppWebView();
                return;
            }
        }
        
        // Standard back navigation - return to main bands list
        if (inLink){
            // Reset the link state
            inLink = false;
        }
        
        // Cancel any ongoing translation operations to prevent memory issues
        if (translator != null) {
            try {
                // Note: ML Kit doesn't have a direct cancel method, but cleanup will handle resources
                Log.d("Translation", "Preparing to clean up translation resources on back press");
            } catch (Exception e) {
                Log.e("Translation", "Error preparing translation cleanup", e);
            }
        }
        
        Log.d("WebView", "Standard back navigation to bands list");
        SystemClock.sleep(70);
        setResult(RESULT_OK, null);
        // LIST POSITION FIX: Use simple finish() to return to existing parent activity
        // This preserves the list position instead of creating a new activity instance
        finish();
    }
    
    @Override
    protected void onDestroy() {
        // Clean up in-app WebView if it exists
        if (inAppWebView != null) {
            inAppWebView.destroy();
            inAppWebView = null;
        }
        
        // Clean up other WebView references
        if (webViewProgressBar != null) {
            webViewProgressBar = null;
        }
        
        // Clean up translation resources to prevent memory leaks
        if (translator != null) {
            try {
                translator.cleanup();
            } catch (Exception e) {
                Log.e("Translation", "Error cleaning up translator resources", e);
            }
            translator = null;
        }
        
        // Background loading is now properly managed at the Application level
        Log.d("DetailsScreen", "Details screen closed - background loading managed at Application level");
        
        super.onDestroy();
    }

    public void SetButtonColors() {

        rankStore.getBandRankings();

        if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.mustSeeIcon)){
            mustButtonColor = "Silver";
            mightButtonColor = "Black";
            wontButtonColor = "Black";
            unknownButtonColor = "Black";
            rankIconLocation = "file:///android_res/drawable/icon_going_yes.png";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.mightSeeIcon)){
            mustButtonColor = "Black";
            mightButtonColor = "Silver";
            wontButtonColor = "Black";
            unknownButtonColor = "Black";
            rankIconLocation = "file:///android_res/drawable/icon_going_maybe.png";

        } else if (rankStore.getRankForBand(BandInfo.getSelectedBand()).equals(staticVariables.wontSeeIcon)){
            mustButtonColor = "Black";
            mightButtonColor = "Black";
            wontButtonColor = "Silver";
            unknownButtonColor = "Black";
            rankIconLocation = "file:///android_res/drawable/icon_going_no.png";

        } else {
            mustButtonColor = "Black";
            mightButtonColor = "Black";
            wontButtonColor = "Black";
            unknownButtonColor = "Silver";
            rankIconLocation = "";
        }
    }

    private String resolveValue (String value){

        String newValue;

        if (value.equals(staticVariables.mustSeeKey)){
            newValue = staticVariables.mustSeeIcon;

        } else if (value.equals(staticVariables.mightSeeKey)){
            newValue = staticVariables.mightSeeIcon;

        } else if (value.equals(staticVariables.wontSeeKey)){
            newValue = staticVariables.wontSeeIcon;

        } else if (value.equals(staticVariables.unknownKey)){
            newValue = "";

        } else {
            newValue = value;
        }

        return newValue;
    }



    public static String getAttendedImage(String attendIndex){

        String icon = staticVariables.attendedHandler.getShowAttendedIcon(attendIndex);
        String image = "";

        Log.d("setAttendedImage", "Link is " + icon + " compare to " + staticVariables.sawAllIcon);
        if (icon.equals(staticVariables.sawAllIcon)){
            image = "file:///android_res/drawable/icon_seen.png";

        } else if (icon.equals(staticVariables.sawSomeIcon)) {
            image = "file:///android_res/drawable/icon_partially_seen.png";

        }

        return image;
    }

    public static String getEventTypeImage(String eventType, String eventName){

        String image = "";

        if (eventType.equals(staticVariables.clinic)){
            image = "file:///android_res/drawable/icon_clinic.png";

        } else if (eventType.equals(staticVariables.meetAndGreet)){
            image = "file:///android_res/drawable/icon_meet_and_greet.png";

        } else if (eventType.equals(staticVariables.specialEvent)){
            if (eventName.equals("All Star Jam")){
                image = "file:///android_res/drawable/icon_all_star_jam.png";

            } else if (eventName.contains("Karaoke")){
                image = "file:///android_res/drawable/icon_karaoke.png";

            } else {
                image = "file:///android_res/drawable/icon_ship_event.png";
            }

        } else if (eventType.equals(staticVariables.unofficalEvent)){
            image = "file:///android_res/drawable/icon_unspecified_event.png";
        }

        return image;
    }





}

/**
 * Detects left and right swipes across a view.
 */
class OnSwipeTouchListener implements View.OnTouchListener {

    private final GestureDetector gestureDetector;

    public OnSwipeTouchListener(Context context) {
        gestureDetector = new GestureDetector(context, new GestureListener());
    }

    public void onSwipeLeft() {
    }

    public void onSwipeRight() {
    }

    public boolean onTouch(View view, MotionEvent event) {
        // Let the gesture detector handle the event
        boolean gestureHandled = gestureDetector.onTouchEvent(event);

        // If the gesture detector didn't handle it (no horizontal swipe detected),
        // allow the ScrollView to handle it for vertical scrolling
        return gestureHandled;
    }



    private final class GestureListener extends GestureDetector.SimpleOnGestureListener {

        private static final int SWIPE_DISTANCE_THRESHOLD = 150;
        private static final int SWIPE_VELOCITY_THRESHOLD = 200;

        @Override
        public boolean onDown(MotionEvent e) {
            return true; // Must return true to receive subsequent events
        }

        @Override
        public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
            if (e1 == null || e2 == null) return false;
            
            float distanceX = e2.getX() - e1.getX();
            float distanceY = e2.getY() - e1.getY();
            
            // Check if this is primarily a horizontal swipe
            if (Math.abs(distanceX) > Math.abs(distanceY) && 
                Math.abs(distanceX) > SWIPE_DISTANCE_THRESHOLD && 
                Math.abs(velocityX) > SWIPE_VELOCITY_THRESHOLD) {
                
                Log.d("SwipeGesture", "Horizontal swipe detected - distanceX: " + distanceX + ", velocityX: " + velocityX);
                
                if (distanceX > 0) {
                    onSwipeRight();
                } else {
                    onSwipeLeft();
                }
                return true;
            }
            return false;
        }
    }

}
