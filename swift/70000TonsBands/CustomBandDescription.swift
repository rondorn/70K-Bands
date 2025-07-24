//
//  CustomBandDescription.swift
//
//
//  Created by Ron Dorn on 9/21/17.
//

import Foundation


open class CustomBandDescription {
    
    // MARK: - Singleton
    static let shared = CustomBandDescription()
    
    var bandDescriptionUrl = [String:String]()
    var bandDescriptionUrlDate = [String:String]()
    private var downloadingBands = Set<String>() // Track bands currently being downloaded
    private let downloadingBandsQueue = DispatchQueue(label: "com.70kbands.downloadingBands", qos: .utility)
    
    // MARK: - Private Initializer
    private init(){
        refreshCache()
    }
    
    func refreshCache(){
        
        let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label
        
        bandDescriptionLock.sync() {
            if (cacheVariables.bandDescriptionUrlCache.isEmpty == false){
                bandDescriptionUrl = cacheVariables.bandDescriptionUrlCache
                bandDescriptionUrlDate = cacheVariables.bandDescriptionUrlDateCache
                
            } else if (currentQueueLabel == "com.apple.main-thread"){
                self.getDescriptionMap();
                
            } else {
                print ("Cache did not load, loading from file desceriptionUrls")
                refreshData()
            }
        }
    }
    
    /**
     Requests data collection with optional year override and completion handler.
     - Parameters:
        - eventYearOverride: If true, cancels all other operations and runs immediately
        - completion: Completion handler called when operation finishes
     */
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        if eventYearOverride {
            // When year changes, we need to refresh the description URL pointer
            // and reload the description map for the new year
            print("CustomBandDescription: Year change detected, refreshing description URL pointer")
            refreshData()
        } else {
            // For normal operations, just refresh cache since it doesn't download from network
            refreshCache()
        }
        completion?()
    }
    
    func refreshData(){
        
        print ("commentFile performaing getAll")
        print ("commentFile getDescriptionMapFile")
        self.getDescriptionMapFile();
        print ("commentFile getDescriptionMap")
        self.getDescriptionMap();
    }
    
    /// Loads the band description map file from disk or cache.
    func getDescriptionMapFile(){
        
        if (isInternetAvailable() == false){
            return;
        }
        
        let mapUrl = getDefaultDescriptionMapUrl()
        let httpData = getUrlData(urlString: mapUrl)
        
        print ("commentFile Map url is \(mapUrl)")
        print ("commentFile Map url Data is \(httpData)")
        if (httpData.isEmpty == false){
            do {
                try FileManager.default.removeItem(atPath: descriptionMapFile)
                
            } catch let error as NSError {
                print ("commentFile Encountered an error removing old descriptionMap file " + error.debugDescription)
            }
            do {
                try httpData.write(toFile: descriptionMapFile, atomically: false, encoding: String.Encoding.utf8)
            } catch let error as NSError {
                print ("commentFile Encountered an error writing descriptionMap file " + error.debugDescription)
            }
            
        }
    }
    
    func writeUrlFile (bandName: String, descriptionUrl: String){
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName);
        
        do {
            try descriptionUrl.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("commentFile " + error.localizedDescription)
}
    }
    
    /// Loads all band descriptions from the description map file.
    func getAllDescriptions(bandNamesSnapshot: [String: [String: String]]? = nil){
        // Ensure bandDescriptionUrl is properly initialized before accessing keys
        if !(bandDescriptionUrl is [String: String]) {
            print("CustomBandDescription: Resetting corrupted bandDescriptionUrl in getAllDescriptions")
            bandDescriptionUrl = [String: String]()
        }
        
        // Extract just the band names from the snapshot, or use our own bandDescriptionUrl
        let bandNames: [String]
        if let snapshot = bandNamesSnapshot {
            bandNames = Array(snapshot.keys)
        } else {
            bandNames = Array(self.bandDescriptionUrl.keys)
        }
        
        if (downloadingAllComments == false){
            downloadingAllComments = true
            print ("commentFile looping through bands")
            for bandName in bandNames {
                // Check if bulk loading is paused
                if bulkLoadingPaused {
                    print("commentFile bulk loading paused, stopping getAllDescriptions")
                    break
                }
                
                print ("commentFile working on bandName " + bandName)
                if (self.doesDescriptionFileExists(bandName: bandName) == false){
                    _ = self.getDescription(bandName: bandName)
                }
            }
        }
        downloadingAllComments = false
    }
    
    func doesDescriptionFileExists(bandName: String) -> Bool {
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent(commentFileName)
        
        print ("commentFile lookup for \(commentFile)");
        return (FileManager.default.fileExists(atPath: commentFile.path))
    }
    
    func custMatchesDefault(customNote: String, bandName: String)-> Bool{
        
        var matches = false
        
        // Type safety check for bandDescriptionUrlDate - handle corruption
        guard let urlDateDict = bandDescriptionUrlDate as? [String: String] else {
            print("CustomBandDescription: bandDescriptionUrlDate is corrupted in custMatchesDefault, type: \(type(of: bandDescriptionUrlDate)), value: \(bandDescriptionUrlDate)")
            // Reset the corrupted dictionary
            bandDescriptionUrlDate = [String: String]()
            return false
        }
        
        // Type safety check for bandDescriptionUrl - handle corruption
        guard let urlDict = bandDescriptionUrl as? [String: String] else {
            print("CustomBandDescription: bandDescriptionUrl is corrupted in custMatchesDefault, type: \(type(of: bandDescriptionUrl)), value: \(bandDescriptionUrl)")
            // Reset the corrupted dictionary
            bandDescriptionUrl = [String: String]()
            return false
        }
        
        if urlDateDict.keys.contains(bandName) && urlDict.keys.contains(bandName){
            var defaultBandNote = getDescriptionFromUrl(bandName: bandName, descriptionUrl: urlDict[bandName]!)
            
            defaultBandNote = defaultBandNote.filter {!$0.isWhitespace}
            
            var strippedCustomNote = customNote
            strippedCustomNote = strippedCustomNote.filter {!$0.isWhitespace}
            
            if (defaultBandNote == strippedCustomNote){
                matches = true
            }
        }
    
        return matches
        
    }
    
    func getNoteFileName (bandName: String)->String {
        
        var approvedFileName = ""
        let custCommentFileName = bandName + "_comment.note-cust";
        
        // Type safety check for bandDescriptionUrlDate - handle corruption
        guard let urlDateDict = bandDescriptionUrlDate as? [String: String] else {
            print("CustomBandDescription: bandDescriptionUrlDate is corrupted, type: \(type(of: bandDescriptionUrlDate)), value: \(bandDescriptionUrlDate)")
            // Reset the corrupted dictionary
            bandDescriptionUrlDate = [String: String]()
            return custCommentFileName
        }
        
        if urlDateDict.keys.contains(bandName){
            let defaultCommentFileName = bandName + "_comment.note-" + urlDateDict[bandName]!;
            
            
            let custCommentFile = directoryPath.appendingPathComponent( custCommentFileName)
            
            if (FileManager.default.fileExists(atPath: custCommentFile.path) == true){
                approvedFileName = custCommentFileName;
            } else {
                approvedFileName = defaultCommentFileName;
            }
        } else {
            approvedFileName = custCommentFileName;
        }
        
        return approvedFileName;
    }
    
    func getDescriptionFromUrl(bandName: String, descriptionUrl: String) -> String {
        
        print ("commentFile lookup for \(bandName) via \(descriptionUrl) hmmm")
        var commentText = ""
        
        let commentFileName = getNoteFileName(bandName: bandName)
        
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        print("CustomBandDescription: getDescriptionFromUrl - Comment file path: \(commentFile.path)")
        
        if (doesDescriptionFileExists(bandName: bandName) == false){
            // Check if already downloading this band to prevent infinite loops
            var shouldDownload = false
            downloadingBandsQueue.sync {
                if downloadingBands.contains(bandName) {
                    print("Already downloading note for \(bandName), skipping duplicate request")
                    return
                }
                downloadingBands.insert(bandName)
                shouldDownload = true
            }
            
            if !shouldDownload {
                return commentText
            }
            print ("commentFile lookup for \(bandName) via \(descriptionUrl) field does not yet exist")
            let httpData = getUrlData(urlString: descriptionUrl);
            print("CustomBandDescription: Downloaded data length: \(httpData.count)")
            print("CustomBandDescription: Downloaded data preview: '\(httpData.prefix(100))...'")
                
                //do not write if we are getting 404 error
                if (httpData.starts(with: "<!DOCTYPE") == false){
                    commentText = httpData;
                    print ("commentFile text is '" + commentText + "'")
                    
                    print ("Wrote commentFile for \(bandName) " + commentText)
                    do {
                        try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                        print("CustomBandDescription: Successfully wrote comment file for \(bandName)")
                        
                        // Notify DetailViewController that note download is complete
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: Notification.Name("NoteDownloaded"), 
                                object: nil, 
                                userInfo: ["bandName": bandName]
                            )
                            print("CustomBandDescription: Posted NoteDownloaded notification for \(bandName)")
                        }
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
                } else {
                    print("CustomBandDescription: Received HTML error page for \(bandName), not saving")
                }
                
                // Remove from downloading set when done
                downloadingBandsQueue.async {
                    self.downloadingBands.remove(bandName)
                }
            } else {
                print("CustomBandDescription: Description file already exists for \(bandName)")
            }

        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.count > 2){
                commentText = data
                print("CustomBandDescription: Successfully read comment file for \(bandName): '\(commentText.prefix(50))...'")
            } else {
                print ("No URL for band  What happened here - \(data)")
            }
        } else {
                print ("No URL for band  What happened here")
        }
    
        commentText = removeSpecialCharsFromString(text: commentText)
        
        return commentText;
    }
    
    func convertOldData(bandName: String){
            
        let oldCommentFileName = bandName + "_comment.txt";
        let oldCommentFile = directoryPath.appendingPathComponent(oldCommentFileName)
        let newCustCommentFile = directoryPath.appendingPathComponent( bandName + "_comment.note-cust")
        var oldCommentText = ""
        
        if (FileManager.default.fileExists(atPath: oldCommentFile.path) == true){
            
            if let data = try? String(contentsOf: oldCommentFile, encoding: String.Encoding.utf8) {
                if (data.count > 2){
                    oldCommentText = data
                } else {
                    print ("No URL for band  What happened here - \(data)")
                }
            } else {
                    print ("No URL for band  What happened here")
            }
            
            var isDefaultNote = self.custMatchesDefault(customNote: oldCommentText, bandName: bandName)
            
            if (oldCommentText.starts(with: "Comment text is not available yet") == false && isDefaultNote == false){
                do {
                    try oldCommentText.write(to: newCustCommentFile, atomically: false, encoding: String.Encoding.utf8)
                } catch {
                    print("commentFile " + error.localizedDescription)
                }
            }
            
            do {
                print ("commentFile being deleted \(oldCommentFile)")
                try FileManager.default.removeItem(atPath: oldCommentFile.path)
                
            } catch let error as NSError {
                print ("Encountered an error removing old commentFile " + error.debugDescription)
            }
        }
    }
    
    /// Returns the description for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The description string for the band.
    func getDescription(bandName: String) -> String {
        
        print("CustomBandDescription: getDescription called for \(bandName)")
        
        // Ensure bandDescriptionUrl is properly initialized
        if !(bandDescriptionUrl is [String: String]) {
            print("CustomBandDescription: Resetting corrupted bandDescriptionUrl")
            bandDescriptionUrl = [String: String]()
        }
        
        convertOldData(bandName: bandName)
        print ("commentFile lookup for \(bandName)")
        var commentText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display."
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        print("CustomBandDescription: Comment file path for \(bandName): \(commentFile.path)")
        print("CustomBandDescription: File exists: \(FileManager.default.fileExists(atPath: commentFile.path))")
        
        if (doesDescriptionFileExists(bandName: bandName) == false){
            print("CustomBandDescription: Description file does not exist for \(bandName)")
            
            if (downloadingAllComments == false){
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self.getDescriptionMapFile();
                    self.getDescriptionMap();
                }
            }
            
            //bandDescriptionLock.sync() {
            // Type safety check for bandDescriptionUrl - handle all possible corruption cases
            guard let urlDict = bandDescriptionUrl as? [String: String] else {
                print("CustomBandDescription: bandDescriptionUrl is corrupted, type: \(type(of: bandDescriptionUrl)), value: \(bandDescriptionUrl)")
                // Reset the corrupted dictionary
                bandDescriptionUrl = [String: String]()
                return commentText
            }
            
            if (urlDict.index(forKey: bandName) != nil && urlDict[bandName] != nil){
                
                print ("commentFile downloading URL \(urlDict[bandName] ?? "nil")")
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    
                    self.getDescriptionFromUrl(bandName: bandName, descriptionUrl: urlDict[bandName]! )
                }
            } else {
                print("CustomBandDescription: No URL found for \(bandName) in bandDescriptionUrl")
                print("CustomBandDescription: Available bands: \(Array(bandDescriptionUrl.keys))")
            }
        } else {
            print ("No URL for band \(bandName) - \(commentFile)")
            if FileManager.default.fileExists(atPath: commentFile.path){
                print ("No URL for band \(bandName) - file exists")
            } else {
                print ("No URL for band \(bandName) - file does not exists")
            }
        
        }
        

        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.count > 2){
                commentText = data
                print("CustomBandDescription: Successfully loaded comment text for \(bandName): '\(commentText.prefix(50))...'")
            } else {
                print ("No URL for band  What happened here - \(data)")
            }
        } else {
                print ("No URL for band  What happened here")
        }
        
        
        commentText = removeSpecialCharsFromString(text: commentText)
        //remove leading space
        commentText = commentText.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        
        if (commentText.contains("Comment text is not available yet. Please wait")){
            // Only try to delete if the file actually exists
            if FileManager.default.fileExists(atPath: commentFile.path) {
                do {
                    print ("commentFile being deleted \(commentFile) -! - \(commentText)")
                    try FileManager.default.removeItem(atPath: commentFile.path)
                    
                } catch let error as NSError {
                    print ("Encountered an error removing old commentFile " + error.debugDescription)
                }
            } else {
                print ("commentFile does not exist, skipping deletion: \(commentFile)")
            }
        }
        
        print("CustomBandDescription: Returning comment text for \(bandName): '\(commentText.prefix(50))...'")
        return commentText;
    }
    
    
    func removeSpecialCharsFromString(text: String) -> String {
        
        var newText = text;
        newText = text.replacingOccurrences(of: "\r", with: "\n")
        let okayChars : Set<Character> =
        Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_\n$\\//")
        return String(newText.filter {okayChars.contains($0) })
    }
    
    func getDescriptionMap(){
        
        if descriptionLock == false {
            descriptionLock = true;
            
            print ("commentFile looking for descriptionMapFile")
            
            if (FileManager.default.fileExists(atPath: descriptionMapFile) == false){
                getDescriptionMapFile();
            }
            
            print ("commentFile looking for descriptionMapFile of \(descriptionMapFile)")
            if let csvDataString = try? String(contentsOfFile: descriptionMapFile, encoding: String.Encoding.utf8) {
                
                var csvData: CSV
                
                csvData = try! CSV(csvStringToParse: csvDataString)
                
                for lineData in csvData.rows {
                    // Type safety check - ensure lineData is a dictionary
                    guard let lineDict = lineData as? [String: String] else {
                        print("CustomBandDescription: Skipping invalid lineData type: \(type(of: lineData))")
                        continue
                    }
                    
                    if (lineDict[bandField] != nil && lineDict[urlField] != nil &&  lineDict[bandField]?.isEmpty == false && lineDict[urlField]?.isEmpty == false){
                        print ("commentFile descriptiopnMap Adding \(lineDict[bandField]?.debugDescription ?? "nil") with url \(lineDict[urlField]?.debugDescription ?? "nil")")
                        bandDescriptionUrl[(lineDict[bandField]) ?? ""] = lineDict[urlField]
                        bandDescriptionUrlDate[(lineDict[bandField]) ?? ""] = lineDict[urlDateField]
                        bandDescriptionLock.async(flags: .barrier) {
                            cacheVariables.bandDescriptionUrlCache[(lineDict[bandField])!] = lineDict[urlField]
                            cacheVariables.bandDescriptionUrlDateCache[(lineDict[bandField])!] = lineDict[urlDateField]
                        }
                        
                    } else {
                        print ("commentFile  Unable to parse descriptionMap line \(lineData)")
                    }
                }
            } else {
                print ("commentFile Encountered an error could not open descriptionMap file")
            }
            
            descriptionLock = false;
        }
    }
    
    func getDefaultDescriptionMapUrl() -> String{
        
        var url = String()

        var descriptionPointer = "descriptionMap";
        
        print ("Gertting descriptionPointerUrl 1");
        url = getPointerUrlData(keyValue: descriptionPointer)
        
        return url
    }
    
    /// Returns the description URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The description URL string for the band.
    func getDescriptionUrl(_ band: String) -> String {
        return bandDescriptionUrl[band] ?? ""
    }
    
    /// Returns the date of the description for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The date string for the band's description.
    func getDescriptionDate(_ band: String) -> String {
        return bandDescriptionUrlDate[band] ?? ""
    }
    
    /// Pauses bulk loading operations
    func pauseBulkLoading() {
        bulkLoadingPaused = true
        print("CustomBandDescription: Bulk loading paused")
    }
    
    /// Resumes bulk loading operations
    func resumeBulkLoading() {
        bulkLoadingPaused = false
        print("CustomBandDescription: Bulk loading resumed")
    }
    
    /// Loads description for a specific band with priority (ignores pause state)
    /// - Parameter bandName: The name of the band to load description for
    func loadDescriptionWithPriority(bandName: String) {
        print("CustomBandDescription: Loading description with priority for \(bandName)")
        if (self.doesDescriptionFileExists(bandName: bandName) == false){
            _ = self.getDescription(bandName: bandName)
        }
    }
}




