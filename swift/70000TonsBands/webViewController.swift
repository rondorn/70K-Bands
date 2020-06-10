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
        
        let url = getUrl()
        
        splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.primaryHidden
        
        self.webDisplay.allowsInlineMediaPlayback = true
        self.webDisplay.mediaPlaybackAllowsAirPlay = true
        self.webDisplay.mediaPlaybackRequiresUserAction = false

        self.activityIndicator.hidesWhenStopped = true;
        print ("Loading url of " + url)
        let requestURL = URL(string: url)
        
        ToastMessages(webMessageHelp).show(self, cellLocation: self.view.frame, heightValue: 8)
        webMessageHelp = String()
        if (requestURL != nil){
            let request = URLRequest(url: requestURL!)
            self.webDisplay.loadRequest(request)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webViewDidStartLoad(_ webView: UIWebView){
        
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
    }
    func webViewDidFinishLoad(_ webView: UIWebView){
        
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
    
    @IBAction func goForward(_ sender: AnyObject) {
        webDisplay.goForward()
    }
    
    @IBAction func GoBack(_ sender: AnyObject) {
        webDisplay.goBack()
    }
    
    
}


