//
//  WebView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 8/28/25.
//

import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}


struct IdentifiedURL: Identifiable, Equatable {
    let id: String
    let url: URL

    init(_ url: URL) {
        self.url = url
        self.id = url.absoluteString
    }

    init?(string: String) {
        guard let url = URL(string: string) else { return nil }
        self.init(url)
    }
}
