package com.Bands70k;

import android.os.Build;
import android.support.annotation.RequiresApi;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class CountryChoiceHandler {

    public CountryChoiceHandler(){

    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public static Map<String, String> loadCountriesList(){

        Map<String, String> countryMap = new HashMap<String, String>();

        //InputStream countryFileInputStream = staticVariables.context.getResources().openRawResource(R.raw.count_codes);
        InputStream countryFile = staticVariables.context.getResources().openRawResource(R.raw.count_codes);

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(countryFile))) {
            while (reader.ready()) {
                String line = reader.readLine();
                List<String> lineData = Arrays.asList(line.split(","));
                countryMap.put(lineData.get(1), lineData.get(0));
            }

        } catch (Exception error) {
            Log.e("Save Data Error", error.getMessage());
        }

        return countryMap;
    }

}
