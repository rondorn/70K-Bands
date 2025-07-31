//
//  variableStore.swift
//  70K Bands
//
//  Created by Ron Dorn on 7/20/23.
//  Copyright © 2023 Ron Dorn. All rights reserved.
//

import Foundation

class variableStore {
    
    // Function to store the [String: String] variable to the file system
    func storeDataToDisk(data: [String: String], fileName: String) {
        do {
            let dataURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName)
            let data = try JSONSerialization.data(withJSONObject: data)
            try data.write(to: dataURL)
        } catch {
            print("storeDataToDisk: Error while storing data: \(error.localizedDescription)")
        }
    }
    
    // Function to read the [String: String] variable from the file system
    func readDataFromDisk(fileName: String) -> [String: String]? {
        print ("readDataFromDisk: Entering");
        do {
            let fileNamePath = directoryPath.appendingPathComponent(fileName)
            print ("readDataFromDisk: I think we are reading to \(fileNamePath)");
            if (FileManager.default.fileExists(atPath: fileNamePath.absoluteString) == true){
                let dataURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName)
                print ("readDataFromDisk: dataURL is \(dataURL)");
                if (dataURL.isFileURL == true){
                    let data = try Data(contentsOf: dataURL)
                    return try JSONSerialization.jsonObject(with: data) as? [String: String]
                }
            }
        } catch {
            print("Error while reading data: \(error.localizedDescription)")
        }
        return nil
    }

    // Function to store the [String: String] variable to the file system
    func storeDataToDisk(data: [String], fileName: String) {
        do {
            print("storeDataToDisk: storing data \(data)")
            let dataURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName)
            print("storeDataToDisk: storing data \(dataURL)")
            let data = try JSONSerialization.data(withJSONObject: data)
            try data.write(to: dataURL)
            print("storeDataToDisk: done storing data \(data)")
        } catch {
            print("storeDataToDisk: Error while storing data: \(error.localizedDescription)")
        }
    }
    
    // Function to read the [String: String] variable from the file system
    func readDataFromDiskArray(fileName: String) -> [String]? {
        do {

            print ("readDataFromDiskArray: loading data \(fileName)")
            let dataURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName)
            if (dataURL.isFileURL == true){
                let data = try Data(contentsOf: dataURL)
                print ("readDataFromDiskArray: found data \(data)")
                return try JSONSerialization.jsonObject(with: data) as? [String]
            }
            
        } catch {
            print("readDataFromDiskArray: Error while reading data: \(error.localizedDescription)")
        }
        //if the
        return nil
    }
}
