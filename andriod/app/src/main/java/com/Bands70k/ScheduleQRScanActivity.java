package com.Bands70k;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.DecodeHintType;
import com.google.zxing.ResultMetadataType;

import com.google.common.util.concurrent.ListenableFuture;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import androidx.camera.view.PreviewView;

/**
 * Scan 1 or 2 schedule QR codes (binary payload: type + 4-byte LE size + zlib).
 * Uses BYTE_SEGMENTS for decoded bytes (like iOS BinaryQRScanner binary mode). Collects payloads
 * by type (0=full, 1=chunk1, 2=chunk2), then decompresses, writes to FileHandler70k.schedule,
 * parses and sets BandInfo.scheduleRecords, sends refresh.
 */
public class ScheduleQRScanActivity extends AppCompatActivity {

    private static final String TAG = "ScheduleQRScan";
    private static final int REQUEST_CAMERA = 1001;
    /** Try decode every N frames; lower = more attempts/sec (helps lock onto iOS QRs). */
    private static final int FRAMES_BETWEEN_SCANS = 3;
    /** Log "no QR decoded" every this many analyses (iOS→Android troubleshooting). */
    private static final int NO_DECODE_LOG_INTERVAL = 50;

    private PreviewView previewView;
    private TextView hintText;
    private ProgressBar progressBar;

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
        Preview preview = new Preview.Builder().build();
        preview.setSurfaceProvider(previewView.getSurfaceProvider());

        ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetResolution(new Size(1280, 720))
                .build();
        imageAnalysis.setAnalyzer(analysisExecutor, this::analyzeFrame);

        CameraSelector selector = new CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_BACK).build();
        try {
            provider.unbindAll();
            provider.bindToLifecycle(this, selector, preview, imageAnalysis);
        } catch (Exception e) {
            Log.e(TAG, "bindToLifecycle failed", e);
        }
        runOnUiThread(() -> progressBar.setVisibility(View.GONE));
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

    private static final int LUMINANCE_UPSCALE_FACTOR = 2;

    /** Decode QR from ImageProxy (YUV_420_888) and return raw bytes. Upscales Y plane 2x for denser QRs, then tries HybridBinarizer then GlobalHistogramBinarizer. */
    private byte[] decodeQRFromImage(ImageProxy image) {
        if (image.getPlanes() == null || image.getPlanes().length == 0) return null;
        ImageProxy.PlaneProxy yPlane = image.getPlanes()[0];
        java.nio.ByteBuffer yBuffer = yPlane.getBuffer();
        int ySize = yBuffer.remaining();
        byte[] yBytes = new byte[ySize];
        yBuffer.get(yBytes);
        int width = image.getWidth();
        int height = image.getHeight();
        int rowStride = yPlane.getRowStride();

        byte[] luminance;
        int lumWidth;
        int lumHeight;
        int lumRowStride;
        if (LUMINANCE_UPSCALE_FACTOR > 1 && width > 0 && height > 0) {
            int outW = width * LUMINANCE_UPSCALE_FACTOR;
            int outH = height * LUMINANCE_UPSCALE_FACTOR;
            luminance = upscaleLuminanceNearest(yBytes, width, height, rowStride, LUMINANCE_UPSCALE_FACTOR);
            lumWidth = outW;
            lumHeight = outH;
            lumRowStride = outW;
        } else {
            luminance = yBytes;
            lumWidth = width;
            lumHeight = height;
            lumRowStride = rowStride;
        }

        com.google.zxing.PlanarYUVLuminanceSource source = new com.google.zxing.PlanarYUVLuminanceSource(
                luminance, lumRowStride, lumHeight, 0, 0, lumWidth, lumHeight, false);
        Map<DecodeHintType, Object> hints = new EnumMap<>(DecodeHintType.class);
        hints.put(DecodeHintType.POSSIBLE_FORMATS, Collections.singleton(BarcodeFormat.QR_CODE));
        hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);

        com.google.zxing.MultiFormatReader reader = new com.google.zxing.MultiFormatReader();
        reader.setHints(hints);

        com.google.zxing.Result result = tryDecode(reader, new com.google.zxing.BinaryBitmap(
                new com.google.zxing.common.HybridBinarizer(source)));
        if (result == null) {
            result = tryDecode(reader, new com.google.zxing.BinaryBitmap(
                    new com.google.zxing.common.GlobalHistogramBinarizer(source)));
        }
        if (result != null) {
            byte[] payload = getDecodedBytePayload(result);
            if (payload != null && payload.length > 0) {
                logPayloadFirstBytes(TAG, "[QRScan] decoded", payload);
                return payload;
            }
            logZxingResultWhenPayloadEmpty(result);
        }
        return null;
    }

    /** Nearest-neighbor upscale of Y plane by scaleFactor (e.g. 2). Caller must ensure scaleFactor >= 1 and dimensions valid. */
    private static byte[] upscaleLuminanceNearest(byte[] in, int width, int height, int rowStride, int scaleFactor) {
        int outW = width * scaleFactor;
        int outH = height * scaleFactor;
        byte[] out = new byte[outW * outH];
        for (int y = 0; y < outH; y++) {
            int sy = y / scaleFactor;
            for (int x = 0; x < outW; x++) {
                int sx = x / scaleFactor;
                out[y * outW + x] = in[sy * rowStride + sx];
            }
        }
        return out;
    }

    /** Try decode and return result or null; log exception type on failure. */
    private com.google.zxing.Result tryDecode(com.google.zxing.Reader reader, com.google.zxing.BinaryBitmap bitmap) {
        try {
            return reader.decode(bitmap);
        } catch (Exception e) {
            Log.v(TAG, "[QRScan] ZXing decode " + e.getClass().getSimpleName() + ": " + e.getMessage());
            return null;
        }
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

    /**
     * Get decoded binary payload from QR result. ZXing treats QR Byte mode as binary; the decoded bytes
     * are in BYTE_SEGMENTS metadata. Fallback: getRawBytes() then text as ISO-8859-1 (lossy for binary).
     */
    private static byte[] getDecodedBytePayload(com.google.zxing.Result result) {
        if (result == null) return null;
        java.util.Map<ResultMetadataType, Object> meta = result.getResultMetadata();
        if (meta != null) {
            @SuppressWarnings("unchecked")
            java.util.List<byte[]> segments = (java.util.List<byte[]>) meta.get(ResultMetadataType.BYTE_SEGMENTS);
            if (segments != null && !segments.isEmpty()) {
                int total = 0;
                for (byte[] seg : segments) total += seg.length;
                byte[] out = new byte[total];
                int off = 0;
                for (byte[] seg : segments) {
                    System.arraycopy(seg, 0, out, off, seg.length);
                    off += seg.length;
                }
                Log.d(TAG, "[QRScan] payload source=BYTE_SEGMENTS segments=" + segments.size() + " totalBytes=" + total);
                return out;
            }
        }
        byte[] raw = result.getRawBytes();
        if (raw != null && raw.length > 0) {
            Log.d(TAG, "[QRScan] payload source=getRawBytes length=" + raw.length);
            return raw;
        }
        String text = result.getText();
        if (text != null) {
            byte[] fromText = text.getBytes(StandardCharsets.ISO_8859_1);
            Log.d(TAG, "[QRScan] payload source=getText(ISO-8859-1) textLen=" + text.length() + " bytes=" + fromText.length);
            return fromText;
        }
        Log.d(TAG, "[QRScan] payload source=none (meta no BYTE_SEGMENTS, getRawBytes null, getText null)");
        return null;
    }

    /**
     * iOS→Android troubleshooting: ZXing decoded a QR but we got no usable binary payload.
     * Log what ZXing actually returned (BYTE_SEGMENTS, getRawBytes, getText) to see if the
     * iOS QR is being decoded as text or with an unexpected structure.
     */
    private static void logZxingResultWhenPayloadEmpty(com.google.zxing.Result result) {
        if (result == null) return;
        Log.d(TAG, "[QRScan] iOS→Android troubleshooting: ZXing returned result but payload null/empty");
        java.util.Map<ResultMetadataType, Object> meta = result.getResultMetadata();
        if (meta != null) {
            @SuppressWarnings("unchecked")
            java.util.List<byte[]> segments = (java.util.List<byte[]>) meta.get(ResultMetadataType.BYTE_SEGMENTS);
            if (segments != null) {
                int total = 0;
                for (byte[] seg : segments) total += seg.length;
                Log.d(TAG, "[QRScan] ZXing BYTE_SEGMENTS: segments=" + segments.size() + " totalBytes=" + total
                        + (total > 0 ? " first20hex=" + bytesToHex(segments.get(0), 20) : ""));
            } else {
                Log.d(TAG, "[QRScan] ZXing BYTE_SEGMENTS: not present");
            }
        } else {
            Log.d(TAG, "[QRScan] ZXing resultMetadata: null");
        }
        byte[] raw = result.getRawBytes();
        if (raw != null) {
            Log.d(TAG, "[QRScan] ZXing getRawBytes: length=" + raw.length + " first20hex=" + bytesToHex(raw, 20));
        } else {
            Log.d(TAG, "[QRScan] ZXing getRawBytes: null");
        }
        String text = result.getText();
        if (text != null) {
            String prefix = text.length() > 60 ? text.substring(0, 60) + "..." : text;
            Log.d(TAG, "[QRScan] ZXing getText: length=" + text.length() + " prefix=" + prefix);
        } else {
            Log.d(TAG, "[QRScan] ZXing getText: null");
        }
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
                    } else {
                        Toast.makeText(this, R.string.schedule_qr_band_file_download_failed, Toast.LENGTH_LONG).show();
                    }
                    finish();
                });
            }).start();
            return;
        }

        doImportPayloads(payloads);
        finish();
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
                Toast.makeText(this, message, Toast.LENGTH_LONG).show();
                return;
            }

            scheduleInfo parser = new scheduleInfo();
            Map<String, scheduleTimeTracker> currentMap = parser.ParseScheduleCSV();
            writeScheduleFileSafe(csv);
            Map<String, scheduleTimeTracker> importedMap = parser.ParseScheduleCSV();
            mergePreservedUnofficialCruiserInto(currentMap, importedMap);
            BandInfo.scheduleRecords = importedMap;
            String combinedCsv = ScheduleCSVExport.buildFullCSVFromSchedule();
            if (combinedCsv != null) writeScheduleFileSafe(combinedCsv);
            Intent refresh = new Intent("RefreshLandscapeSchedule");
            androidx.localbroadcastmanager.content.LocalBroadcastManager.getInstance(this).sendBroadcast(refresh);
            Toast.makeText(this, R.string.schedule_qr_import_success, Toast.LENGTH_LONG).show();
            Intent main = new Intent(this, showBands.class);
            main.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(main);
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
        super.onDestroy();
    }
}
