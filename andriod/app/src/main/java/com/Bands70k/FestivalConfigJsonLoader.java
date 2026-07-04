package com.Bands70k;

import android.content.Context;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * About-screen team member (name + localized role keys from festival.json).
 */
class AboutTeamMember {
    public final String name;
    public final String roleTranslationKey;
    public final String photoPositionTranslationKey;
    /** Android drawable resource names; empty when this member has no photo(s). */
    public final List<String> photoDrawableNames;

    AboutTeamMember(String name, String roleTranslationKey, String photoPositionTranslationKey,
                    List<String> photoDrawableNames) {
        this.name = name;
        this.roleTranslationKey = roleTranslationKey;
        this.photoPositionTranslationKey = photoPositionTranslationKey;
        this.photoDrawableNames = photoDrawableNames;
    }
}

/**
 * About-screen team section from festival.json.
 */
class AboutTeamConfig {
    public final List<AboutTeamMember> members;

    AboutTeamConfig(List<AboutTeamMember> members) {
        this.members = members;
    }
}

/**
 * Loads {@link FestivalConfig} fields from bundled assets/festival.json and registry.json.
 */
final class FestivalConfigJsonLoader {

    private static final String TAG = "FestivalConfig";
    private static final String FESTIVAL_ASSET = "festival.json";
    private static final String REGISTRY_ASSET = "festival_registry.json";

    private FestivalConfigJsonLoader() {
    }

    static LoadedFestivalConfig load(Context context) {
        try {
            JSONObject festivalRoot = readJsonAsset(context, FESTIVAL_ASSET);
            JSONObject registry = readJsonAsset(context, REGISTRY_ASSET);
            String[] shareExtensions = loadShareExtensions(registry, festivalRoot);
            return parse(context, festivalRoot, registry, shareExtensions);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to load festival config", e);
        }
    }

    private static String[] loadShareExtensions(JSONObject registry, JSONObject festivalRoot) throws Exception {
        try {
            JSONArray arr = registry.getJSONArray("shareFileExtensions");
            String[] out = new String[arr.length()];
            for (int i = 0; i < arr.length(); i++) {
                out[i] = arr.getString(i);
            }
            return out;
        } catch (Exception e) {
            Log.w(TAG, "shareFileExtensions missing from registry; using festival share extension only", e);
            return new String[]{festivalRoot.getString("shareFileExtension")};
        }
    }

    private static String topicFromRegistryOrFestival(
            JSONObject registry, JSONObject festivalRoot, String key) throws Exception {
        if (festivalRoot.has(key) && !festivalRoot.isNull(key)) {
            String override = festivalRoot.optString(key, null);
            if (override != null && !override.isEmpty()) {
                return override;
            }
        }
        return registry.getString(key);
    }

    private static LoadedFestivalConfig parse(
            Context context, JSONObject root, JSONObject registry, String[] shareExtensions) throws Exception {
        LoadedFestivalConfig c = new LoadedFestivalConfig();
        c.shareExtensions = shareExtensions;
        c.festivalName = root.getString("festivalName");
        c.festivalShortName = root.getString("festivalShortName");
        c.appName = root.getString("appName");
        c.packageName = root.getString("packageName");
        c.defaultStorageUrl = root.getString("defaultStorageUrl");
        c.defaultStorageUrlTest = root.getString("defaultStorageUrlTest");
        c.firebaseConfigFile = platformString(root.getJSONObject("firebaseConfigFile"), "android");
        c.subscriptionTopic = topicFromRegistryOrFestival(registry, root, "subscriptionTopic");
        c.subscriptionTopicTest = topicFromRegistryOrFestival(registry, root, "subscriptionTopicTest");
        c.subscriptionUnofficalTopic = topicFromRegistryOrFestival(registry, root, "subscriptionUnofficalTopic");
        c.artistUrlDefault = root.optString("artistUrlDefault", "");
        c.scheduleUrlDefault = root.optString("scheduleUrlDefault", "");
        c.logoResourceName = platformString(root.getJSONObject("logo"), "android");
        c.logoResourceId = FestivalConfig.getDrawableResourceId(context, c.logoResourceName);
        c.appIconResourceId = FestivalConfig.getDrawableResourceId(
                context, platformString(root.getJSONObject("appIconDrawable"), "android"));
        c.notificationChannelId = root.getString("notificationChannelId");
        c.notificationChannelName = root.getString("notificationChannelName");
        c.notificationChannelDescription = root.getString("notificationChannelDescription");
        c.shareUrl = root.getString("shareUrl");
        c.shareFileExtension = root.getString("shareFileExtension");
        c.meetAndGreetsEnabledDefault = root.getBoolean("meetAndGreetsEnabledDefault");
        c.specialEventsEnabledDefault = root.getBoolean("specialEventsEnabledDefault");
        c.unofficalEventsEnabledDefault = root.getBoolean("unofficalEventsEnabledDefault");
        c.aiSchedule = root.getBoolean("aiSchedule");
        c.scheduleQRShareEnabled = root.getBoolean("scheduleQRShareEnabled");
        c.scheduleQRGuideURL = root.optString("scheduleQRGuideURL", "").trim();
        c.commentsNotAvailableTranslationKey = root.getString("commentsNotAvailableTranslationKey");
        c.commentsNotAvailableStringResourceId = resolveStringResourceId(context, c.commentsNotAvailableTranslationKey);

        JSONObject graphics = root.getJSONObject("graphics");
        c.mustSeeIconSmall = platformString(graphics.getJSONObject("mustSeeIconSmall"), "android");
        c.mightSeeIconSmall = platformString(graphics.getJSONObject("mightSeeIconSmall"), "android");
        c.wontSeeIconSmall = platformString(graphics.getJSONObject("wontSeeIconSmall"), "android");
        c.unknownIconSmall = platformString(graphics.getJSONObject("unknownIconSmall"), "android");
        c.mustSeeIcon = platformString(graphics.getJSONObject("mustSeeIcon"), "android");
        c.mustSeeIconAlt = platformString(graphics.getJSONObject("mustSeeIconAlt"), "android");
        c.mightSeeIcon = platformString(graphics.getJSONObject("mightSeeIcon"), "android");
        c.mightSeeIconAlt = platformString(graphics.getJSONObject("mightSeeIconAlt"), "android");
        c.wontSeeIcon = platformString(graphics.getJSONObject("wontSeeIcon"), "android");
        c.wontSeeIconAlt = platformString(graphics.getJSONObject("wontSeeIconAlt"), "android");
        c.unknownIcon = platformString(graphics.getJSONObject("unknownIcon"), "android");
        c.unknownIconAlt = platformString(graphics.getJSONObject("unknownIconAlt"), "android");
        c.preferencesIcon = platformString(graphics.getJSONObject("preferencesIcon"), "android");
        c.shareIcon = platformString(graphics.getJSONObject("shareIcon"), "android");
        c.statsIcon = platformString(graphics.getJSONObject("statsIcon"), "android");
        c.fallbackMiscGenericGoingIcon = platformString(graphics.getJSONObject("fallbackMiscGenericGoingIcon"), "android");
        c.fallbackMiscGenericNotGoingIcon = platformString(graphics.getJSONObject("fallbackMiscGenericNotGoingIcon"), "android");

        c.venues = parseVenues(root.getJSONArray("venues"));
        c.genericVenueSlots = parseGenericSlots(root.getJSONArray("genericVenueSlots"));
        c.eventTypeDisplayNames = parseLocalizedEventMap(root.getJSONObject("eventTypeDisplayNames"));
        c.eventTypeFilterDisplayNames = parseLocalizedEventMap(root.getJSONObject("eventTypeFilterDisplayNames"));
        c.aboutTeam = parseAboutTeam(root.getJSONObject("about"));
        return c;
    }

    private static AboutTeamConfig parseAboutTeam(JSONObject about) throws Exception {
        JSONArray membersArr = about.getJSONArray("members");
        List<AboutTeamMember> members = new ArrayList<>();
        for (int i = 0; i < membersArr.length(); i++) {
            JSONObject m = membersArr.getJSONObject(i);
            String positionKey = m.has("photoPositionTranslationKey") && !m.isNull("photoPositionTranslationKey")
                    ? m.getString("photoPositionTranslationKey") : null;
            members.add(new AboutTeamMember(
                    m.getString("name"),
                    m.getString("roleTranslationKey"),
                    positionKey,
                    parseMemberPhotos(m)
            ));
        }
        return new AboutTeamConfig(members);
    }

    private static List<String> parseMemberPhotos(JSONObject member) throws Exception {
        List<String> photoNames = new ArrayList<>();
        if (member.has("photos") && !member.isNull("photos")) {
            JSONArray photosArr = member.getJSONArray("photos");
            for (int j = 0; j < photosArr.length(); j++) {
                photoNames.add(platformString(photosArr.getJSONObject(j), "android"));
            }
        } else if (member.has("photo") && !member.isNull("photo")) {
            photoNames.add(platformString(member.getJSONObject("photo"), "android"));
        }
        return photoNames;
    }

    private static List<Venue> parseVenues(JSONArray arr) throws Exception {
        List<Venue> venues = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject v = arr.getJSONObject(i);
            venues.add(new Venue(
                    v.getString("name"),
                    v.getString("color"),
                    platformString(v.getJSONObject("goingIcon"), "android"),
                    platformString(v.getJSONObject("notGoingIcon"), "android"),
                    v.getString("location")
            ));
        }
        return venues;
    }

    private static List<GenericVenueSlot> parseGenericSlots(JSONArray arr) throws Exception {
        List<GenericVenueSlot> slots = new ArrayList<>();
        for (int i = 0; i < arr.length(); i++) {
            JSONObject s = arr.getJSONObject(i);
            slots.add(new GenericVenueSlot(
                    s.getString("color"),
                    platformString(s.getJSONObject("goingIcon"), "android"),
                    platformString(s.getJSONObject("notGoingIcon"), "android")
            ));
        }
        return slots;
    }

    private static Map<String, Map<String, String>> parseLocalizedEventMap(JSONObject root) throws Exception {
        Map<String, Map<String, String>> out = new HashMap<>();
        Iterator<String> keys = root.keys();
        while (keys.hasNext()) {
            String eventType = keys.next();
            JSONObject langs = root.getJSONObject(eventType);
            Map<String, String> perLang = new HashMap<>();
            Iterator<String> langKeys = langs.keys();
            while (langKeys.hasNext()) {
                String lang = langKeys.next();
                perLang.put(lang.toLowerCase(Locale.ROOT), langs.getString(lang));
            }
            out.put(eventType, perLang);
        }
        return out;
    }

    private static int resolveStringResourceId(Context context, String name) {
        int id = context.getResources().getIdentifier(name, "string", context.getPackageName());
        if (id == 0) {
            throw new IllegalStateException("Missing string resource for comments key: " + name);
        }
        return id;
    }

    private static String platformString(JSONObject obj, String platform) throws Exception {
        return obj.getString(platform);
    }

    private static JSONObject readJsonAsset(Context context, String assetName) throws Exception {
        try (InputStream in = context.getAssets().open(assetName);
             BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append('\n');
            }
            return new JSONObject(sb.toString());
        }
    }

    static final class LoadedFestivalConfig {
        String[] shareExtensions;
        String festivalName;
        String festivalShortName;
        String appName;
        String packageName;
        String defaultStorageUrl;
        String defaultStorageUrlTest;
        String firebaseConfigFile;
        String subscriptionTopic;
        String subscriptionTopicTest;
        String subscriptionUnofficalTopic;
        String artistUrlDefault;
        String scheduleUrlDefault;
        String logoResourceName;
        int logoResourceId;
        int appIconResourceId;
        String notificationChannelId;
        String notificationChannelName;
        String notificationChannelDescription;
        String shareUrl;
        String shareFileExtension;
        String mustSeeIconSmall;
        String mightSeeIconSmall;
        String wontSeeIconSmall;
        String unknownIconSmall;
        String mustSeeIcon;
        String mustSeeIconAlt;
        String mightSeeIcon;
        String mightSeeIconAlt;
        String wontSeeIcon;
        String wontSeeIconAlt;
        String unknownIcon;
        String unknownIconAlt;
        String preferencesIcon;
        String shareIcon;
        String statsIcon;
        String fallbackMiscGenericGoingIcon;
        String fallbackMiscGenericNotGoingIcon;
        List<Venue> venues;
        List<GenericVenueSlot> genericVenueSlots;
        boolean meetAndGreetsEnabledDefault;
        boolean specialEventsEnabledDefault;
        boolean unofficalEventsEnabledDefault;
        Map<String, Map<String, String>> eventTypeDisplayNames;
        Map<String, Map<String, String>> eventTypeFilterDisplayNames;
        String commentsNotAvailableTranslationKey;
        int commentsNotAvailableStringResourceId;
        boolean aiSchedule;
        boolean scheduleQRShareEnabled;
        /** Custom URL for guide QR (camera app opens in-app schedule scanner). Empty when not configured. */
        String scheduleQRGuideURL;
        AboutTeamConfig aboutTeam;
    }
}
