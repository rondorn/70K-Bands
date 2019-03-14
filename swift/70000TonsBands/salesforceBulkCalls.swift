//
//  salesforceBulkCalls.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/13/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation

class salesforceBulkCalls {
    
    func processBatchJob(object:String, externalID:String, operation:String, data:String){
        
        let sessionID = batchAuth()
        
        let jobId = createBatchJob(object: object, externalID: externalID, operation: operation, sessionID: sessionID)
        
        addJob (data: data, sessionID: sessionID, jobID: jobId)
        closeJob (sessionID: sessionID, jobID: jobId)
        
    }
    
    func batchAuth()->String{
        
        let sfHandler = salesforceRestCalls()
        let sfUserName = sfHandler.getUserName()
        let sfPassword = sfHandler.getPassword()
        
        
        var authXML = "<?xml version=\"1.0\" encoding=\"utf-8\" ?> "
        authXML += "<env:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" "
        authXML += "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" "
        authXML += "xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\"> "
        authXML += "<env:Body> "
        authXML += "<n1:login xmlns:n1=\"urn:partner.soap.sforce.com\"> "
        authXML += "<n1:username>" + sfUserName  + "</n1:username> "
        authXML += "<n1:password>" + sfPassword + "</n1:password> "
        authXML += "</n1:login> "
        authXML += "</env:Body> "
        authXML += "</env:Envelope>\n"
        
        let url = "/services/Soap/u/45.0";
        
        let results = makeWebCall(url: url, type: "POST", body: authXML, contentType: "text/xml; charset=UTF-8", specialHeader: "SOAPAction", specialText: "")
        
        var sessionID = matches(for: "<sessionId>.*</sessionId>", in: results)
        
        sessionID = sessionID.replacingOccurrences(of: "<sessionId>", with: "")
        sessionID = sessionID.replacingOccurrences(of: "</sessionId>", with: "")
        
        return sessionID
        
    }
    
    func createBatchJob(object:String, externalID:String, operation:String, sessionID:String)->String{
        
        var jobXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?> "
        jobXML += "<jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\"> "
        jobXML += "<operation>" + operation + "</operation><object>" + object + "</object> "
        jobXML += "<externalIdFieldName>" + externalID + "</externalIdFieldName><contentType>CSV</contentType></jobInfo>\n"
        
        let jobUrl = "/services/async/45.0/job";
        let jobResults = makeWebCall(url: jobUrl, type: "POST", body: jobXML, contentType: "text/xml; charset=UTF-8", specialHeader: "X-SFDC-Session", specialText: sessionID)
        
        var jobID = matches(for: "<id>.*</id>", in: jobResults)
        
        jobID = jobID.replacingOccurrences(of: "<id>", with: "")
        jobID = jobID.replacingOccurrences(of: "</id>", with: "")
        print ("Https response jobID = \(jobID)");

        return jobID
    }
    
    func addJob (data:String,sessionID: String, jobID: String){
        
        
        let url = "/services/async/45.0/job/" + jobID + "/batch";
        
        let jobResults = makeWebCall(url: url, type: "POST", body: data, contentType: "text/csv; charset=UTF-8", specialHeader: "X-SFDC-Session", specialText: sessionID)
        
    }
    
    func closeJob (sessionID: String, jobID: String){
        

        var jobXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?> "
        jobXML += "<jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\"> "
        jobXML += "<state>Closed</state></jobInfo>\n"
        
        let url = "/services/async/45.0/job/" + jobID;
        
        let jobResults = makeWebCall(url: url, type: "POST", body: jobXML, contentType: "application/xml; charset=UTF-8", specialHeader: "X-SFDC-Session", specialText: sessionID)
    }

    func makeWebCall(url: String, type: String, body: String, contentType: String, specialHeader: String, specialText: String)->String{
        
        var parser = XMLParser();
        var dataText = ""
        
        let salesforceURL = salesforceBaseUrl + url;
        let nsUrl = URL(string: salesforceURL)
        let request = NSMutableURLRequest(url: nsUrl!)
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if (specialHeader == "SOAPAction"){
            request.setValue("login", forHTTPHeaderField: "SOAPAction")
            
        } else if (specialHeader == "X-SFDC-Session"){
            request.setValue(specialText, forHTTPHeaderField: "X-SFDC-Session")
        }
    
        print("Https response url destination is  \(String(describing: nsUrl))")
        print("Https response type is  \(String(describing: type))")
        print("Https response Content-Type is  \(String(describing: contentType))")
        
        let sem = DispatchSemaphore(value: 0)
        
        request.httpMethod = type as String
        
        print("Https response encoding body")
        let body = body.data(using: String.Encoding.utf8)
        
        print("Https response setting body")
        request.httpBody = body;
        
        print("Https response https call")
        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard let data = data, error == nil else {
                print("Https response error parsing data \(String(describing: error))")
                print(error ?? "Unknown error Https response")
                sem.signal()
                return
            }
            
            dataText = String(data: data, encoding: String.Encoding.utf8) as! String
            print("Https response parsing XML data \(String(describing: dataText))")
            
            sem.signal()

   
        }
        task.resume()
        sem.wait(timeout: DispatchTime.distantFuture)
        
        print("Https response is  \(String(describing: dataText))")
        return dataText;
    }
    
    func matches(for regex: String, in text: String) -> String {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            let resultMap = results.map { nsString.substring(with: $0.range)}
            if (resultMap.count == 1){
                return resultMap[0]
            } else {
                return ""
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return ""
        }
    }
    
    func createCSVText(dataArray:[String:String])->String{
        
        var result = "";
        var headers = ""
        var body = ""
        
        for externalId in dataArray{
            
            print ("csvData is externalId " + externalId.key + " = " + externalId.value);
            do {
                let dataRecord = externalId.value.data(using: .utf8)
                
                let jasonResponse = try (JSONSerialization.jsonObject(with: dataRecord!, options: []) as? [String: Any] ?? ["Error":"Json processing error"])
                
                if (headers.isEmpty == true){
                    for index1 in jasonResponse.keys {
                        headers += index1 + ",";
                    }
                    headers += "externalId__c\n";
                    //print ("csvData is part headers is " + headers);
                }
                
                for index2 in jasonResponse {
                    body += index2.value as! String + ",";
                }
                body += externalId.key + "\n";
                //print ("csvData is part body is " + body);
                
            } catch {
                //print ("Could not pase send JSON")
            }
        }
        
        print ("csvData is full body is " + body);
        
        result = headers + body;
        
        return result
    }
}
