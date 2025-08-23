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
    var downloadingAllImages = false
    private var activeDownloads = 0
    private let maxConcurrentDownloads = 3
    private let downloadQueue = DispatchQueue(label: "imageDownloadQueue", qos: .utility)
    
    /// Returns the festival-specific default logo
    /// - Returns: UIImage of the festival logo, or a system default if loading fails
    private func getFestivalDefaultLogo() -> UIImage {
        // Use the festival-specific logo from configuration
        let logoName = FestivalConfig.current.logoUrl
        
        if let logo = UIImage(named: logoName) {
            print("Using festival logo: \(logoName)")
            return logo
        }
        
        // Fallback to 70K logo if festival logo not found
        if logoName != "70000TonsLogo", let fallbackLogo = UIImage(named: "70000TonsLogo") {
            print("Festival logo '\(logoName)' not found, using 70K fallback")
            return fallbackLogo
        }
        
        // Ultimate fallback - system image
        print("No bundled logos found, using system fallback")
        return UIImage(systemName: "music.note") ?? UIImage()
    }
    
    /// Analyzes a URL to determine if image inversion should be applied
    /// - Parameter urlString: The URL string to analyze
    /// - Returns: True if inversion should be applied, false otherwise
    func shouldApplyInversion(urlString: String) -> Bool {
        // DISABLED: Image inversion is not needed for the new SwiftUI details screen
        // The inversion logic was causing brightness/whitening issues when attendance status changed
        print("Image inversion disabled - no-op for URL: \(urlString)")
        return false
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
            print("Invalid URL, using festival-specific default logo")
            return getFestivalDefaultLogo()
        }
        
        // If no cached image and no valid URL, return festival-specific default
        print("No cached image and no valid URL for \(bandName)")
        return getFestivalDefaultLogo()
    }
    
    /// Downloads an image from URL and caches it with proper inversion analysis
    /// - Parameters:
    ///   - urlString: The URL string for the image
    ///   - bandName: The name of the band
    ///   - completion: Completion handler called with the processed image
    func downloadAndCacheImage(urlString: String, bandName: String, completion: @escaping (UIImage?) -> Void) {
        // Check if we're at the concurrent download limit
        if activeDownloads >= maxConcurrentDownloads {
            print("⏸️ Download limit reached (\(activeDownloads)/\(maxConcurrentDownloads)) - queuing download for \(bandName)")
            downloadQueue.async {
                self.downloadAndCacheImage(urlString: urlString, bandName: bandName, completion: completion)
            }
            return
        }
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL for \(bandName): \(urlString)")
            completion(nil)
            return
        }
        
        activeDownloads += 1
        print("🔄 Downloading image for \(bandName) from \(urlString) (active: \(activeDownloads)/\(maxConcurrentDownloads))")
        
        // Create a URLRequest with timeout for slow connections
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0 // 30 second timeout
        request.cachePolicy = .returnCacheDataElseLoad // Use cache when available
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer {
                self?.activeDownloads -= 1
            }
            
            if let error = error {
                print("❌ Error downloading image for \(bandName): \(error)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = response?.mimeType,
                  mimeType.hasPrefix("image"),
                  let data = data,
                  let image = UIImage(data: data) else {
                print("❌ Invalid response for \(bandName) image download")
                completion(nil)
                return
            }
            
            // No image processing needed - use original image
            let processedImage = image
            
            // Cache the processed image as PNG to preserve quality (v2 = high quality PNG)
            let imageStoreFile = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent(bandName + "_v2.png"))
            do {
                let imageData = processedImage.pngData()
                try imageData?.write(to: imageStoreFile, options: [.atomic])
                print("Successfully cached processed image for \(bandName) as PNG")
            } catch {
                print("Error caching image for \(bandName): \(error)")
            }
            
            completion(processedImage)
        }.resume()
    }
    
    /// Processes an image (no processing needed for SwiftUI interface)
    /// - Parameters:
    ///   - image: The image to process
    ///   - urlString: The URL string (unused, kept for compatibility)
    /// - Returns: The original image without any processing
    func processImage(_ image: UIImage, urlString: String) -> UIImage {
        print("No image processing needed for URL: \(urlString)")
        return image
    }

    func getAllImages(bandNameHandle: bandNamesHandler? = nil){
        
        if (downloadingAllImages == false){
            downloadingAllImages = true
            
            // Use the combined image list instead of just band names
            let combinedImageList = CombinedImageListHandler.shared.combinedImageList
            
            print("🖼️ Starting throttled bulk image loading with \(combinedImageList.count) entries")
            
            // Convert to array for batch processing
            let imageEntries = Array(combinedImageList)
            
            // Process images in batches to avoid overwhelming slow networks
            processBulkImagesInBatches(imageEntries: imageEntries, batchSize: 3, delay: 0.5)
        }
    }
    
    private func processBulkImagesInBatches(imageEntries: [(String, String)], batchSize: Int, delay: TimeInterval) {
        guard !imageEntries.isEmpty else {
            print("🖼️ Bulk image loading completed - all batches processed")
            downloadingAllImages = false
            return
        }
        
        // Take the next batch
        let currentBatch = Array(imageEntries.prefix(batchSize))
        let remainingEntries = Array(imageEntries.dropFirst(batchSize))
        
        print("🖼️ Processing batch of \(currentBatch.count) images (remaining: \(remainingEntries.count))")
        
        let group = DispatchGroup()
        
        // Process current batch
        for (bandName, imageURL) in currentBatch {
            let oldImageStoreName = bandName + ".png"        // Old cache format
            let newImageStoreName = bandName + "_v2.png"     // New cache format (high quality PNG)
            let oldImageStoreFile = directoryPath.appendingPathComponent(oldImageStoreName)
            let newImageStoreFile = directoryPath.appendingPathComponent(newImageStoreName)
            
            // Check if we already have the new high-quality cache
            if FileManager.default.fileExists(atPath: newImageStoreFile.path) {
                print("⏭️ Skipping \(bandName) - already have high-quality cache")
            } else {
                // Check if we have old cache that should be upgraded
                if FileManager.default.fileExists(atPath: oldImageStoreFile.path) {
                    print("🔄 Upgrading old cache for \(bandName) - deleting old and downloading new")
                    do {
                        try FileManager.default.removeItem(at: oldImageStoreFile)
                        print("✅ Deleted old cached image for \(bandName)")
                    } catch {
                        print("❌ Error deleting old cached image for \(bandName): \(error)")
                    }
                }
                
                // Download and cache with new format
                group.enter()
                print("🖼️ Downloading high-quality image for \(bandName) from \(imageURL)")
                downloadAndCacheImage(urlString: imageURL, bandName: bandName) { downloadedImage in
                    if downloadedImage != nil {
                        print("✅ Successfully downloaded and cached high-quality image for \(bandName)")
                    } else {
                        print("❌ Failed to download image for \(bandName)")
                    }
                    group.leave()
                }
            }
        }
        
        // Wait for current batch to complete, then process next batch after delay
        group.notify(queue: .global(qos: .background)) {
            if !remainingEntries.isEmpty {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + delay) {
                    self.processBulkImagesInBatches(imageEntries: remainingEntries, batchSize: batchSize, delay: delay)
                }
            } else {
                print("🖼️ Bulk image loading completed - all images processed")
                self.downloadingAllImages = false
            }
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
