//
//  imageHander.swift
//  Control Fun
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit
import CoreData


open class imageHandler {
    
    // MARK: - Singleton
    static let shared = imageHandler()
    
    // MARK: - Private Initializer
    private init() {
        // Initialize singleton
    }
    
    /**
     Requests data collection with optional year override and completion handler.
     - Parameters:
        - eventYearOverride: If true, cancels all other operations and runs immediately
        - completion: Completion handler called when operation finishes
     */
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        // For imageHandler, we don't need to do anything since images are loaded on-demand
        completion?()
    }
    
    func displayImage ( urlString: String, bandName: String) -> UIImage {
        
        
        let bandName = bandName
        let trimmedUrlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        var returnedImage:UIImage?;
        
        print ("urlString is " + trimmedUrlString);
        
        let imageStore = getDocumentsDirectory().appendingPathComponent(bandName + ".png")
        
        let imageStoreFile = URL(fileURLWithPath: dirs[0]).appendingPathComponent( bandName + ".png")
        
        // First, check if we have a cached image - this should always be used if available
        if let imageData: UIImage = UIImage(contentsOfFile: imageStore) {
            print ("ImageCall using cached image from \(imageStoreFile)")
            returnedImage = imageData
        
        } else if (trimmedUrlString.isEmpty || trimmedUrlString == "http://"){
            // Only use generic logo if no URL is available
            print("ImageCall: No URL available for \(bandName), using generic logo")
            returnedImage = UIImage(named: "70000TonsLogo")!
        } else if let url = URL(string: trimmedUrlString), url.scheme != nil {

            print ("ImageCall: Starting download for \(bandName) from \(trimmedUrlString)")
            
            // Start background download without blocking the UI
            DispatchQueue.global(qos: .background).async {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    guard
                        let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                        let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                        let data = data, error == nil,
                        let image = UIImage(data: data)
                        else { 
                            print("Failed to download image for \(bandName): \(error?.localizedDescription ?? "unknown error")")
                            return 
                        }
                    
                    // Save image to cache in background
                    DispatchQueue.global(qos: .background).async {
                        do {
                            print ("Loading image URL String from file \(imageStoreFile)")
                            let imageData = image.jpegData(compressionQuality: 0.75)
                            try imageData?.write(to: imageStoreFile, options: [.atomic])
                            print("Successfully cached image for \(bandName)")
                            
                            // Notify DetailViewController to refresh the display
                            DispatchQueue.main.async {
                                print("imageHandler: Sending ImageDownloaded notification for \(bandName)")
                                NotificationCenter.default.post(
                                    name: Notification.Name("ImageDownloaded"), 
                                    object: nil, 
                                    userInfo: ["bandName": bandName]
                                )
                                print("imageHandler: ImageDownloaded notification sent for \(bandName)")
                            }
                        } catch {
                            print ("ImageCall \(error)")
                        }
                    }
                }.resume()
            }
            
            // For now, return generic logo while downloading, but the notification will update it
            print("ImageCall: Returning generic logo while downloading proper image for \(bandName)")
            returnedImage = UIImage(named: "70000TonsLogo")!
        } else {
            // Invalid URL (no scheme, etc.)
            print("ImageCall: Invalid URL for \(bandName): \(trimmedUrlString)")
            returnedImage = UIImage(named: "70000TonsLogo")!
        }

        if (trimmedUrlString.contains("www.dropbox.com") == true || trimmedUrlString.isEmpty == true){
            print ("Image URL string is not Inverted for " + trimmedUrlString);
        } else {
            print ("Image URL string is Inverted for " + trimmedUrlString);
            returnedImage = returnedImage?.inverseImage(cgResult: true)
        }
        return returnedImage ?? UIImage(named: "70000TonsLogo")!;
    }

    func getAllImages(bandNamesSnapshot: [String: [String: String]]){
        if downloadingAllImages == false {
            downloadingAllImages = true
            let bands = Array(bandNamesSnapshot.keys)
            // Prefetch all image URLs into a dictionary
            var bandImageUrls: [String: String] = [:]
            for bandName in bands {
                bandImageUrls[bandName] = bandNamesSnapshot[bandName]?["bandImageUrl"] ?? ""
            }
            for bandName in bands {
                // Check if bulk loading is paused
                if bulkLoadingPaused {
                    print("imageHandler bulk loading paused, stopping getAllImages")
                    break
                }
                let imageStoreName = bandName + ".png"
                let imageStoreFile = directoryPath.appendingPathComponent(imageStoreName)
                if FileManager.default.fileExists(atPath: imageStoreFile.path) == false {
                    let imageURL = bandImageUrls[bandName] ?? ""
                    print("Loading image in background so it will be cached by default " + imageURL)
                    _ = displayImage(urlString: imageURL, bandName: bandName)
                }
            }
        }
        downloadingAllImages = false
    }
    
    /// Pauses bulk loading operations
    func pauseBulkLoading() {
        bulkLoadingPaused = true
        print("imageHandler: Bulk loading paused")
    }
    
    /// Resumes bulk loading operations
    func resumeBulkLoading() {
        bulkLoadingPaused = false
        print("imageHandler: Bulk loading resumed")
    }
    
    /// Loads image for a specific band with priority (ignores pause state)
    /// - Parameter bandName: The name of the band to load image for
    func loadImageWithPriority(bandName: String, bandNameHandle: bandNamesHandler) {
        print("imageHandler: Loading image with priority for \(bandName)")
        let imageURL = bandNameHandle.getBandImageUrl(bandName)
        let imageStoreName = bandName + ".png"
        let imageStoreFile = directoryPath.appendingPathComponent(imageStoreName)
        if FileManager.default.fileExists(atPath: imageStoreFile.path) == false {
            print("Loading image with priority for \(bandName) from \(imageURL)")
            _ = displayImage(urlString: imageURL, bandName: bandName)
        } else {
            print("imageHandler: Image already exists for \(bandName), skipping priority load")
        }
    }

}
extension UIImage {
    func inverseImage(cgResult: Bool) -> UIImage? {
        let coreImage = UIKit.CIImage(image: self)
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setValue(coreImage, forKey: kCIInputImageKey)
        guard let result = filter.value(forKey: kCIOutputImageKey) as? UIKit.CIImage else { return nil }
        if cgResult { // I've found that UIImage's that are based on CIImages don't work with a lot of calls properly
            return UIImage(cgImage: CIContext(options: nil).createCGImage(result, from: result.extent)!)
        }
        return UIImage(ciImage: result)
    }
}
