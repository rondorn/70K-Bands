package com.Bands70k;

import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import io.nayuki.qrcodegen.QrCode;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Share schedule via one or two QR codes. Uses raw cached schedule CSV (same source as download)
 * when available so both platforms process the same input; otherwise builds CSV from in-memory schedule.
 * Compresses for QR and displays QR image(s) matching iOS.
 */
public class ScheduleQRShareActivity extends AppCompatActivity {

    private static final String TAG = "ScheduleQRShare";

    /** Target bitmap size (symbol only); quiet zone added separately. */
    private static final int QR_SIZE = 600;
    /** ISO 18004: quiet zone = 4 modules on all sides. Required for reliable scanning. */
    private static final int QUIET_ZONE_MODULES = 4;
    /** Minimum pixels per module so cameras can resolve the symbol (avoid too-dense QRs). */
    private static final int MIN_PIXELS_PER_MODULE = 6;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_schedule_qr_share);

        setTitle(getString(R.string.schedule_qr_share_title));

        TextView instructions = findViewById(R.id.schedule_qr_share_instructions);
        instructions.setText(buildInstructionsText());

        ImageView qr1 = findViewById(R.id.schedule_qr_image_1);
        ImageView qr2 = findViewById(R.id.schedule_qr_image_2);
        Button done = findViewById(R.id.schedule_qr_share_done);

        int eventYear = staticVariables.eventYear != null ? staticVariables.eventYear : 0;
        if (eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
            eventYear = staticVariables.eventYear;
        }

        // Use cached schedule CSV for QR with Unofficial/Cruiser stripped (matches iOS; import adds them back).
        String csv = ScheduleCSVExport.readScheduleCsvForQRExport();
        if (csv == null || csv.isEmpty()) {
            Toast.makeText(this, R.string.schedule_qr_empty_schedule, Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        List<String> bandNames = BandInfo.getCanonicalBandNamesForQR();
        List<String> venueNames = FestivalConfig.getInstance().getAllVenueNames();

        try {
            List<byte[]> payloads = ScheduleQRCompression.compressScheduleForOneOrTwoQRs(
                    csv, eventYear, bandNames, venueNames);
            if (payloads.isEmpty()) {
                Log.w(TAG, "[QRCreate] compress returned empty list");
                Toast.makeText(this, R.string.schedule_qr_compression_failed, Toast.LENGTH_LONG).show();
                finish();
                return;
            }
            Log.d(TAG, "[QRCreate] encoding " + payloads.size() + " payload(s) to QR bitmap size=" + QR_SIZE + "px (Nayuki single Byte segment, like iOS)");
            Bitmap bmp1 = encodePayloadToQR(payloads.get(0));
            if (bmp1 != null) {
                qr1.setImageBitmap(bmp1);
                Log.d(TAG, "[QRCreate] QR1 bitmap " + bmp1.getWidth() + "x" + bmp1.getHeight());
            } else {
                Log.e(TAG, "[QRCreate] QR1 encode failed for payload length=" + payloads.get(0).length);
            }
            qr1.setVisibility(View.VISIBLE);
            if (payloads.size() > 1) {
                Bitmap bmp2 = encodePayloadToQR(payloads.get(1));
                if (bmp2 != null) {
                    qr2.setImageBitmap(bmp2);
                    Log.d(TAG, "[QRCreate] QR2 bitmap " + bmp2.getWidth() + "x" + bmp2.getHeight());
                } else {
                    Log.e(TAG, "[QRCreate] QR2 encode failed for payload length=" + payloads.get(1).length);
                }
                qr2.setVisibility(View.VISIBLE);
            } else {
                qr2.setVisibility(View.GONE);
            }
        } catch (IOException e) {
            Log.e(TAG, "[QRCreate] IOException", e);
            Toast.makeText(this, R.string.schedule_qr_compression_failed, Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        done.setOnClickListener(v -> finish());
    }

    private String buildInstructionsText() {
        return getString(R.string.QRShareInstructionsIntro) + "\n"
                + getString(R.string.QRShareCondition1) + "\n"
                + getString(R.string.QRShareCondition2) + "\n\n"
                + getString(R.string.QRShareInstructionsHow) + "\n"
                + getString(R.string.QRShareStep1) + "\n"
                + getString(R.string.QRShareStep2) + "\n"
                + getString(R.string.QRShareStep3) + "\n"
                + getString(R.string.QRShareStep4);
    }

    /**
     * Encode binary payload to QR using Nayuki: single Byte-mode segment (like iOS CIFilter),
     * so iOS Vision may return the full payload instead of truncating at first segment.
     * Adds 4-module quiet zone (ISO 18004) and enforces minimum pixels per module for scannability.
     */
    private Bitmap encodePayloadToQR(byte[] payload) {
        if (payload == null || payload.length == 0) return null;
        Log.d(TAG, "[QRCreate] encodePayloadToQR: payloadLength=" + payload.length);
        try {
            QrCode qr = QrCode.encodeBinary(payload, QrCode.Ecc.MEDIUM);
            int moduleSize = qr.size;
            int scale = Math.max(MIN_PIXELS_PER_MODULE, Math.max(1, QR_SIZE / moduleSize));
            int symbolPx = moduleSize * scale;
            int borderPx = QUIET_ZONE_MODULES * scale;
            int bitmapSize = symbolPx + 2 * borderPx;
            int[] pixels = new int[bitmapSize * bitmapSize];
            Arrays.fill(pixels, 0xFFFFFFFF);
            for (int y = 0; y < symbolPx; y++) {
                for (int x = 0; x < symbolPx; x++) {
                    boolean dark = qr.getModule(x / scale, y / scale);
                    int px = (borderPx + y) * bitmapSize + (borderPx + x);
                    pixels[px] = dark ? 0xFF000000 : 0xFFFFFFFF;
                }
            }
            Bitmap bitmap = Bitmap.createBitmap(bitmapSize, bitmapSize, Bitmap.Config.ARGB_8888);
            bitmap.setPixels(pixels, 0, bitmapSize, 0, 0, bitmapSize, bitmapSize);
            Log.d(TAG, "[QRCreate] Nayuki encode OK: modules=" + moduleSize + " scale=" + scale + " px/module bitmap=" + bitmapSize + "x" + bitmapSize);
            return bitmap;
        } catch (Exception e) {
            Log.e(TAG, "[QRCreate] Nayuki encode failed: " + e.getMessage(), e);
            return null;
        }
    }
}
