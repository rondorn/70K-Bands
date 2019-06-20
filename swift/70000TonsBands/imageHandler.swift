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

var imageCache = [String: UIImage]()

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
                imageCache[urlString] = returnedImage
                do {
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
        /*
        let dataTask = session.dataTask(with: request) { (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode == 200 {
                    do {
                        if (data != nil){
                            returnedImage = UIImage(data: data!)!
                            imageCache[urlString] = returnedImage
  
                            try? UIImageJPEGRepresentation((returnedImage!),1.0)?.write(to: imageStoreFile, options: [.atomic])
                        } else {
                            returnedImage = UIImage(named: "70000TonsLogo")
                            print("Could not Download image encountered image download error")
                        }
                    }
                    
                } else {
                    returnedImage = UIImage(named: "70000TonsLogo")!
                    print("Could not Download image " + statusCode.description)
                }
            } else {
                returnedImage = UIImage(named: "70000TonsLogo")!
                print("Could not Download image Not sure what is going on here " + response.debugDescription)
            }
        }
        
        dataTask.resume()
        */
    }
    
    print ("ImageCall returned \(urlString) - " + returnedImage.debugDescription)
    
    return returnedImage ?? UIImage(named: "70000TonsLogo")!;
    
}

func getAllImages(){
    
    let bandNameHandle = bandNamesHandler()
    
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

