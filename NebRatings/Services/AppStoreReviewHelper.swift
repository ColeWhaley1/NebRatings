//
//  AppStoreReviewHelper.swift
//  NebRatings
//
//  Handles in-app review prompts and opening the App Store review page.
//

import StoreKit
import SwiftUI
import UIKit

enum AppStoreReviewHelper {
    private static let lastReviewRequestDateKey = "lastAppReviewRequestDate"
    private static let minimumReviewsBeforePrompt = 3
    private static let minimumDaysBetweenPrompts = 30
    
    /// App Store ID from Info.plist (set via Config.xcconfig / Config.local.xcconfig).
    /// Add APP_STORE_ID = your_numeric_id to Config.local.xcconfig
    private static var appStoreID: String {
        Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String ?? ""
    }
    
    // MARK: - In-App Review Prompt (SKStoreReviewController)
    
    /// Call after positive user actions (e.g., after saving a review).
    /// Apple may or may not display the prompt; we limit requests to avoid over-prompting.
    static func maybeRequestInAppReview(userReviewCount: Int) {
        guard shouldRequestInAppReview(userReviewCount: userReviewCount) else { return }
        
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        
        recordReviewRequestDate()
        SKStoreReviewController.requestReview(in: scene)
    }
    
    private static func shouldRequestInAppReview(userReviewCount: Int) -> Bool {
        guard userReviewCount >= minimumReviewsBeforePrompt else { return false }
        
        let lastRequest = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date
        if let last = lastRequest {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            guard daysSince >= minimumDaysBetweenPrompts else { return false }
        }
        
        return true
    }
    
    private static func recordReviewRequestDate() {
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
    }
    
    // MARK: - Direct App Store Link
    
    /// Opens the App Store write-review page for this app.
    /// Works on device; simulator may open Safari or fail gracefully.
    static func openAppStoreReviewPage() {
        let id = appStoreID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.allSatisfy({ $0.isNumber }) else { return }
        
        let urlString = "https://apps.apple.com/app/id\(id)?action=write-review"
        guard let url = URL(string: urlString) else { return }

        UIApplication.shared.open(url)
    }

    /// Opens this app's App Store product page (used by the "update available"
    /// prompt). Works on device; the simulator may open Safari or no-op.
    static func openAppStorePage() {
        let id = appStoreID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.allSatisfy({ $0.isNumber }) else { return }

        let urlString = "https://apps.apple.com/app/id\(id)"
        guard let url = URL(string: urlString) else { return }

        UIApplication.shared.open(url)
    }
}
