//
//  dataLoadingTests.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/10/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import XCTest

class dataLoadingTests: XCTestCase {
    
    var artistsUrl = "https://www.dropbox.com/s/5hcaxigzdj7fjrt/artistLineup.html?dl=1"
    
    func testGatherData (){
        
        var bandNameObject = bandNameHandler()
        
        bandNameObject.gatherData()
        
        println (bandNameObject.getBandNames())
        
    }
    
    
}
