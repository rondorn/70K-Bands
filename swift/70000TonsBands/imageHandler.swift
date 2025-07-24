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
    
    func displayImage ( urlString: String, bandName: String) -> UIImage {
        
        
        let bandName = bandName
        let urlString = urlString

        var returnedImage:UIImage?;
        
        print ("urlString is " + urlString);
        
        let imageStore = getDocumentsDirectory().appendingPathComponent(bandName + ".png")
        
        let imageStoreFile = URL(fileURLWithPath: dirs[0]).appendingPathComponent( bandName + ".png")
        
        if let imageData: UIImage = UIImage(contentsOfFile: imageStore) {
            print ("ImageCall using cached imaged from \(imageStoreFile)")
            returnedImage = imageData
        
        } else if (urlString == ""){
            returnedImage = UIImage(named: "70000TonsLogo")!
        
        } else if (urlString == "http://"){
            returnedImage = UIImage(named: "70000TonsLogo")!
        
        } else {

            print ("ImageCall download imaged from \(urlString)")

            let url = URL(string: urlString)
            if (url == nil){
                return UIImage(named: "70000TonsLogo")!
            }
            
            URLSession.shared.dataTask(with: url!) { data, response, error in
                guard
                    let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                    let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                    let data = data, error == nil,
                    let image = UIImage(data: data)
                    else { return }
                DispatchQueue.main.async() {
                    returnedImage = image
       
                    do {
                        print ("Loading image URL String from file \(imageStoreFile)")
                        let imageData = returnedImage?.jpegData(compressionQuality: 0.75)
                        try imageData?.write(to: imageStoreFile, options: [.atomic])
                    } catch {
                        print ("ImageCall \(error)")
                    }
                }
                }.resume()
            var count = 0;
            while (returnedImage == nil){
                if (count == 15){
                    break
                }
                sleep(1)
                count = count + 1
            }
        }

        if (urlString.contains("www.dropbox.com") == true || urlString.isEmpty == true){
            print ("Image URL string is not Inverted for " + urlString);
        } else {
            print ("Image URL string is Inverted for " + urlString);
            returnedImage = returnedImage?.inverseImage(cgResult: true)
        }
        
        return returnedImage ?? UIImage(named: "70000TonsLogo")!;
        
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
