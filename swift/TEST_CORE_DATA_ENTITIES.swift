//
//  TEST_CORE_DATA_ENTITIES.swift
//  Test file to check if Core Data entities are generated
//

import CoreData
import Foundation

// Test if Core Data entities are available
func testCoreDataEntities() {
    // Try to reference the entities - if this compiles, they exist!
    let _ = Band.self
    let _ = Event.self  
    let _ = Priority.self
    let _ = AttendedStatus.self
    let _ = BandDescription.self
    let _ = BandImage.self
    
    print("✅ All Core Data entities found!")
}

// If the above code compiles without errors, the entities are generated!
// If it shows "Cannot find 'Band' in scope" errors, we need to configure Codegen
