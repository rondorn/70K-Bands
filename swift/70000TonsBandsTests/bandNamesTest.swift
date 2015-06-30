//
//  bandNamesTest.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/10/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import XCTest


class bandNameTests: XCTestCase {
    
    func testViewDidLoad(){
        
        loadBands()
        loadBandsOffline()
        
    }
    
    func loadBands (){
        
        var bands = [String]()
        gatherData()
        bands = getBandNames()
        
        XCTAssertEqual(bands.count, 60, "Found 60 bands " + String(bands.count))
        XCTAssertEqual(bands[0], "1349", "First band is 1349 " + bands[0])
        XCTAssertEqual(bands[59], "Wintersun", "First band is Wintersun " + bands[59])
        
    }
    
    func loadBandsOffline(){
        
        var bands = [String]()
        readBandFile()
        bands = getBandNames()
        
        println(bands)
        
        XCTAssertEqual(bands.count, 60, "Found 60 bands " + String(bands.count))
        XCTAssertEqual(bands[0], "1349", "First band is 1349 " + bands[0])
        XCTAssertEqual(bands[59], "Wintersun", "First band is Wintersun " + bands[59])
        
    }
}

