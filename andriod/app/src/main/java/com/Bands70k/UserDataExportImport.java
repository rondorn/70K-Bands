package com.Bands70k;

import android.util.Log;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class UserDataExportImport {

    public static String exportDataToZip() {

        String zipFile = FileHandler70k.baseDirectory.getAbsolutePath() + "/userExport.zip";
        File userDir = FileHandler70k.baseDirectory;

        try {
            FileOutputStream fos = new FileOutputStream(zipFile);
            ZipOutputStream zos = new ZipOutputStream(fos);
            File srcFile = new File(userDir.getAbsolutePath());
            File[] files = srcFile.listFiles();
            Log.d("", "Zip directory: " + srcFile.getName());
            for (int i = 0; i < files.length; i++) {
                String fileName = files[i].getName();
                if (fileName.contains("cachedImages")) {
                    Log.d("", "byPassing cache image Dir");

                } else if (fileName.equals("userExport.zip") == true){
                    Log.d("", "byPassing cprevious backup");

                } else {
                    Log.d("", "Adding file: " + fileName);
                    byte[] buffer = new byte[1024];
                    FileInputStream fis = new FileInputStream(files[i]);
                    zos.putNextEntry(new ZipEntry(fileName));
                    int length;
                    while ((length = fis.read(buffer)) > 0) {
                        zos.write(buffer, 0, length);
                    }
                    zos.closeEntry();
                    fis.close();
                }
            }
            zos.close();
        } catch (IOException ioe) {
            Log.e("", ioe.getMessage());
        }

        File zipFileVerify = new File(zipFile);
        if (zipFileVerify.exists() == true){
            Log.d("", "Zip file existance verified " + zipFileVerify.getAbsolutePath());
        } else {
            Log.d("", "Zip file existance verified false " + zipFileVerify.getAbsolutePath());
        }

        return zipFileVerify.getAbsolutePath();
    }
}
