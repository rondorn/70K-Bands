//
//  UtilityHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/15/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//

import Foundation
import UIKit


    
func showAlert (message: String, title:String){
    
    let alert = UIAlertView()
    if (message.isEmpty == false){
        alert.title = title
        alert.message = message
        alert.addButtonWithTitle("Ok")
        alert.show()
    }
}