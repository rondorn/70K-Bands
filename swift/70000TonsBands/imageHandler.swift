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
    
    /// Analyzes a URL to determine if image inversion should be applied
    /// - Parameter urlString: The URL string to analyze
    /// - Returns: True if inversion should be applied, false otherwise
    func shouldApplyInversion(urlString: String) -> Bool {
        // Don't apply inversion for Dropbox URLs or empty URLs
        if urlString.contains("www.dropbox.com") || urlString.isEmpty {
            print("Image URL does not require inversion: \(urlString)")
            return false
        } else {
            print("Image URL requires inversion: \(urlString)")
            return true
        }
    }
    
    /// Loads and processes an image from cache or downloads it if needed
    /// - Parameters:
    ///   - urlString: The URL string for the image
    ///   - bandName: The name of the band
    /// - Returns: The processed image (with inversion applied if needed)
    func displayImage(urlString: String, bandName: String) -> UIImage {
        print("displayImage called for \(bandName) with URL: \(urlString)")
        
        let imageStore = getDocumentsDirectory().appendingPathComponent(bandName + ".png")
        
        // First check if we have a cached image
        if let imageData: UIImage = UIImage(contentsOfFile: imageStore) {
            print("Using cached image from \(imageStore)")
            return processImage(imageData, urlString: urlString)
        }
        
        // Check for invalid URLs
        if urlString.isEmpty || urlString == "http://" {
            print("Invalid URL, using default logo")
            return UIImage(named: "70000TonsLogo")!
        }
        
        // If no cached image and no valid URL, return default
        print("No cached image and no valid URL for \(bandName)")
        return UIImage(named: "70000TonsLogo")!
    }
    
    /// Downloads an image from URL and caches it with proper inversion analysis
    /// - Parameters:
    ///   - urlString: The URL string for the image
    ///   - bandName: The name of the band
    ///   - completion: Completion handler called with the processed image
    func downloadAndCacheImage(urlString: String, bandName: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL for \(bandName): \(urlString)")
            completion(nil)
            return
        }
        
        print("Downloading image for \(bandName) from \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error downloading image for \(bandName): \(error)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = response?.mimeType,
                  mimeType.hasPrefix("image"),
                  let data = data,
                  let image = UIImage(data: data) else {
                print("Invalid response for \(bandName) image download")
                completion(nil)
                return
            }
            
            // Analyze URL for inversion requirement
            let shouldInvert = self.shouldApplyInversion(urlString: urlString)
            let processedImage = shouldInvert ? (image.inverseImage(cgResult: true) ?? image) : image
            
            // Cache the processed image
            let imageStoreFile = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent(bandName + ".png"))
            do {
                let imageData = processedImage.jpegData(compressionQuality: 0.75)
                try imageData?.write(to: imageStoreFile, options: [.atomic])
                print("Successfully cached processed image for \(bandName)")
            } catch {
                print("Error caching image for \(bandName): \(error)")
            }
            
            completion(processedImage)
        }.resume()
    }
    
    /// Processes an image (applies inversion if needed based on URL analysis)
    /// - Parameters:
    ///   - image: The image to process
    ///   - urlString: The URL string to analyze for inversion requirement
    /// - Returns: The processed image
    func processImage(_ image: UIImage, urlString: String) -> UIImage {
        let shouldInvert = shouldApplyInversion(urlString: urlString)
        
        if shouldInvert {
            print("Applying inversion to image for URL: \(urlString)")
            return image.inverseImage(cgResult: true) ?? image
        } else {
            print("No inversion needed for URL: \(urlString)")
            return image
        }
    }

    func getAllImages(bandNameHandle: bandNamesHandler){
        
        if (downloadingAllImages == false){
            downloadingAllImages = true
            bands = bandNameHandle.getBandNames()
            for bandName in bands {
                
                let imageStoreName = bandName + ".png"
                let imageStoreFile = directoryPath.appendingPathComponent( imageStoreName)

                if (FileManager.default.fileExists(atPath: imageStoreFile.path) == false){
                    
                    let imageURL = bandNameHandle.getBandImageUrl(bandName)
                    print ("Loading image in background so it will be cached by default " + imageURL);
                    _ = displayImage(urlString: imageURL, bandName: bandName)
                }
            }
        }
        downloadingAllImages = false
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
