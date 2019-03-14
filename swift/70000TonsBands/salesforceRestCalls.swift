//
//  salesforceRestCalls.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/3/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation

class salesforceRestCalls {

    var authToken:String = ""
    var apiData:[String: AnyObject] = [String: AnyObject]();
    
    init(){
        readApiPropertyList();
    }
    func getClientID()->String{
        
        return apiData["apiClientID"] as! String

    }
    
    func getClientSecret()->String{
         return apiData["apiClientSecret"] as! String
    }
    
    func getUserName()->String{
        return apiData["apiAccount"] as! String
    }

    func getPassword()->String{
        return apiData["apiPassword"] as! String
    }
    
    func readApiPropertyList(){
        
        var propertyListForamt =  PropertyListSerialization.PropertyListFormat.xml //Format of the Property List.
        var plistData: [String: AnyObject] = [:] //Our data
        let plistPath: String? = Bundle.main.path(forResource: "ApiKeys", ofType: "plist")! //the path of the data
        let plistXML = FileManager.default.contents(atPath: plistPath!)!
        do {//convert the data to a dictionary and handle errors.
            plistData = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListForamt) as! [String:AnyObject]
            
        } catch {
            print("Error reading plist: \(error), format: \(propertyListForamt)")
        }
        
        apiData = plistData
    }
    
    func getAuthenticationToken (userName:String, password:String, clientID: String, clientSecret: String){
        
        let url = "/services/oauth2/token"
        var authReponse:[String:Any]
        
        var postString = "grant_type=password&"
        postString += "&client_id=" + clientID.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        postString += "&client_secret=" + clientSecret.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        postString += "&username=" +  userName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        postString += "&password=" + password.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
        authReponse = makeWebCall(url: url,type: "POST", body: postString, contentType: "application/x-www-form-urlencoded", specialHeader: "")
        
        self.authToken = authReponse["access_token"] as? String ?? "unknown"
        
        print ("Https response auth token is \(authToken)")
        
    }
    
    func upsert(recordID:String, object:String, data:String){
        
        var type:String;
        var url = "/services/data/v38.0/sobjects/" + object + "/" + recordID
        
        if (self.authToken.isEmpty == true){
            let clientID = self.getClientID()
            let clientSecret = self.getClientSecret()
            let sfUserName = self.getUserName()
            let sfPassword = self.getPassword()
            
            self.getAuthenticationToken(userName: sfUserName, password: sfPassword, clientID: clientID, clientSecret: clientSecret)
        }
        
        if (recordID.isEmpty == false){
            type = "PATCH"
            url = "/services/data/v38.0/sobjects/" + object + "/externalID__c/" + recordID + "/"
        } else {
            type = "POST"
        }
        
        let results = self.makeWebCall (url: url, type: type, body: data, contentType: "application/json", specialHeader: "Authorized");
    }
    
    func makeWebCall(url: String, type: String, body: String, contentType: String, specialHeader: String)->[String:Any]{
        
        let salesforceURL = salesforceBaseUrl + url;
        var jasonResponse = [String:Any]();
        
        
        let nsUrl = URL(string: salesforceURL)
        
        if (nsUrl == nil){
            jasonResponse["Error"] = "Url is empty";
            return jasonResponse
        }
        let request = NSMutableURLRequest(url: nsUrl!)

        print("Https response url destination is  \(String(describing: nsUrl))")
        print("Https response type is  \(String(describing: type))")
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        var sem = DispatchSemaphore(value: 0)
        
        if (specialHeader == "Authorized"){
            print("Https response setting authToken to " + authToken);
            request.setValue("Bearer " + authToken, forHTTPHeaderField: "Authorization")
        
        } else if (specialHeader == "SOAPAction"){
            print("Https response setting SOAPAction to login");
            request.setValue("login", forHTTPHeaderField: "SOAPAction")
            
        }
        
        request.httpMethod = type as String
    
        let body = body.data(using: String.Encoding.utf8)
    
        request.httpBody = body;
    
        let session = URLSession.shared
    

        let response = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            if let antwort = response as? HTTPURLResponse {
                let code = antwort.statusCode
                print("Https response code is \(code)")
                
                guard let data = data else { return }
                
                print("Https response data is \(antwort)")
                if (specialHeader != "SOAPAction"){
                    do {
                        jasonResponse = try (JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? ["NotJson":data])
                        
                        // now we have the todo
                        // let's just print it to prove we can access it[
                        print("Https response full authReponse is \(jasonResponse)")
                        

                        sem.signal()
                        
                    } catch {
                        print("Https response code is JSON Failure post \(error)")
                        jasonResponse = ["NotJson":data];
                        sem.signal()
                    }
                } else {
                    jasonResponse = ["NotJson":data];
                }
            }
        }
    
        response.resume()
        sem.wait(timeout: DispatchTime.distantFuture)
        
        return jasonResponse
    
    }
}
