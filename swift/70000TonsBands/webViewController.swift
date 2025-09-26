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
        
        // Add close button for modal presentation
        if navigationController == nil || presentingViewController != nil {
            let closeButton = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(closeButtonTapped))
            navigationItem.leftBarButtonItem = closeButton
        } else {
            // Ensure back button always says "Back" for navigation controller context
            let backItem = UIBarButtonItem()
            backItem.title = "Back"
            self.navigationItem.backBarButtonItem = backItem
        }
        
        // Fix WebView layout for iPad landscape - ensure it takes full available space
        setupWebViewConstraints()
        
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
        print ("🎯 [STATS_DEBUG] WebView loading URL: " + url)
        let requestURL = URL(string: url)
        print ("🎯 [STATS_DEBUG] Parsed URL: \(requestURL?.absoluteString ?? "nil")")
        
        if (webMessageHelp.isEmpty == false){
            ToastMessages(webMessageHelp).show(self, cellLocation: self.view.frame,  placeHigh: false)
        }
        webMessageHelp = String()
        if (requestURL != nil){
            let request = URLRequest(url: requestURL!)
            print ("🎯 [STATS_DEBUG] WebView attempting to load request: \(request.url?.absoluteString ?? "nil")")
            self.webDisplay.load(request)
        } else {
            print ("🎯 [STATS_DEBUG] ❌ WebView failed to parse URL: \(url)")
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
            // Re-setup constraints for new orientation
            self.setupWebViewConstraints()
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
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView){
       endActivity()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!) {
        endActivity()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        endActivity()
        print("❌ WebView failed to load: \(error.localizedDescription)")
        print("❌ Failed URL: \(webView.url?.absoluteString ?? "unknown")")
        
        // Show error message to user
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Loading Error", message: "Failed to load stats page: \(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
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
    
    @objc func closeButtonTapped() {
        print("WebView Close button tapped")
        dismiss(animated: true, completion: nil)
    }
    
    /// Sets up WebView constraints to ensure it takes full available space, especially on iPad landscape
    private func setupWebViewConstraints() {
        // Remove any existing constraints that might be limiting the WebView
        webDisplay.translatesAutoresizingMaskIntoConstraints = false
        
        // Remove all existing constraints
        webDisplay.removeFromSuperview()
        view.addSubview(webDisplay)
        
        // Set up constraints to fill the entire view
        NSLayoutConstraint.activate([
            webDisplay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webDisplay.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webDisplay.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webDisplay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Ensure the activity indicator is centered
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: webDisplay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: webDisplay.centerYAnchor)
        ])
        
        print("🔧 WebView constraints set up for full screen display")
    }
}


