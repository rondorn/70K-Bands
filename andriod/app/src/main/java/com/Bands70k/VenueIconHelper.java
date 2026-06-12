package com.Bands70k;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.Drawable;

import androidx.appcompat.content.res.AppCompatResources;
import androidx.core.graphics.drawable.DrawableCompat;

import java.util.Locale;

/** Builds filter-menu venue icons; tints generic location assets with each venue's assigned color. */
public final class VenueIconHelper {

    private VenueIconHelper() {}

    public static boolean isGenericVenueIconName(String iconName) {
        if (iconName == null) {
            return true;
        }
        String lower = iconName.toLowerCase(Locale.ROOT);
        return lower.contains("unknown")
                || "icon_unknown".equals(lower)
                || "icon_unknown_alt".equals(lower);
    }

    public static Drawable getFilterMenuVenueIcon(Context context, String venueName, boolean isEnabled) {
        FestivalConfig config = FestivalConfig.getInstance();
        String iconName = isEnabled
                ? config.getVenueGoingIcon(venueName)
                : config.getVenueNotGoingIcon(venueName);

        if (isGenericVenueIconName(iconName)) {
            return getGenericLocationIcon(context, venueName, isEnabled);
        }

        int resourceId = context.getResources().getIdentifier(iconName, "drawable", context.getPackageName());
        if (resourceId != 0) {
            return AppCompatResources.getDrawable(context, resourceId);
        }

        return getHardcodedVenueDrawable(context, venueName, isEnabled);
    }

    private static Drawable getGenericLocationIcon(Context context, String venueName, boolean isEnabled) {
        int resId = isEnabled ? R.drawable.icon_location_generic : R.drawable.icon_location_generic_alt;
        Drawable base = AppCompatResources.getDrawable(context, resId);
        if (base == null) {
            return null;
        }
        if (!isEnabled) {
            return base;
        }
        return tintWithVenueColor(base, configVenueColor(venueName));
    }

    private static Drawable getHardcodedVenueDrawable(Context context, String venueName, boolean isEnabled) {
        switch (venueName) {
            case "Lounge":
                return AppCompatResources.getDrawable(context,
                        isEnabled ? R.drawable.icon_lounge : R.drawable.icon_lounge_alt);
            case "Pool":
                return AppCompatResources.getDrawable(context,
                        isEnabled ? R.drawable.icon_pool : R.drawable.icon_pool_alt);
            case "Rink":
                return AppCompatResources.getDrawable(context,
                        isEnabled ? R.drawable.icon_rink : R.drawable.icon_rink_alt);
            case "Theater":
                return AppCompatResources.getDrawable(context,
                        isEnabled ? R.drawable.icon_theater : R.drawable.icon_theater_alt);
            default:
                return getGenericLocationIcon(context, venueName, isEnabled);
        }
    }

    private static int configVenueColor(String venueName) {
        try {
            return Color.parseColor("#" + FestivalConfig.getInstance().getVenueColor(venueName));
        } catch (IllegalArgumentException e) {
            return Color.parseColor("#A9A9A9");
        }
    }

    /** Recolor a generic grey icon using the venue color; asset stays neutral on disk. */
    private static Drawable tintWithVenueColor(Drawable drawable, int color) {
        Drawable wrapped = DrawableCompat.wrap(drawable.mutate());
        DrawableCompat.setTint(wrapped, color);
        return wrapped;
    }
}
