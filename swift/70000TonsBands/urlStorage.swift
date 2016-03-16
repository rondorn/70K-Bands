//
//  urlStorage.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/13/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation


var openUrl = ""


func setUrl (url: String){
    print ("Setting url to be " + url);
    openUrl = url;
}

func getUrl () -> String {
    print ("Returning url of " + openUrl)
    return openUrl;
}