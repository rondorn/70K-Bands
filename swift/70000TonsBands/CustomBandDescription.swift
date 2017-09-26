//
//  CustomBandDescription.swift
//
//
//  Created by Ron Dorn on 9/21/17.
//

import Foundation


open class CustomBandDescription {
    
    func getDescriptionMapFile(){
        
        var mapUrl = getDefaultDescriptionMapUrl()
        let httpData = getUrlData(mapUrl)
        
        if (httpData.isEmpty == false){
            do {
                try FileManager.default.removeItem(atPath: descriptionMapFile)
                
            } catch let error as NSError {
                print ("Encountered an error removing old descriptionMap file " + error.debugDescription)
            }
            do {
                try httpData.write(toFile: descriptionMapFile, atomically: false, encoding: String.Encoding.utf8)
            } catch let error as NSError {
                print ("Encountered an error writing descriptionMap file " + error.debugDescription)
            }
            
        }
    }
    
    func getAllDescriptions(){
        
        print ("commentFile performaing getAll")
        print ("commentFile getDescriptionMapFile")
        getDescriptionMapFile();
        print ("commentFile getDescriptionMap")
        getDescriptionMap();
        
        print ("commentFile looping through bands")
        for record in bandDescriptionUrl{
            let bandName = record.key
            _ = getDescription(bandName: bandName)
        }
    }
    
    
    func getDescription(bandName: String) -> String {
        
        print ("commentFile lookup for \(bandName)")
        var commentText = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display."
        
        let commentFileName = bandName + "_comment.txt";
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        if (FileManager.default.fileExists(atPath: commentFile.path) == false){
            if (bandDescriptionUrl[bandName] != nil){
                let httpData = getUrlData(bandDescriptionUrl[bandName]!);
                
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    commentText = httpData;
                    print ("Wrote commentFile for \(bandName) " + commentText)
                    do {
                        try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
                }
            }
        } else {
            if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
                if (data.characters.count > 2){
                    commentText = data
                }
            }
        }
        
        sleep(1)
        commentText = removeSpecialCharsFromString(text: commentText)
        return commentText;
    }
    
    
    func removeSpecialCharsFromString(text: String) -> String {
        let okayChars : Set<Character> =
            Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_\n".characters)
        return String(text.characters.filter {okayChars.contains($0) })
    }
    
    func getDescriptionMap(){
        
        if (FileManager.default.fileExists(atPath: descriptionMapFile) == false){
            getDescriptionMapFile();
        }
        
        if let csvDataString = try? String(contentsOfFile: descriptionMapFile, encoding: String.Encoding.utf8) {
            
            var csvData: CSV
            
            csvData = try! CSV(csvStringToParse: csvDataString)
            
            for lineData in csvData.rows {
                if (lineData[bandField]?.isEmpty == false && lineData[urlField]?.isEmpty == false){
                    print ("descriptiopnMap Adding \(lineData[bandField]) with url \(lineData[urlField])")
                    bandDescriptionUrl[(lineData[bandField])!] = lineData[urlField]
                } else {
                    print ("Unable to parse descriptionMap line")
                }
            }
        } else {
            print ("Encountered an error could not open descriptionMap file")
        }
    }
    
    func getDefaultDescriptionMapUrl() -> String{
        
        var url = String()
        let httpData = getUrlData(defaultStorageUrl)
        
        let dataArray = httpData.components(separatedBy: "\n")
        for record in dataArray {
            var valueArray = record.components(separatedBy: "::")
            if (valueArray[0] == "descriptionMap"){
                url = valueArray[1]
            }
        }
        
        print ("Using default DescriptionMapUrl of " + url)
        return url
    }
}



