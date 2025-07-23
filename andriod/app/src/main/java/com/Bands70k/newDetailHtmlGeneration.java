package com.Bands70k;

import android.content.Context;
import android.content.res.Resources;
import android.util.DisplayMetrics;
import android.util.Log;

import java.util.Iterator;
import java.util.Map;

/**
 * Generates HTML for displaying band details, schedules, and links in the app (new version).
 */
public class newDetailHtmlGeneration {

    private static Integer noteViewPercentage = 65;
    private Context mContext;

    /**
     * Constructor for newDetailHtmlGeneration.
     * @param context The application context.
     */
    public newDetailHtmlGeneration(Context context) {
        mContext = context;
    }

    /**
     * Sets up the HTML for the band title and logo.
     * @param bandName The name of the band.
     * @return The HTML string for the title and logo.
     */
    public String setupTitleAndLogo(String bandName){

        ImageHandler imageHandler = new ImageHandler(bandName);
        String imageUrl = String.valueOf(imageHandler.getImageImmediate());

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
                        "<center><img id=\"bandLogo\" style='max-height:100px;max-width:90%' src='" + imageUrl + "'</img></center></div>";

        Log.d("tileLogohtmlData", "tile Logo html Data is :" + htmlText);

        return htmlText;

    }

    /**
     * Generates the HTML for the band's schedule.
     * @param bandName The name of the band.
     * @param displayWidth The width for display.
     * @return The HTML string for the schedule.
     */
    public String displaySchedule(String bandName, int displayWidth){

        String scheduleHtml = "";

        try {
            if (BandInfo.scheduleRecords.get(bandName) != null) {
                Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();

                //Log.d("schedule htmlData is", "display width processes: " + displayWidth + " - " + (int)densityDpi);
                //Log.d("schedule htmlData is", "display width processes: - " + widthPixels + " - " + (int)scaleDense  + " - " + (int)xdpi);
                displayWidth = 440;
                int locationWidth = displayWidth - 150;

                while (entries.hasNext()) {

                    noteViewPercentage = noteViewPercentage - 8;
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

                    location = location + " " + staticVariables.venueLocation.get(location);

                    //top row
                    scheduleHtml += "<div style='face=sans-serif-thin;text-align::left;display:grid;grid-template-columns: 2% 62% 7% 20% 7%;height:21px;width=100%;left:0;right:0;margin:0;background:black' onclick='ok.performClick(\"" + attendIndex + "\");'>";
                    scheduleHtml += "<div style='background:" + locationColor + "'></div>";
                    scheduleHtml += "<div style='background:black;font-size:18px;color:white'>" + location + "</div>";


                    if (attendedImage.isEmpty() == false) {
                        scheduleHtml += "<div style='background:black'><image src='" + attendedImage + "' height=12 width=18/>&nbsp;</div>";
                    } else {
                        scheduleHtml += "<div style='background:black'></div>";
                    }

                    scheduleHtml += "<div style='text-align:right;background:black;font-size:14px;color:white'>" + startTime + "&nbsp;</div>";
                    scheduleHtml += "<div style='text-align:center;background:grey;font-size:12px;color:white'>Day</div></div>";

                    //bottom row
                    scheduleHtml += "<div style='face=sans-serif-thin;text-align::left;display:grid;grid-template-columns: 2% 62% 7% 20% 7%;height:21px;width=100%;left:0;right:0;margin:0;background:black' onclick='ok.performClick(\"" + attendIndex + "\");'>";
                    scheduleHtml += "<div style='background:" + locationColor + "'></div>";
                    scheduleHtml += "<div style='display:grid;grid-template-columns:100%;height:21px;width=100%;left:0;right:0'>";
                    scheduleHtml += "<div style='display:grid;grid-template-columns:100%'>";
                    scheduleHtml += "<div style='text-align:right;background:black;font-size:11px;color:white'>" + eventType + "&nbsp;</div></div>";
                    scheduleHtml += "<div style='display:grid;grid-template-columns:72%'>";
                    scheduleHtml += "<div style='text-align:left;background:black;font-size:11px;color:white'>" + eventNote + "</div></div></div>";

                    if (eventType.isEmpty() == true){
                        scheduleHtml += "<div style='background:black'></div>";
                    } else {
                        scheduleHtml += "<div style='background:black'><image src='" + eventTypeImage + "' height=16 width=16/>&nbsp;</div>";
                    }



                    scheduleHtml += "<div style='text-align:right;background:black;font-size:14px;color:grey'>" + endTime + "&nbsp;</div>";
                    scheduleHtml += "<div style='text-align:center;background:grey;font-size:14px;color:white'><b>" + dayNumber + "</b></div></div>";


                }

            }
        } catch (Exception error){
            //no worries

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
        Log.d("rotation", "rotation is WTH");
        if (BandInfo.getMetalArchivesWebLink(bandName).contains("metal") == true) {

            String disable;
            if (OnlineStatus.isOnline() == true) {
                disable = "";
            } else {
                //disable and gray out link if offline
                disable = "style='pointer-events:none;cursor:default;color:grey'";
            }

            Log.d("rotation", "rotation is generating links!");

            Log.d("Officia;Link", "Link is " + BandInfo.getOfficalWebLink(bandName));
            html = "<div style='width=100%; left:0;right:0;'>" +
                    "<center><table width=95%><tr width=100% style='font-size:15px;font-size:5.0vw;list-style-type:none;text-align:left;margin-left:60px'>" +
                    "<td  style='color:" + staticVariables.blueColor + "' + staticVariables.blueColor + \"' width=40%>Visit Band On: </td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getOfficalWebLink(bandName) + "' onclick='link.webLinkClick(\"webPage\")'><img src=file:///android_res/drawable/icon_www.png height=24 width=27></a></td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getMetalArchivesWebLink(bandName) + "' onclick='link.webLinkClick(\"metalArchives\")'><img src=file:///android_res/drawable/icon_ma.png height=21 width=27></a></td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getWikipediaWebLink(bandName) + "' onclick='link.webLinkClick(\"wikipedia\")'><img src=file:///android_res/drawable/icon_wiki.png height=17 width=27></a></td>" +
                    "<td width=15%><a " + disable + " href='" + BandInfo.getYouTubeWebLink(bandName) + "' onclick='link.webLinkClick(\"youTube\")'><img src=file:///android_res/drawable/icon_youtube.png height=19 width=27></a></td>" +
                    "</tr></table></center></div>";


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

            htmlText += "<div style='width=100%; left:0;right:0;width=100%;'>" +
                    "<ul style='overflow:hidden;font-size:14px;font-size:4.0vw;list-style-type:none;text-align:left;margin-left:-25px;color:white'>";

            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:20%'>Country:</li>";
            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:80%'>" + BandInfo.getCountry(bandName) + "</li>";

            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:20%'>Genre:</li>";
            htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:80%'>" + BandInfo.getGenre(bandName) + "</li>";

            if (BandInfo.getNote(bandName) != "") {
                htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:20%'>Misc:</li>";
                htmlText += "<li style='color:" + staticVariables.blueColor + ";float:left;display:inline;width:80%'>" + BandInfo.getNote(bandName) + "</li>";
            }
            htmlText += "</ul></div>";

        }

        return htmlText;
    }

    /**
     * Generates the HTML for displaying band notes.
     * @param bandNote The note to display.
     * @return The HTML string for the notes section.
     */
    public String displayNotes(String bandNote){

        String notesHeight = String.valueOf(noteViewPercentage) + "%";

        Log.d("notesHeight", "notesHeight equals " + notesHeight);
        String htmlText = "";
        if (bandNote != "") {
            htmlText += "<br>";
            htmlText += "<div style='height:" + notesHeight + ";text-align:left;padding-bottom:20px;overflow:auto;width:98%;scroll;text-overflow:ellipsis;font-size:10px;font-size:4.0vw' ondblclick='ok.performClick(\"Notes\");'>" + bandNote + "</div></center>";
        }

        return htmlText;
    }

    /**
     * Generates the HTML for the must/might/wont buttons and icons.
     * @param rankIconLocation The location of the rank icon.
     * @param unknownButtonColor The color for the unknown button.
     * @param mustButtonColor The color for the must button.
     * @param mightButtonColor The color for the might button.
     * @param wontButtonColor The color for the wont button.
     * @return The HTML string for the must/might/wont section.
     */
    public String displayMustMightWont(String rankIconLocation,
                                              String unknownButtonColor,
                                              String mustButtonColor,
                                              String mightButtonColor,
                                              String wontButtonColor){

        String htmlText = "<div style='position:fixed;bottom:10;width: 100%;left:0;right:0'><center>";
        htmlText += "<div style='display:grid;grid-template-columns:1fr 2fr 2fr 2fr 2fr;height:25px;width:100%;margin:0'>";

        if (rankIconLocation.isEmpty() == false) {
            htmlText += "<div><img src=" + rankIconLocation + " height=28 width=28></div>";
        } else {
            htmlText += "<div></div>";
        }

        htmlText += "<div><button style='color:white;width:100%;background:" + unknownButtonColor + "' type=button value=" + staticVariables.unknownKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.unknown) + "</button></div>" +
                "<div><button style='color:white;width:100%;background:" + mustButtonColor + "' type=button value=" + staticVariables.mustSeeKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.must) + "</button></div>" +
                "<div><button style='color:white;width:100%;background:" + mightButtonColor + "' type=button value=" + staticVariables.mightSeeKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.might) + "</button></div>" +
                "<div'><button style='color:white;width:100%;background:" + wontButtonColor + "' type=button value=" + staticVariables.wontSeeKey + " onclick='ok.performClick(this.value);'>" + mContext.getResources().getString(R.string.wont) + "</button></div>" +
                "</div></center></div></div>" +
                "</body></html>";


        Log.d("schedule htmlData is", "Adding MustMightWont HTML text of: " + htmlText);
        return htmlText;
    }
}
