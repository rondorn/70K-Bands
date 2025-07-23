package com.Bands70k;

import android.content.Context;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.Iterator;
import java.util.Map;

/**
 * Generates HTML for displaying band details, schedules, and links in the app.
 */
public class DetailHtmlGeneration {

    private Integer noteViewPercentage = 54;
    private Integer noteViewPercentageDefault = 54;
    private Context mContext;

    /**
     * Constructor for DetailHtmlGeneration.
     * @param context The application context.
     */
    public DetailHtmlGeneration(Context context) {
        mContext = context;
    }

    /**
     * Sets up the HTML for the band title and logo.
     * @param bandName The name of the band.
     * @return The HTML string for the title and logo.
     */
    public String setupTitleAndLogo(String bandName){

        ImageHandler imageHandler = new ImageHandler(bandName);
        String htmlImage = String.valueOf(imageHandler.getImageImmediate());
        String imageSetup = getImageBoundry(htmlImage, bandName);
        Log.d("loadImageFile", "htmlImahge is   " + htmlImage);
        String htmlText =
                "<html><head>" +
                        "<meta name='viewport' content='width=device-width, initial-scale=1'>" +
                        "<script>function invert(){\n" +
                        "document.getElementById(\"bandLogo\").style.filter=\"invert(100%)\";\n" +
                        "}</script><body leftmargin=0 topmargin=0 rightmargin=0 bottommargin=0 bgcolor=\"black\" style='color:white;height:100%'> " +
                        "<div style='overflow: hidden;height=90%'>" +
                        "<div style='height:20px;font-size:130%;left:0;right:0;'>" +
                        "<center>" + bandName + "</center>" + "</div>" +
                        "<div style='width=100%;left:0;right:0;'>" +
                        "<center><img " + imageSetup + " Id=bandLogo style='max-width: 100%;max-height: 100%;' src='" + htmlImage + "'/></center></div>";

        Log.d("tileLogohtmlData", "tile Logo html Data is :" + htmlText);

        return htmlText;

    }
    /**
     * Determines the image boundary for the band logo.
     * @param image The image URL.
     * @param bandName The name of the band.
     * @return The image boundary string for HTML.
     */
    public String getImageBoundry(String image, String bandName){
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;

        int width = 0;
        int height = 0;
        String imageSetup = "";

        //Returns null, sizes are in the options variable
        URL url = null;
        try {
            url = new URL(image);
            Bitmap bmp = BitmapFactory.decodeStream(url.openStream());

            width = bmp.getWidth();
            height = bmp.getHeight();

        } catch (Exception e) {
            e.printStackTrace();
        }
        int ratio = 0;
        if (width > 0 &&  height > 0) {
            ratio = (width / height);
            if (ratio > 5) {
                imageSetup = "width=70%";

            } else {
                imageSetup = "height=10%";
            }
        } else {
            imageSetup = "width=70%";
            ratio = 5;
        }

        Log.d("tileLogohtmlData", "image dimensions are " + String.valueOf(ratio) + "-" + imageSetup + "-" + bandName);

        return imageSetup;
    }

    /**
     * Generates the HTML for the band's schedule.
     * @param bandName The name of the band.
     * @param displayWidth The width for display.
     * @return The HTML string for the schedule.
     */
    public String displaySchedule(String bandName, int displayWidth){

        String scheduleHtml = "";
        noteViewPercentage = noteViewPercentageDefault;
        try {
            if (BandInfo.scheduleRecords.get(bandName) != null) {
                Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();

                displayWidth = 440;
                int locationWidth = displayWidth - 150;

                while (entries.hasNext()) {

                    noteViewPercentage = noteViewPercentage - 4;
                    Map.Entry thisEntry = (Map.Entry) entries.next();
                    Object key = thisEntry.getKey();

                    String location = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowLocation();
                    String locationColor = staticVariables.getVenueColor(location);

                    String rawStartTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getStartTimeString();
                    String startTime = dateTimeFormatter.formatScheduleTime(rawStartTime);
                    String endTime = dateTimeFormatter.formatScheduleTime(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getEndTimeString());
                    String dayNumber = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowDay();
                    dayNumber = dayNumber.replaceFirst("Day ", "");

                    String eventType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowType();
                    String eventNote = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key).getShowNotes();

                    String attendIndex = bandName + ":" + location + ":" + rawStartTime + ":" + eventType + ":" + String.valueOf(staticVariables.eventYear);
                    String eventTypeImage = showBandDetails.getEventTypeImage(eventType, bandName);
                    String attendedImage = showBandDetails.getAttendedImage(attendIndex);

                    //dont need to display show for that event type as this is assumed to be the dsefault
                    if (eventType.equals(staticVariables.show)){
                        eventType = "";
                    }

                    if (staticVariables.venueLocation.get(location) != null) {
                        location = location + " " + staticVariables.venueLocation.get(location);
                    }

                    scheduleHtml += "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" width=100%  onclick='ok.performClick(\"" + attendIndex + "\");'><tr width=100% height=21px>";
                    scheduleHtml += "<td width=2% bgcolor=" + locationColor + "><td>";
                    scheduleHtml += "<td width=62% style='background:black;font-size:18px;color:white'>" + location  + "</td>";

                    if (attendedImage.isEmpty() == false) {
                        scheduleHtml += "<td width=7% style='background:black'><image src='" + attendedImage + "' height=12 width=18/>&nbsp;</td>";
                    } else {
                        scheduleHtml += "<td width=7%></td>";
                    }
                    scheduleHtml += "<td width=20% style='background:black;font-size:14px;color:white;text-align:right'>" + startTime  + "&nbsp;</td>";
                    scheduleHtml += "<td width=7% bgcolor=grey style='font-size:12px;color:white;text-align:center'>" + staticVariables.context.getString(R.string.Day) + "</td></tr>";

                    scheduleHtml += "<td width=2% bgcolor=" + locationColor + "><td>";
                    scheduleHtml += "<td width=64%><table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" width=100%>";
                    scheduleHtml += "<tr><td style='background:black;font-size:11px;color:white;text-align:right'>" + Utilities.convertEventTypeToLocalLanguage(eventType) +  "&nbsp;</td></tr>";
                    scheduleHtml += "<tr><td style='background:black;font-size:11px;color:white;text-align:left'>" + eventNote + "</td></tr></table>";

                    if (eventTypeImage.isEmpty() == false) {
                        scheduleHtml += "<td width=7% style='background:black'><image src='" + eventTypeImage + "' height=18 width=18/>&nbsp;</td>";
                    } else {
                        scheduleHtml += "<td width=7%></td>";
                    }

                    scheduleHtml += "<td width=20% style='background:black;font-size:14px;color:grey;text-align:right'>" + endTime  + "&nbsp;</td>";
                    scheduleHtml += "<td width=7% bgcolor=grey style='font-size:14px;color:white;text-align:center'>" + dayNumber + "</td></tr></table>";

                }

            }
        } catch (Exception error){
            noteViewPercentage = noteViewPercentageDefault;

        }

        Log.d("schedule htmlData is", "Adding Schedule HTML text of: " + scheduleHtml);

        return scheduleHtml;
    }

    /**
     * Generates the HTML for the band's external links.
     * @param bandName The name of the band.
     * @param orientation The orientation (portrait or landscape).
     * @return The HTML string for the links.
     */
    public String displayLinks(String bandName, String orientation){

        String html = "";

        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal") == true) {

            String disable;
            if (OnlineStatus.isOnline() == true) {
                disable = "";
            } else {
                //disable and gray out link if offline
                disable = "style='pointer-events:none;cursor:default;color:grey'";
            }

            //if (orientation == "portrait") {
                String linkLabel = staticVariables.context.getString(R.string.visitBands);
                Log.d("Officia;Link", "Link is " + BandInfo.getOfficalWebLink(bandName));
                html = "<div style='width=100%; left:0;right:0;'>" +
                        "<center><table width=95%><tr width=100% style='font-size:15px;font-size:5.0vw;list-style-type:none;text-align:left;margin-left:60px'>" +
                        "<td  style='color:" + staticVariables.blueColor + "' + staticVariables.blueColor + \"' width=40%>" + linkLabel + ": </td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getOfficalWebLink(bandName) + "' onclick='link.webLinkClick(\"webPage\")'><img src=file:///android_res/drawable/icon_www.png height=24 width=27></a></td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getMetalArchivesWebLink(bandName) + "' onclick='link.webLinkClick(\"metalArchives\")'><img src=file:///android_res/drawable/icon_ma.png height=21 width=27></a></td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getWikipediaWebLink(bandName) + "' onclick='link.webLinkClick(\"wikipedia\")'><img src=file:///android_res/drawable/icon_wiki.png height=17 width=27></a></td>" +
                        "<td width=15%><a " + disable + " href='" + BandInfo.getYouTubeWebLink(bandName) + "' onclick='link.webLinkClick(\"youTube\")'><img src=file:///android_res/drawable/icon_youtube.png height=19 width=27></a></td>" +
                        "</tr></table></center></div>";
            //}

        }

        return html;

    }

    /**
     * Generates the HTML for extra band data.
     * @param bandName The name of the band.
     * @return The HTML string for extra data.
     */
    public String displayExtraData(String bandName){

        String htmlText = "";
        if (BandInfo.getCountry(bandName) != "") {

            String countryLabel = staticVariables.context.getString(R.string.country);
            String genreLabel = staticVariables.context.getString(R.string.genre);
            String previousYearsLabel = staticVariables.context.getString(R.string.LastOnCruise);
            String notesLabel = staticVariables.context.getString(R.string.Note);

            htmlText += "<div style='width=100%; left:0;right:0;width=100%;'>" +
                    "<ul style='overflow:hidden;font-size:14px;font-weight:bold;font-size:3.5vw;list-style-type:none;text-align:left;margin-left:-25px;color:white'>";

            if (BandInfo.getCountry(bandName).isEmpty() == false) {
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:bold;display:inline;width:35%'>" + countryLabel + ":</li>";
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:normal;display:inline;width:65%'>" + BandInfo.getCountry(bandName) + "</li>";
            }

            if (BandInfo.getGenre(bandName).isEmpty() == false) {
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:bold;display:inline;width:35%'>" + genreLabel + ":</li>";
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:normal;display:inline;width:65%'>" + BandInfo.getGenre(bandName) + "</li>";
            }

            if (BandInfo.getPriorYears(bandName).isEmpty() == false) {
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:bold;display:inline;width:35%'>" + previousYearsLabel + ":</li>";
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:normal;display:inline;width:65%'>" + BandInfo.getPriorYears(bandName) + "</li>";
            }

            if (BandInfo.getNote(bandName).isEmpty() == false) {
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:bold;display:inline;width:35%'>" + notesLabel + ":</li>";
                htmlText += "<li style='color:" + staticVariables.lightGrey + ";float:left;font-weight:normal;display:inline;width:65%'>" + BandInfo.getNote(bandName) + "</li>";
            }

            htmlText += "</ul></div>";

        }

        return htmlText;
    }

    public String displayNotes(String bandNote){

        String notesHeight = String.valueOf(noteViewPercentage) + "%";

        int width = Resources.getSystem().getDisplayMetrics().widthPixels;
        int height = Resources.getSystem().getDisplayMetrics().heightPixels;

        String fontSizeString = "4.5vw";

        if (width > 1700 && height > 1700){
            fontSizeString = "2.0vw";
        }
        Log.d("screenDimensions", "screenDimensions " + width + "-" + height);

        Log.d("notesHeight", "notesHeight equals " + notesHeight);
        String htmlText = "";
        if (bandNote != "") {
            htmlText += "<br>";
            //htmlText += "<div style='height:" + notesHeight + ";text-align:left;margin-left:10px;padding-bottom:20px;overflow:auto;width:95%;scroll;text-overflow:ellipsis;font-size:11px;font-size:4.5vw' ondblclick='ok.performClick(\"Notes\");'>" + bandNote + "</div></center>";
            htmlText += "<div style='height:" + notesHeight + ";text-align:left;margin-left:10px;padding-bottom:20px;overflow:auto;width:95%;scroll;text-overflow:ellipsis;font-size:11px;font-size:" + fontSizeString + "' ondblclick='ok.performClick(\"Notes\");'>" + bandNote + "</div></center>";
        }

        return htmlText;
    }

    public String displayMustMightWont(String rankIconLocation,
                                              String unknownButtonColor,
                                              String mustButtonColor,
                                              String mightButtonColor,
                                              String wontButtonColor){



        String htmlText = "<div style='position:fixed;bottom:10;width: 100%;left:0;right:0'><center>";
        htmlText += "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" width=100%><tr>";

        if (rankIconLocation.isEmpty() == false) {
            htmlText += "<td width=10%><img src='" + rankIconLocation + "' height=28 width=28></img></td>";
        } else {
            htmlText += "<td width=10%></td>";
        }

        htmlText += "<td width=22%><button style='color:white;width:100%;background:" + unknownButtonColor + "' type=button value=" + staticVariables.unknownKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.unknown) + "</button></td>";
        htmlText += "<td width=22%><button style='color:white;width:100%;background:" + mustButtonColor + "' type=button value=" + staticVariables.mustSeeKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.must) + "</button></td>";
        htmlText += "<td width=22%><button style='color:white;width:100%;background:" + mightButtonColor + "' type=button value=" + staticVariables.mightSeeKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.might) + "</button></td>";
        htmlText += "<td width=22%><button style='color:white;width:100%;background:" + wontButtonColor + "' type=button value=" + staticVariables.wontSeeKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.wont) + "</button></td>";
        htmlText += "</td></table></center></div>";

        Log.d("mustMightWonthtmlDatais", "Adding MustMightWont HTML text of: " + htmlText);
        return htmlText;
    }
}
