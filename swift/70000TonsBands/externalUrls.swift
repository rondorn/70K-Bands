//
//  externalDataSources.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/4/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation


func getWikipediaPage (_ bandName: String) -> String{
    
    var wikipediaUrl = String()
    
    if (wikipediaLink[bandName]?.isEmpty == false){
        wikipediaUrl = wikipediaLink[bandName]!;

        var language: String = Locale.preferredLanguages[0]
    
        language = language.substring(to: language.characters.index(language.startIndex, offsetBy: 2))
        print ("Language is " + language);
        if (language != "en"){
            let replacement: String = language + ".wikipedia.org";
        
            wikipediaUrl = wikipediaUrl.replacingOccurrences(of: "en.wikipedia.org", with:replacement)
        }
    }
    
    return (wikipediaUrl)
    
}

func getYouTubePage (_ bandName: String) -> String{
    
    var youTubeUrl = String()
    
    if (youtubeLinks[bandName]?.isEmpty == false){
        youTubeUrl = youtubeLinks[bandName]!;
    
        let language: String = Locale.preferredLanguages[0]
    
        if (language != "en"){
            youTubeUrl = youTubeUrl + "&hl=" + language
        }
    }
    
    return (youTubeUrl)
    
}

func getMetalArchives (_ bandName: String) -> String {
    
    var metalArchives = String();
    if (metalArchiveLinks[bandName]?.isEmpty == false){
        metalArchives = metalArchiveLinks[bandName]!;
    }
    
    return (metalArchives)
}
