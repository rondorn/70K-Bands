package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.util.AttributeSet;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.TextView;

/**
 * Tutorial overlay to help users find the profile switcher after importing
 * Shows an arrow pointing to the band count header with an explanatory message
 */
public class ProfileTutorialOverlay extends FrameLayout {
    private static final String TAG = "ProfileTutorial";
    
    private TextView messageLabel;
    private TextView dismissLabel;
    private View arrowView;
    private int targetViewY = 0;
    private int targetViewX = 0;
    
    public ProfileTutorialOverlay(Context context) {
        super(context);
        setupView();
    }
    
    public ProfileTutorialOverlay(Context context, AttributeSet attrs) {
        super(context, attrs);
        setupView();
    }
    
    private void setupView() {
        // Semi-transparent background
        setBackgroundColor(Color.argb(102, 0, 0, 0)); // 40% black
        setClickable(true);
        setFocusable(true);
        
        // Dismiss on tap anywhere
        setOnClickListener(v -> dismissTutorial());
        
        // Message label with background container
        messageLabel = new TextView(getContext());
        messageLabel.setText(R.string.tap_here_to_switch_profiles);
        messageLabel.setTextColor(Color.WHITE);
        messageLabel.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 17);
        messageLabel.setGravity(Gravity.CENTER);
        messageLabel.setPadding(32, 32, 32, 32);
        
        // Rounded corners background
        float radius = 12 * getResources().getDisplayMetrics().density;
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setColor(Color.argb(217, 0, 0, 0)); // 85% black
        drawable.setCornerRadius(radius);
        messageLabel.setBackground(drawable);
        
        // Arrow view
        arrowView = new ArrowView(getContext());
        
        // Dismiss hint
        dismissLabel = new TextView(getContext());
        dismissLabel.setText(R.string.tap_anywhere_to_close);
        dismissLabel.setTextColor(Color.argb(179, 255, 255, 255)); // 70% white
        dismissLabel.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 15);
        dismissLabel.setGravity(Gravity.CENTER);
        
        Log.d(TAG, "setupView: messageLabel text = " + messageLabel.getText());
        Log.d(TAG, "setupView: dismissLabel text = " + dismissLabel.getText());
        
        // Add views with layout params to ensure they're drawn
        FrameLayout.LayoutParams arrowParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        addView(arrowView, arrowParams);
        
        FrameLayout.LayoutParams messageParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        addView(messageLabel, messageParams);
        
        FrameLayout.LayoutParams dismissParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        );
        addView(dismissLabel, dismissParams);
        
        // Initially invisible, will fade in
        setAlpha(0f);
    }
    
    /**
     * Custom view that draws an upward-pointing arrow
     */
    private static class ArrowView extends View {
        private Paint paint;
        private Path arrowPath;
        
        public ArrowView(Context context) {
            super(context);
            paint = new Paint();
            paint.setColor(Color.WHITE);
            paint.setStyle(Paint.Style.FILL);
            paint.setAntiAlias(true);
            paint.setShadowLayer(4, 0, 2, Color.BLACK);
            setLayerType(View.LAYER_TYPE_SOFTWARE, paint); // Enable shadow
            
            arrowPath = new Path();
            setWillNotDraw(false); // Important: ensure onDraw() is called
        }
        
        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            
            float width = getWidth();
            float height = getHeight();
            
            if (width == 0 || height == 0) {
                return; // Not laid out yet
            }
            
            float centerX = width / 2;
            
            // Create bold upward-pointing arrow
            arrowPath.reset();
            arrowPath.moveTo(centerX, 0); // Top point
            arrowPath.lineTo(0, 15); // Left head
            arrowPath.lineTo(centerX - 8, 15); // Left inner
            arrowPath.lineTo(centerX - 8, height); // Left shaft
            arrowPath.lineTo(centerX + 8, height); // Right shaft
            arrowPath.lineTo(centerX + 8, 15); // Right inner
            arrowPath.lineTo(width, 15); // Right head
            arrowPath.close();
            
            canvas.drawPath(arrowPath, paint);
        }
    }
    
    /**
     * Position the overlay relative to a target view (the band count header)
     */
    public void setTargetView(View targetView) {
        // Get target view position on screen
        int[] location = new int[2];
        targetView.getLocationOnScreen(location);
        targetViewX = location[0] + (targetView.getWidth() / 2);
        targetViewY = location[1] + targetView.getHeight();
        
        Log.d(TAG, "Target view position: X=" + targetViewX + ", Y=" + targetViewY);
        
        // Trigger layout to position elements
        requestLayout();
    }
    
    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        
        if (targetViewY == 0) {
            return; // Not positioned yet
        }
        
        int width = right - left;
        int height = bottom - top;
        
        // Convert dp to pixels
        float density = getResources().getDisplayMetrics().density;
        int arrowWidth = (int) (50 * density);
        int arrowHeight = (int) (40 * density);
        int messageWidth = (int) (280 * density);
        int dismissWidth = (int) (220 * density);
        int spacing = (int) (10 * density);
        
        // Measure message label to get its actual height
        messageLabel.measure(
            View.MeasureSpec.makeMeasureSpec(messageWidth, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        );
        int messageHeight = messageLabel.getMeasuredHeight();
        
        // Measure dismiss label to get its actual height
        dismissLabel.measure(
            View.MeasureSpec.makeMeasureSpec(dismissWidth, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        );
        int dismissHeight = dismissLabel.getMeasuredHeight();
        
        // Position arrow pointing up at target
        int arrowLeft = targetViewX - (arrowWidth / 2);
        int arrowTop = targetViewY + spacing;
        arrowView.layout(arrowLeft, arrowTop, arrowLeft + arrowWidth, arrowTop + arrowHeight);
        
        // Position message below arrow
        int messageLeft = Math.max(20, Math.min(width - messageWidth - 20, targetViewX - (messageWidth / 2)));
        int messageTop = arrowTop + arrowHeight + spacing;
        messageLabel.layout(messageLeft, messageTop, messageLeft + messageWidth, messageTop + messageHeight);
        
        // Position dismiss hint at bottom
        int dismissTop = height - dismissHeight - (int) (60 * density);
        int dismissLeft = (width - dismissWidth) / 2;
        dismissLabel.layout(dismissLeft, dismissTop, dismissLeft + dismissWidth, dismissTop + dismissHeight);
        
        Log.d(TAG, "Layout: arrow=(" + arrowLeft + "," + arrowTop + "), message=(" + messageLeft + "," + messageTop + " w=" + messageWidth + " h=" + messageHeight + "), dismiss=(" + dismissLeft + "," + dismissTop + ")");
    }
    
    private void dismissTutorial() {
        animate()
            .alpha(0f)
            .setDuration(300)
            .withEndAction(() -> {
                if (getParent() != null) {
                    ((ViewGroup) getParent()).removeView(this);
                }
            })
            .start();
    }
    
    /**
     * Shows the tutorial overlay on the given activity
     */
    public static void show(Activity activity) {
        Log.d(TAG, "📚 [TUTORIAL] Showing profile switch tutorial");
        
        // Find the band count header view (the clickable profile switcher)
        View rootView = activity.findViewById(android.R.id.content);
        View bandCountHeader = activity.findViewById(R.id.headerBandCount);
        
        if (bandCountHeader == null) {
            Log.e(TAG, "❌ [TUTORIAL] Could not find headerBandCount view");
            return;
        }
        
        // Create overlay
        ProfileTutorialOverlay overlay = new ProfileTutorialOverlay(activity);
        
        // Add to root view
        ViewGroup decorView = (ViewGroup) activity.getWindow().getDecorView();
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        );
        decorView.addView(overlay, params);
        
        // Position relative to band count header
        bandCountHeader.post(() -> {
            overlay.setTargetView(bandCountHeader);
            
            Log.d(TAG, "📚 [TUTORIAL] Views added to overlay:");
            Log.d(TAG, "  - arrowView: " + overlay.arrowView);
            Log.d(TAG, "  - messageLabel: " + overlay.messageLabel.getText());
            Log.d(TAG, "  - dismissLabel: " + overlay.dismissLabel.getText());
            
            // Force layout pass
            overlay.requestLayout();
            overlay.invalidate();
            
            // Fade in
            overlay.animate()
                .alpha(1f)
                .setDuration(300)
                .start();
        });
    }
}

