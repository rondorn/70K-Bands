//
//  CoreDataIndexManager.swift
//  70K Bands
//
//  Creates performance indexes for Core Data entities programmatically
//  This replaces the invalid fetchIndex elements in the .xcdatamodeld file
//

import Foundation
import CoreData

class CoreDataIndexManager {
    
    static let shared = CoreDataIndexManager()
    
    private init() {}
    
    /// Create all performance indexes for optimal query performance
    func createPerformanceIndexes(for context: NSManagedObjectContext) {
        print("🔍 Creating Core Data performance indexes...")
        
        // Create indexes for Band entity
        createIndexesForBandEntity(in: context)
        
        // Create indexes for Event entity  
        createIndexesForEventEntity(in: context)
        
        // Create indexes for UserPriority entity
        createIndexesForUserPriorityEntity(in: context)
        
        // Create indexes for UserAttendance entity
        createIndexesForUserAttendanceEntity(in: context)
        
        print("✅ All performance indexes created successfully")
    }
    
    // MARK: - Band Entity Indexes
    
    private func createIndexesForBandEntity(in context: NSManagedObjectContext) {
        let bandEntity = NSEntityDescription.entity(forEntityName: "Band", in: context)!
        
        // Index for fast band name lookups
        let nameIndex = NSFetchIndexDescription(name: "byBandName", elements: [
            NSFetchIndexElementDescription(property: bandEntity.attributesByName["bandName"]!, collationType: .binary)
        ])
        
        // Index for fast year filtering
        let yearIndex = NSFetchIndexDescription(name: "byEventYear", elements: [
            NSFetchIndexElementDescription(property: bandEntity.attributesByName["eventYear"]!, collationType: .binary)
        ])
        
        // Index for fast country filtering
        let countryIndex = NSFetchIndexDescription(name: "byCountry", elements: [
            NSFetchIndexElementDescription(property: bandEntity.attributesByName["country"]!, collationType: .binary)
        ])
        
        // Index for fast genre filtering
        let genreIndex = NSFetchIndexDescription(name: "byGenre", elements: [
            NSFetchIndexElementDescription(property: bandEntity.attributesByName["genre"]!, collationType: .binary)
        ])
        
        // Add indexes to entity
        bandEntity.indexes = [nameIndex, yearIndex, countryIndex, genreIndex]
    }
    
    // MARK: - Event Entity Indexes
    
    private func createIndexesForEventEntity(in context: NSManagedObjectContext) {
        let eventEntity = NSEntityDescription.entity(forEntityName: "Event", in: context)!
        
        // Index for fast time-based sorting
        let timeIndex = NSFetchIndexDescription(name: "byTimeIndex", elements: [
            NSFetchIndexElementDescription(property: eventEntity.attributesByName["timeIndex"]!, collationType: .binary)
        ])
        
        // Index for fast year filtering
        let yearIndex = NSFetchIndexDescription(name: "byEventYear", elements: [
            NSFetchIndexElementDescription(property: eventEntity.attributesByName["eventYear"]!, collationType: .binary)
        ])
        
        // Index for fast location filtering
        let locationIndex = NSFetchIndexDescription(name: "byLocation", elements: [
            NSFetchIndexElementDescription(property: eventEntity.attributesByName["location"]!, collationType: .binary)
        ])
        
        // Index for fast event type filtering
        let typeIndex = NSFetchIndexDescription(name: "byEventType", elements: [
            NSFetchIndexElementDescription(property: eventEntity.attributesByName["eventType"]!, collationType: .binary)
        ])
        
        // Index for fast date filtering
        let dateIndex = NSFetchIndexDescription(name: "byDate", elements: [
            NSFetchIndexElementDescription(property: eventEntity.attributesByName["date"]!, collationType: .binary)
        ])
        
        // Add indexes to entity
        eventEntity.indexes = [timeIndex, yearIndex, locationIndex, typeIndex, dateIndex]
    }
    
    // MARK: - UserPriority Entity Indexes
    
    private func createIndexesForUserPriorityEntity(in context: NSManagedObjectContext) {
        let priorityEntity = NSEntityDescription.entity(forEntityName: "UserPriority", in: context)!
        
        // Index for fast priority level filtering
        let levelIndex = NSFetchIndexDescription(name: "byPriorityLevel", elements: [
            NSFetchIndexElementDescription(property: priorityEntity.attributesByName["priorityLevel"]!, collationType: .binary)
        ])
        
        // Index for fast year filtering
        let yearIndex = NSFetchIndexDescription(name: "byEventYear", elements: [
            NSFetchIndexElementDescription(property: priorityEntity.attributesByName["eventYear"]!, collationType: .binary)
        ])
        
        // Add indexes to entity
        priorityEntity.indexes = [levelIndex, yearIndex]
    }
    
    // MARK: - UserAttendance Entity Indexes
    
    private func createIndexesForUserAttendanceEntity(in context: NSManagedObjectContext) {
        let attendanceEntity = NSEntityDescription.entity(forEntityName: "UserAttendance", in: context)!
        
        // Index for fast attendance status filtering
        let statusIndex = NSFetchIndexDescription(name: "byAttendanceStatus", elements: [
            NSFetchIndexElementDescription(property: attendanceEntity.attributesByName["attendanceStatus"]!, collationType: .binary)
        ])
        
        // Index for fast year filtering
        let yearIndex = NSFetchIndexDescription(name: "byEventYear", elements: [
            NSFetchIndexElementDescription(property: attendanceEntity.attributesByName["eventYear"]!, collationType: .binary)
        ])
        
        // Add indexes to entity
        attendanceEntity.indexes = [statusIndex, yearIndex]
    }
}

// MARK: - Usage Example

/*
 
 To use this index manager:
 
 1. After Core Data stack is initialized:
    CoreDataIndexManager.shared.createPerformanceIndexes(for: persistentContainer.viewContext)
 
 2. The indexes will be created programmatically and provide the same performance benefits
    as the invalid fetchIndex elements that were causing crashes.
 
 3. All queries will automatically use these indexes for optimal performance.
 
 */
