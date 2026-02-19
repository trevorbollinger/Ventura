
import Foundation
import WebKit
import Combine

class GasPriceFetcher: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = GasPriceFetcher()
    
    var webView: WKWebView?
    @Published var stations: [GasStation] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    private var pendingLatitude: Double = 0.0
    private var pendingLongitude: Double = 0.0
    
    @Published var lastFetchTime: Date?
    private let cacheKey = "GasStationsCache"
    private let timeKey = "GasStationsTime"
    private let latKey = "GasStationsLat"
    private let lonKey = "GasStationsLon"
    
    // Throttle: 2 Hours
    private let cacheDuration: TimeInterval = 2 * 60 * 60
    
    override init() {
        super.init()
        // Lazy initialization of WebView moved to ensureWebView()
        
        // Load Cache
        loadCache()
    }
    
    private func ensureWebView() {
        guard webView == nil else { return }
        
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "gasData")
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"
        
        let newWebView = WKWebView(frame: .zero, configuration: config)
        newWebView.navigationDelegate = self
        self.webView = newWebView
        print("GasPriceFetcher: WKWebView lazily initialized.")
    }

    func fetchGasPrices(latitude: Double, longitude: Double, force: Bool = false) {
        // Cache Check
        if !force, let lastTime = lastFetchTime, !stations.isEmpty {
            let elapsed = Date().timeIntervalSince(lastTime)
            
            // Check distance (if user moved > 5km, refetch regardless of time)
            let lastLat = UserDefaults.standard.double(forKey: latKey)
            let lastLon = UserDefaults.standard.double(forKey: lonKey)
            
            // Basic coordinate distance approx (1 deg lat ~ 111km)
            let latDiff = abs(latitude - lastLat)
            let lonDiff = abs(longitude - lastLon)
            let movedSignificantly = (latDiff > 0.05 || lonDiff > 0.05) // Roughly 5km
            
            if elapsed < cacheDuration && !movedSignificantly {
                print("GAS FETCH SKIPPED: Using cached data (\(Int(elapsed/60)) min old). (Foreground check)")
                return
            }
        }
        
        // Prevent stacking requests
        if isLoading && !force {
            print("GAS FETCH SKIPPED: Already loading.")
            return
        }
        
        print("Starting fetchGasPrices for location: \(latitude), \(longitude)... Is Loading: \(isLoading)")
        
        ensureWebView()
        guard let webView = webView else { return }
        
        self.pendingLatitude = latitude
        self.pendingLongitude = longitude
        
        if let url = URL(string: "https://www.gasbuddy.com") {
            isLoading = true
            lastError = nil
            webView.stopLoading() // Stop any previous or background activity first
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(stations)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
            UserDefaults.standard.set(pendingLatitude, forKey: latKey)
            UserDefaults.standard.set(pendingLongitude, forKey: lonKey)
            self.lastFetchTime = Date()
            print("GAS CACHE SAVED: \(stations.count) stations.")
        } catch {
            print("GAS CACHE ERROR: Failed to save: \(error)")
        }
    }
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        self.lastFetchTime = UserDefaults.standard.object(forKey: timeKey) as? Date
        
        do {
            let cachedStations = try JSONDecoder().decode([GasStation].self, from: data)
            self.stations = cachedStations
            print("GAS CACHE LOADED: \(cachedStations.count) stations from \(lastFetchTime?.formatted() ?? "Unknown").")
        } catch {
            print("GAS CACHE ERROR: Failed to load: \(error)")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // ... (rest of method same as below but simplified or kept)
        print("WEBVIEW: didFinish loading. Injecting Fetch JS...")
        
        let jsQuery = """
        function getCookie(name) {
            const value = `; ${document.cookie}`;
            const parts = value.split(`; ${name}=`);
            if (parts.length === 2) return parts.pop().split(';').shift();
        }
        
        const csrfToken = getCookie('gbcsrf');
        console.log("Using CSRF Token: " + csrfToken);

        const payload = {
            operationName: 'LocationBySearchTerm',
            variables: { 
                fuel: 1,
                lang: 'en',
                lat: \(pendingLatitude),
                lng: \(pendingLongitude)
            },
            query: `query LocationBySearchTerm($brandId: Int, $cursor: String, $fuel: Int, $lang: String, $lat: Float, $lng: Float, $maxAge: Int, $search: String) { locationBySearchTerm(lat: $lat, lng: $lng, search: $search, priority: "locality") { countryCode displayName latitude longitude regionCode stations(brandId: $brandId, cursor: $cursor, fuel: $fuel, lat: $lat, lng: $lng, maxAge: $maxAge, priority: "locality") { count cursor { next __typename } results { address { country line1 line2 locality postalCode region __typename } badges(lang: $lang) { badgeId callToAction campaignId clickTrackingUrl description detailsImageUrl detailsImpressionTrackingUrls imageUrl impressionTrackingUrls targetUrl title __typename } brands { brandId brandingType imageUrl name __typename } distance emergencyStatus { hasDiesel { nickname reportStatus updateDate __typename } hasGas { nickname reportStatus updateDate __typename } hasPower { nickname reportStatus updateDate __typename } __typename } enterprise fuels hasActiveOutage id latitude longitude isFuelmanSite name offers { discounts { grades highlight pwgbDiscount receiptDiscount __typename } highlight id types use __typename } payStatus { isPayAvailable __typename } prices { cash { nickname postedTime price formattedPrice __typename } credit { nickname postedTime price formattedPrice __typename } discount fuelProduct __typename } priceUnit ratingsCount starRating __typename } __typename } trends { areaName country today todayLow trend __typename } __typename } }`
        };
        
        console.log("SENDING FETCH REQUEST...");
        
        fetch('/graphql', {
            method: 'POST',
            credentials: 'include',
            headers: { 
                'Content-Type': 'application/json',
                'Accept': '*/*',
                'apollo-require-preflight': 'true',
                'gbcsrf': csrfToken,
                'Origin': window.location.origin,
                'Referer': window.location.href,
                'x-requested-with': 'XMLHttpRequest'
            },
            body: JSON.stringify(payload)
        }).then(async response => {
            console.log("FETCH STATUS: " + response.status);
            const text = await response.text();
            try {
                return JSON.parse(text);
            } catch (e) {
                console.log("JSON PARSE ERROR: " + e);
                console.log("BODY START: " + text.substring(0, 100));
                window.webkit.messageHandlers.gasData.postMessage("ERROR: " + e);
                throw new Error("Failed to parse JSON: " + e);
            }
        }).then(data => {
            console.log("SUCCESS: Data received");
            window.webkit.messageHandlers.gasData.postMessage(JSON.stringify(data));
        }).catch(error => {
            console.log("FETCH ERROR: " + error);
            window.webkit.messageHandlers.gasData.postMessage("ERROR: " + error);
        });
        """
        webView.evaluateJavaScript(jsQuery) { result, error in
            if let error = error {
                print("WEBVIEW: Error evaluating JS: \(error)")
            } else {
                print("WEBVIEW: JS Injected successfully.")
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "gasData" {
            guard let jsonString = message.body as? String else { 
                print("BRIDGE: Received message but body was not a string.")
                return 
            }
            
            if jsonString.hasPrefix("ERROR:") {
                print("BRIDGE: Received JS Error: \(jsonString)")
                DispatchQueue.main.async {
                    self.lastError = jsonString.replacingOccurrences(of: "ERROR:", with: "").trimmingCharacters(in: .whitespaces)
                    self.isLoading = false
                }
                return
            }
            
            print("BRIDGE: Received Gas Data. Decoding...")
            
            guard let data = jsonString.data(using: .utf8) else { 
                print("BRIDGE: Could not convert string to data.")
                return 
            }
            
            do {
                let response = try JSONDecoder().decode(GasDataResponse.self, from: data)
                let allStations = response.data.locationBySearchTerm.stations?.results ?? []
                
                // FILTER: Only show stations with valid regular gas prices
                let validStations = allStations.filter { ($0.regularPrice ?? 0) > 0 }
                
                print("SUCCESS: Parsed \(allStations.count) stations. \(validStations.count) have valid prices.")
                
                DispatchQueue.main.async {
                    self.stations = validStations
                    self.isLoading = false
                    self.saveCache()
                    
                    // PERFORMANCE: Pause/Clear the Web View now that we have data
                    // This prevents background CPU usage from ads/trackers on the page.
                    self.webView?.evaluateJavaScript("document.body.innerHTML = ''; window.stop();") { _, _ in 
                         // print("WEBVIEW: Cleared and stopped.")
                    }
                }
            } catch {
                print("DECODE ERROR: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Failed to decode server response"
                    self.isLoading = false
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.lastError = "Connection failed"
            self.isLoading = false
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView provisional navigation failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.lastError = "Slow connection or block"
            self.isLoading = false
        }
    }
}

// MARK: - SwiftUI View Wrapper
import SwiftUI

struct WebViewContainer: UIViewRepresentable, Equatable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op to prevent reload
    }
    
    static func == (lhs: WebViewContainer, rhs: WebViewContainer) -> Bool {
        return lhs.webView === rhs.webView
    }
}

/// Isolated view that hosts the hidden WebView for gas price fetching.
/// By observing GasPriceFetcher here (instead of at VenturaApp root),
/// state changes only invalidate THIS view, not the entire app hierarchy.
struct WebViewBackground: View {
    @ObservedObject private var gasFetcher = GasPriceFetcher.shared
    
    var body: some View {
        Group {
            if let webView = gasFetcher.webView {
                WebViewContainer(webView: webView)
                    .equatable()
            }
        }
    }
}
