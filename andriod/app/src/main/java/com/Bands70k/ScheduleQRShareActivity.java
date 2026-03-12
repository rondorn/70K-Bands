package com.Bands70k;

import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * Share schedule via one or two QR codes. Uses raw cached schedule CSV (same source as download)
 * when available so both platforms process the same input; otherwise builds CSV from in-memory schedule.
 * Compresses for QR and displays QR image(s) matching iOS.
 */
public class ScheduleQRShareActivity extends AppCompatActivity {

    private static final String TAG = "ScheduleQRShare";

    /** Match iOS: 400pt display; use 600px bitmap so QR is less dense and scannable (iOS uses 400pt scaled from CIFilter). */
    private static final int QR_SIZE = 600;

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
            Log.d(TAG, "[QRCreate] encoding " + payloads.size() + " payload(s) to QR bitmap size=" + QR_SIZE + "px ISO-8859-1 Byte mode");
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
                LinearLayout container = findViewById(R.id.schedule_qr_share_qr_container);
                if (container != null) container.setOrientation(LinearLayout.VERTICAL);
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

    /** Encode binary payload to QR as ISO-8859-1 so scanner returns raw bytes (Byte mode). */
    private Bitmap encodePayloadToQR(byte[] payload) {
        if (payload == null || payload.length == 0) return null;
        Log.d(TAG, "[QRCreate] encodePayloadToQR: payloadLength=" + payload.length + " QR_SIZE=" + QR_SIZE);
        String asString = new String(payload, StandardCharsets.ISO_8859_1);
        Map<EncodeHintType, Object> hints = new java.util.EnumMap<>(EncodeHintType.class);
        hints.put(EncodeHintType.CHARACTER_SET, "ISO-8859-1");
        hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.L);
        try {
            QRCodeWriter writer = new QRCodeWriter();
            BitMatrix matrix = writer.encode(asString, BarcodeFormat.QR_CODE, QR_SIZE, QR_SIZE, hints);
            int w = matrix.getWidth();
            int h = matrix.getHeight();
            int[] pixels = new int[w * h];
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    pixels[y * w + x] = matrix.get(x, y) ? 0xFF000000 : 0xFFFFFFFF;
                }
            }
            Bitmap bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
            bitmap.setPixels(pixels, 0, w, 0, 0, w, h);
            Log.d(TAG, "[QRCreate] ZXing encode OK: matrix " + w + "x" + h);
            return bitmap;
        } catch (WriterException e) {
            Log.e(TAG, "[QRCreate] ZXing WriterException: " + e.getMessage(), e);
            return null;
        }
    }
}
