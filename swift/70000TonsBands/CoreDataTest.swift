//
//  CoreDataTest.swift
//  70000TonsBands
//
//  Simple test to verify Core Data is working
//

import Foundation
import CoreData

class CoreDataTest {
    
    static func testBasicOperations() {
        print("🧪 Testing Core Data basic operations...")
        
        let manager = CoreDataManager.shared
        
        // Test 1: Create a band
        let testBand = manager.createBand(name: "Test Band")
        print("✅ Created band: \(testBand.bandName ?? "Unknown")")
        
        // Test 2: Save context
        manager.saveContext()
        print("✅ Saved context")
        
        // Test 3: Fetch bands
        let bands = manager.fetchBands()
        print("✅ Fetched \(bands.count) bands")
        
        // Test 4: Create an event
        let testEvent = manager.createEvent(
            band: testBand,
            location: "Test Location", 
            startTime: "12:00 PM",
            eventType: "Show"
        )
        print("✅ Created event: \(testEvent.band?.bandName ?? "Unknown") at \(testEvent.location ?? "Unknown")")
        
        // Test 5: Save and fetch events
        manager.saveContext()
        let events = manager.fetchEvents()
        print("✅ Fetched \(events.count) events")
        
        print("🎉 Core Data basic operations test completed!")
    }
    
    static func testCSVImport() {
        print("🧪 Testing CSV import functionality...")
        
        let importer = BandCSVImporter()
        
        // Test CSV data (sample from the actual CSV structure)
        let testCSV = """
        bandName,officalSite,imageUrl,youtube,metalArchives,wikipedia,country,genre,noteworthy,priorYears
        Emperor,www.emperorhorde.com/,70000tons.com/wp-content/uploads/2024/04/01_EMPEROR.png,https://www.youtube.com/results?search_query=official+music%20video+EMPEROR,http://www.metal-archives.com/search?searchString=EMPEROR&type=band_name,https://en.wikipedia.org/wiki/Special:Search/insource:album%20insource:band%20intitle:EMPEROR,Norway,Symphonic Black Metal,,2020
        Stratovarius,stratovarius.com/,70000tons.com/wp-content/uploads/2024/04/02_STRATOVARIUS.png,https://www.youtube.com/results?search_query=official+music%20video+STRATOVARIUS,http://www.metal-archives.com/search?searchString=STRATOVARIUS&type=band_name,https://en.wikipedia.org/wiki/Special:Search/insource:album%20insource:band%20intitle:STRATOVARIUS,Finland,Melodic Power Metal,,2016 2012
        """
        
        // Test 1: Import CSV data
        let success = importer.importBandsFromCSV(testCSV)
        print("✅ CSV import success: \(success)")
        
        // Test 2: Verify bands were imported
        let bandNames = importer.getBandNamesArray()
        print("✅ Imported bands: \(bandNames)")
        
        // Test 3: Get specific band data
        if let emperorData = importer.getBandData(for: "Emperor") {
            print("✅ Emperor data: \(emperorData["country"] ?? "Unknown") - \(emperorData["genre"] ?? "Unknown")")
        }
        
        // Test 4: Get all bands data
        let allBands = importer.getAllBandsData()
        print("✅ Total bands in database: \(allBands.count)")
        
        print("🎉 CSV import test completed!")
    }
}
