//
//  UtilityHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/15/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit


    
func showAlert (_ message: String, title:String){
    
    let alert = UIAlertView()
    if (message.isEmpty == false){
        alert.title = title
        alert.message = message
        alert.addButton(withTitle: "Ok")
        alert.show()
    }
}

func displayTimeIn24() -> Bool {
    
    var is24 = false
    
    let locale = NSLocale.current
    let formatter : String = DateFormatter.dateFormat(fromTemplate: "j", options:0, locale:locale)!
    if formatter.contains("a") {
        is24 = false
    } else {
        is24 = true
    }
    
    return is24
}

func formatTimeValue(timeValue: String) -> String {
    
    var newDate = ""
    
    if (timeValue.isEmpty == false){
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        
        let date = dateFormatter.date(from: timeValue)
        
        if (displayTimeIn24() == false){
            dateFormatter.dateFormat = "h:mma"
        }
        if (date != nil){
            newDate = dateFormatter.string(from: date!)
        }
    }
    
    return newDate
}

func getDateFormatter() -> DateFormatter {
    
    let dateFormatter = DateFormatter()
    
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.timeStyle = DateFormatter.Style.short
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    return dateFormatter
}


func monthDateRegionalFormatting(dateValue: String)->String{
    
    var newDateValue = dateValue
    
    let monthDayValues = dateValue.split(separator: "/");
    
    //pick a static date, in this case 10/29/2019 (or 29/10/2019 as the case maybe)
    let myDate = NSDate.init(timeIntervalSince1970: 1572359503);
    let timestamp = DateFormatter.localizedString(from: myDate as Date, dateStyle: .short, timeStyle: .short)
    let dateString = timestamp as String
    
    //determine if the local time format puts day before month
    if (dateString.contains("29/10") == true && dateValue.contains("Day") == false){
        newDateValue = monthDayValues[1] + "/" + monthDayValues[0]
    }
    
    return newDateValue;
    
}
