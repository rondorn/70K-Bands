//
//  salesforceRestCalls.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/3/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation

class salesforceRestCalls {

    let salesforceURL = "https://na85.salesforce.com";
    
    func getClientID()->String{
        return "3MVG9KsVczVNcM8wGlNuZtSOdQGx8FzKqb0zJjYKEhDxr.LptM8jiecVyMpgvTV2Dx5MKq6MijZIJUKgGbbRT";
    }
    
    func getClientSecret()->String{
        return "990ECB8D78A4A5518702B53DABE493890E0C0C4E3ECC42E84C54B223BF6A1663";
    }
    
    func getUserName()->String{
        return "apiAccount@70kbands.com";
    }

    func getPassword()->String{
        return "4lJ3vdLt6Q3l!";
    }
    
    func getAuthenticationToken (userName:String, password:String, clientID: String, clientSecret: String)->String{
        
        var authToken:String = ""
        
        let url = NSURL(string: salesforceURL)
        let request = NSMutableURLRequest(url: url! as URL)
        
        request.setValue("password", forHTTPHeaderField: "grant_type")
        request.setValue(clientID, forHTTPHeaderField: "client_id")
        request.setValue(clientSecret, forHTTPHeaderField: "client_secret")
        request.setValue(userName, forHTTPHeaderField: "username")
        request.setValue(password, forHTTPHeaderField: "password")
        
        request.httpMethod = "GET"
        
        //let dataLoad = HTTPsendRequest(request as URLRequest)
        //print("Https text is \(dataLoad)")
        
        let session = URLSession.shared
        

        let response = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            if let antwort = response as? HTTPURLResponse {
                let code = antwort.statusCode
                print("Https response code is \(code)")
                
                guard let data = data else { return }
                
                print("Https response code is \(data)")
                do {
                    guard let todo = try JSONSerialization.jsonObject(with: data, options: [])
                        as? [String: Any] else {
                            print("Https response code is JSON Failure Pre")
                            return
                    }
                    // now we have the todo
                    // let's just print it to prove we can access it
                    print("Https response code is \(todo)")
                } catch {
                    print("Https response code is JSON Failure \(error)")
                }
            }
        }
        
        response.resume()
        
        return authToken;
    }
}
/*
sub getAuthenticationToken{
    
    my $properties = shift;
    
    if ($properties->{salesforce}->{proxy}){
        $proxyString = '-x ' . $properties->{salesforce}->{proxy};
    }
    
    my $password = $properties->{salesforce}->{password};
    
    
    $authArguments->[0] = '-d "grant_type=password"';
    $authArguments->[1] = '--data-urlencode "client_id=' . $properties->{salesforce}->{client_id} . '" ';
    $authArguments->[2] = '--data-urlencode "client_secret=' . $properties->{salesforce}->{client_secret} . '" ';
    $authArguments->[3] = '-d "username=' . $properties->{salesforce}->{user} . '" ';
    $authArguments->[4] = '--data-urlencode "password=' .  $password . '" ';
    $authArguments->[5] = '--connect-timeout 5';
    $authArguments->[6] = '--max-time 15';
    $authArguments->[7] = "--tlsv1.2";
    
    my $tokenData = makeWebCall("$properties->{salesforce}->{url}/services/oauth2/token", $properties);
    
    
    if ($tokenData !~ /HASH/){
        croak ("Authentication issue encountered for user $properties->{salesforce}->{user}!\n" . $tokenData);
        
    } elsif (!$tokenData->{access_token}){
        croak ("Authentication issue encountered for user $properties->{salesforce}->{user}!\n" . Dumper($tokenData));
    }
    
    $authArguments->[0] = '-H "Authorization: Bearer ' . $tokenData->{access_token} . '"';
    $authArguments->[1] = "";
    $authArguments->[2] = "";
    $authArguments->[3] = "";
    $authArguments->[4] = "";
    $authArguments->[5] = "";
    $authArguments->[6] = "";
    $authArguments->[7] = "";
    
    return();
}

 */
