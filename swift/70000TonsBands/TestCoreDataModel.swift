//
//  TestCoreDataModel.swift
//  70K Bands
//
//  Simple test to verify Core Data model loads correctly
//

import Foundation
import CoreData

class TestCoreDataModel {
    
    static func testModelLoading() -> Bool {
        print("🧪 Testing Core Data model loading...")
        
        do {
            // Try to create a managed object model
            guard let modelURL = Bundle.main.url(forResource: "DataModel", withExtension: "momd") else {
                print("❌ Could not find DataModel.momd")
                return false
            }
            
            guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
                print("❌ Could not load NSManagedObjectModel")
                return false
            }
            
            print("✅ Successfully loaded Core Data model")
            print("   - Entities: \(model.entities.count)")
            
            for entity in model.entities {
                print("   - Entity: \(entity.name ?? "Unknown")")
                print("     - Attributes: \(entity.attributesByName.count)")
                print("     - Relationships: \(entity.relationshipsByName.count)")
            }
            
            return true
            
        } catch {
            print("❌ Error loading Core Data model: \(error)")
            return false
        }
    }
}

// MARK: - Usage
/*
 
 To test if the model loads:
 
 1. Build the project first (to generate .momd file)
 2. Call: TestCoreDataModel.testModelLoading()
 3. Check console output for success/errors
 
 */
