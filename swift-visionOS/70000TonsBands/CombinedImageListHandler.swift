//
//  CombinedImageListHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

/// Handles the combined image list that merges artist and event images
/// Artists take priority over events when both have image URLs
class CombinedImageListHandler {
    
    // Thread-safe queue for image list access
    private let imageListQueue = DispatchQueue(label: "com.yourapp.combinedImageList", attributes: .concurrent)
    
    // Private backing store for the combined image list
    private var _combinedImageList: [String: String] = [:]
    
    // Thread-safe accessor
    var combinedImageList: [String: String] {
        get {
            return imageListQueue.sync { _combinedImageList }
        }
        set {
            imageListQueue.async(flags: .barrier) { self._combinedImageList = newValue }
        }
    }
    
    // File path for the combined image list cache
    private let combinedImageListFile = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent("combinedImageList.json"))
    
    /// Singleton instance
    static let shared = CombinedImageListHandler()
    
    private init() {
        loadCombinedImageList()
    }
    
    /// Generates the combined image list from artist and event data
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    ///   - completion: Completion handler called when the list is generated
    func generateCombinedImageList(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler, completion: @escaping () -> Void) {
        print("Generating combined image list...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var newCombinedList: [String: String] = [:]
            
            // Get all band names and their image URLs
            let bandNames = bandNameHandle.getBandNames()
            for bandName in bandNames {
                let imageUrl = bandNameHandle.getBandImageUrl(bandName)
                if !imageUrl.isEmpty {
                    newCombinedList[bandName] = imageUrl
                    print("Added artist image for \(bandName): \(imageUrl)")
                }
            }
            
            // Get all event names and their image URLs from schedule data
            let scheduleData = scheduleHandle.schedulingData
            for (bandName, events) in scheduleData {
                for (_, eventData) in events {
                    // Check for ImageURL first (higher priority), then Description URL
                    if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            newCombinedList[bandName] = imageUrl
                            print("Added event image URL for \(bandName): \(imageUrl)")
                        } else {
                            print("Skipped event image URL for \(bandName) (artist already has image): \(imageUrl)")
                        }
                    } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            newCombinedList[bandName] = descriptionUrl
                            print("Added event description URL for \(bandName): \(descriptionUrl)")
                        } else {
                            print("Skipped event description URL for \(bandName) (artist already has image): \(descriptionUrl)")
                        }
                    } else {
                        print("No image URL found for event: \(bandName)")
                    }
                }
            }
            
            // Update the combined list
            self.combinedImageList = newCombinedList
            
            // Save to disk
            self.saveCombinedImageList()
            
            print("Combined image list generated with \(newCombinedList.count) entries")
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /// Gets the image URL for a given name (artist or event)
    /// - Parameter name: The name to look up
    /// - Returns: The image URL or empty string if not found
    func getImageUrl(for name: String) -> String {
        let url = combinedImageList[name] ?? ""
        print("CombinedImageListHandler: Getting image URL for '\(name)': \(url)")
        return url
    }
    
    /// Checks if the combined list needs to be regenerated based on new data
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    /// - Returns: True if regeneration is needed, false otherwise
    func needsRegeneration(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler) -> Bool {
        let currentList = combinedImageList
        
        // Check if any new artists have been added
        let bandNames = bandNameHandle.getBandNames()
        for bandName in bandNames {
            let imageUrl = bandNameHandle.getBandImageUrl(bandName)
            if !imageUrl.isEmpty && currentList[bandName] != imageUrl {
                print("New artist image detected for \(bandName), regeneration needed")
                return true
            }
        }
        
        // Check if any new events have been added
        let scheduleData = scheduleHandle.schedulingData
        for (bandName, events) in scheduleData {
            for (_, eventData) in events {
                // Check for ImageURL first (higher priority), then Description URL
                if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                    if currentList[bandName] != imageUrl {
                        print("New event image URL detected for \(bandName), regeneration needed")
                        return true
                    }
                } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                    if currentList[bandName] != descriptionUrl {
                        print("New event description URL detected for \(bandName), regeneration needed")
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Saves the combined image list to disk
    private func saveCombinedImageList() {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: combinedImageList, options: .prettyPrinted)
            try jsonData.write(to: combinedImageListFile)
            print("Combined image list saved to disk")
        } catch {
            print("Error saving combined image list: \(error)")
        }
    }
    
    /// Loads the combined image list from disk
    private func loadCombinedImageList() {
        guard FileManager.default.fileExists(atPath: combinedImageListFile.path) else {
            print("No combined image list file found, will generate on first use")
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: combinedImageListFile)
            if let loadedList = try JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
                combinedImageList = loadedList
                print("Combined image list loaded from disk with \(loadedList.count) entries")
            }
        } catch {
            print("Error loading combined image list: \(error)")
        }
    }
    
    /// Clears the combined image list cache
    func clearCache() {
        combinedImageList.removeAll()
        do {
            try FileManager.default.removeItem(at: combinedImageListFile)
            print("Combined image list cache cleared")
        } catch {
            print("Error clearing combined image list cache: \(error)")
        }
    }
    
    /// Manually triggers the combined image list generation
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    ///   - completion: Completion handler called when the list is generated
    func manualGenerateCombinedImageList(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler, completion: @escaping () -> Void) {
        print("CombinedImageListHandler: Manual generation triggered")
        generateCombinedImageList(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle, completion: completion)
    }
    
    /// Prints the current combined image list for debugging
    func printCurrentList() {
        print("CombinedImageListHandler: Current list contains \(combinedImageList.count) entries:")
        for (name, url) in combinedImageList.sorted(by: { $0.key < $1.key }) {
            print("  '\(name)': \(url)")
        }
    }
    
    /// Test method to manually generate and print the combined image list
    func testGenerateAndPrint() {
        print("CombinedImageListHandler: Testing generation...")
        let bandNameHandle = bandNamesHandler()
        let scheduleHandle = scheduleHandler()
        
        generateCombinedImageList(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle) {
            print("CombinedImageListHandler: Generation completed, printing results...")
            self.printCurrentList()
        }
    }
} 