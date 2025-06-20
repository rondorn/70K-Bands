//
//  webView.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/4/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//


import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate {

    @IBOutlet weak var webDisplay: WKWebView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Style the navigation bar to match the rest of the app
        if let navController = self.navigationController {
            navController.navigationBar.barStyle = .blackTranslucent
            navController.navigationBar.tintColor = .white
            navController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            navController.navigationBar.barTintColor = .black
            navController.view.backgroundColor = .black
        }
        self.view.backgroundColor = .black
        
        webDisplay.navigationDelegate = self
        
        webDisplay.allowsBackForwardNavigationGestures = true
        webDisplay.addSubview(activityIndicator)
        let url = getUrl()
        
        splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.primaryHidden
    

        //self.webDisplay.allowsInlineMediaPlayback = true
        //self.webDisplay.mediaPlaybackAllowsAirPlay = true
        //self.webDisplay.mediaPlaybackRequiresUserAction = false

        self.activityIndicator.hidesWhenStopped = true;
        print ("Loading url of " + url)
        let requestURL = URL(string: url)
        
        ToastMessages(webMessageHelp).show(self, cellLocation: self.view.frame,  placeHigh: false)
        webMessageHelp = String()
        if (requestURL != nil){
            let request = URLRequest(url: requestURL!)
            self.webDisplay.load(request)
        }
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.gray

        var swipeRight = UISwipeGestureRecognizer(target: self, action: "swipeRightAction:")
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        webDisplay.addGestureRecognizer(swipeRight)
         
        var swipeLeft = UISwipeGestureRecognizer(target: self, action: "swipeLeftAction:")
        swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
        webDisplay.addGestureRecognizer(swipeLeft)
        
        webDisplay.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webViewDidStartLoad(_ webView: UIWebView){
        startActivity()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        startActivity()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        endActivity()
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView){
       endActivity()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!) {
        endActivity()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            endActivity()
        }
    }

    func startActivity(){
        print ("WebView start busy Animation")
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    
    func endActivity(){
        print ("WebView end busy Animation")
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
    
    @IBAction func swipeRightAction(_ sender: Any) {
        print ("WebView Go Back")
        webDisplay.goBack()
    }

    @IBAction func swipeLeftAction(_ sender: Any) {
        print ("WebView Go Forward")
        webDisplay.goForward()
    }
}


