//
//  SwiftUIWebView.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Configure appearance to match app style
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("WebView navigation failed: \(error.localizedDescription)")
        }
    }
}

struct WebViewContainer: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = true
    @State private var webView: WKWebView?
    
    var body: some View {
        NavigationView {
            ZStack {
                WebView(url: url)
                    .onAppear {
                        setupWebView()
                    }
                
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Loading...")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
                }
            }
            .navigationTitle("Web View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Back") {
                        if let webView = webView, webView.canGoBack {
                            webView.goBack()
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            webView?.goBack()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(webView?.canGoBack != true)
                        
                        Button(action: {
                            webView?.goForward()
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(webView?.canGoForward != true)
                        
                        Button(action: {
                            webView?.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
    }
    
    private func setupWebView() {
        // Configure web view appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Convenience Initializers

extension WebView {
    init(urlString: String) {
        self.url = URL(string: urlString) ?? URL(string: "https://www.70000tons.com")!
    }
}

extension WebViewContainer {
    init(urlString: String) {
        self.url = URL(string: urlString) ?? URL(string: "https://www.70000tons.com")!
    }
}

#Preview {
    WebViewContainer(urlString: "https://www.70000tons.com")
}
