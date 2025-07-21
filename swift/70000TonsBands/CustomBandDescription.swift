//
//  CustomBandDescription.swift
//
//
//  Created by Ron Dorn on 9/21/17.
//

import Foundation


open class CustomBandDescription {
    
    var bandDescriptionUrl = [String:String]()
    var bandDescriptionUrlDate = [String:String]()
    private var downloadingBands = Set<String>() // Track bands currently being downloaded
    
    init(){
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
        // For CustomBandDescription, we just refresh cache since it doesn't download from network
        refreshCache()
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
    func getAllDescriptions(){
        
        if (downloadingAllComments == false){
            downloadingAllComments = true
            print ("commentFile looping through bands")
            for record in self.bandDescriptionUrl{
                let bandName = record.key
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
        
        if bandDescriptionUrlDate.keys.contains(bandName){
            var defaultBandNote = getDescriptionFromUrl(bandName: bandName, descriptionUrl: bandDescriptionUrl[bandName]!)
            
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
        
        if bandDescriptionUrlDate.keys.contains(bandName){
            let defaultCommentFileName = bandName + "_comment.note-" + bandDescriptionUrlDate[bandName]!;
            
            
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
        
        if (doesDescriptionFileExists(bandName: bandName) == false){
            // Check if already downloading this band to prevent infinite loops
            if downloadingBands.contains(bandName) {
                print("Already downloading note for \(bandName), skipping duplicate request")
                return commentText
            }
            
            downloadingBands.insert(bandName)
            print ("commentFile lookup for \(bandName) via \(descriptionUrl) field does not yet exist")
            let httpData = getUrlData(urlString: descriptionUrl);
                
                //do not write if we are getting 404 error
                if (httpData.starts(with: "<!DOCTYPE") == false){
                    commentText = httpData;
                    print ("commentFile text is '" + commentText + "'")
                    
                    print ("Wrote commentFile for \(bandName) " + commentText)
                    do {
                        try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                        
                        // Notify DetailViewController that note download is complete
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: Notification.Name("NoteDownloaded"), 
                                object: nil, 
                                userInfo: ["bandName": bandName]
                            )
                        }
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
                }
                
                // Remove from downloading set when done
                downloadingBands.remove(bandName)
            }

        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.count > 2){
                commentText = data
            }
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
        
        convertOldData(bandName: bandName)
        print ("commentFile lookup for \(bandName)")
        var commentText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display."
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        if (doesDescriptionFileExists(bandName: bandName) == false){
            
            if (downloadingAllComments == false){
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self.getDescriptionMapFile();
                    self.getDescriptionMap();
                }
            }
            
            //bandDescriptionLock.sync() {
            if (bandDescriptionUrl.index(forKey: bandName) != nil && bandDescriptionUrl[bandName] != nil){
                
                print ("commentFile downloading URL \(bandDescriptionUrl[bandName])")
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    
                    self.getDescriptionFromUrl(bandName: bandName, descriptionUrl: self.bandDescriptionUrl[bandName]! )
                }
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
                    if (lineData[bandField] != nil && lineData[urlField] != nil &&  lineData[bandField]?.isEmpty == false && lineData[urlField]?.isEmpty == false){
                        print ("commentFile descriptiopnMap Adding \(lineData[bandField].debugDescription) with url \(lineData[urlField].debugDescription)")
                        bandDescriptionUrl[(lineData[bandField]) ?? ""] = lineData[urlField]
                        bandDescriptionUrlDate[(lineData[bandField]) ?? ""] = lineData[urlDateField]
                        bandDescriptionLock.async(flags: .barrier) {
                            cacheVariables.bandDescriptionUrlCache[(lineData[bandField])!] = lineData[urlField]
                            cacheVariables.bandDescriptionUrlDateCache[(lineData[bandField])!] = lineData[urlDateField]
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
}




