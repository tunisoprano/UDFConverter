//
//  UDFConverterApp.swift
//  UDFConverter
//
//  Created by Tunahan Sarı on 11.05.2026.
//

import SwiftUI

#if os(iOS)
import GoogleMobileAds
import AppTrackingTransparency
#endif

@main
struct UDFConverterApp: App {
    @StateObject private var storeManager = StoreManager()
    @StateObject private var usageLimitManager = UsageLimitManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var localizationManager = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(storeManager)
                .environmentObject(usageLimitManager)
                .environmentObject(appearanceManager)
                .environmentObject(localizationManager)
                .task {
                    await requestTrackingAndStartAds()
                }
        }
    }

    private func requestTrackingAndStartAds() async {
        #if os(iOS)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        _ = await MobileAds.shared.start()
        #endif
    }
}
