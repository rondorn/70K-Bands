//
//  countryHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 11/9/22.
//  Copyright © 2022 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class countryHandler {
    
    var countryShortLong = [String:String]()
    var countryLongShort = [String:String]()
    
    init(){
        
    }
    
    /// Returns a dictionary mapping country short codes to their long names.
    /// - Returns: A dictionary with country short codes as keys and long names as values.
    func getCountryShortLong()->[String:String]{
        return countryShortLong
    }
    
    /// Returns a dictionary mapping country long names to their short codes.
    /// - Returns: A dictionary with country long names as keys and short codes as values.
    func getCountryLongShort()->[String:String]{
        return countryLongShort
    }
    
    /// Loads country data from the bundled file and populates the country dictionaries.
    func loadCountryData(){
        
        print("Loading Countries are!")
        let countryFile = Bundle.main.url(forResource: "countries", withExtension: "txt")
        print("Loading Countries are! --- \(countryFile)")
        if let filepath = Bundle.main.path(forResource: "countries", ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                let keys = contents.components(separatedBy: "\n")
                
                for value in keys{
                    if value.contains(","){
                        print("Loading Countries are! - reviewing  \(value)")
                        var values = value.components(separatedBy: ",")
                        var countryLongName = values[0]
                        var countryShortName = values[1]
                        
                        self.countryLongShort[countryLongName] = countryShortName
                        self.countryShortLong[countryShortName] = countryLongName
                    }
                }
                print("Loading Countries are! - \(countryLongShort)")
            } catch {
                print("Loading Countries are! - bad things")
                // contents could not be loaded
            }
        }
    }
    
}
