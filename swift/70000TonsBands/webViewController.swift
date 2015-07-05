//
//  webView.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/4/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//


import UIKit

class WebViewController: UIViewController {

    @IBOutlet weak var webDisplay: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var url = getUrl()
        
        splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.PrimaryHidden
        
        self.webDisplay.allowsInlineMediaPlayback = true
        self.webDisplay.mediaPlaybackAllowsAirPlay = true
        self.webDisplay.mediaPlaybackRequiresUserAction = false
        
    
        let requestURL = NSURL(string: url)
        let request = NSURLRequest(URL: requestURL!)
        webDisplay.loadRequest(request)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}


