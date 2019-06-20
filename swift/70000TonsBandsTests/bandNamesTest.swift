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
        
        let bandNameHandle = bandNamesHandler()
        bandNameHandle.gatherData()
        bands = bandNameHandle.getBandNames()
        
        XCTAssertEqual(bands.count, 60, "Found 60 bands " + String(bands.count))
        XCTAssertEqual(bands[0], "1349", "First band is 1349 " + bands[0])
        XCTAssertEqual(bands[59], "Wintersun", "First band is Wintersun " + bands[59])
        
    }
    
    func loadBandsOffline(){
        
        let bandNameHandle = bandNamesHandler()
        var bands = [String]()
        bandNameHandle.readBandFile()
        bands = bandNameHandle.getBandNames()
        
        print(bands)
        
        XCTAssertEqual(bands.count, 60, "Found 60 bands " + String(bands.count))
        XCTAssertEqual(bands[0], "1349", "First band is 1349 " + bands[0])
        XCTAssertEqual(bands[59], "Wintersun", "First band is Wintersun " + bands[59])
        
    }
}

