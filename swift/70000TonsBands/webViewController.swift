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
    
    private var loadingTimeout: Timer?
    private let loadingTimeoutInterval: TimeInterval = 30.0 // 30 seconds timeout
    
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
    
    deinit {
        // Clean up timer and observer
        loadingTimeout?.invalidate()
        webDisplay.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
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
        
        // Check if it's a network error that might be temporary
        let nsError = error as NSError
        let isNetworkError = nsError.domain == NSURLErrorDomain && (
            nsError.code == NSURLErrorNotConnectedToInternet ||
            nsError.code == NSURLErrorNetworkConnectionLost ||
            nsError.code == NSURLErrorTimedOut ||
            nsError.code == NSURLErrorCannotConnectToHost
        )
        
        DispatchQueue.main.async {
            if isNetworkError {
                // For network errors, show a retry option
                let alert = UIAlertController(title: "Network Error", message: "Unable to load stats page. Check your internet connection and try again.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                    // Retry loading the same URL
                    if let url = webView.url {
                        let request = URLRequest(url: url)
                        webView.load(request)
                    }
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(alert, animated: true)
            } else {
                // For other errors, show a simple error message
                let alert = UIAlertController(title: "Loading Error", message: "Failed to load stats page: \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            // Only end activity when progress reaches 1.0 (100%)
            if let progress = change?[.newKey] as? Double, progress >= 1.0 {
                endActivity()
            }
        }
    }

    func startActivity(){
        print ("WebView start busy Animation")
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
        // Set up timeout timer
        loadingTimeout?.invalidate()
        loadingTimeout = Timer.scheduledTimer(withTimeInterval: loadingTimeoutInterval, repeats: false) { [weak self] _ in
            print("⏰ WebView loading timeout after \(self?.loadingTimeoutInterval ?? 30) seconds")
            self?.endActivity()
            
            // Show timeout error
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Loading Timeout", message: "The stats page is taking too long to load. Please check your internet connection and try again.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                    // Retry loading the current URL
                    if let url = self?.webDisplay.url {
                        let request = URLRequest(url: url)
                        self?.webDisplay.load(request)
                    }
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self?.present(alert, animated: true)
            }
        }
    }
    
    func endActivity(){
        print ("WebView end busy Animation")
        loadingTimeout?.invalidate()
        loadingTimeout = nil
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
        // Only set up constraints if they haven't been set up already
        guard webDisplay.superview == nil || webDisplay.constraints.isEmpty else {
            print("🔧 WebView constraints already set up, skipping")
            return
        }
        
        // Remove any existing constraints that might be limiting the WebView
        webDisplay.translatesAutoresizingMaskIntoConstraints = false
        
        // Only remove from superview if it's already added
        if webDisplay.superview != nil {
            webDisplay.removeFromSuperview()
        }
        view.addSubview(webDisplay)
        
        // Set up constraints to fill the entire view
        NSLayoutConstraint.activate([
            webDisplay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webDisplay.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webDisplay.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webDisplay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Ensure the activity indicator is centered (only if not already constrained)
        if activityIndicator.constraints.isEmpty {
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: webDisplay.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: webDisplay.centerYAnchor)
            ])
        }
        
        print("🔧 WebView constraints set up for full screen display")
    }
}


