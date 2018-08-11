//
//  iCloudFileHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/21/18.
//  Copyright © 2018 Ron Dorn. All rights reserved.
//

import Foundation


func createiCloudDirectory(){
    
    return;
    do {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier:nil)?.appendingPathComponent("Documents"){
            
            print("iCloud Drive createing directory \(iCloudDocumentsURL)")
            
            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                //only do on directory create for backward compatability
                //copyDocumentsToiCloudDrive();
            }
        }
    } catch {
        print("iCloud Drive error on create directory " + error.localizedDescription);
    }
}

func copyDocumentsToiCloudDrive() {
    return;
    do {
        
        print("iCloud Drive writing data")
        
        let localDocumentsURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).last! as NSURL
        
        let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier:nil)?.appendingPathComponent("Documents")
        
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            var isDir:ObjCBool = false
            if (FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: &isDir)) {
                try FileManager.default.removeItem(at: iCloudDocumentsURL)
            }
            
            try FileManager.default.copyItem(at: localDocumentsURL as URL, to: iCloudDocumentsURL)
        }
    } catch {
        print("iCloud Drive error on write " + error.localizedDescription);
    }
}

func saveFileToiCloudDrive(localFile : URL, fileName : String){

    createiCloudDirectory()
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {

        let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier:nil)?.appendingPathComponent("Documents").appendingPathComponent(fileName, isDirectory: false)
        
        //if (iCloudDocumentsURL?.absoluteString.isEmpty == false){
            do {
                
                if (FileManager.default.fileExists(atPath: (iCloudDocumentsURL?.path)!) == true){
                    try FileManager.default.removeItem(atPath: iCloudDocumentsURL!.path)
                }
                
                print("iCloud Drive saving file from \(localFile) and copying to \(iCloudDocumentsURL?.path)")
                try FileManager.default.copyItem(atPath:localFile.path, toPath: iCloudDocumentsURL!.path)
                print("iCloud Drive wrote file \(iCloudDocumentsURL?.path)")
                try FileManager.default.startDownloadingUbiquitousItem(at: iCloudDocumentsURL!)
                
            } catch {
                print("iCloud Drive error on load of single file of \(localFile.path) could not be copied to \(iCloudDocumentsURL?.path) " + error.localizedDescription);
            }
        //} else {
        //    print("iCloud Drive file \(fileName) is not available in the cloud")
        //}
    }
}


func loadFileFromiCloudDrive(localFile : URL, fileName : String){

    let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier:nil)?.appendingPathComponent("Documents").appendingPathComponent(fileName, isDirectory: false)
    
    if (iCloudDocumentsURL?.absoluteString.isEmpty == false){
        print("iCloud Drive loaded file from \(iCloudDocumentsURL?.path) and copying to \(localFile)")
        
        do {
            let localModify : Date = try FileManager.default.attributesOfItem(atPath: localFile.path)[FileAttributeKey.modificationDate] as! Date;
            
            let cloudModify :Date  = try FileManager.default.attributesOfItem(atPath: iCloudDocumentsURL!.path)[FileAttributeKey.modificationDate] as! Date;
            
            //print ("iCloud Drive localModify is \(localModify) and cloudModify is \(cloudModify)")
            //if (cloudModify > localModify){
            
            if (FileManager.default.fileExists(atPath: (localFile.path)) == true){
                try FileManager.default.removeItem(atPath: localFile.path)
            }
            print("iCloud Drive copied file \(iCloudDocumentsURL?.path) to \(localFile.path)")
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudDocumentsURL!)
            try FileManager.default.copyItem(atPath: (iCloudDocumentsURL?.path)!, toPath: localFile.path)
            print("iCloud Drive wrote file \(localFile.path)")
            
        } catch {
            print("iCloud Drive error on load of single file of \(iCloudDocumentsURL?.path) could not be copied to \(localFile.path) " + error.localizedDescription);
        }
    } else {
        print("iCloud Drive file \(localFile.path) is not available in the cloud")
    }
    
}

