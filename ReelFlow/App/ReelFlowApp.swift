//
//  ReelFlowApp.swift
//  ReelFlow
//
//  Created by 牧云踏歌 on 2026/2/6.
//

import SwiftUI

@main
struct ReelFlowApp: App {
    @StateObject private var purchaseStore = PurchaseStore()

    var body: some Scene {
        WindowGroup {
            ContentView(purchaseStore: purchaseStore)
        }
        .defaultSize(width: 1200, height: 760)
        .commands {
            ReelFlowAppCommands(purchaseStore: purchaseStore)
        }

        Window(String(localized: "关于 ReelFlow"), id: AboutReelFlowView.windowID) {
            AboutReelFlowView(hasProAccess: purchaseStore.hasProAccess)
        }
        .defaultSize(width: 420, height: 320)
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
}

private struct ReelFlowAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var purchaseStore: PurchaseStore

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "关于 ReelFlow")) {
                openWindow(id: AboutReelFlowView.windowID)
            }
            Divider()
            Button(String(localized: purchaseStore.hasProAccess ? "ReelFlow Pro 已解锁" : "升级 Pro")) {
                purchaseStore.purchasePro()
            }
            .disabled(purchaseStore.hasProAccess || purchaseStore.isBusy || !purchaseStore.isEntitlementResolved)

            Button(String(localized: "恢复购买")) {
                purchaseStore.restorePurchases()
            }
            .disabled(purchaseStore.isBusy || !purchaseStore.isEntitlementResolved)
        }
    }
}
