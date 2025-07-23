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
        
        // Ensure back button always says "Back"
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
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
        
        updateSplitViewDisplayMode(for: view.bounds.size)
        
        //self.webDisplay.allowsInlineMediaPlayback = true
        //self.webDisplay.mediaPlaybackAllowsAirPlay = true
        //self.webDisplay.mediaPlaybackRequiresUserAction = false

        self.activityIndicator.hidesWhenStopped = true;
        print ("Loading url of " + url)
        let requestURL = URL(string: url)
        
        if (webMessageHelp.isEmpty == false){
            ToastMessages(webMessageHelp).show(self, cellLocation: self.view.frame,  placeHigh: false)
        }
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateSplitViewDisplayMode(for: size)
        }, completion: nil)
    }

    func updateSplitViewDisplayMode(for size: CGSize) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if size.width > size.height { // Landscape
                splitViewController?.preferredDisplayMode = .allVisible
            } else { // Portrait
                splitViewController?.preferredDisplayMode = .primaryHidden
            }
        }
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
        
        // Check if the loaded page is an error page
        webView.evaluateJavaScript("document.body.innerText") { [weak self] (result, error) in
            if let text = result as? String {
                self?.checkForErrorPage(text)
            }
        }
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView){
       endActivity()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!) {
        endActivity()
        print("❌ WebView failed to load: \(navigation.debugDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        endActivity()
        print("❌ WebView failed provisional navigation: \(error.localizedDescription)")
        
        // Check if this is a stats page and handle the error
        if let url = webView.url?.absoluteString, url.contains("stats.html") {
            handleStatsPageError()
        }
    }
    
    private func checkForErrorPage(_ pageText: String) {
        let lowercased = pageText.lowercased()
        
        // Check for common error indicators in the page content
        let errorIndicators = [
            "error (4",
            "error 4",
            "404",
            "403",
            "401",
            "400",
            "not found",
            "forbidden",
            "unauthorized",
            "bad request",
            "page not found",
            "access denied",
            "server error",
            "temporarily unavailable",
            "service unavailable"
        ]
        
        for indicator in errorIndicators {
            if lowercased.contains(indicator) {
                print("🚨 Detected error indicator in loaded page: '\(indicator)'")
                handleStatsPageError()
                return
            }
        }
        
        // Check if the page content is too short (likely an error page)
        if pageText.count < 50 {
            print("🚨 Loaded page content is too short (\(pageText.count) characters), likely an error page")
            handleStatsPageError()
            return
        }
    }
    
    private func handleStatsPageError() {
        print("🚨 Stats page error detected, notifying MasterViewController")
        
        // Try to get the MasterViewController and call its error handling method
        if let navigationController = self.navigationController {
            // For iPhone: MasterViewController is the root of the navigation stack
            if let masterViewController = navigationController.viewControllers.first as? MasterViewController {
                masterViewController.handleStatsPageError()
                return
            }
            
            // For iPad: MasterViewController is in the split view controller
            if let splitViewController = navigationController.splitViewController,
               let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController,
               let masterViewController = masterNavigationController.viewControllers.first as? MasterViewController {
                masterViewController.handleStatsPageError()
                return
            }
        }
        
        // Fallback: handle locally if we can't find the MasterViewController
        print("⚠️ Could not find MasterViewController, handling error locally")
        let fileManager = FileManager.default
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = documentsUrl.appendingPathComponent("stats.html")
        let oldStatsUrl = documentsUrl.appendingPathComponent("stats.html.old")
        
        if fileManager.fileExists(atPath: oldStatsUrl.path) {
            // Try to restore old stats
            do {
                if fileManager.fileExists(atPath: fileUrl.path) {
                    try fileManager.removeItem(at: fileUrl)
                }
                try fileManager.moveItem(at: oldStatsUrl, to: fileUrl)
                print("✅ Restored old stats successfully")
                
                // Reload the web view with the old stats
                let request = URLRequest(url: fileUrl)
                webDisplay.load(request)
            } catch {
                print("❌ Error restoring old stats: \(error.localizedDescription)")
                showStatsUnavailableMessage()
            }
        } else {
            // No old stats available
            showStatsUnavailableMessage()
        }
    }
    
    private func showStatsUnavailableMessage() {
        DispatchQueue.main.async {
            // Create HTML content for stats unavailable message
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Stats Unavailable</title>
                <style>
                    body {
                        background-color: #000000;
                        color: #FFFFFF;
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        margin: 0;
                        text-align: center;
                    }
                    .container {
                        padding: 40px;
                        max-width: 400px;
                    }
                    .icon {
                        font-size: 64px;
                        margin-bottom: 20px;
                        color: #797D7F;
                    }
                    .title {
                        font-size: 24px;
                        font-weight: bold;
                        margin-bottom: 16px;
                        color: #FFFFFF;
                    }
                    .message {
                        font-size: 16px;
                        line-height: 1.5;
                        color: #CCCCCC;
                        margin-bottom: 24px;
                    }
                    .subtitle {
                        font-size: 14px;
                        color: #797D7F;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="icon">⚠️</div>
                    <div class="title">Stats Unavailable</div>
                    <div class="message">The stats page encountered an error and is not available at this time.</div>
                    <div class="subtitle">Please try again later or contact support if the problem persists.</div>
                </div>
            </body>
            </html>
            """
            
            // Load the error message directly into the web view
            self.webDisplay.loadHTMLString(htmlContent, baseURL: nil)
        }
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


