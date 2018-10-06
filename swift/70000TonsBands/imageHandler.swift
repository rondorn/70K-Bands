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

func displayImage ( urlString: String, bandName: String, logoImage: UIImageView) -> DarwinBoolean {
    
    
    let bandName = bandName
    let urlString = urlString
    let logoImage = logoImage

    print ("urlString is " + urlString);
    
    let imageStore = getDocumentsDirectory().appendingPathComponent(bandName + ".png")
    
    let imageStoreFile = URL(fileURLWithPath: dirs[0]).appendingPathComponent( bandName + ".png")
    
    if let imageData: UIImage = UIImage(contentsOfFile: imageStore) {
        print("Loading image from file cache for " + bandName)
        logoImage.image = imageData
        return true
    }
    
    if (urlString == ""){
        logoImage.image = UIImage(named: "70000TonsLogo")
        return true
    }
    
    if (urlString == "http://"){
        logoImage.image = UIImage(named: "70000TonsLogo")
        return true
    }
    
    var image = UIImage()
    
    let session = URLSession.shared
    let url = URL(string: urlString)
    let request = URLRequest(url: url!)
    
    let dataTask = session.dataTask(with: request) { (data, response, error) -> Void in
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            if statusCode == 200 {
                do {
                    if (data != nil){
                        image = UIImage(data: data!)!
                        imageCache[urlString] = image
                        logoImage.image =  image
                    
                        try? UIImageJPEGRepresentation(image,1.0)!.write(to: imageStoreFile, options: [.atomic])
                    } else {
                        logoImage.image = UIImage(named: "70000TonsLogo")
                        print("Could not Download image encountered image download error")
                    }
                }
                
            } else {
                logoImage.image = UIImage(named: "70000TonsLogo")
                print("Could not Download image " + statusCode.description)
            }
        } else {
            logoImage.image = UIImage(named: "70000TonsLogo")
            print("Could not Download image Not sure what is going on here " + response.debugDescription)
        }
    }

    dataTask.resume()
    
    return true;
    
}

func getAllImages(){
    
    bands = getBandNames()
    for bandName in bands {
        
        let imageStoreName = bandName + ".png"
        let imageStoreFile = directoryPath.appendingPathComponent( imageStoreName)
        let nullImage : UIImageView = UIImageView.init()
        
        if (FileManager.default.fileExists(atPath: imageStoreFile.path) == false){
            
            let imageURL = getBandImageUrl(bandName)
            print ("Loading image in background so it will be cached by default " + imageURL);
            displayImage(urlString: imageURL, bandName: bandName, logoImage: nullImage)
        }
    }
}

