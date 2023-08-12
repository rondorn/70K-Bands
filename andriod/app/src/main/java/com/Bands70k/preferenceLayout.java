package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.graphics.Color;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.ContextThemeWrapper;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.PopupMenu;
import android.widget.Switch;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.core.app.NavUtils;

import java.io.BufferedInputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import static android.app.ActivityManager.isRunningInTestHarness;
import static android.app.PendingIntent.getActivity;
import static com.Bands70k.staticVariables.PERMISSIONS_STORAGE;
import static com.Bands70k.staticVariables.context;
import static com.Bands70k.staticVariables.eventYearArray;
import static com.Bands70k.staticVariables.listState;
import static com.Bands70k.staticVariables.staticVariablesInitialize;
import static java.lang.Thread.sleep;


/**
 * Created by rdorn on 8/15/15.
 */
public class preferenceLayout  extends Activity {

    private Button dataImportButton;

    private Switch showSpecialEvents;
    private Switch showMeetAndGreet;
    private Switch showClinicEvents;
    private Switch showAlbumListen;
    private Switch showUnoffical;

    private Switch showPoolShows;
    private Switch showTheaterShows;
    private Switch showRinkShows;
    private Switch showLoungeShows;
    private Switch showOtherShows;

    private Switch hideExpiredEvents;
    private Switch promptForAttendedStatus;

    private Switch mustSee;
    private Switch mightSee;
    private Switch alertForShows;
    private Switch alertForSpecial;
    private Switch alertForClinics;
    private Switch alertForMeetAndGreet;
    private Switch alertForAlbum;
    private Switch alertUnofficalEvents;
    private Switch lastYearsData;
    private Switch onlyForShowWillAttend;

    private EditText alertMin;

    private EditText bandsUrl;
    private EditText scheduleUrl;
    private EditText pointerUrl;
    private String versionString = "";

    private Button eventYearButton;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        setTheme(R.style.AppTheme);
        super.onCreate(savedInstanceState);
        setContentView(R.layout.preferences);

        //staticVariables.preferences.loadData();
        setValues();
        setLabels();
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);

        try {
            PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            versionString = pInfo.versionName;
        } catch (Exception error) {
            //do nothing
        }

        dataImportButton = (Button) findViewById(R.id.ImportDataBackup);
        dataImportButton.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                dataImportFunc();
            }
        });
        eventYearButton();

        disableAlertButtonsIfNeeded();
        TextView headerText = (TextView) this.findViewById(R.id.preferenceHeader);
        headerText.setText("70K Bands Preferences - Build:" + versionString);

    }

    private void eventYearButton() {

        eventYearButton.setText(String.valueOf(staticVariables.preferences.getEventYearToLoad()));
        //popup menu
        final PopupMenu popupMenu = new PopupMenu(this, eventYearButton);

        //add menu items in popup menu
        int arrayCounter = 0;
        for (String eventYear : eventYearArray) {
            popupMenu.getMenu().add(Menu.NONE, arrayCounter, arrayCounter, eventYear);
            arrayCounter = arrayCounter + 1;
        }

        //handle menu item clicks
        popupMenu.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
            @Override
            public boolean onMenuItemClick(MenuItem menuItem) {
                //get id of the clicked item
                String selectedEventYear = String.valueOf(menuItem.getTitle());
                //handle clicks
                buildRebootDialog();
                eventYearButton.setText(selectedEventYear);
                return true;
            }
        });


        //handle button click, show popup menu
        eventYearButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                popupMenu.show();
            }
        });
    }


    private void dataImportFunc() {

        TextView titleView = new TextView(context);
        titleView.setText("Provide the URL to the Backup File");
        titleView.setPadding(20, 30, 20, 30);
        titleView.setTextSize(20F);
        titleView.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
        titleView.setGravity(Gravity.CENTER);
        titleView.setBackgroundColor(Color.parseColor("#505050"));
        titleView.setTextColor(Color.WHITE);

        // create an alert builder
        final AlertDialog.Builder builder = new AlertDialog.Builder(new ContextThemeWrapper(this, R.style.AlertDialog));
        builder.setCustomTitle(titleView);

        // set the custom layout
        final View customLayout = getLayoutInflater().inflate(R.layout.import_prompt, null);
        builder.setView(customLayout);


        Button importButton = (Button) customLayout.findViewById(R.id.Import);
        Button cancelButton = (Button) customLayout.findViewById(R.id.Cancel);
        final TextView importUrl = (TextView) customLayout.findViewById(R.id.pointerUrl);

        // create and show the alert dialog
        final AlertDialog dialog = builder.create();

        cancelButton.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                dialog.dismiss();
            }
        });

        importButton.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                InputMethodManager inputManager = (InputMethodManager) getSystemService(Activity.INPUT_METHOD_SERVICE);
                inputManager.hideSoftInputFromWindow(customLayout.getWindowToken(), 0);

                dialog.dismiss();
                String downloadUrl = importUrl.getText().toString();
                System.out.println("in DownloadBandFile " + isRunningInTestHarness());
                if (OnlineStatus.isOnline() == true) {
                    System.out.println("downloading backup File from " + downloadUrl);
                    try {
                        //dropbox link fix
                        if (downloadUrl.contains("dropbox") == true) {
                            downloadUrl = downloadUrl.replaceAll("dl=0", "dl=1");

                            //Google Drive link fix
                        } else if (downloadUrl.contains("https://drive.google.com/file/d/") == true) {
                            System.out.println("parsing download link 1 " + downloadUrl);
                            downloadUrl = downloadUrl.replaceAll("https://drive.google.com/file/d/", "");
                            System.out.println("parsing download link 2 " + downloadUrl);

                            downloadUrl = downloadUrl.replaceAll("/.*", "");
                            System.out.println("parsing download link 3 " + downloadUrl);

                            downloadUrl = "https://drive.google.com/uc?export=download&id=" + downloadUrl;
                            System.out.println("parsing download link 4 " + downloadUrl);

                        } else if (downloadUrl.contains("https://onedrive.live.com/embed?") == true) {
                            downloadUrl = downloadUrl.replaceAll("https://onedrive.live.com/embed?", "https://onedrive.live.com/download?");
                            System.out.println("parsing download link 4 " + downloadUrl);
                        }

                        URL u = new URL(downloadUrl);
                        InputStream is = u.openStream();

                        DataInputStream dis = new DataInputStream(is);

                        byte[] buffer = new byte[1024];
                        int length;

                        FileOutputStream fos = new FileOutputStream(FileHandler70k.backupFileTemp);
                        while ((length = dis.read(buffer)) > 0) {
                            fos.write(buffer, 0, length);
                        }


                    } catch (MalformedURLException mue) {
                        Log.e("SYNC getUpdate", "malformed url error", mue);
                    } catch (IOException ioe) {
                        Log.e("SYNC getUpdate", "io error", ioe);
                    } catch (SecurityException se) {
                        Log.e("SYNC getUpdate", "security error", se);

                    } catch (Exception generalError) {
                        Log.e("General Exception", "Downloading bandData", generalError);
                    }
                }

                File backupFile = new File(FileHandler70k.backupFileTemp.toURI());
                if (backupFile.exists()) {
                    AlertDialog.Builder restartDialog = new AlertDialog.Builder(preferenceLayout.this);

                    // Setting Dialog Title
                    restartDialog.setTitle("Confirm Restart");

                    // Setting Dialog Message
                    restartDialog.setMessage(getResources().getString(R.string.importMessage));

                    // Setting Icon to Dialog
                    restartDialog.setIcon(R.drawable.alert_icon);

                    // Setting Positive "Yes" Btn
                    restartDialog.setPositiveButton(getResources().getString(R.string.Ok),
                            new DialogInterface.OnClickListener() {
                                public void onClick(DialogInterface dialog, int which) {
                                    unpackZip(FileHandler70k.baseDirectory.getPath() + "/", FileHandler70k.backupFileTemp.getAbsolutePath());
                                    File backupFile = new File(FileHandler70k.backupFileTemp.toURI());
                                    backupFile.delete();
                                    finish();

                                    finishAffinity();
                                    System.exit(0);
                                }
                            });

                    // Showing Alert Dialog
                    restartDialog.show();
                } else {
                    HelpMessageHandler.showMessage("Something went wrong downloading file from URL " + importUrl.getText());
                }

            }
        });

        dialog.show();

    }

    private boolean unpackZip(String path, String zipname) {
        InputStream is;
        ZipInputStream zis;
        try {
            String filename;
            is = new FileInputStream(zipname);
            zis = new ZipInputStream(new BufferedInputStream(is));
            ZipEntry ze;
            byte[] buffer = new byte[1024];
            int count;

            while ((ze = zis.getNextEntry()) != null) {
                filename = ze.getName();

                // Need to create directories if not exists, or
                // it will generate an Exception...
                if (ze.isDirectory()) {
                    File fmd = new File(path + filename);
                    fmd.mkdirs();
                    continue;
                }

                FileOutputStream fout = new FileOutputStream(path + filename);

                while ((count = zis.read(buffer)) != -1) {
                    fout.write(buffer, 0, count);
                }

                fout.close();
                zis.closeEntry();
            }

            zis.close();
        } catch (IOException e) {
            Log.e("General Exception", "Something went wrong " + e.getMessage());
            HelpMessageHandler.showMessage("Something went wrong " + e.getMessage());
            e.printStackTrace();
            return false;
        }

        return true;
    }

    private void setLabels() {
        TextView poolVenueLable = (TextView) findViewById(R.id.poolVenueLable);
        poolVenueLable.setText(getResources().getString(R.string.PoolVenue));
        poolVenueLable.setTextColor(Color.parseColor(staticVariables.poolVenueColor));

        TextView theaterVenueLable = (TextView) findViewById(R.id.theaterVenueLable);
        theaterVenueLable.setText(getResources().getString(R.string.TheaterVenue));
        theaterVenueLable.setTextColor(Color.parseColor(staticVariables.theaterVenueColor));

        TextView rinkVenueLable = (TextView) findViewById(R.id.rinkVenueLable);
        rinkVenueLable.setText(getResources().getString(R.string.RinkVenue));
        rinkVenueLable.setTextColor(Color.parseColor(staticVariables.rinkVenueColor));

        TextView loungeVenueLable = (TextView) findViewById(R.id.loungeVenueLable);
        loungeVenueLable.setText(getResources().getString(R.string.LoungeVenue));
        loungeVenueLable.setTextColor(Color.parseColor(staticVariables.loungeVenueColor));

        TextView otherVenueLable = (TextView) findViewById(R.id.otherVenueLable);
        otherVenueLable.setText(getResources().getString(R.string.OtherVenue));
        otherVenueLable.setTextColor(Color.parseColor(staticVariables.unknownVenueColor));

        TextView specialEventLable = (TextView) findViewById(R.id.specialEventLable);
        specialEventLable.setText(getResources().getString(R.string.SpecialEvents));

        TextView meetAndGreetEventLable = (TextView) findViewById(R.id.meetAndGreetEventLable);
        meetAndGreetEventLable.setText(getResources().getString(R.string.MeetAndGreet));

        TextView clinicEventLable = (TextView) findViewById(R.id.clinicEventLable);
        clinicEventLable.setText(getResources().getString(R.string.ClinicEvents));

        TextView albumListeningEventLable = (TextView) findViewById(R.id.albumListeningEventLable);
        albumListeningEventLable.setText(getResources().getString(R.string.AlbumListeningEvents));

        TextView unofficalEventLable = (TextView) findViewById(R.id.unofficalEventLable);
        unofficalEventLable.setText(getResources().getString(R.string.unofficalEventLable));

        TextView userIdentifier = (TextView) findViewById(R.id.userIdentifier);
        userIdentifier.setText(staticVariables.userID);
        userIdentifier.setTextColor(Color.WHITE);
        userIdentifier.setBackgroundColor(Color.parseColor("#505050"));
        userIdentifier.setGravity(Gravity.CENTER);

        TextView selectYearLabel = (TextView) findViewById(R.id.selectYearLabel);
        selectYearLabel.setText(getResources().getString(R.string.SelectYearLabel));

        eventYearButton = findViewById(R.id.eventYearButton);
    }

    private void abortLastYearOperation() {

        AlertDialog.Builder restartDialog = new AlertDialog.Builder(preferenceLayout.this);

        // Setting Dialog Title
        restartDialog.setTitle(getResources().getString(R.string.restartTitle));

        // Setting Dialog Message
        restartDialog.setMessage(getResources().getString(R.string.yearChangeAborted));

        // Setting Icon to Dialog
        restartDialog.setIcon(R.drawable.alert_icon);

        // Setting Positive "Yes" Btn
        restartDialog.setPositiveButton(getResources().getString(R.string.Ok), new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
                eventYearButton.setText(String.valueOf(staticVariables.preferences.getEventYearToLoad()));
            }
        });
        // Showing Alert Dialog
        restartDialog.show();
    }

    private void bandListOrScheduleDialog() {
        AlertDialog.Builder restartDialog = new AlertDialog.Builder(preferenceLayout.this);

        // Setting Dialog Title
        restartDialog.setTitle(getResources().getString(R.string.SelectYearLabel));

        // Setting Dialog Message
        restartDialog.setMessage(getResources().getString(R.string.eventOrBandPrompt));

        // Setting Icon to Dialog
        restartDialog.setIcon(R.drawable.alert_icon);

        // Setting Positive "Yes" Btn
        restartDialog.setNegativeButton(getResources().getString(R.string.bandListButton),
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        staticVariables.preferences.setHideExpiredEvents(true);
                        onBackPressed();
                    }
                });
        restartDialog.setPositiveButton(getResources().getString(R.string.eventListButton),
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        staticVariables.preferences.setHideExpiredEvents(false);
                        onBackPressed();
                    }
                });

        // Showing Alert Dialog
        restartDialog.show();
    }

    private void buildRebootDialog(){

        AlertDialog.Builder restartDialog = new AlertDialog.Builder(preferenceLayout.this);

        // Setting Dialog Title
        restartDialog.setTitle(getResources().getString(R.string.SelectYearLabel));

        // Setting Dialog Message
        restartDialog.setMessage(getResources().getString(R.string.restartMessage));

        // Setting Icon to Dialog
        restartDialog.setIcon(R.drawable.alert_icon);

        // Setting Positive "Yes" Btn
        restartDialog.setPositiveButton(getResources().getString(R.string.Ok),
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        Log.d("preferenceLayout", "Testing network connection");
                        if (OnlineStatus.testInternetAvailableSynchronous() == false){
                            Log.d("preferenceLayout", "Testing network connection, failed");
                            abortLastYearOperation();
                            return;
                        }

                        if (String.valueOf(eventYearButton.getText()).equals("Current") == false) {
                            bandListOrScheduleDialog();
                        }

                        Log.d("preferenceLayout", "Testing network connection, passed");
                        //staticVariables.preferences.setUseLastYearsData(lastYearsData.isChecked());
                        staticVariables.preferences.setEventYearToLoad(String.valueOf(eventYearButton.getText()));
                        staticVariables.preferences.resetMainFilters();
                        staticVariables.preferences.saveData();
                        staticVariables.artistURL = null;
                        staticVariables.eventYear = 0;
                        staticVariables.eventYearIndex = String.valueOf(eventYearButton.getText());
                        staticVariables.lookupUrls();

                        //delete band file
                        Log.d("preferenceLayout", "Deleting band file");
                        File fileBandFile = FileHandler70k.bandInfo;
                        fileBandFile.delete();

                        //delete current schedule file
                        Log.d("preferenceLayout", "Deleting schedule file");
                        File fileSchedule = FileHandler70k.schedule;
                        fileSchedule.delete();


                        //erase existing alerts
                        Log.d("preferenceLayout", "Erasing alerts");

                        scheduleAlertHandler alerts = new scheduleAlertHandler();
                        alerts.clearAlerts();

                        BandInfo bandInfo = new BandInfo();
                        bandInfo.getDownloadtUrls();
                        bandInfo.DownloadBandFile();
                        try {
                            sleep(1000);
                        } catch (InterruptedException e) {
                            throw new RuntimeException(e);
                        }
                        ArrayList<String> bandList  = bandInfo.DownloadBandFile();
                        staticVariablesInitialize();



                        mainListHandler listHandler = new mainListHandler();
                        staticVariables.updatelistHandlerCache(listHandler);
                        listState = null;
                        showsAttended showsAttendedHandle = new showsAttended();
                        showsAttendedHandle.loadShowsAttended();

                        staticVariables.refreshActivated = true;


                        if (String.valueOf(eventYearButton.getText()).equals("Current") == true) {
                            bandListOrScheduleDialog();
                            onBackPressed();
                        }

                    }
                });
        // Setting Negative "NO" Btn
        restartDialog.setNegativeButton(getResources().getString(R.string.Cancel),
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        staticVariables.preferences.setEventYearToLoad(String.valueOf(eventYearButton.getText()));
                    }
                });

        // Showing Alert Dialog
        restartDialog.show();
    }

    private void disableAlertButtonsIfNeeded(){

        if (onlyForShowWillAttend.isChecked() == true){
            mustSee.setEnabled(false);
            mightSee.setEnabled(false);
            alertForShows.setEnabled(false);
            alertForSpecial.setEnabled(false);
            alertForMeetAndGreet.setEnabled(false);
            alertForClinics.setEnabled(false);
            alertForAlbum.setEnabled(false);
            alertUnofficalEvents.setEnabled(false);

        } else {
            mustSee.setEnabled(true);
            mightSee.setEnabled(true);
            alertForShows.setEnabled(true);
            alertForSpecial.setEnabled(true);
            alertForMeetAndGreet.setEnabled(true);
            alertForClinics.setEnabled(true);
            alertForAlbum.setEnabled(true);
            alertUnofficalEvents.setEnabled(true);

        }

    }

    private void setValues(){

        mustSee = (Switch)findViewById(R.id.mustSeecheckBox);
        mustSee.setChecked(staticVariables.preferences.getMustSeeAlert());
        mustSee.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setMustSeeAlert(mustSee.isChecked());
            }
        });

        mightSee = (Switch)findViewById(R.id.mightSeecheckBox);
        mightSee.setChecked(staticVariables.preferences.getMightSeeAlert());
        mightSee.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setMightSeeAlert(mightSee.isChecked());
            }
        });

        onlyForShowWillAttend = (Switch)findViewById(R.id.alertOnlyForShowWillAttendSwitch);
        onlyForShowWillAttend.setChecked(staticVariables.preferences.getAlertOnlyForShowWillAttend());
        onlyForShowWillAttend.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertOnlyForShowWillAttend(onlyForShowWillAttend.isChecked());
                disableAlertButtonsIfNeeded();
                if (onlyForShowWillAttend.isChecked() == true){
                    HelpMessageHandler.showMessage(getString(R.string.OnlyAlertForShowsYouWillAttend));
                } else {
                    HelpMessageHandler.showMessage(getString(R.string.AlertForShowsAccordingToSelection));
                }
            }
        });

        alertForShows = (Switch)findViewById(R.id.alertForShows);
        alertForShows.setChecked(staticVariables.preferences.getAlertForShows());
        alertForShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForShows(alertForShows.isChecked());
            }
        });

        alertForSpecial = (Switch)findViewById(R.id.alertForSpecialEvents);
        alertForSpecial.setChecked(staticVariables.preferences.getAlertForSpecialEvents());
        alertForSpecial.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForSpecialEvents(alertForSpecial.isChecked());
            }
        });

        alertForClinics = (Switch)findViewById(R.id.alertForClinics);
        alertForClinics.setChecked(staticVariables.preferences.getAlertForClinics());
        alertForClinics.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForClinics(alertForClinics.isChecked());
            }
        });

        alertForMeetAndGreet = (Switch)findViewById(R.id.alertForMeetAndGreet);
        alertForMeetAndGreet.setChecked(staticVariables.preferences.getAlertForMeetAndGreet());
        alertForMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForMeetAndGreet(alertForMeetAndGreet.isChecked());
            }
        });

        alertForAlbum = (Switch)findViewById(R.id.alertForAlbumListen);
        alertForAlbum.setChecked(staticVariables.preferences.getAlertForListeningParties());
        alertForAlbum.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForListeningParties(alertForAlbum.isChecked());
            }
        });

        alertUnofficalEvents = (Switch)findViewById(R.id.alertForUnofficalEvents);
        alertUnofficalEvents.setChecked(staticVariables.preferences.getAlertForUnofficalEvents());
        alertUnofficalEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setAlertForUnofficalEvents(alertUnofficalEvents.isChecked());
            }
        });
        /*
        lastYearsData = (Switch)findViewById(R.id.useLastYearsData);
        lastYearsData.setChecked(staticVariables.preferences.getUseLastYearsData());
        lastYearsData.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setUseLastYearsData(lastYearsData.isChecked());
                buildRebootDialog();
            }
        });
        */
        alertMin = (EditText)findViewById(R.id.minBeforeEvent);
        alertMin.setText(staticVariables.preferences.getMinBeforeToAlert().toString());

        bandsUrl = (EditText)findViewById(R.id.bandsUrl);
        bandsUrl.setText(staticVariables.preferences.getArtsistsUrl().toString());

        scheduleUrl = (EditText)findViewById(R.id.scheduleUrl);
        scheduleUrl.setText(staticVariables.preferences.getScheduleUrl().toString());

        pointerUrl = (EditText)findViewById(R.id.pointerUrl);
        pointerUrl.setText(staticVariables.preferences.getPointerUrl().toString());

        showSpecialEvents = (Switch)findViewById(R.id.showSpecialEvent);
        showSpecialEvents.setChecked(staticVariables.preferences.getShowSpecialEvents());
        showSpecialEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowSpecialEvents(showSpecialEvents.isChecked());
            }
        });

        showMeetAndGreet = (Switch)findViewById(R.id.showMeetAndGreet);
        showMeetAndGreet.setChecked(staticVariables.preferences.getShowMeetAndGreet());
        showMeetAndGreet.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowMeetAndGreet(showMeetAndGreet.isChecked());
            }
        });

        showClinicEvents = (Switch)findViewById(R.id.showClinic);
        showClinicEvents.setChecked(staticVariables.preferences.getShowClinicEvents());
        showClinicEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowClinicEvents(showClinicEvents.isChecked());
            }
        });

        showAlbumListen = (Switch)findViewById(R.id.showListeningEvent);
        showAlbumListen.setChecked(staticVariables.preferences.getShowAlbumListen());
        showAlbumListen.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowAlbumListen(showAlbumListen.isChecked());
            }
        });

        showUnoffical = (Switch)findViewById(R.id.unofficalEvent);
        showUnoffical.setChecked(staticVariables.preferences.getShowUnofficalEvents());
        showUnoffical.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowUnofficalEvents(showUnoffical.isChecked());
            }
        });

        showPoolShows = (Switch)findViewById(R.id.showPool);
        showPoolShows.setChecked(staticVariables.preferences.getShowPoolShows());
        showPoolShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowPoolShows(showPoolShows.isChecked());
            }
        });

        showTheaterShows = (Switch)findViewById(R.id.showTheater);
        showTheaterShows.setChecked(staticVariables.preferences.getShowTheaterShows());
        showTheaterShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowTheaterShows(showTheaterShows.isChecked());
            }
        });

        showRinkShows = (Switch)findViewById(R.id.showRink);
        showRinkShows.setChecked(staticVariables.preferences.getShowRinkShows());
        showRinkShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowRinkShows(showRinkShows.isChecked());
            }
        });

        showLoungeShows = (Switch)findViewById(R.id.showLounge);
        showLoungeShows.setChecked(staticVariables.preferences.getShowLoungeShows());
        showLoungeShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowLoungeShows(showLoungeShows.isChecked());
            }
        });

        showOtherShows = (Switch)findViewById(R.id.showOther);
        showOtherShows.setChecked(staticVariables.preferences.getShowOtherShows());
        showOtherShows.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setShowOtherShows(showOtherShows.isChecked());
            }
        });

        hideExpiredEvents = (Switch)findViewById(R.id.hideExpiredEvents);
        hideExpiredEvents.setChecked(staticVariables.preferences.getHideExpiredEvents());
        hideExpiredEvents.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setHideExpiredEvents(hideExpiredEvents.isChecked());
            }
        });

        promptForAttendedStatus = (Switch)findViewById(R.id.promptForAttendedStatus);
        promptForAttendedStatus.setChecked(staticVariables.preferences.getPromptForAttendedStatus());
        promptForAttendedStatus.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                staticVariables.preferences.setPromptForAttendedStatus(promptForAttendedStatus.isChecked());
            }
        });


    }

    @Override
    public void onBackPressed() {

        staticVariables.preferences.setMinBeforeToAlert(Integer.valueOf(alertMin.getText().toString()));
        staticVariables.preferences.setArtsistsUrl(bandsUrl.getText().toString());
        staticVariables.preferences.setScheduleUrl(scheduleUrl.getText().toString());
        staticVariables.preferences.setPointerUrl(pointerUrl.getText().toString());
        staticVariables.preferences.saveData();

        SystemClock.sleep(70);
        setResult(RESULT_OK, null);
        finish();
        NavUtils.navigateUpTo(this, new Intent(this,
                showBands.class));

    }

}