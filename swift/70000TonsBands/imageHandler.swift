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

func displayImage (urlString: String, bandName: String, logoImage: UIImageView) -> Void {
    
    
    let imageStore = getDocumentsDirectory().stringByAppendingPathComponent(bandName + ".png")
    
    let imageStoreFile = NSURL(fileURLWithPath: dirs[0]).URLByAppendingPathComponent( bandName + ".png")
    
    if let imageData: UIImage = UIImage(contentsOfFile: imageStore) {
        print("Loading image from file cache for " + bandName)
        logoImage.image = imageData
        return
    }
    
    if (urlString == ""){
        logoImage.image = UIImage(named: "70000TonsLogo")
        return
    }
    
    var image = UIImage()
    
    let session = NSURLSession.sharedSession()
    let url = NSURL(string: urlString)
    let request = NSURLRequest(URL: url!)
    let dataTask = session.dataTaskWithRequest(request) { (data:NSData?, response:NSURLResponse?, error:NSError?) -> Void in
        if let httpResponse = response as? NSHTTPURLResponse {
            let statusCode = httpResponse.statusCode
            if statusCode == 200 {
                image = UIImage(data: data!)!
                imageCache[urlString] = image
                logoImage.image =  image
                
                UIImageJPEGRepresentation(image,1.0)!.writeToURL(imageStoreFile, atomically: true)
                
                print("Download image " + imageStoreFile.absoluteString)
                
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
    
}