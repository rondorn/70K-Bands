//
//  scheduleHandlerTest.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/10/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import XCTest


class loadingSchedule: XCTestCase {
    
    var schedule = scheduleHandler()
    
    func testViewDidLoad(){
        downloadCsvSchedule()
        getCsvScheduleOffline()
    }
    
    func downloadCsvSchedule (){
        print ("Sync: Loading schedule data loadingSchedule")
        schedule.DownloadCsv()
        schedule.populateSchedule()
        
        XCTAssertNotNil(schedule.schedulingData["1349"], "Band 1349 has an entry")
        XCTAssertNotNil(schedule.schedulingData["Wintersun"], "Band Wintersun has an entry")
        
    }
    
    func getCsvScheduleOffline (){
        
        schedule.schedulingData = [String : [TimeInterval : [String : String]]]()
        schedule.populateSchedule()
        
        print (schedule.schedulingData)
        XCTAssertNotNil(schedule.schedulingData["1349"], "Band 1349 has an entry")
        XCTAssertNotNil(schedule.schedulingData["Wintersun"], "Band Wintersun has an entry")
        
    }

}
    
