//
//  ShowsAttended.swift
//  
//
//  Created by Ron Dorn on 6/10/18.
//

open class ShowsAttended {
    
    //var showsAttendedArray: [String : String] = [String : String]();
    
    func addShowsAttended (band: String, location: String, startTime: String, eventType: String)->String{
        
        let index = band + ":" + location + ":" + startTime + ":" + eventType
        
        var value = ""
        
        if (showsAttendedArray[index]?.isEmpty == true){
            value = "Attended";
            
        } else if (showsAttendedArray[index] == "Attended"){
            value = "Partially Attended";
            
        } else if (showsAttendedArray[index] == "Attended"){
            value = "";
            
        }
        
        //showsAttendedArray[index] = value
        
        return value
    }
    
}
