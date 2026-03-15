package com.Bands70k;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.ContextThemeWrapper;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.FocusMeteringAction;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.core.MeteringPoint;
import androidx.camera.core.MeteringPointFactory;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.android.gms.tasks.Tasks;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import androidx.camera.view.PreviewView;

/**
 * Scan 1 or 2 schedule QR codes (binary payload: type + 4-byte LE size + zlib).
 * Uses ML Kit for decoding (getRawBytes() for binary payload). Collects payloads
 * by type (0=full, 1=chunk1, 2=chunk2), then decompresses, writes to FileHandler70k.schedule,
 * parses and sets BandInfo.scheduleRecords, sends refresh.
 */
public class ScheduleQRScanActivity extends AppCompatActivity {

    private static final String TAG = "ScheduleQRScan";
    private static final int REQUEST_CAMERA = 1001;
    /** Try decode every N frames. */
    private static final int FRAMES_BETWEEN_SCANS = 4;
    /** Log "no QR decoded" every this many analyses. */
    private static final int NO_DECODE_LOG_INTERVAL = 50;

    private static final String TAG_QR_ERROR = "QR Error";

    private PreviewView previewView;
    private TextView hintText;
    private ProgressBar progressBar;
    private ProcessCameraProvider cameraProvider;
    private BarcodeScanner barcodeScanner;

    private byte[] chunk1;
    private byte[] chunk2;
    private boolean didSucceed;
    private int frameCount;
    /** Consecutive analyses that did not yield a decoded QR; reset when a QR is decoded. */
    private int noDecodeCount;
    private final ExecutorService analysisExecutor = Executors.newSingleThreadExecutor();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_schedule_qr_scan);

        setTitle(getString(R.string.schedule_qr_scan_title));
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
        }

        previewView = findViewById(R.id.schedule_qr_scan_preview);
        hintText = findViewById(R.id.schedule_qr_scan_hint);
        progressBar = findViewById(R.id.schedule_qr_scan_progress);

        hintText.setText(getString(R.string.schedule_qr_scan_hint));

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.CAMERA}, REQUEST_CAMERA);
            return;
        }
        startCamera();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_CAMERA) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera();
            } else {
                Toast.makeText(this, R.string.schedule_qr_camera_required, Toast.LENGTH_LONG).show();
                finish();
            }
        }
    }

    private void startCamera() {
        progressBar.setVisibility(View.VISIBLE);
        ListenableFuture<ProcessCameraProvider> future = ProcessCameraProvider.getInstance(this);
        future.addListener(() -> {
            try {
                ProcessCameraProvider provider = future.get();
                bindCamera(provider);
            } catch (Exception e) {
                Log.e(TAG, "Camera bind failed", e);
                runOnUiThread(() -> {
                    progressBar.setVisibility(View.GONE);
                    Toast.makeText(this, R.string.schedule_qr_camera_unavailable, Toast.LENGTH_LONG).show();
                    finish();
                });
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private void bindCamera(ProcessCameraProvider provider) {
        cameraProvider = provider;
        if (barcodeScanner == null) {
            BarcodeScannerOptions options = new BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                    .build();
            barcodeScanner = BarcodeScanning.getClient(options);
        }
        Preview preview = new Preview.Builder().build();
        preview.setSurfaceProvider(previewView.getSurfaceProvider());

        // Higher resolution so each QR module has enough pixels (dense/small QRs decode more reliably).
        ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetResolution(new Size(1920, 1080))
                .build();
        imageAnalysis.setAnalyzer(analysisExecutor, this::analyzeFrame);

        CameraSelector selector = new CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_BACK).build();
        try {
            provider.unbindAll();
            Camera camera = provider.bindToLifecycle(this, selector, preview, imageAnalysis);
            // Focus and meter on center so QR in frame center gets sharp and well-exposed.
            if (camera != null) {
                previewView.postDelayed(() -> startCenterFocusAndMetering(camera), 350);
            }
        } catch (Exception e) {
            Log.e(TAG, "bindToLifecycle failed", e);
        }
        runOnUiThread(() -> progressBar.setVisibility(View.GONE));
    }

    /** Trigger focus and exposure metering at view center (where user typically holds the QR). */
    private void startCenterFocusAndMetering(Camera camera) {
        try {
            MeteringPointFactory factory = previewView.getMeteringPointFactory();
            MeteringPoint point = factory.createPoint(0.5f, 0.5f);
            FocusMeteringAction action = new FocusMeteringAction.Builder(point)
                    .setAutoCancelDuration(2, TimeUnit.SECONDS)
                    .build();
            camera.getCameraControl().startFocusAndMetering(action);
        } catch (Exception e) {
            Log.d(TAG, "startFocusAndMetering not supported or failed", e);
        }
    }

    /** Unbind camera so it closes before validation/import. Call from main thread. */
    private void closeCamera() {
        if (cameraProvider != null) {
            try {
                cameraProvider.unbindAll();
            } catch (Exception e) {
                Log.e(TAG, "closeCamera unbindAll", e);
            }
            cameraProvider = null;
        }
    }

    private void analyzeFrame(@NonNull ImageProxy image) {
        if (didSucceed) {
            image.close();
            return;
        }
        frameCount++;
        if (frameCount == 1) {
            Log.d(TAG, "[QRScan] analysis resolution " + image.getWidth() + "x" + image.getHeight());
        }
        if (frameCount % FRAMES_BETWEEN_SCANS != 0) {
            image.close();
            return;
        }
        try {
            byte[] payload = decodeQRFromImage(image);
            if (payload != null && payload.length > 5) {
                noDecodeCount = 0;
                logScanPayloadReceived(payload);
                ScheduleQRCompression.PayloadTypeResult result = ScheduleQRCompression.scheduleQRBinaryPayloadType(payload);
                if (result != null) {
                    Log.d(TAG, "[QRScan] valid payload type=" + (result.type & 0xFF) + " length=" + payload.length + " -> handlePayload");
                    runOnUiThread(() -> handlePayload(payload, result));
                } else {
                    int typeByte = payload[0] & 0xFF;
                    Log.d(TAG, "[QRScan] payload rejected: typeByte=" + typeByte + " (expected 0/1/2); length=" + payload.length + " firstBytesHex=" + bytesToHex(payload, 30));
                }
            } else {
                noDecodeCount++;
                if (noDecodeCount % NO_DECODE_LOG_INTERVAL == 0) {
                    Log.d(TAG, "[QRScan] iOS→Android troubleshooting: no QR decoded in last " + NO_DECODE_LOG_INTERVAL + " attempts (total noDecode=" + noDecodeCount + ")");
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "[QRScan] analyzeFrame exception", e);
        } finally {
            image.close();
        }
    }

    /** Decode QR from ImageProxy using ML Kit; returns raw binary payload or null. */
    private byte[] decodeQRFromImage(ImageProxy image) {
        if (barcodeScanner == null) return null;
        android.media.Image mediaImage = image.getImage();
        if (mediaImage == null) return null;
        try {
            int rotation = image.getImageInfo().getRotationDegrees();
            InputImage inputImage = InputImage.fromMediaImage(mediaImage, rotation);
            List<Barcode> barcodes = Tasks.await(barcodeScanner.process(inputImage));
            if (barcodes == null || barcodes.isEmpty()) return null;
            for (Barcode barcode : barcodes) {
                byte[] raw = barcode.getRawBytes();
                if (raw != null && raw.length > 0) {
                    logPayloadFirstBytes(TAG, "[QRScan] decoded", raw);
                    return raw;
                }
            }
            // ML Kit found QR(s) but no raw bytes; fallback to raw value as bytes (e.g. if encoded as text)
            Barcode first = barcodes.get(0);
            String rawValue = first.getRawValue();
            if (rawValue != null && !rawValue.isEmpty()) {
                byte[] fromText = rawValue.getBytes(StandardCharsets.ISO_8859_1);
                Log.d(TAG, "[QRScan] payload source=rawValue(ISO-8859-1) length=" + fromText.length);
                return fromText;
            }
        } catch (Exception e) {
            Log.v(TAG, "[QRScan] ML Kit decode " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
        return null;
    }

    private static void logPayloadFirstBytes(String tag, String label, byte[] payload) {
        if (payload == null || payload.length == 0) return;
        int show = Math.min(12, payload.length);
        StringBuilder hex = new StringBuilder();
        for (int i = 0; i < show; i++) hex.append(String.format("%02X ", payload[i] & 0xFF));
        Log.d(tag, label + " length=" + payload.length + " firstBytesHex=" + hex.toString().trim());
    }

    /** Cross-platform scan logging: when we get a payload from the camera, log type byte and first 30 bytes hex. Grep [QRScan]. */
    private static void logScanPayloadReceived(byte[] payload) {
        if (payload == null || payload.length == 0) return;
        int typeByte = payload[0] & 0xFF;
        Log.d(TAG, "[QRScan] payload received length=" + payload.length + " typeByte=" + typeByte);
        Log.d(TAG, "[QRScan] payload firstBytesHex=" + bytesToHex(payload, 30));
    }

    private static String bytesToHex(byte[] payload, int maxLen) {
        if (payload == null) return "";
        int show = Math.min(maxLen, payload.length);
        StringBuilder hex = new StringBuilder();
        for (int i = 0; i < show; i++) hex.append(String.format("%02X ", payload[i] & 0xFF));
        if (payload.length > show) hex.append("...");
        return hex.toString().trim();
    }

    private void handlePayload(byte[] payload, ScheduleQRCompression.PayloadTypeResult result) {
        if (result.type == ScheduleQRCompression.SCHEDULE_QR_TYPE_FULL) {
            onPayloadsComplete(Collections.singletonList(payload));
            return;
        }
        if (result.type == ScheduleQRCompression.SCHEDULE_QR_TYPE_CHUNK1) {
            chunk1 = payload;
            hintText.setText(getString(R.string.schedule_qr_scan_second));
            if (chunk2 != null) onPayloadsComplete(collectChunks());
            return;
        }
        if (result.type == ScheduleQRCompression.SCHEDULE_QR_TYPE_CHUNK2) {
            chunk2 = payload;
            if (chunk1 != null) {
                onPayloadsComplete(collectChunks());
            } else {
                hintText.setText(getString(R.string.schedule_qr_scan_first));
            }
        }
    }

    private List<byte[]> collectChunks() {
        List<byte[]> list = new ArrayList<>();
        list.add(chunk1);
        list.add(chunk2);
        return list;
    }

    private void onPayloadsComplete(List<byte[]> payloads) {
        if (didSucceed) return;
        didSucceed = true;

        closeCamera();

        Log.d(TAG, "[QRScan] onPayloadsComplete payloadCount=" + (payloads != null ? payloads.size() : 0));

        if (!BandInfo.isBandFileAvailableForQR()) {
            String bandFileError = BandInfo.getBandFileRequiredForQRMessage(this);
            if (bandFileError != null) {
                Toast.makeText(this, bandFileError, Toast.LENGTH_LONG).show();
                finish();
                return;
            }
            Toast.makeText(this, R.string.schedule_qr_downloading_band_list, Toast.LENGTH_SHORT).show();
            new Thread(() -> {
                BandInfo bi = new BandInfo();
                bi.DownloadBandFile();
                runOnUiThread(() -> {
                    if (BandInfo.isBandFileAvailableForQR()) {
                        doImportPayloads(payloads);
                        // finish() only on success path inside doImportPayloads
                    } else {
                        Toast.makeText(this, R.string.schedule_qr_band_file_download_failed, Toast.LENGTH_LONG).show();
                        finish();
                    }
                });
            }).start();
            return;
        }

        doImportPayloads(payloads);
        // Do not finish() here: only finish on success path inside doImportPayloads (after navigating to showBands).
        // When validation fails, stay on this screen so the user can read the dialog and press Back.
    }

    private void doImportPayloads(List<byte[]> payloads) {
        int eventYear = staticVariables.eventYear != null ? staticVariables.eventYear : 0;
        if (eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
            eventYear = staticVariables.eventYear;
        }
        List<String> bandNames = BandInfo.getCanonicalBandNamesForQR();
        List<String> venueNames = FestivalConfig.getInstance().getAllVenueNames();

        try {
            Log.d(TAG, "[QRScan] calling decompressAndMergeOneOrTwoPayloads payloadCount=" + (payloads != null ? payloads.size() : 0));
            String csv = ScheduleQRCompression.decompressAndMergeOneOrTwoPayloads(
                    payloads, eventYear, bandNames, venueNames);
            Log.d(TAG, "[QRScan] decompress OK csvLength=" + (csv != null ? csv.length() : 0));

            String currentCsv = ScheduleQRImportValidation.readCurrentScheduleContent();
            ScheduleQRImportValidation.Result validation = ScheduleQRImportValidation.validate(currentCsv, csv);
            if (!validation.success) {
                String message = getString(R.string.schedule_qr_import_validation_failed, validation.failureExampleMessage);
                Log.e(TAG_QR_ERROR, message);
                AlertDialog dialog = new AlertDialog.Builder(new ContextThemeWrapper(this, R.style.DarkDialogTheme))
                        .setTitle(R.string.schedule_qr_import_validation_failed_title)
                        .setMessage(message)
                        .setPositiveButton(android.R.string.ok, (d, which) -> d.dismiss())
                        .setCancelable(true)
                        .create();
                dialog.show();
                if (dialog.getWindow() != null) {
                    dialog.getWindow().setBackgroundDrawableResource(android.R.color.black);
                }
                return;
            }

            scheduleInfo parser = new scheduleInfo();
            Map<String, scheduleTimeTracker> currentMap = parser.ParseScheduleCSV();
            writeScheduleFileSafe(csv);
            updateScheduleCacheHashAfterWrite();
            Map<String, scheduleTimeTracker> importedMap = parser.ParseScheduleCSV();
            mergePreservedUnofficialCruiserInto(currentMap, importedMap);
            BandInfo.scheduleRecords = importedMap;
            String combinedCsv = ScheduleCSVExport.buildFullCSVFromSchedule();
            if (combinedCsv != null) {
                writeScheduleFileSafe(combinedCsv);
                updateScheduleCacheHashAfterWrite();
            }
            Intent refresh = new Intent("RefreshLandscapeSchedule");
            androidx.localbroadcastmanager.content.LocalBroadcastManager.getInstance(this).sendBroadcast(refresh);
            Toast.makeText(this, R.string.schedule_qr_import_success, Toast.LENGTH_LONG).show();
            Intent main = new Intent(this, showBands.class);
            main.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(main);
            finish();
        } catch (IOException e) {
            Log.e(TAG, "[QRScan] Decompress/import failed: " + e.getMessage(), e);
            Toast.makeText(this, R.string.schedule_qr_import_failed, Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Log.e(TAG, "[QRScan] Import failed: " + e.getMessage(), e);
            Toast.makeText(this, R.string.schedule_qr_invalid_payload, Toast.LENGTH_LONG).show();
        }
    }

    /** Copy Unofficial Event and Cruiser Organized events from currentMap into importedMap (reduces QR payload; scanner restores them). */
    private void mergePreservedUnofficialCruiserInto(Map<String, scheduleTimeTracker> currentMap, Map<String, scheduleTimeTracker> importedMap) {
        if (currentMap == null || importedMap == null) return;
        for (Map.Entry<String, scheduleTimeTracker> entry : currentMap.entrySet()) {
            String bandName = entry.getKey();
            scheduleTimeTracker tracker = entry.getValue();
            if (tracker == null || tracker.scheduleByTime == null) continue;
            for (Map.Entry<Long, scheduleHandler> timeEntry : tracker.scheduleByTime.entrySet()) {
                scheduleHandler h = timeEntry.getValue();
                if (h == null) continue;
                String type = h.getShowType();
                if (staticVariables.unofficalEvent.equals(type) || staticVariables.unofficalEventOld.equals(type)) {
                    scheduleTimeTracker target = importedMap.get(bandName);
                    if (target == null) {
                        target = new scheduleTimeTracker();
                        importedMap.put(bandName, target);
                    }
                    target.addToscheduleByTime(h.getEpochStart(), h);
                }
            }
        }
    }

    /**
     * Updates CacheHashManager's scheduleInfo hash to match the current schedule file on disk.
     * Must be called after any write to FileHandler70k.schedule (e.g. QR import) so that a
     * subsequent network download correctly detects that the file content differs and replaces it.
     */
    private void updateScheduleCacheHashAfterWrite() {
        CacheHashManager cacheManager = CacheHashManager.getInstance();
        String hash = cacheManager.calculateFileHash(FileHandler70k.schedule);
        if (hash != null) {
            cacheManager.saveCachedHash("scheduleInfo", hash);
            Log.d(TAG, "[QRScan] Updated schedule cache hash after write");
        }
    }

    /** Write CSV to schedule file so existing parser (split by comma) works: no commas inside fields. */
    private void writeScheduleFileSafe(String csv) throws IOException {
        String[] lines = csv.split("\\n");
        try (OutputStreamWriter w = new OutputStreamWriter(new FileOutputStream(FileHandler70k.schedule), StandardCharsets.UTF_8)) {
            for (int i = 0; i < lines.length; i++) {
                if (i > 0) w.write("\n");
                String line = lines[i];
                List<String> fields = ScheduleQRCompression.parseCSVLine(line.trim());
                // Sanitize: replace comma in each field with space so split(",") works
                for (int j = 0; j < fields.size(); j++) {
                    if (j > 0) w.write(",");
                    String f = fields.get(j).replace(",", " ");
                    w.write(f);
                }
            }
        }
    }

    @Override
    public boolean onSupportNavigateUp() {
        finish();
        return true;
    }

    @Override
    protected void onDestroy() {
        analysisExecutor.shutdown();
        if (barcodeScanner != null) {
            try {
                barcodeScanner.close();
            } catch (Exception e) {
                Log.d(TAG, "barcodeScanner.close", e);
            }
            barcodeScanner = null;
        }
        super.onDestroy();
    }
}
