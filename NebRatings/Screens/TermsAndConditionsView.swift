//
//  TermsAndConditionsView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI
import WebKit

struct TermsAndConditionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        ZStack {
            if let error = loadError {
                ContentUnavailableView(
                    "Unable to Load Terms and Conditions",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                TermsWebViewRepresentable(isLoading: $isLoading, loadError: $loadError)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        }
        .navigationTitle("Terms and Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsWebViewRepresentable: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var loadError: Error?
    @Environment(\.colorScheme) var colorScheme
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if isLoading && loadError == nil {
            loadHTMLContent(in: webView)
        }
        
        // Update background color based on color scheme
        if colorScheme == .dark {
            webView.backgroundColor = .black
            webView.isOpaque = false
        } else {
            webView.backgroundColor = .white
            webView.isOpaque = true
        }
    }
    
    func loadHTMLContent(in webView: WKWebView) {
        var htmlString: String?
        var baseURL: URL?
        
        // Try to load from LegalDocs subdirectory first
        if let path = Bundle.main.path(forResource: "termsAndConditions", ofType: "html", inDirectory: "LegalDocs") {
            htmlString = try? String(contentsOfFile: path, encoding: .utf8)
            baseURL = Bundle.main.bundleURL.appendingPathComponent("LegalDocs")
        }
        
        // If not found, try to load from root
        if htmlString == nil, let path = Bundle.main.path(forResource: "termsAndConditions", ofType: "html") {
            htmlString = try? String(contentsOfFile: path, encoding: .utf8)
            baseURL = Bundle.main.bundleURL
        }
        
        guard let htmlString = htmlString else {
            loadError = NSError(domain: "TermsAndConditionsView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Terms and conditions file not found in app bundle"])
            isLoading = false
            return
        }
        
        webView.loadHTMLString(htmlString, baseURL: baseURL ?? Bundle.main.bundleURL)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var loadError: Error?
        
        init(isLoading: Binding<Bool>, loadError: Binding<Error?>) {
            _isLoading = isLoading
            _loadError = loadError
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadError = error
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadError = error
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        TermsAndConditionsView()
    }
}

