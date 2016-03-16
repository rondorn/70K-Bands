//
//  externalDataSources.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/4/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation


func getWikipediaPage (bandName: String) -> String{
    
    var wikipediaUrl = wikipediaLink[bandName];

    var language: String = NSLocale.preferredLanguages()[0]
    
    language = language.substringToIndex(language.startIndex.advancedBy(2))
    print ("Language is " + language);
    if (language != "en"){
        let replacement: String = language + ".wikipedia.org";
        
        wikipediaUrl = wikipediaUrl!.stringByReplacingOccurrencesOfString("en.wikipedia.org", withString:replacement)
    }
    
    return (wikipediaUrl)!
    
}

func getYouTubePage (bandName: String) -> String{
    
    var youTubeUrl = youtubeLinks[bandName];

    let language: String = NSLocale.preferredLanguages()[0] 
    
    if (language != "en"){
        youTubeUrl = youTubeUrl! + "&hl=" + language
    }
    
    return (youTubeUrl)!
    
}

func getMetalArchives (bandName: String) -> String {
    
    let metalArchives = metalArchiveLinks[bandName];

    return (metalArchives)!
}
