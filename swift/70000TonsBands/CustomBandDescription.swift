//
//  CustomBandDescription.swift
//
//
//  Created by Ron Dorn on 9/21/17.
//

import Foundation


open class CustomBandDescription {
    
    var bandDescriptionUrl = [String:String]()
    
    init(){
        refreshCache()
    }
    
    func refreshCache(){
        
        let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label
        
        bandDescriptionLock.sync() {
            if (cacheVariables.bandDescriptionUrlCache.isEmpty == false){
                bandDescriptionUrl = cacheVariables.bandDescriptionUrlCache
            
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
        
        let commentFileName = bandName + "_commentUrl.txt";
        let commentFile = directoryPath.appendingPathComponent( commentFileName);
        
        do {
            try descriptionUrl.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("commentFile " + error.localizedDescription)
        }
    }
 
    func saveComments(bandName: String, commentText: String)->Bool{
        
        var saveSuccessfull = true;
        
        let commentFile = directoryPath.appendingPathComponent( bandName + "_comment.txt")
        if (commentText.starts(with: "Comment text is not available yet") == true){
            saveSuccessfull = false;
            removeBadNote(commentFile: commentFile)
            
        } else if (commentText.count < 2){
            saveSuccessfull = false;
            removeBadNote(commentFile: commentFile)

        } else {
            print ("COMMENT saving commentFile");
        
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                print ("COMMENT Writting commentFile " + commentText)

                do {
                    try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                } catch {
                    print("COMMENT commentFile " + error.localizedDescription)
                }
            }
        }

        return saveSuccessfull;
    }
    
    func removeBadNote(commentFile: URL){
        do {
            print ("commentFile being deleted \(commentFile)")
            try FileManager.default.removeItem(atPath: commentFile.path)
            
        } catch let error as NSError {
            print ("Encountered an error removing old commentFile " + error.debugDescription)
        }
        
        if (FileManager.default.fileExists(atPath: commentFile.path) == true){
            print ("ERROR: commentFile was not deleted")
        } else {
            print ("CONFIRMATION: commentFile was deleted")
        }
    }
    
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
        
        let commentFileName = bandName + "_comment.txt";
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        print ("commentFile lookup for \(commentFile)");
        return (FileManager.default.fileExists(atPath: commentFile.path))
    }
 
    func doesUrlFileExists(bandName: String) -> Bool {
        
        let commentFileName = bandName + "_commentUrl.txt";
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        print ("commentFile lookup for \(commentFile)");
        return (FileManager.default.fileExists(atPath: commentFile.path))
    }
    /*
    func getTextFromUrl (bandName: String){
        
        let commentUrlFile = bandName + "_commentUrl.txt";
        if (doesUrlFileExists(bandName: bandName) == true){
            
            let commetUrl = "";
            if let data = try? String(contentsOf: commentUrlFile, encoding: String.Encoding.utf8) {
                if (data.count > 2){
                    commetUrl = data
                }
            }
        }
    }
    */
    func getDescriptionFromUrl(bandName: String, descriptionUrl: String) -> String {
        
        print ("commentFile lookup for \(bandName) via \(descriptionUrl) hmmm")
        var commentText = "Comment text is not available yet."
        
        let commentFileName = bandName + "_comment.txt";
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        if (doesDescriptionFileExists(bandName: bandName) == false){
            print ("commentFile lookup for \(bandName) via \(descriptionUrl) fiel does not yes exist")
            let httpData = getUrlData(urlString: descriptionUrl);
                
                //do not write if we are getting 404 error
                if (httpData.starts(with: "<!DOCTYPE") == false){
                    commentText = httpData;
                    print ("commentFile text is '" + commentText + "'")
                    
                    print ("Wrote commentFile for \(bandName) " + commentText)
                    do {
                        try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
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
    
    func getDescription(bandName: String) -> String {
        
        print ("commentFile lookup for \(bandName)")
        var commentText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display."
        
        let commentFileName = bandName + "_comment.txt";
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        if (doesDescriptionFileExists(bandName: bandName) == false){
            
            if (downloadingAllComments == false){
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self.getDescriptionMapFile();
                    self.getDescriptionMap();
                }
            }
            
            print ("commentFile does not exist \(bandDescriptionUrl)")
            print ("commentFile does not exist \(bandName) - \(bandDescriptionUrl[bandName])")
            if (bandDescriptionUrl[bandName] != nil){
                
                print ("commentFile downloading URL \(bandDescriptionUrl[bandName])")
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    
                    var url = self.bandDescriptionUrl[bandName]!
                    let httpData = getUrlData(urlString: url);
                    print ("Trying to download comment from url \(httpData)")
                    //do not write if we are getting 404 error
                    if (httpData.starts(with: "<!DOCTYPE") == false){
                        commentText = httpData;
                        print ("commentFile text is '" + commentText + "'")
                        
                        print ("Wrote commentFile for \(bandName) " + commentText)
                        do {
                            try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                            self.writeUrlFile(bandName: bandName, descriptionUrl: url)
                            
                        } catch {
                            print("commentFile " + error.localizedDescription)
                        }
                    }
                }
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
    
    
    func removeSpecialCharsFromString(text: String) -> String {
        
        var newText = text;
        newText = text.replacingOccurrences(of: "\r", with: "\n")
        let okayChars : Set<Character> =
            Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_\n")
        return String(newText.filter {okayChars.contains($0) })
    }
    
    func getDescriptionMap(){
        
        print ("commentFile looking for descriptionMapFile")
        
        if (FileManager.default.fileExists(atPath: descriptionMapFile) == false){
            getDescriptionMapFile();
        }
        
        print ("commentFile looking for descriptionMapFile of \(descriptionMapFile)")
        if let csvDataString = try? String(contentsOfFile: descriptionMapFile, encoding: String.Encoding.utf8) {
            
            var csvData: CSV
            
            csvData = try! CSV(csvStringToParse: csvDataString)
            
            for lineData in csvData.rows {
                if (lineData[bandField]?.isEmpty == false && lineData[urlField]?.isEmpty == false){
                    print ("commentFile descriptiopnMap Adding \(lineData[bandField].debugDescription) with url \(lineData[urlField].debugDescription)")
                    bandDescriptionUrl[(lineData[bandField])!] = lineData[urlField]
                    
                    bandDescriptionLock.async(flags: .barrier) {
                        cacheVariables.bandDescriptionUrlCache[(lineData[bandField])!] = lineData[urlField]
                    }
                    
                } else {
                    print ("commentFile  Unable to parse descriptionMap line \(lineData)")
                }
            }
        } else {
            print ("commentFile Encountered an error could not open descriptionMap file")
        }
    }
    
    func getDefaultDescriptionMapUrl() -> String{
        
        var url = String()

        var descriptionPointer = "descriptionMap";
        
        if (defaults.string(forKey: "scheduleUrl") == lastYearSetting){
            descriptionPointer = "descriptionMapLastYear"
        }
        
        url = getPointerUrlData(keyValue: descriptionPointer)
        
        return url
    }
}



