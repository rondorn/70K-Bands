//
//  TEST_CORE_DATA_SIMPLE.swift
//  Simple test to verify Core Data is working
//

import CoreData
import Foundation

func testSimpleCoreDataOperation() {
    print("🧪 Testing simple Core Data operation...")
    
    // This will only work once Band entity is added to the model
    /*
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
        print("❌ Could not get AppDelegate")
        return
    }
    
    let context = appDelegate.persistentContainer.viewContext
    
    // Try to create a test band
    let testBand = Band(context: context)
    testBand.name = "Test Band"
    testBand.eventYear = 2024
    testBand.country = "Test Country"
    
    do {
        try context.save()
        print("✅ Successfully created test band in Core Data")
        
        // Try to fetch it back
        let fetchRequest: NSFetchRequest<Band> = Band.fetchRequest()
        let results = try context.fetch(fetchRequest)
        print("✅ Successfully fetched \(results.count) bands from Core Data")
        
        // Clean up test data
        for band in results {
            if band.name == "Test Band" {
                context.delete(band)
            }
        }
        try context.save()
        print("✅ Test cleanup successful")
        
    } catch {
        print("❌ Core Data test failed: \(error)")
    }
    */
    
    print("📝 Uncomment the code above once Band entity is added to the model")
}
