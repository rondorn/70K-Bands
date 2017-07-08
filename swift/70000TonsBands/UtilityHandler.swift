//
//  UtilityHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/15/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit


    
func showAlert (_ message: String, title:String){
    
    let alert = UIAlertView()
    if (message.isEmpty == false){
        alert.title = title
        alert.message = message
        alert.addButton(withTitle: "Ok")
        alert.show()
    }
}
