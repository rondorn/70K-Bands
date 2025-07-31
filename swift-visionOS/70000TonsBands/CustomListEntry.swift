//
//  CustomListEntry..swift
//  DropDown
//
//  Created by Kevin Hirsch on 17/08/16.
//  Copyright © 2016 Kevin Hirsch. All rights reserved.
//

import UIKit
//import DropDown

class CustomListEntry: UIView {
    
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var optionLabel: UILabel!
    
    // Add custom property for visionOS compatibility
    var isInteractionEnabled: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Initialize the view
        backgroundColor = UIColor.clear
    }
    
}
