//
//  CoreDataManager.swift
//  70000TonsBands
//
//  Simple, clean Core Data manager using pure Swift
//

import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Save Context
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    // MARK: - Band Operations
    
    func fetchBands() -> [Band] {
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch bands error: \(error)")
            return []
        }
    }
    
    func fetchBand(byName name: String) -> Band? {
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        request.predicate = NSPredicate(format: "bandName == %@", name)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Fetch band by name error: \(error)")
            return nil
        }
    }
    
    func createBand(name: String) -> Band {
        let band = Band(context: context)
        band.bandName = name
        return band
    }
    
    func createOrUpdateBand(
        name: String,
        officialSite: String? = nil,
        imageUrl: String? = nil,
        youtube: String? = nil,
        metalArchives: String? = nil,
        wikipedia: String? = nil,
        country: String? = nil,
        genre: String? = nil,
        noteworthy: String? = nil,
        priorYears: String? = nil
    ) -> Band {
        // Try to find existing band first
        let existingBand = fetchBand(byName: name)
        let band = existingBand ?? Band(context: context)
        
        // Update all fields
        band.bandName = name
        band.officialSite = officialSite
        band.imageUrl = imageUrl
        band.youtube = youtube
        band.metalArchives = metalArchives
        band.wikipedia = wikipedia
        band.country = country
        band.genre = genre
        band.noteworthy = noteworthy
        band.priorYears = priorYears
        
        return band
    }
    
    func deleteAllBands() {
        let request: NSFetchRequest<NSFetchRequestResult> = Band.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Delete all bands error: \(error)")
        }
    }
    
    // MARK: - Event Operations
    
    func fetchEvents() -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch events error: \(error)")
            return []
        }
    }
    
    func createEvent(band: Band, location: String, startTime: String, eventType: String? = nil) -> Event {
        let event = Event(context: context)
        event.band = band
        event.location = location
        event.startTime = startTime
        event.eventType = eventType
        return event
    }
    
    // MARK: - Priority Operations
    
    func fetchUserPriorities() -> [UserPriority] {
        let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching user priorities: \(error)")
            return []
        }
    }
    
    func createUserPriority(band: Band, priority: Int16, lastModified: Double? = nil) -> UserPriority {
        let userPriority = UserPriority(context: context)
        userPriority.band = band
        userPriority.priorityLevel = priority
        userPriority.createdAt = Date()
        userPriority.updatedAt = Date()
        return userPriority
    }
    
    // MARK: - Attendance Operations
    
    func fetchUserAttendances() -> [UserAttendance] {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching user attendances: \(error)")
            return []
        }
    }
    
    func createUserAttendance(event: Event, status: Int16, lastModified: Double? = nil) -> UserAttendance {
        let userAttendance = UserAttendance(context: context)
        userAttendance.event = event
        userAttendance.attendanceStatus = status
        userAttendance.createdAt = Date()
        userAttendance.updatedAt = Date()
        return userAttendance
    }
}
