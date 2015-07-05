//
//  externalDataSources.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/4/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//

import Foundation


func getWikipediaPage (bandName: String) -> String{
    
    var wikipediaUrl = wikipediaLink[bandName];

    return (wikipediaUrl)!
    
}

func getYouTubePage (bandName: String) -> String{
    
    var youTubeUrl = youtubeLinks[bandName];

    return (youTubeUrl)!
    
}

func getMetalArchives (bandName: String) -> String {
    
    var metalArchives = metalArchiveLinks[bandName];

    return (metalArchives)!
}
