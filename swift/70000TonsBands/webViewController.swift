//
//  webView.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/4/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//


import UIKit

class WebViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet weak var webDisplay: UIWebView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet var swipeRight: UISwipeGestureRecognizer!
    
    @IBOutlet var swipeLeft: UISwipeGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webDisplay.delegate = self
        
        var url = getUrl()
        
        splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.PrimaryHidden
        
        self.webDisplay.allowsInlineMediaPlayback = true
        self.webDisplay.mediaPlaybackAllowsAirPlay = true
        self.webDisplay.mediaPlaybackRequiresUserAction = false

        self.activityIndicator.hidesWhenStopped = true;
        let requestURL = NSURL(string: url)
        let request = NSURLRequest(URL: requestURL!)
        
     
        self.webDisplay.loadRequest(request)

        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webViewDidStartLoad(webView: UIWebView){
        
        activityIndicator.hidden = false
        activityIndicator.startAnimating()
        
    }
    func webViewDidFinishLoad(webView: UIWebView){
        
        activityIndicator.hidden = true
        activityIndicator.stopAnimating()
    }
    
    @IBAction func goForward(sender: AnyObject) {
        webDisplay.goForward()
    }
    
    @IBAction func GoBack(sender: AnyObject) {
        webDisplay.goBack()
    }
    
    
}


