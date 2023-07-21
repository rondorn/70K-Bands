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
            print("Error while storing data: \(error.localizedDescription)")
        }
    }
    
    // Function to read the [String: String] variable from the file system
    func readDataFromDisk(fileName: String) -> [String: String]? {
        do {
            let dataURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName)
            let data = try Data(contentsOf: dataURL)
            return try JSONSerialization.jsonObject(with: data) as? [String: String]
        } catch {
            print("Error while reading data: \(error.localizedDescription)")
            return nil
        }
    }
}
