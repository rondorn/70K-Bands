//
//  imageHander.swift
//  Control Fun
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//

import Foundation
import UIKit
import CoreData

var imageCache = [String: UIImage]()

func displayImage (urlString: String, bandName: String, logoImage: UIImageView) -> Void {
    
    var imageStore = dirs[0].stringByAppendingPathComponent( bandName + ".png")
    
    
    if var imageData: UIImage = UIImage(contentsOfFile: imageStore) {
        println("Loading image from file cache for " + bandName)
        logoImage.image = imageData
        return
    }
    
    if (urlString == ""){
        return
    }
    
    var image = UIImage()


    // If the image does not exist, we need to download it
    var imgURL: NSURL = NSURL(string: urlString)!
        
    // Download an NSData representation of the image at the URL
    var request: NSURLRequest = NSURLRequest(URL: imgURL)
    
    var urlConnection: NSURLConnection = NSURLConnection(request: request, delegate: nil)!
    
    NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: {(response: NSURLResponse!,data: NSData!,error: NSError!) -> Void in

        if let httpResponse = response as? NSHTTPURLResponse {
            let statusCode = httpResponse.statusCode
            if statusCode == 200 {
                image = UIImage(data: data)!
                imageCache[urlString] = image
                logoImage.image =  image
                
                UIImageJPEGRepresentation(image,1.0).writeToFile(imageStore, atomically: true)
                
                usleep(200)
                
            } else {
                println(statusCode)
            }
        }

    })
}