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
        let normalizedBandName = normalizeBandName(bandName)
        
        if bandDescriptionUrlDate.keys.contains(normalizedBandName){
            var defaultBandNote = getDescriptionFromUrl(bandName: bandName, descriptionUrl: bandDescriptionUrl[normalizedBandName]!)
            
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
        let normalizedBandName = normalizeBandName(bandName)
        
        if bandDescriptionUrlDate.keys.contains(normalizedBandName){
            let defaultCommentFileName = bandName + "_comment.note-" + bandDescriptionUrlDate[normalizedBandName]!;
            
            
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
        
        print ("DEBUG_commentFile: lookup for \(bandName) via \(descriptionUrl)")
        var commentText = ""
        
        let commentFileName = getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        print ("DEBUG_commentFile: doesDescriptionFileExists for \(bandName)")
        if (doesDescriptionFileExists(bandName: bandName) == false){
            print ("DEBUG_commentFile: lookup for \(bandName) via \(descriptionUrl) field does not yet exist")
            
            // Check if internet is available
            guard isInternetAvailable() else {
                print("No internet available for \(bandName) description download")
                return "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display."
            }
            
            let httpData = getUrlData(urlString: descriptionUrl);
                
            //do not write if we are getting 404 error or HTML error page
            if (httpData.starts(with: "<!DOCTYPE") == false && !httpData.isEmpty){
                commentText = httpData;
                print ("commentFile text is '" + commentText + "'")
                
                print ("Wrote commentFile for \(bandName) " + commentText)
                do {
                    try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                } catch {
                    print("commentFile " + error.localizedDescription)
                }
            } else {
                print("Received HTML error page or empty response for \(bandName)")
            }
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
        let normalizedBandName = normalizeBandName(bandName)
        print ("DEBUG_commentFile:  lookup for \(bandName) (normalized: \(normalizedBandName))")
        var commentText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display."
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        print ("DEBUG_commentFile: doesDescriptionFileExists for \(bandName)")
        if (doesDescriptionFileExists(bandName: bandName) == false){
            
            if (downloadingAllComments == false){
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self.getDescriptionMapFile();
                    self.getDescriptionMap();
                }
            }
            
            //bandDescriptionLock.sync() {
            if (bandDescriptionUrl.index(forKey: normalizedBandName) != nil && bandDescriptionUrl[normalizedBandName] != nil){
                
                print ("DEBUG_commentFile: downloading URL \(bandDescriptionUrl[normalizedBandName])")
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    
                    self.getDescriptionFromUrl(bandName: bandName, descriptionUrl: self.bandDescriptionUrl[normalizedBandName]! )
                }
            } else {
                print ("DEBUG_commentFile: No URL for band '\(normalizedBandName)' - \(bandDescriptionUrl)")
            }
        } else {
            print ("DEBUG_commentFile: No URL for band \(bandName) - \(commentFile)")
            if FileManager.default.fileExists(atPath: commentFile.path){
                print ("DEBUG_commentFile: No URL for band \(bandName) - file exists")
            } else {
                print ("DEBUG_commentFile: No URL for band \(bandName) - file does not exists")
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
            do {
                print ("commentFile being deleted \(commentFile) -! - \(commentText)")
                try FileManager.default.removeItem(atPath: commentFile.path)
                
            } catch let error as NSError {
                print ("Encountered an error removing old commentFile " + error.debugDescription)
            }
        }
        return commentText;
    }
    
    
    public func removeSpecialCharsFromString(text: String) -> String {
        
        var newText = text;
        newText = text.replacingOccurrences(of: "\r", with: "\n")
        let okayChars : Set<Character> =
        Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_\n$\\//")
        return String(newText.filter {okayChars.contains($0) })
    }
    
    /// Normalizes a band name by removing invisible Unicode characters and trimming whitespace.
    /// - Parameter bandName: The band name to normalize.
    /// - Returns: The normalized band name.
    func normalizeBandName(_ bandName: String) -> String {
        // Remove invisible Unicode characters and normalize
        let normalized = bandName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "⁦", with: "") // Remove left-to-right mark
            .replacingOccurrences(of: "⁧", with: "") // Remove right-to-left mark
            .replacingOccurrences(of: "\u{200E}", with: "") // Remove left-to-right mark
            .replacingOccurrences(of: "\u{200F}", with: "") // Remove right-to-left mark
            .replacingOccurrences(of: "\u{202A}", with: "") // Remove left-to-right embedding
            .replacingOccurrences(of: "\u{202B}", with: "") // Remove right-to-left embedding
            .replacingOccurrences(of: "\u{202C}", with: "") // Remove pop directional formatting
            .replacingOccurrences(of: "\u{202D}", with: "") // Remove left-to-right override
            .replacingOccurrences(of: "\u{202E}", with: "") // Remove right-to-left override
            .replacingOccurrences(of: "\u{2066}", with: "") // Remove left-to-right isolate
            .replacingOccurrences(of: "\u{2067}", with: "") // Remove right-to-left isolate
            .replacingOccurrences(of: "\u{2068}", with: "") // Remove first strong isolate
            .replacingOccurrences(of: "\u{2069}", with: "") // Remove pop directional isolate
        
        return normalized
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
                
                if let csvData = try? CSV(csvStringToParse: csvDataString) {
                    for lineData in csvData.rows {
                        if (lineData[bandField] != nil && lineData[urlField] != nil &&  lineData[bandField]?.isEmpty == false && lineData[urlField]?.isEmpty == false){
                            let normalizedBandName = normalizeBandName(lineData[bandField] ?? "")
                            print ("commentFile descriptiopnMap Adding \(normalizedBandName) with url \(lineData[urlField].debugDescription)")
                            bandDescriptionUrl[normalizedBandName] = lineData[urlField]
                            bandDescriptionUrlDate[normalizedBandName] = lineData[urlDateField]
                            bandDescriptionLock.async(flags: .barrier) {
                                cacheVariables.bandDescriptionUrlCache[normalizedBandName] = lineData[urlField]
                                cacheVariables.bandDescriptionUrlDateCache[normalizedBandName] = lineData[urlDateField]
                            }
                        } else {
                            print ("commentFile  Unable to parse descriptionMap line \(lineData)")
                        }
                    }
                } else {
                    print("Error: Failed to parse CSV data in getDescriptionMap.")
                }
            } else {
                print ("commentFile Encountered an error could not open descriptionMap file - \(descriptionMapFile)")
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
        let normalizedBand = normalizeBandName(band)
        return bandDescriptionUrl[normalizedBand] ?? ""
    }
    
    /// Returns the date of the description for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The date string for the band's description.
    func getDescriptionDate(_ band: String) -> String {
        let normalizedBand = normalizeBandName(band)
        return bandDescriptionUrlDate[normalizedBand] ?? ""
    }
}




