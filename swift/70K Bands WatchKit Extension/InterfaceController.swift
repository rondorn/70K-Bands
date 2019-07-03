//
//  InterfaceController.swift
//  70K Bands WatchKit Extension
//
//  Created by Ron Dorn on 3/13/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//
/*

import WatchKit
import Foundation


@available(iOS 8.2, *)
class InterfaceController: WKInterfaceController {

    @IBOutlet weak var nextBand: WKInterfaceLabel!
    @IBOutlet weak var DayTime: WKInterfaceLabel!
    @IBOutlet weak var location: WKInterfaceLabel!
    @IBOutlet weak var Next: WKInterfaceButton!
    
    var bandsByTime = [String]()
    var schedule = scheduleHandler()
    var bands =  [String]()
    var DayTimeText = String();
    var LocationText = String();
    var index = 0;
    
    var bandNameHandle = bandNamesHandler()
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Start iCloud key-value updates
        NSUbiquitousKeyValueStore.default.synchronize()
        updateBandFromICloud()
        
       
        //register application testing defaults
        let defaultValues = ["artistUrl": lastYearsartistUrlDefault,
            "scheduleUrl": lastYearsScheduleUrlDefault,
            "mustSeeAlert": mustSeeAlertDefault, "mightSeeAlert": mightSeeAlertDefault,
            "onlyAlertForAttended": onlyAlertForAttendedDefault,
            "minBeforeAlert": minBeforeAlertDefault, "alertForShows": alertForShowsDefault,
            "alertForSpecial": alertForSpecialDefault, "alertForMandG": alertForMandGDefault,
            "alertForClinics": alertForClinicsDefault, "alertForListening": alertForListeningDefault,
            "validateScheduleFile": validateScheduleFileDefault]
        
        
        UserDefaults.standard.register(defaults: defaultValues)
        
        //var scheduleUrl = defaults.stringForKey("scheduleUrl")

        bandNameHandle.gatherData()
        schedule.DownloadCsv()
        schedule.populateSchedule()
        refreshData()
        
    }
    
    @IBAction func NextShow() {
        
        print(index)
        print(bandsByTime.count)
        
        if (index < (bandsByTime.count - 1)){
            index = index + 1
            refreshData()
        }
    }
    
    @IBAction func PreviousShow() {
        if (index != 0){
            index = index - 1
            refreshData()
        }
    }
    
    func refreshData() {
        
        //bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule)
        sortBandsByTime()
        //readiCloudData()
        print(schedule.schedulingData);
        /*
        //let bandText = getPriorityIcon(getPriorityData(bandsByTime[index])) + bandsByTime[index]
        nextBand.setText(bandText)
        getScheduleData(bandsByTime[index])
        if (DayTimeText.isEmpty == true){
            DayTime.setText("Schedule Not");
            location.setText("Yet  Available")
        } else {
            DayTime.setText(DayTimeText)
            location.setText(LocationText)
        }
        */
    }
    
    func getScheduleData (_ bandName: String) {
        
        if (schedule.schedulingData[bandName]?.isEmpty == false){
            let keyValues = schedule.schedulingData[bandName]!.keys
            let arrayValues = keyValues.enumerated()
            //var sortedArray = arrayValues.sort({
            //    $0 < $1
            //})
            
            let sortedArray = arrayValues.reversed()
            //var count = 1
            for index in sortedArray {
                
                let location = schedule.getData(bandName, index: Double(index.0), variable: locationField)
                let day = schedule.getData(bandName, index: Double(index.0), variable: dayField)
                let startTime = schedule.getData(bandName, index: Double(index.0), variable: startTimeField)
                let date = schedule.getData(bandName, index:Double(index.0), variable: dateField)

                if (date.isEmpty == false){
                    DayTimeText = day + " " + startTime
                    LocationText = location;
                    return
                }
            }
        }
    }

    
    fileprivate func updateBandFromICloud() {
        let bandInfo = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
        if (bandInfo.count >= 1) {
            //readiCloudData()
        }
    }
    
    func sortBandsByTime() {
        
        var sortableBands = Dictionary<TimeInterval, String>()
        var sortableTimeIndexArray = [TimeInterval]()
        var sortedBands = [String]()
        
        //var fullBands = bands;
        var dupAvoidBands = Dictionary<String,Int>()
        
        let futureTime :Int64 = 8000000000000;
        var noShowsLeftMagicNumber = TimeInterval(futureTime)

        for bandName in bands {
            let timeIndex: TimeInterval = schedule.getCurrentIndex(bandName);
            if (timeIndex > Date().timeIntervalSince1970 - 3600){
                sortableBands[timeIndex] = bandName
                sortableTimeIndexArray.append(timeIndex)
            } else {
                sortableBands[noShowsLeftMagicNumber] = bandName
                sortableTimeIndexArray.append(noShowsLeftMagicNumber)
                noShowsLeftMagicNumber = noShowsLeftMagicNumber + 1
            }
        }
        
        
        let sortedArray = sortableTimeIndexArray.sorted(by: {$0 < $1})
        
        for index in sortedArray{
            if (dupAvoidBands[sortableBands[index]!] == nil){
                sortedBands.append(sortableBands[index]!)
                dupAvoidBands[sortableBands[index]!] = 1
            }
        }
        
        
        bandsByTime = sortedBands
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
 */
